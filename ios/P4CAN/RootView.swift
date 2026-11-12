import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    @State private var isLoading = false
    @State private var banner: String?
    @State private var settingsHint = false

    /// 引导页跟随用户选择的外观；进入仪表盘后固定深色——
    /// 设备网页本身是深色的，浅色状态栏压上去读不清。
    private var activeScheme: ColorScheme? {
        if model.state.isOnline { return .dark }
        return (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    var body: some View {
        ZStack {
            Theme.base.ignoresSafeArea()

            if model.state.isOnline {
                webLayer
                    .transition(.opacity)
            } else {
                ConnectView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.state.isOnline)
        .preferredColorScheme(activeScheme)
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
        .onAppear {
            model.startProbing()
            model.applyIdleTimer()
        }
    }

    // MARK: - 网页（内容层）

    private var webLayer: some View {
        DeviceWebView(
            url: model.baseURL,
            reloadToken: model.reloadToken,
            zhEnabled: model.zhEnabled,
            isLoading: $isLoading,
            onNavigationFailed: { msg in banner = msg },
            onAppSettings: { model.showSettings = true },
            onInjectedRow: { found in
                guard !found else { return }
                withAnimation(.easeOut(duration: 0.2)) { settingsHint = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    withAnimation(.easeIn(duration: 0.3)) { settingsHint = false }
                }
            }
        )
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: model.reloadToken) { _ in banner = nil }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let msg = banner {
                    failureBanner(msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if settingsHint {
                    settingsHintCapsule
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.22), value: banner)
    }

    // MARK: - 控制层

    // 连接后不再在页面上叠浮动按钮：设备网页自带悬浮底部导航和右侧开关，
    // 任何固定位置都会压住控件。原生设置走网页里注入的 "P4-CAN App" 行，
    // 重新加载走下拉刷新，两者都不占版面。
    // 原厂固件没有那一行，由 DeviceWebView 探测后启用"长按 0.7 秒"，
    // 这里只负责飘一次提示，告诉用户手势在哪。

    private var settingsHintCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.footnote.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)

            Text("长按页面可打开 App 设置")
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: Metrics.minTap)
        .glassSurface(.capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("长按页面可以打开应用设置")
    }

    private func failureBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.warn)

            Text(msg)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Button("重试") {
                banner = nil
                model.reload()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Metrics.minTap)
        .glassSurface(.capsule)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RootView().environmentObject(AppModel())
}
