import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel

    @State private var draftHost: String = ""
    @State private var showHelp = false
    @State private var showPreview = false
    @FocusState private var hostFocused: Bool

    var body: some View {
        ZStack {
            AppBackdrop()

            ScrollArea {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    header
                    statusCard
                    previewCard
                    stepsSection
                    addressSection
                    helpSection
                    footer
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 64)     // 让内容从顶部玻璃按钮下方开始
                .padding(.bottom, 148) // 底部操作区留白，内容可滚到玻璃之下
            }
        }
        .overlay(alignment: .topTrailing) {
            GlassCluster(spacing: 10) {
                GlassIconButton(systemImage: "slider.horizontal.3", label: "设置") {
                    model.showSettings = true
                }
            }
            .padding(.trailing, Metrics.screenPadding)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            bottomControls
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 10)
        }
        .onAppear { draftHost = model.host }
    }

    // MARK: - 标题

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.gapM) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Theme.accentDeep.opacity(0.5), radius: 16, y: 8)
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("P4-CAN 控制器")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Universal Unlock · 车载仪表盘")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 连接状态

    private var statusCard: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 13) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 5)
                            .blur(radius: 3)
                    }
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if case .probing = model.state {
                    ProgressView()
                        .tint(Theme.accent)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("连接状态：\(statusTitle)。\(statusDetail)")
    }

    private var statusColor: Color {
        switch model.state {
        case .probing: return Theme.warn
        case .online: return Theme.accent
        case .offline: return Theme.danger
        }
    }

    private var statusTitle: String {
        switch model.state {
        case .probing: return "正在查找设备"
        case .online: return "已连接"
        case .offline: return "未连接"
        }
    }

    private var statusDetail: String {
        switch model.state {
        case .probing:
            return "正在探测 \(model.normalizedHost)"
        case .online:
            return "\(model.normalizedHost) · 正在加载仪表盘"
        case .offline(let reason):
            return reason
        }
    }

    // MARK: - 连接步骤

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Metrics.gapS) {
            sectionTitle("连接步骤")

            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    stepRow(1, "打开「设置」→「无线局域网」", "Open Settings → Wi-Fi")
                    rowDivider
                    stepRow(2, "选择热点 \(AppModel.apHint)", "密码 \(AppModel.apPassword)", mono: true)
                    rowDivider
                    stepRow(3, "回到本 App，自动进入仪表盘", "无需手动输入地址")
                }
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    private func stepRow(_ index: Int, _ title: String, _ detail: String, mono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
                .background(Theme.accent.opacity(0.14), in: Circle())
                .overlay { Circle().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 0.8) }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(mono ? .footnote.monospaced().weight(.semibold) : .footnote)
                    .foregroundStyle(mono ? Theme.accent : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 设备地址

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: Metrics.gapS) {
            sectionTitle("设备地址")

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        TextField("192.168.4.1", text: $draftHost)
                            .font(.body.monospaced())
                            .foregroundStyle(.primary)
                            #if canImport(UIKit)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($hostFocused)
                            .onSubmit(applyHost)
                            .padding(.horizontal, 14)
                            .frame(minHeight: Metrics.minTap)
                            .background(
                                Theme.well,
                                in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 0.8)
                            }
                            .accessibilityLabel("设备地址")

                        Button("连接", action: applyHost)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .tint(Theme.accent)
                    }

                    HStack(spacing: 8) {
                        Text("AP 模式默认 192.168.4.1；接入路由器后改成它的局域网 IP。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Button("恢复默认") {
                            model.resetHost()
                            draftHost = AppModel.defaultHost
                            model.probeOnce()
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 界面预览

    /// 设备不在手边时的入口：用 App 自带的示例页看仪表盘长什么样
    @ViewBuilder
    private var previewCard: some View {
        #if os(iOS)
        SurfaceCard(padding: 0) {
            Button {
                showPreview = true
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("界面预览")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("设备不在手边也能看仪表盘长什么样（示例数据）")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .frame(minHeight: Metrics.minTap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("界面预览。用示例数据查看仪表盘界面")
        }
        .fullScreenCover(isPresented: $showPreview) {
            PreviewView(zhEnabled: model.zhEnabled)
        }
        #endif
    }

    // MARK: - 排查

    private var helpSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showHelp.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "questionmark.circle")
                            .font(.body.weight(.medium))
                            .symbolRenderingMode(.hierarchical)
                        Text("一直连不上？")
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .rotationEffect(.degrees(showHelp ? 180 : 0))
                    }
                    .foregroundStyle(.primary)
                    .frame(minHeight: Metrics.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("一直连不上？展开排查建议")
                .accessibilityHint(showHelp ? "已展开" : "已收起")

                if showHelp {
                    VStack(alignment: .leading, spacing: 14) {
                        helpItem("设备没上电", "P4-CAN 需要 12V 供电，插上线束后指示灯应亮起。")
                        helpItem("热点没出现", "首次开机 AP 默认开启；改过 Wi-Fi 配置需长按复位键回 AP 模式。")
                        helpItem("连上了打不开", "iOS 提示「无互联网连接」时选「保持连接」，不要断开。")
                        helpItem("IP 被改过", "在上方「设备地址」填实际 IP 后点连接。")
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func helpItem(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(.tertiary)
                .frame(width: 4, height: 4)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App 1.3.0 (4) · 固件 P4-CAN Universal v3.29.3")
            Text("界面由设备自带网页提供，本 App 仅作原生外壳")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 底部操作（控制层）

    private var bottomControls: some View {
        GlassCluster(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ActionButton(
                    title: "打开无线局域网设置",
                    systemImage: "wifi",
                    emphasis: .primary,
                    fullWidth: true,
                    action: openWiFiSettings
                )

                GlassIconButton(systemImage: "arrow.clockwise", label: "重新探测设备") {
                    model.probeOnce()
                }
            }
            // 两个控件同为 controlHeight，锁住高度后高度与中心线都对得上
            .frame(height: Metrics.controlHeight)
        }
    }

    // MARK: - 组件

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.leading, 6)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 动作

    private func applyHost() {
        let value = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        hostFocused = false
        model.host = value
        model.probeOnce()
    }

    private func openWiFiSettings() {
        #if canImport(UIKit)
        tryOpen(["App-Prefs:root=WIFI", "App-Prefs:WIFI", "prefs:root=WIFI"], at: 0)
        #endif
    }

    private func tryOpen(_ list: [String], at index: Int) {
        guard index < list.count, let url = URL(string: list[index]) else {
            #if canImport(UIKit)
            if let fallback = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(fallback)
            }
            #endif
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok { self.tryOpen(list, at: index + 1) }
        }
        #endif
    }
}

#Preview {
    ConnectView().environmentObject(AppModel())
}
