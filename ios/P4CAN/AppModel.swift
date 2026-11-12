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

    var reason: String? {
        if case .offline(let r) = self { return r }
        return nil
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

    // MARK: - 运行时状态

    @Published private(set) var state: LinkState = .probing
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var probeCount = 0
    @Published var reloadToken = 0
    @Published var showSettings = false

    private var probeTask: Task<Void, Never>?
    private let session: URLSession

    init() {
        let saved = UserDefaults.standard.string(forKey: "p4can.host") ?? Self.defaultHost
        host = saved.isEmpty ? Self.defaultHost : saved

        if UserDefaults.standard.object(forKey: "p4can.keepAwake") == nil {
            keepAwake = true
        } else {
            keepAwake = UserDefaults.standard.bool(forKey: "p4can.keepAwake")
        }

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 2.5
        cfg.timeoutIntervalForResource = 4
        cfg.waitsForConnectivity = false
        cfg.allowsCellularAccess = false
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    // MARK: - 地址

    var normalizedHost: String {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.isEmpty { h = Self.defaultHost }
        for prefix in ["http://", "https://"] where h.lowercased().hasPrefix(prefix) {
            h = String(h.dropFirst(prefix.count))
        }
        if let slash = h.firstIndex(of: "/") { h = String(h[..<slash]) }
        return h.isEmpty ? Self.defaultHost : h
    }

    var baseURL: URL {
        if let url = URL(string: "http://\(normalizedHost)/") { return url }
        return URL(string: "http://\(Self.defaultHost)/")!
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
        guard let url = URL(string: "http://\(normalizedHost)/api/wifi/status") else { return }

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
                if !state.isOnline {
                    state = .online
                    lastSuccess = Date()
                    applyIdleTimer()
                }
            } else {
                state = .offline("设备返回 HTTP \(http.statusCode)")
                applyIdleTimer()
            }
        } catch {
            let msg = Self.describe(error)
            if state != .offline(msg) {
                state = .offline(msg)
                applyIdleTimer()
            }
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

    func markOnlineAgain() {
        guard !state.isOnline else { return }
        probeOnce()
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
