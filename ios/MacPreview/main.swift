import SwiftUI
import AppKit

// macOS 运行预览：同一套 SwiftUI 视图，真窗口里跑起来。
// macOS 26+ 会用与 iOS 26 相同的 Liquid Glass 合成，因此这里能直接看到
// glassEffect 的实时效果（折射、边缘高光、按下形变），而不是离屏渲染的空白。
// 仅作开发期预览，不参与 iOS 打包。

@MainActor
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 系统会记住上次窗口位置；换过显示器/拔掉外接屏后窗口可能落在屏幕外，
        // 那样 screencapture 抓到的是空缓存（全黑）。每次启动都摆回主屏中央。
        DispatchQueue.main.async {
            guard let win = NSApp.windows.first(where: { $0.isVisible }),
                  let screen = NSScreen.main else { return }
            let frame = win.frame
            let visible = screen.visibleFrame
            win.setFrameOrigin(NSPoint(
                x: visible.midX - frame.width / 2,
                y: visible.midY - frame.height / 2
            ))
            win.makeKeyAndOrderFront(nil)
        }

        // 窗口合成自检：SwiftUI 的内容在 CALayer 里，层数够多说明确实画出来了。
        // 进程内无法把 SwiftUI 内容抓成位图（由窗口服务器合成），故只做结构校验。
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let win = NSApp.windows.first(where: { $0.isVisible }),
                  let view = win.contentView else {
                Self.log("no visible window")
                return
            }
            let subviews = Self.describe(view, depth: 0)
            Self.log("window \(Int(win.frame.width))x\(Int(win.frame.height)) "
                     + "subviews=\(view.subviews.count) sublayers=\(view.layer?.sublayers?.count ?? 0)")
            Self.log(subviews)
        }
    }

    static func describe(_ v: NSView, depth: Int) -> String {
        guard depth < 4 else { return "" }
        var out = String(repeating: "  ", count: depth)
            + "\(type(of: v)) \(Int(v.bounds.width))x\(Int(v.bounds.height)) "
            + "layers=\(v.layer?.sublayers?.count ?? 0)\n"
        for sub in v.subviews { out += describe(sub, depth: depth + 1) }
        return out
    }

    static func log(_ s: String) {
        let line = "[\(Date())] \(s)\n"
        let url = URL(fileURLWithPath: "/tmp/p4can-preview.log")
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct P4CANPreviewApp: App {
    @NSApplicationDelegateAdaptor(PreviewDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("P4CAN 运行预览") {
            PreviewRoot()
                .frame(width: 393, height: 900)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct PreviewRoot: View {
    @StateObject private var model = AppModel()
    @AppStorage("previewMode") private var mode = 0
    @AppStorage("previewSheet") private var openSheet = false
    @AppStorage("previewDark") private var dark = true
    /// 演示设备地址：本地模拟器默认 127.0.0.1:8899
    @AppStorage("previewHost") private var host = "127.0.0.1:8899"

    var body: some View {
        VStack(spacing: 0) {
            strip
            ZStack {
                if mode == 2 {
                    // 已连接：真实仪表盘网页（无浮动按钮，原生入口在网页设置页里）
                    ConnectedScreen(host: host)
                        .environmentObject(model)
                } else {
                    ConnectView()
                        .environmentObject(model)
                        // macOS 没有 Home Indicator 区，补 34pt 让底部玻璃条
                        // 与 iPhone 上的实际位置一致，便于比对版式。
                        .safeAreaPadding(.bottom, 34)
                }
            }
            .frame(width: 393, height: 852)
            .clipped()
        }
        .background(Color.black)
        .environment(\.colorScheme, dark ? .dark : .light)
        .preferredColorScheme(dark ? .dark : .light)
        .onAppear {
            applyAppearance()
            apply()
            if openSheet {
                openSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.showSettings = true }
            }
        }
        .onChange(of: dark) { _ in applyAppearance() }
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .environmentObject(model)
                // sheet 在 macOS 上是独立窗口，不继承外层的环境值，这里补一次
                .environment(\.colorScheme, dark ? .dark : .light)
                .preferredColorScheme(dark ? .dark : .light)
        }
    }

    /// macOS 上只靠 `preferredColorScheme` 不一定改到窗口外观，
    /// 而 `Theme` 里的动态色是按 NSAppearance 解析的，因此显式设置一次。
    private func applyAppearance() {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }

    private var strip: some View {
        HStack(spacing: 10) {
            Text("预览")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $mode) {
                Text("探测中").tag(0)
                Text("未连接").tag(1)
                Text("已连接").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .onChange(of: mode) { _ in apply() }

            Spacer(minLength: 0)

            if mode == 2 {
                TextField("地址", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 130)
            }

            Button {
                dark.toggle()
            } label: {
                Image(systemName: dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(dark ? "切到浅色" : "切到深色")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func apply() {
        switch mode {
        case 1: model.previewState(.offline("连不上设备，请确认已连上 P4-CAN 热点"))
        case 2: model.previewState(.online)
        default: model.previewState(.probing)
        }
    }
}
