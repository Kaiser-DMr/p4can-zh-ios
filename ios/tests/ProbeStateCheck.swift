import Foundation

/// 探活状态机的回归检查（不依赖 XCTest，可脱离 Xcode 直接跑）。
///
/// 覆盖这次修的两处逻辑：
/// 1. 连上过之后要容忍抖动、且 `hasBeenOnline` 只增不减（RootView 据此保活 WebView）；
/// 2. 非法地址必须落到 `.offline`，不能停在 `.probing` 一直转圈。
///
/// 用法：`bash tests/run-probe-check.sh`

// MARK: - URLProtocol 桩

final class StubProtocol: URLProtocol {
    /// nil 表示按网络错误返回
    static var status: Int? = 200
    static var failure: URLError?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let code = Self.status ?? 200
        let resp = HTTPURLResponse(url: request.url!,
                                   statusCode: code,
                                   httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "text/plain"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"ok\":true}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - 断言

var failures = 0

func expect(_ ok: Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if ok {
        print("  ✓ \(name)")
    } else {
        failures += 1
        let d = detail()
        print("  ✗ \(name)\(d.isEmpty ? "" : " —— \(d)")")
    }
}

func reason(_ s: LinkState) -> String? {
    if case .offline(let r) = s { return r }
    return nil
}

// MARK: - 用例

@MainActor
func run() async {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [StubProtocol.self]
    let session = URLSession(configuration: cfg)

    func settle() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    print("地址校验")
    let hostCases: [(String, String?)] = [
        ("192.168.4.1", "192.168.4.1"),
        ("  192.168.4.1  ", "192.168.4.1"),
        ("http://192.168.4.1/", "192.168.4.1"),
        ("https://192.168.4.1:8443/index.html", "192.168.4.1:8443"),
        ("p4can.local", "p4can.local"),
        ("192.168.4.1:80", "192.168.4.1:80"),
        ("", nil),
        ("   ", nil),
        ("192.168.4.1 abc", nil),
        ("车载热点", nil),
        ("192.168.4.1:0", nil),
        ("192.168.4.1:99999", nil),
        ("192.168.4.1:80:90", nil),
        ("-bad.local", nil),
    ]
    for (input, expected) in hostCases {
        let got = AppModel.sanitizedHost(input)
        expect(got == expected, "\"\(input)\" → \(expected ?? "nil")",
               "实际 \(got ?? "nil")")
    }

    print("首次连接")
    let model = AppModel(session: session)
    model.host = "192.168.4.1"
    StubProtocol.status = 200
    StubProtocol.failure = nil
    model.probeOnce()
    await settle()
    expect(model.state.isOnline, "成功一次 → online", "\(model.state)")
    expect(model.hasBeenOnline, "成功一次 → hasBeenOnline = true")

    print("连上之后容忍抖动")
    StubProtocol.status = nil
    StubProtocol.failure = URLError(.timedOut)
    model.probeOnce()
    await settle()
    expect(model.state.isOnline, "第 1 次失败仍保持 online", "\(model.state)")

    model.probeOnce()
    await settle()
    expect(model.state.isOnline, "第 2 次失败仍保持 online", "\(model.state)")

    model.probeOnce()
    await settle()
    expect(!model.state.isOnline, "第 3 次失败降级为 offline", "\(model.state)")
    expect(model.hasBeenOnline, "降级后 hasBeenOnline 仍为 true（页面不卸载）")
    expect(reason(model.state) == AppModel.describe(URLError(.timedOut)),
           "降级原因使用 describe() 文案", "\(reason(model.state) ?? "nil")")

    print("恢复")
    StubProtocol.status = 200
    StubProtocol.failure = nil
    model.probeOnce()
    await settle()
    expect(model.state.isOnline, "恢复后回到 online", "\(model.state)")

    print("从未连上过：第一次失败就报错")
    let cold = AppModel(session: session)
    cold.host = "192.168.4.1"
    StubProtocol.status = nil
    StubProtocol.failure = URLError(.cannotConnectToHost)
    cold.probeOnce()
    await settle()
    expect(cold.state == .offline(AppModel.describe(URLError(.cannotConnectToHost))),
           "首次失败 → offline", "\(cold.state)")
    expect(!cold.hasBeenOnline, "hasBeenOnline 保持 false（应显示连接页）")

    print("非法地址")
    let bad = AppModel(session: session)
    bad.host = "192.168.4.1 abc"
    StubProtocol.status = 200
    StubProtocol.failure = nil
    bad.probeOnce()
    await settle()
    expect(reason(bad.state)?.contains("地址格式不正确") == true,
           "非法地址 → offline 且给出原因", "\(bad.state)")
    expect(bad.normalizedHost == "192.168.4.1 abc",
           "状态卡仍显示用户输入的原值", bad.normalizedHost)
    expect(bad.baseURL.absoluteString == "http://192.168.4.1/",
           "baseURL 与 requestHost 同口径回落", bad.baseURL.absoluteString)

    print("HTTP 状态码")
    let http = AppModel(session: session)
    http.host = "192.168.4.1"
    StubProtocol.status = 401
    StubProtocol.failure = nil
    http.probeOnce()
    await settle()
    expect(http.state.isOnline, "401 视为设备在线（端口通即连上）", "\(http.state)")

    print("")
    if failures == 0 {
        print("全部通过")
    } else {
        print("\(failures) 项失败")
        exit(1)
    }
}

@main
struct ProbeStateCheck {
    static func main() async {
        await run()
    }
}
