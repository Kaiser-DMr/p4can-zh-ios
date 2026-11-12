import SwiftUI
import AppKit

// 在 macOS 上用 ImageRenderer 渲染真实的 SwiftUI 视图，
// 用于在没有 iOS 模拟器的情况下检查布局、对比度与玻璃质感。
// 仅作为开发期预览工具，不参与 App 打包。

@MainActor
enum Harness {
    static func render<V: View>(_ view: V,
                                width: CGFloat,
                                height: CGFloat,
                                scale: CGFloat,
                                name: String) {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = scale
        renderer.isOpaque = true

        guard let cgImage = renderer.cgImage else {
            print("!! 渲染失败: \(name)")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }

        let out = URL(fileURLWithPath: "Preview/out/\(name).png")
        try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: out)
        print("wrote \(out.path)  \(cgImage.width)x\(cgImage.height)")
    }

    static func screen<V: View>(_ content: V,
                                typeSize: DynamicTypeSize,
                                scheme: ColorScheme = .dark) -> some View {
        content
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, typeSize)
            .environment(\.p4StaticLayout, true)   // ImageRenderer 画不出 ScrollView
    }
}

MainActor.assumeIsolated {
    let model = AppModel()
    model.host = AppModel.defaultHost

    let base = ConnectView().environmentObject(model)

    Harness.render(Harness.screen(base, typeSize: .large),
                   width: 393, height: 852, scale: 3, name: "connect-default")

    // 浅色：纯色磨砂底 + 玻璃控件的对比度
    Harness.render(Harness.screen(base, typeSize: .large, scheme: .light),
                   width: 393, height: 852, scale: 3, name: "connect-light")

    // 无障碍：辅助功能大字号，检查是否截断/溢出
    Harness.render(Harness.screen(base, typeSize: .accessibility2),
                   width: 393, height: 852, scale: 3, name: "connect-ax2")

    // 小屏机型
    Harness.render(Harness.screen(base, typeSize: .large),
                   width: 320, height: 568, scale: 2, name: "connect-se")

    Harness.render(Harness.screen(base, typeSize: .accessibility5),
                   width: 320, height: 568, scale: 2, name: "connect-se-ax5")
}
