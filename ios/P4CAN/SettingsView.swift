import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    @State private var hostDraft: String = ""
    @State private var clearing = false
    @State private var cleared = false

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                appearanceSection
                languageSection
                deviceSection
                displaySection
                webSection
                aboutSection
            }
            #if os(macOS)
            .formStyle(.grouped)   // 桌面预览用分组样式，贴近 iOS 的 inset grouped
            #endif
            .scrollContentBackground(.hidden)
            .background(Theme.base.opacity(scheme == .dark ? 0.45 : 0.30))
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.body.weight(.semibold))
                        .tint(Theme.accent)
                }
            }
            .onAppear { hostDraft = model.host }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .p4SheetCornerRadius(Metrics.sheetRadius)
        .p4SheetBackground()
        .preferredColorScheme(appearance.colorScheme)
    }

    // MARK: - 状态

    private var statusSection: some View {
        Section {
            HStack(spacing: 11) {
                Circle()
                    .fill(model.state.isOnline ? Theme.accent : Theme.danger)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)

                Text(model.state.isOnline ? "已连接" : "未连接")
                    .font(.body.weight(.medium))

                Spacer()

                Text(model.normalizedHost)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: Metrics.minTap)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(model.state.isOnline ? "已连接 \(model.normalizedHost)" : "未连接")
        } header: {
            Text("状态")
        }
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        Section {
            Picker("外观", selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases) { item in
                    Text(item.title).tag(item.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(minHeight: Metrics.minTap)
            .accessibilityLabel("外观")
        } header: {
            Text("外观")
        } footer: {
            Text("背景为纯色磨砂玻璃，浅色与深色各有一套配色。连上设备查看仪表盘时固定使用深色——设备网页本身是深色的，浅色状态栏会看不清。")
        }
    }

    // MARK: - 语言

    private var languageSection: some View {
        Section {
            Toggle(isOn: $model.zhEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("中文界面")
                        .font(.body)
                    Text("由 App 注入网页，不影响固件")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            .frame(minHeight: Metrics.minTap)
            .disabled(!ZhPatch.isAvailable)
            .accessibilityHint("关闭后显示设备原本的英文界面")
        } header: {
            Text("语言")
        } footer: {
            Text(ZhPatch.isAvailable
                 ? "原厂英文固件也能显示中文：App 加载网页后自己补一层中文注释，不改固件、不影响任何车辆功能。关掉这个开关就是原始的英文界面。若固件本身已内置汉化，此处开关不起作用。"
                 : "当前安装包内没有附带汉化脚本，界面语言完全由固件决定。")
        }
    }

    // MARK: - 设备

    private var deviceSection: some View {
        Section {
            HStack(spacing: 12) {
                Text("地址")
                    .font(.body)

                Spacer()

                TextField("192.168.4.1", text: $hostDraft)
                    .font(.body.monospaced())
                    .multilineTextAlignment(.trailing)
                    #if canImport(UIKit)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onSubmit(apply)
                    .accessibilityLabel("设备地址")
            }
            .frame(minHeight: Metrics.minTap)

            Button("保存并重新连接", action: apply)
                .foregroundStyle(Theme.accent)
                .frame(minHeight: Metrics.minTap)

            Button("恢复默认 192.168.4.1") {
                hostDraft = AppModel.defaultHost
                apply()
            }
            .foregroundStyle(.secondary)
            .frame(minHeight: Metrics.minTap)
        } header: {
            Text("设备")
        } footer: {
            Text("AP 模式下默认 192.168.4.1；接入路由器后可改成设备的局域网 IP。")
        }
    }

    // MARK: - 显示

    private var displaySection: some View {
        Section {
            Toggle(isOn: $model.keepAwake) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("保持屏幕常亮")
                        .font(.body)
                    Text("仪表盘运行时阻止自动锁屏")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            .frame(minHeight: Metrics.minTap)
        } header: {
            Text("显示")
        }
    }

    // MARK: - 网页

    private var webSection: some View {
        Section {
            Button {
                clearing = true
                Task {
                    await model.clearWebCache()
                    clearing = false
                    withAnimation(.easeInOut(duration: 0.2)) { cleared = true }
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    withAnimation(.easeInOut(duration: 0.2)) { cleared = false }
                }
            } label: {
                HStack {
                    Text(cleared ? "已清除，正在重新加载" : "清除网页缓存")
                        .foregroundStyle(cleared ? Theme.accent : Color.primary)
                    Spacer()
                    if clearing {
                        ProgressView()
                    }
                }
                .frame(minHeight: Metrics.minTap)
            }
            .disabled(clearing)

            Button {
                model.reload()
                dismiss()
            } label: {
                Text("重新加载仪表盘")
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: Metrics.minTap)
            }
        } header: {
            Text("网页")
        } footer: {
            Text("清除缓存会丢掉网页里保存的界面偏好，设备端的车辆配置不受影响。")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("App 版本") {
                Text("1.3.0 (4)").foregroundStyle(.secondary)
            }
            LabeledContent("适配固件") {
                Text("v3.29.3").foregroundStyle(.secondary)
            }
            LabeledContent("探测次数") {
                Text("\(model.probeCount)").foregroundStyle(.secondary).monospacedDigit()
            }
        } header: {
            Text("关于")
        } footer: {
            Text("本 App 是设备自带网页的原生外壳，不含任何车辆控制逻辑；功能与安全策略均由 P4-CAN 硬件与固件决定。")
        }
    }

    private func apply() {
        let value = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        model.host = value
        model.probeOnce()
    }
}

#Preview {
    SettingsView().environmentObject(AppModel())
}
