import SwiftUI

// MARK: - 玻璃表面

/// Liquid Glass 只用于**控制层**（浮动按钮、操作条）。
/// iOS 26 起走原生 `glassEffect`，低版本退回 `ultraThinMaterial`，视觉层次保持一致。
/// 「减弱透明度 / 增强对比度」等辅助功能由系统自动作用于玻璃，无需手动分支。
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive: Bool

    @Environment(\.colorScheme) private var scheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(glass, in: shape)
                // 纯色底上没有内容可折射，系统给的高光很弱；补一圈顶亮下暗的
                // 细描边，作为玻璃厚度的视觉暗示（Liquid Glass 的边缘折射特征）。
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(scheme == .dark ? 0.26 : 0.80),
                                .white.opacity(scheme == .dark ? 0.04 : 0.30),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        Color.white.opacity(scheme == .dark ? 0.18 : 0.55),
                        lineWidth: 0.8
                    )
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.12), radius: 14, y: 6)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var glass: Glass {
        var effect: Glass = .regular
        if let tint { effect = effect.tint(tint) }
        if interactive { effect = effect.interactive() }
        return effect
    }
}

extension View {
    /// 给控制层元素加玻璃质感
    func glassSurface<S: Shape>(
        _ shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

// MARK: - 玻璃容器

/// 多个玻璃元素应放在同一容器里，系统会合并渲染并允许形状相互融合。
struct GlassCluster<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - 圆形图标按钮（控制层）

struct GlassIconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = Metrics.controlHeight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressStyle())
        .glassSurface(.circle, interactive: true)
        .accessibilityLabel(label)
    }
}

/// 按下时轻微缩放，给触觉反馈的视觉对应
struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 主/次操作按钮（控制层）

/// 胶囊形操作按钮。与 `GlassIconButton` 共用同一套玻璃修饰器与同一高度
/// （`Metrics.controlHeight`），所以并排时高度、圆角视觉重量完全一致。
///
/// 用**无色磨砂玻璃**而不是 `glassProminent`：后者是 tint 实心填充，在纯色底上
/// 会退化成一块色块。主次靠品牌色图标 + 一圈淡色描边表达，材质本身与右侧圆钮一致。
struct ActionButton: View {
    enum Emphasis { case primary, secondary }

    let title: String
    let systemImage: String
    var emphasis: Emphasis = .primary
    var fullWidth: Bool = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// 辅助功能字号下文字会挤满胶囊，直接收成图标按钮，保证高度与右侧圆钮一致。
    private var compact: Bool { typeSize >= .accessibility3 }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: Metrics.controlHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle())
        .glassSurface(.capsule, tint: emphasis == .primary ? Theme.accent.opacity(0.30) : nil, interactive: true)
        .accessibilityLabel(title)
    }

    /// 宽度不足时降级为纯图标，任何尺寸下都不截字、不撑破胶囊。
    @ViewBuilder
    private var label: some View {
        if compact {
            icon.frame(width: Metrics.controlHeight)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    icon
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 18)

                icon
                    .frame(width: Metrics.controlHeight)
            }
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(emphasis == .primary ? Theme.accent : Color.primary)
    }
}
