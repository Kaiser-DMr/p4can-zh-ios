import Foundation
#if canImport(UIKit)
import UIKit
#endif
import WebKit

enum LinkState: Equatable {
    case probing          // 首次/正在探测
    case online           // 设备网页可达
    case offline(String)  // 带原因的失败

    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }
}

@MainActor
final class AppModel: ObservableObject {

    static let defaultHost = "192.168.4.1"
    static let apHint = "P4-CAN-XXXX"
    static let apPassword = "12345678"

    // MARK: - 持久化设置

    @Published var host: String {
        didSet {
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: "p4can.host")
        }
    }

    @Published var keepAwake: Bool {
        didSet {
            UserDefaults.standard.set(keepAwake, forKey: "p4can.keepAwake")
            applyIdleTimer()
        }
    }

    /// 是否往设备网页里注入中文。默认开：原厂英文固件也能看懂。
    @Published var zhEnabled: Bool {
        didSet { UserDefaults.standard.set(zhEnabled, forKey: "p4can.zh") }
    }

    // MARK: - 运行时状态

    @Published private(set) var state: LinkState = .probing
    /// 本次启动是否连上过。只增不减：连上过之后探活失败不再卸载 WebView，
    /// 只降级为顶部提示条——否则设备返回 430 KB 大页面时一次 2.5s 超时，
    /// 仪表盘就会被销毁重载，驾驶中体感是「闪一下从头加载」。
    @Published private(set) var hasBeenOnline = false
    @Published private(set) var probeCount = 0
    @Published var reloadToken = 0
    @Published var showSettings = false

    /// 连续失败多少次才判定离线。没连上过时第一次就判定（用户需要立刻看到「连不上」）；
    /// 连上过之后容忍两次抖动。
    private static let failuresBeforeOffline = 3
    private var consecutiveFailures = 0

    private var probeTask: Task<Void, Never>?
    private let session: URLSession

    /// `session` 只为测试注入：探活状态机是纯逻辑，但没有注入缝就只能靠真机验证
    init(session: URLSession? = nil) {
        let saved = UserDefaults.standard.string(forKey: "p4can.host") ?? Self.defaultHost
        host = saved.isEmpty ? Self.defaultHost : saved

        if UserDefaults.standard.object(forKey: "p4can.keepAwake") == nil {
            keepAwake = true
        } else {
            keepAwake = UserDefaults.standard.bool(forKey: "p4can.keepAwake")
        }

        if UserDefaults.standard.object(forKey: "p4can.zh") == nil {
            zhEnabled = true
        } else {
            zhEnabled = UserDefaults.standard.bool(forKey: "p4can.zh")
        }

        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 2.5
            cfg.timeoutIntervalForResource = 4
            cfg.waitsForConnectivity = false
            cfg.allowsCellularAccess = false
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - 地址

    /// 设备地址校验：只接受主机名 / IPv4 / `主机:端口`。
    /// 返回 nil 表示输入里有不能进 URL 的字符（空格、中文、括号……）或端口非法。
    static func sanitizedHost(_ raw: String) -> String? {
        var h = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !h.isEmpty else { return nil }

        for prefix in ["http://", "https://"] where h.lowercased().hasPrefix(prefix) {
            h = String(h.dropFirst(prefix.count))
        }
        if let slash = h.firstIndex(of: "/") { h = String(h[..<slash]) }
        h = h.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return nil }

        // 主机名允许字母数字、点、连字符；端口再加一个冒号
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:")
        guard h.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        guard !h.hasPrefix("."), !h.hasPrefix("-"), !h.hasSuffix("."), !h.hasSuffix("-") else {
            return nil
        }

        let colons = h.filter { $0 == ":" }.count
        guard colons <= 1 else { return nil }        // 车载场景不用 IPv6
        if colons == 1 {
            let parts = h.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty,
                  let port = Int(parts[1]), (1...65535).contains(port) else { return nil }
        }
        return h
    }

    /// 用于显示的主机。非法输入原样返回（仅去首尾空白），
    /// 让用户看到自己输的东西；能不能发请求看 `requestHost`。
    var normalizedHost: String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Self.defaultHost }
        return Self.sanitizedHost(trimmed) ?? trimmed
    }

    /// nil 表示这个地址不可用于请求
    var requestHost: String? { Self.sanitizedHost(host) }

    /// 与 `requestHost` 保持同一口径：地址非法时一起回落到默认值，
    /// 不再出现「状态卡显示坏地址、实际探的却是 192.168.4.1」。
    var baseURL: URL {
        let h = requestHost ?? Self.defaultHost
        return URL(string: "http://\(h)/") ?? URL(string: "http://\(Self.defaultHost)/")!
    }

    func resetHost() {
        host = Self.defaultHost
    }

    // MARK: - 探活

    func startProbing() {
        guard probeTask == nil else { return }
        probeTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.probe()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopProbing() {
        probeTask?.cancel()
        probeTask = nil
    }

    func probeOnce() {
        Task { await probe() }
    }

    private func probe() async {
        probeCount += 1

        // 地址非法时以前是静默 return，`state` 永远停在 .probing ——
        // 界面一直转圈显示「正在查找设备」，既不报错也不超时。
        guard let host = requestHost,
              let url = URL(string: "http://\(host)/api/wifi/status") else {
            consecutiveFailures += 1
            let msg = "地址格式不正确，请填写 IP 或 IP:端口"
            if state != .offline(msg) {
                state = .offline(msg)
                applyIdleTimer()
            }
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 2.5
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("text/plain", forHTTPHeaderField: "Accept")

        do {
            let (_, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            if (200..<500).contains(http.statusCode) {
                recordSuccess()
            } else {
                recordFailure("设备返回 HTTP \(http.statusCode)")
            }
        } catch {
            recordFailure(Self.describe(error))
        }
    }

    private func recordSuccess() {
        consecutiveFailures = 0
        // @Published 不做相等比较，每 3 秒重复赋 true 会让整个 RootView 白刷新一次
        if !hasBeenOnline { hasBeenOnline = true }
        if !state.isOnline {
            state = .online
            applyIdleTimer()
        }
    }

    /// 失败分两档：没连上过就立刻报（用户要知道连不上），
    /// 连上过则容忍两次抖动，第三次才把状态降级。
    /// 降级只影响顶部提示条与常亮策略，WebView 由 `hasBeenOnline` 保活，不会被销毁。
    private func recordFailure(_ msg: String) {
        consecutiveFailures += 1
        let threshold = hasBeenOnline ? Self.failuresBeforeOffline : 1
        guard consecutiveFailures >= threshold else { return }
        if state != .offline(msg) {
            state = .offline(msg)
            applyIdleTimer()
        }
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return ns.localizedDescription }
        switch ns.code {
        case NSURLErrorCannotConnectToHost:
            return "连不上设备，请确认已连上 P4-CAN 热点"
        case NSURLErrorTimedOut:
            return "连接超时，设备未响应"
        case NSURLErrorNotConnectedToInternet:
            return "手机未连接无线局域网"
        case NSURLErrorCannotFindHost:
            return "找不到该地址，请检查 IP"
        case NSURLErrorNetworkConnectionLost:
            return "网络连接中断"
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return "系统拦截了明文连接"
        default:
            return "连接失败（\(ns.code)）"
        }
    }

    // MARK: - 操作

    func reload() {
        reloadToken &+= 1
    }

    func applyIdleTimer() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = keepAwake && state.isOnline
        #endif
    }

    #if P4CAN_PREVIEW
    /// 仅供 macOS 运行预览注入状态，iOS 包不编译此分支
    func previewState(_ s: LinkState) { state = s }
    #endif

    func clearWebCache() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) {
                cont.resume()
            }
        }
        reload()
    }
}
