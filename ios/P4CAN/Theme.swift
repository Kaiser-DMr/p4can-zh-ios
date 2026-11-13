import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 版本信息

/// 版本号的唯一来源是工程设置（`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`），
/// 运行时从 Info.plist 读。以前在 build 脚本和两个视图里各手抄一份，发版时必然漏改。
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// 形如 `1.3.1 (5)`
    static var versionLine: String { "\(version) (\(build))" }

    /// 固件版本只有连上设备才知道，这里只声明本版适配的固件线。
    static let expectedFirmware = "v3.29.3"
}

// MARK: - 颜色工具

/// 一组 sRGB 分量，用来声明亮/暗两套色值。
struct RGBA {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1
}

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    #if canImport(UIKit)
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
    #endif

    #if canImport(AppKit)
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    #endif
}

extension Color {
    /// 随外观自动切换的颜色。真机与 macOS 真窗口都按当前 appearance 解析，
    /// 因此「跟随系统」时不必在每个视图里手写分支。
    static func adaptive(_ light: RGBA, _ dark: RGBA) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            (trait.userInterfaceStyle == .dark ? dark : light).uiColor
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return (isDark ? dark : light).nsColor
        })
        #else
        return light.color
        #endif
    }
}

// MARK: - 设计令牌

/// 颜色 / 圆角 / 间距 / 控件尺寸
enum Theme {
    // 品牌青绿。深色下用亮青，浅色下压深。
    // 浅色值按 WCAG 复算过：底 4.98:1、卡片材质 5.22:1（原 4.09/4.29 不达 4.5）。
    static let accentLight = RGBA(r: 0.035, g: 0.470, b: 0.415)
    static let accentDark = RGBA(r: 0.290, g: 0.850, b: 0.760)
    static let accent = Color.adaptive(accentLight, accentDark)

    static let accentDeep = Color.adaptive(
        RGBA(r: 0.078, g: 0.404, b: 0.365),
        RGBA(r: 0.090, g: 0.520, b: 0.470)
    )

    static let warn = Color.adaptive(
        RGBA(r: 0.702, g: 0.416, b: 0.000),
        RGBA(r: 1.000, g: 0.740, b: 0.320)
    )
    static let danger = Color.adaptive(
        RGBA(r: 0.761, g: 0.188, b: 0.157),
        RGBA(r: 1.000, g: 0.459, b: 0.427)
    )

    /// 纯色底：磨砂玻璃的衬底。亮暗各一套，都是单一纯色，不叠彩色光晕。
    static let baseLight = RGBA(r: 0.957, g: 0.965, b: 0.976)
    static let baseDark = RGBA(r: 0.043, g: 0.051, b: 0.067)
    static let base = Color.adaptive(baseLight, baseDark)

    /// 下沉容器（输入框等），在纯色底上做出一点「玻璃下的凹槽」
    static let well = Color.adaptive(
        RGBA(r: 0.898, g: 0.914, b: 0.937),
        RGBA(r: 0.000, g: 0.000, b: 0.000, a: 0.28)
    )

    /// 卡片与控件描边
    static let hairline = Color.adaptive(
        RGBA(r: 0, g: 0, b: 0, a: 0.08),
        RGBA(r: 1, g: 1, b: 1, a: 0.10)
    )

    /// 磨砂颗粒强度
    static func grain(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.030 : 0.024
    }
}

/// HIG：8pt 栅格；圆角遵循同心原则（外层大、内层递减）
enum Metrics {
    static let screenPadding: CGFloat = 20
    static let sheetRadius: CGFloat = 32
    static let cardRadius: CGFloat = 24
    static let innerRadius: CGFloat = 16
    static let controlRadius: CGFloat = 14

    static let gapXS: CGFloat = 6
    static let gapS: CGFloat = 10
    static let gapM: CGFloat = 16
    static let gapL: CGFloat = 24
    static let sectionGap: CGFloat = 28

    /// 最小可点击尺寸，Apple 要求 44×44
    static let minTap: CGFloat = 44

    /// 控制层统一高度：底部主按钮与圆形图标按钮共用，保证同一基线。
    static let controlHeight: CGFloat = 46

    /// 连接页内容相对顶部玻璃按钮的下沉量，与底部玻璃控制条的高度。
    /// 两处留白由浮层高度推导，改按钮尺寸时一起改，避免内容被玻璃压住。
    static let floatingTopInset: CGFloat = 64
    static let floatingBottomInset: CGFloat = 148

    /// 横屏（verticalSizeClass == .compact）下的同一组留白：
    /// 393pt 高度里再去掉 212pt，首屏就什么都看不到了。
    static let compactTopInset: CGFloat = 32
    static let compactBottomInset: CGFloat = 92

    /// iPad / 横屏下的正文最大宽度：超过后行长过长，反而难读。
    static let readableWidth: CGFloat = 560
}

// MARK: - 外观设置

/// 用户可选的外观。`system` 跟随 iOS 的深色模式开关。
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "p4can.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - 背景（内容层）

/// 纯色磨砂玻璃底。
///
/// 整块底是**单一纯色**，之上只叠一层极细噪点做磨砂质感——没有彩色光晕，
/// 也没有渐变亮带。玻璃控件靠自身的边缘高光与明度差在纯色上被辨识，
/// 这正是 iOS 26 玻璃在纯色背景下的真实表现。
struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? Theme.baseDark.color : Theme.baseLight.color)
            FrostGrain(opacity: Theme.grain(scheme))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 磨砂颗粒。固定种子的伪随机点阵，绘制成两张 Path 后各填一次，
/// 避免逐点 fill 造成的每次重绘开销。
struct FrostGrain: View {
    var opacity: Double

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1, opacity > 0 else { return }

            var rng = SplitMix64(seed: 0x9E37_79B9_7F4A_7C15)
            var bright = Path()
            var shade = Path()
            let step: CGFloat = 7

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let px = x + CGFloat(rng.unit()) * step
                    let py = y + CGFloat(rng.unit()) * step
                    let r = 0.3 + CGFloat(rng.unit()) * 0.7
                    let rect = CGRect(x: px, y: py, width: r, height: r)
                    if rng.unit() > 0.5 {
                        bright.addEllipse(in: rect)
                    } else {
                        shade.addEllipse(in: rect)
                    }
                    x += step
                }
                y += step
            }

            context.fill(bright, with: .color(.white.opacity(opacity)))
            context.fill(shade, with: .color(.black.opacity(opacity * 0.9)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 确定性随机源：背景重绘时颗粒位置不变，不会「闪」。
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}

// MARK: - 内容层卡片

/// 内容层用「标准材质」，不用 Liquid Glass。
/// HIG 明确：玻璃属于控制层，铺在内容层会破坏层级。
struct SurfaceCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.6)
            }
            .shadow(
                color: .black.opacity(scheme == .dark ? 0.34 : 0.10),
                radius: scheme == .dark ? 20 : 14,
                y: scheme == .dark ? 10 : 6
            )
    }
}

// MARK: - 小工具

/// 滚动区域。默认就是标准 `ScrollView`。
/// 只有在离屏渲染（`ImageRenderer` 画不出 ScrollView 子视图）时才退化为静态容器，
/// 由渲染器通过 `p4StaticLayout` 环境开关打开。
struct ScrollArea<Content: View>: View {
    @Environment(\.p4StaticLayout) private var staticLayout
    @ViewBuilder var content: Content

    var body: some View {
        if staticLayout {
            VStack(spacing: 0) { content }
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView { content }
                .p4ScrollEdgeSoft()
                .scrollDismissesKeyboard(.interactively)
        }
    }
}

private struct P4StaticLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 仅为离屏渲染器准备：把滚动容器换成静态 VStack
    var p4StaticLayout: Bool {
        get { self[P4StaticLayoutKey.self] }
        set { self[P4StaticLayoutKey.self] = newValue }
    }
}

extension View {
    /// iOS 16.4 起才有的 sheet 圆角
    @ViewBuilder
    func p4SheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }

    /// iOS 26 的滚动边缘效果，旧系统为无操作。
    /// 可用性判断必须带上 macOS —— 预览目标也编译这个文件，
    /// 只写 iOS 会让 macOS < 26 踩到不存在的 API。
    @ViewBuilder
    func p4ScrollEdgeSoft() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// sheet 背景：让系统材质透出底下内容，而不是盖一层不透明色
    @ViewBuilder
    func p4SheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.regularMaterial)
        } else {
            self
        }
    }
}
