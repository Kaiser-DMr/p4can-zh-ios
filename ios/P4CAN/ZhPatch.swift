import Foundation

/// App 内置的汉化脚本。
///
/// 脚本以资源形式随包发布（`P4CAN/zh-bilingual.js`，由 `build-ipa.sh` 从
/// 仓库根目录的 `i18n/zh-bilingual.js` 同步进来），运行时读出来交给
/// `WKUserScript` 注入设备网页——所以原厂英文固件也能显示中文。
///
/// 文件缺失时（只拿了源码没跑打包脚本、或 macOS 预览窗口）返回 `nil`，
/// App 退化成纯英文外壳，功能不受影响。
enum ZhPatch {

    static let source: String? = {
        guard let url = Bundle.main.url(forResource: "zh-bilingual", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }()

    /// 设置面板据此决定开关是否可用
    static var isAvailable: Bool { source != nil }
}
