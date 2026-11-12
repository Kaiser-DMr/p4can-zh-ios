import SwiftUI
import WebKit

/// macOS 预览用的网页容器。
/// iOS 那边是 `UIViewRepresentable`，AppKit 上换成 `NSViewRepresentable`，
/// 目标一样：把设备自带的仪表盘原样嵌进来，让预览里看到的就是真机"已连接"后的画面。
struct DeviceWebPane: NSViewRepresentable {

    let url: URL
    let reloadToken: Int
    @Binding var isLoading: Bool
    var onFail: (String) -> Void
    var onAppSettings: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()
        cfg.userContentController.add(context.coordinator, name: "p4canApp")

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        web.allowsBackForwardNavigationGestures = false

        context.coordinator.web = web
        context.coordinator.load(url, token: reloadToken)
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(url: url, token: reloadToken)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: DeviceWebPane
        weak var web: WKWebView?
        private var lastURL: URL?
        private var lastToken: Int

        init(_ parent: DeviceWebPane) {
            self.parent = parent
            self.lastToken = parent.reloadToken
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "p4canApp" else { return }
            DispatchQueue.main.async { self.parent.onAppSettings() }
        }

        func load(_ url: URL, token: Int) {
            lastURL = url
            lastToken = token
            web?.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8))
        }

        func sync(url: URL, token: Int) {
            if url != lastURL { load(url, token: token); return }
            if token != lastToken {
                lastToken = token
                if let w = web, w.url != nil { w.reload() } else { load(url, token: token) }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(error)
        }

        private func fail(_ error: Error) {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onFail(AppModel.describe(error))
            }
        }
    }
}

/// "已连接"状态的整屏：网页铺满，不叠任何浮动按钮。
/// 原生设置由网页里注入的 `P4-CAN App` 行回调打开，版式与 `RootView.webLayer` 一致。
struct ConnectedScreen: View {
    @EnvironmentObject private var model: AppModel
    let host: String

    @State private var isLoading = false
    @State private var banner: String?
    @State private var token = 0

    private var url: URL { URL(string: "http://\(host)/")! }

    var body: some View {
        DeviceWebPane(
            url: url,
            reloadToken: token,
            isLoading: $isLoading,
            onFail: { banner = $0 },
            onAppSettings: { model.showSettings = true }
        )
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) {
            if let msg = banner {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                    Text(msg).font(.footnote).lineLimit(2)
                    Spacer(minLength: 6)
                    Button("重试") { banner = nil; token &+= 1 }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: Metrics.minTap)
                .glassSurface(.capsule)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: banner)
    }
}
