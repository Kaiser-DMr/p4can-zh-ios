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
///
/// 中文界面：App 里带一份 `zh-bilingual.js`，用 `WKUserScript` 注入，
/// 因此**原厂英文固件也能显示中文**，不必改板子。固件自己已经内置补丁时，
/// 脚本里的单例守卫会让注入的这一份直接退出，不会重复翻译。
struct DeviceWebView: UIViewRepresentable {

    let url: URL
    let reloadToken: Int
    /// 是否注入中文（App 设置里可关）
    var zhEnabled: Bool = true
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
        Self.installZH(into: cfg.userContentController, enabled: zhEnabled)
        context.coordinator.zhApplied = zhEnabled

        let webView = WKWebView(frame: .zero, configuration: cfg)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

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
        context.coordinator.syncZH(zhEnabled, in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "p4canApp")
    }

    // MARK: - 中文注入

    /// 设备网页的 HTML 本来就是英文，注入发生在文档解析完之后，
    /// 中间会闪一下英文原文。先在 documentStart 把整页压成透明，
    /// 注入完成（或 1.2 秒兜底）再淡入 —— 兜底保证脚本出问题时不会白屏。
    private static let holdScript = """
    (function () {
      if (window.__p4zhHold) return;
      window.__p4zhHold = true;
      var d = null;
      window.__p4zhReveal = function () {
        if (!d) return;
        d.style.transition = 'opacity .16s ease-out';
        d.style.opacity = '1';
      };
      (function wait() {
        d = document.documentElement;
        if (!d) { setTimeout(wait, 8); return; }
        d.style.opacity = '0';
        setTimeout(window.__p4zhReveal, 1200);
      })();
    })();
    """

    /// 注入脚本跑完后立刻显示；给浏览器一帧时间应用样式
    private static let revealScript = """
    setTimeout(function () { if (window.__p4zhReveal) window.__p4zhReveal(); }, 60);
    """

    /// 重装 user scripts。`removeAllUserScripts` 只影响之后发生的加载，所以调用方要重新加载页面。
    static func installZH(into ucc: WKUserContentController, enabled: Bool) {
        ucc.removeAllUserScripts()
        guard enabled, let src = ZhPatch.source else { return }
        ucc.addUserScript(WKUserScript(source: holdScript,
                                       injectionTime: .atDocumentStart,
                                       forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: src + "\n" + revealScript,
                                       injectionTime: .atDocumentEnd,
                                       forMainFrameOnly: true))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
                             WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var parent: DeviceWebView
        weak var webView: WKWebView?
        /// 当前 user scripts 是否已按中文开关装好；nil 表示还没装过
        var zhApplied: Bool?
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

        /// 开关变了才重装脚本并重新加载，否则每次 updateUIView 都会刷新页面。
        func syncZH(_ enabled: Bool, in webView: WKWebView) {
            guard zhApplied != enabled else { return }
            zhApplied = enabled
            DeviceWebView.installZH(into: webView.configuration.userContentController, enabled: enabled)
            if let u = lastLoadedURL {
                load(u)
            } else {
                webView.reload()
            }
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
