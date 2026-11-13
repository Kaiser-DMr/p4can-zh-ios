import SwiftUI
import WebKit

/// 离线界面预览。
///
/// 没有设备时也能看仪表盘长什么样：加载 App 自带的 `preview.html`
/// （我们自己写的示例页面，不联网、不发任何 CAN 帧），页面上标了「DEMO · 示例数据」。
/// 中文仍然走 `zh-bilingual.js` 注入，所以开关「中文界面」时这里也会跟着变。
struct PreviewView: View {

    /// 跟 App 设置里的语言开关联动
    var zhEnabled: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            PreviewWebView(zhEnabled: zhEnabled)
                .ignoresSafeArea()
            closeButton
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                // 视觉仍是 36pt 胶囊，命中区补到 HIG 要求的 44pt
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.16), lineWidth: 0.8) }
                .frame(width: Metrics.minTap, height: Metrics.minTap)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭预览")
    }
}

// MARK: - 网页容器

private struct PreviewWebView: UIViewRepresentable {

    var zhEnabled: Bool

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        // 预览不落任何缓存，避免和真实页面的 localStorage 混在一起
        cfg.websiteDataStore = .nonPersistent()
        // 注意：这里不加 p4canApp 消息通道，补丁就不会往示例页里插「P4-CAN App」那一行
        DeviceWebView.installZH(into: cfg.userContentController, enabled: zhEnabled)

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        if let file = Bundle.main.url(forResource: "preview", withExtension: "html") {
            webView.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(Self.missingPage, baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// 打包时漏了资源也不至于白屏
    private static let missingPage = """
    <html><body style="margin:0;background:#0B0D11;color:#8C8C88;font:15px -apple-system;
    display:flex;align-items:center;justify-content:center;height:100vh;text-align:center">
    <div>预览页资源缺失<br><span style="font-size:12px">preview.html not bundled</span></div>
    </body></html>
    """
}
