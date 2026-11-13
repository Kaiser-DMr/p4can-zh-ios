import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    @State private var banner: String?
    @State private var settingsHint = false

    /// 只要连上过就一直保留仪表盘：设备偶发超时不该把页面销毁重载。
    private var showsDashboard: Bool { model.state.isOnline || model.hasBeenOnline }

    /// 引导页跟随用户选择的外观；进入仪表盘后固定深色——
    /// 设备网页本身是深色的，浅色状态栏压上去读不清。
    private var activeScheme: ColorScheme? {
        if showsDashboard { return .dark }
        return (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    /// 连上过之后探活失败：只提示，不卸载页面
    private var probeFailure: String? {
        guard model.hasBeenOnline, case .offline(let reason) = model.state else { return nil }
        return reason
    }

    var body: some View {
        ZStack {
            Theme.base.ignoresSafeArea()

            if showsDashboard {
                webLayer
                    .transition(.opacity)
            } else {
                ConnectView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showsDashboard)
        .preferredColorScheme(activeScheme)
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
        .onAppear {
            model.startProbing()
            model.applyIdleTimer()
        }
        .onChange(of: scenePhase) { phase in
            // 后台不轮询：以前进后台也每 3 秒发一次请求，耗电且回前台立刻
            // 触发一次状态翻转。回前台先主动探一次，不必干等一个周期。
            if phase == .active {
                model.startProbing()
                model.probeOnce()
            } else {
                model.stopProbing()
            }
        }
    }

    // MARK: - 网页（内容层）

    private var webLayer: some View {
        DeviceWebView(
            url: model.baseURL,
            reloadToken: model.reloadToken,
            zhEnabled: model.zhEnabled,
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
                    failureBanner(msg, actionTitle: "重试") {
                        banner = nil
                        model.reload()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if let msg = probeFailure {
                    failureBanner(msg, actionTitle: "重新探测") {
                        model.probeOnce()
                    }
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
        .animation(.easeInOut(duration: 0.22), value: probeFailure)
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

    /// 失败提示条。整条是容器而不是合并元素——里面那个按钮是唯一的恢复入口，
    /// `.combine` 会把它的语义和 action 一起吞掉，VoiceOver 滑得到、点不动。
    private func failureBanner(_ msg: String,
                               actionTitle: String,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.warn)
                .accessibilityHidden(true)

            Text(msg)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Button(actionTitle, action: action)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
                // 命中区补到 44pt：文字本身只有约 16pt 高
                .frame(minWidth: 44, minHeight: Metrics.minTap)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: Metrics.minTap)
        .glassSurface(.capsule)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    RootView().environmentObject(AppModel())
}
