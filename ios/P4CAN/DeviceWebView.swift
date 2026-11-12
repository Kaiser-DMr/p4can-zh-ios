import SwiftUI
import WebKit

/// 把设备自带的网页仪表盘嵌入原生容器。
/// 保持 localStorage / cookie 持久化，刷新用下拉手势。
///
/// 原生入口不在页面上浮动按钮——设备网页自带悬浮底部导航与右侧开关，
/// 叠一层玻璃按钮必然压住控件。改为在网页"设置 → 系统"里注入一行
/// `P4-CAN App`，点击后通过 `p4canApp` 消息通道回调到原生。
///
/// 若设备跑的是原厂固件（没打汉化补丁），那一行不存在，此时退回
/// "长按页面 0.7 秒"的手势入口，保证任何固件下都能进 App 设置。
struct DeviceWebView: UIViewRepresentable {

    let url: URL
    let reloadToken: Int
    @Binding var isLoading: Bool
    var onNavigationFailed: (String) -> Void
    var onAppSettings: () -> Void
    /// 加载完成后探测网页里是否有原生入口行：true 有、false 没有（原厂固件）
    var onInjectedRow: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()
        cfg.userContentController.add(context.coordinator, name: "p4canApp")

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(Theme.accent)
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        // 原厂固件没有网页入口行时的兜底：长按 0.7 秒开设置。
        // cancelsTouchesInView = false，不抢网页自己的点击与滚动。
        let press = UILongPressGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleLongPress))
        press.minimumPressDuration = 0.7
        press.allowableMovement = 12
        press.cancelsTouchesInView = false
        press.delegate = context.coordinator
        webView.addGestureRecognizer(press)

        context.coordinator.webView = webView
        context.coordinator.load(url)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(reloadToken: reloadToken, url: url)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "p4canApp")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
                             WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var parent: DeviceWebView
        weak var webView: WKWebView?
        private var lastToken: Int
        private var lastLoadedURL: URL?
        /// 网页里没有原生入口行（原厂固件），长按才生效
        private var rowMissing = false

        init(_ parent: DeviceWebView) {
            self.parent = parent
            self.lastToken = parent.reloadToken
        }

        /// 网页里注入的那一行 `P4-CAN App` 被点击
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "p4canApp" else { return }
            DispatchQueue.main.async { self.parent.onAppSettings() }
        }

        func load(_ url: URL) {
            lastLoadedURL = url
            webView?.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 8))
        }

        func sync(reloadToken: Int, url: URL) {
            if url != lastLoadedURL {
                lastToken = reloadToken
                load(url)
                return
            }
            if reloadToken != lastToken {
                lastToken = reloadToken
                if let wv = webView, wv.url != nil {
                    wv.reload()
                } else {
                    load(url)
                }
            }
        }

        @objc func handleRefresh() {
            webView?.reload()
        }

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, rowMissing else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            parent.onAppSettings()
        }

        // 与网页自身的点击/滚动并行，不互相吞掉
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
            probeInjectedRow(in: webView, attempt: 0)
        }

        /// 补丁在"设置 → 系统"插的那一行是异步加的（DOMContentLoaded + 1.2s 各一次），
        /// 所以等一拍再问，最多问 3 次；确实没有才认定是原厂固件。
        private func probeInjectedRow(in webView: WKWebView, attempt: Int) {
            if attempt == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.probeInjectedRow(in: webView, attempt: 1)
                }
                return
            }
            webView.evaluateJavaScript("!!document.getElementById('p4canAppRow')") { value, _ in
                if let has = value as? Bool, has {
                    self.rowMissing = false
                    DispatchQueue.main.async { self.parent.onInjectedRow(true) }
                    return
                }
                if attempt >= 3 {
                    self.rowMissing = true
                    DispatchQueue.main.async { self.parent.onInjectedRow(false) }
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    self.probeInjectedRow(in: webView, attempt: attempt + 1)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishWithFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishWithFailure(error)
        }

        private func finishWithFailure(_ error: Error) {
            parent.isLoading = false
            webView?.scrollView.refreshControl?.endRefreshing()
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            parent.onNavigationFailed(AppModel.describe(error))
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow)
                return
            }
            switch scheme {
            case "http", "https":
                if navigationAction.targetFrame == nil {
                    webView.load(navigationAction.request)
                    decisionHandler(.cancel)
                } else {
                    decisionHandler(.allow)
                }
            case "about", "data", "blob":
                decisionHandler(.allow)
            default:
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        // window.open / target=_blank 留在应用内
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
