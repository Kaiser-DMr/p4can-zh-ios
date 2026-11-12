import AppKit
import CoreGraphics
import Foundation

// 生成 1024x1024 App 图标
let S: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

func cg(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 底色
ctx.setFillColor(cg(0x080B12))
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// 左上青光（径向）
let glowA = CGGradient(colorsSpace: cs,
                       colors: [cg(0x2FD8BE, 0.34), cg(0x2FD8BE, 0.0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(glowA,
                       startCenter: CGPoint(x: S * 0.24, y: S * 0.80), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.24, y: S * 0.80), endRadius: S * 0.72,
                       options: [])

// 右下蓝光（径向）
let glowB = CGGradient(colorsSpace: cs,
                       colors: [cg(0x2B62C8, 0.30), cg(0x2B62C8, 0.0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(glowB,
                       startCenter: CGPoint(x: S * 0.82, y: S * 0.14), startRadius: 0,
                       endCenter: CGPoint(x: S * 0.82, y: S * 0.14), endRadius: S * 0.70,
                       options: [])

// 顶部到底部的暗角压暗
let vignette = CGGradient(colorsSpace: cs,
                          colors: [cg(0x000000, 0.0), cg(0x000000, 0.35)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(vignette,
                       start: CGPoint(x: 0, y: S * 0.55),
                       end: CGPoint(x: 0, y: 0),
                       options: [])

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

let accent = rgb(0x4AD9C2)
let busY = S * 0.5
let chipSide = S * 0.56
let chipRect = NSRect(x: (S - chipSide) / 2, y: (S - chipSide) / 2,
                      width: chipSide, height: chipSide)

// CAN 总线（从芯片左右伸出）
let bus = NSBezierPath()
bus.move(to: NSPoint(x: S * 0.055, y: busY))
bus.line(to: NSPoint(x: S * 0.945, y: busY))
bus.lineWidth = S * 0.009
accent.withAlphaComponent(0.45).setStroke()
bus.stroke()

// 两侧终端电阻
for x in [S * 0.055, S * 0.945] {
    let d = S * 0.046
    let dot = NSBezierPath(ovalIn: NSRect(x: x - d / 2, y: busY - d / 2, width: d, height: d))
    rgb(0x080B12).setFill()
    dot.fill()
    dot.lineWidth = S * 0.0075
    accent.withAlphaComponent(0.75).setStroke()
    dot.stroke()
}

// 芯片体外阴影
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = rgb(0x000000, 0.6)
shadow.shadowBlurRadius = S * 0.045
shadow.shadowOffset = NSSize(width: 0, height: -S * 0.014)
shadow.set()
rgb(0x0C1420).setFill()
NSBezierPath(roundedRect: chipRect, xRadius: chipSide * 0.235, yRadius: chipSide * 0.235).fill()
NSGraphicsContext.restoreGraphicsState()

// 芯片内渐变
let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: chipSide * 0.235, yRadius: chipSide * 0.235)
NSGraphicsContext.saveGraphicsState()
chipPath.addClip()
NSGradient(colors: [rgb(0x2FD8BE, 0.20), rgb(0x0C1420, 0.0), rgb(0x2B62C8, 0.10)])!
    .draw(in: chipRect, angle: -72)
NSGraphicsContext.restoreGraphicsState()

// 芯片描边
chipPath.lineWidth = S * 0.0075
accent.withAlphaComponent(0.50).setStroke()
chipPath.stroke()

// 文字：P4 在上，CAN 在下，整体垂直居中
let p4Font = NSFont.systemFont(ofSize: S * 0.195, weight: .bold)
let canFont = NSFont.systemFont(ofSize: S * 0.070, weight: .heavy)

let p4 = NSAttributedString(string: "P4", attributes: [
    .font: p4Font,
    .foregroundColor: NSColor.white,
    .kern: -S * 0.006,
])
let canText = NSAttributedString(string: "CAN", attributes: [
    .font: canFont,
    .foregroundColor: accent,
    .kern: S * 0.026,
])

let p4Size = p4.size()
let canSize = canText.size()
let gap = S * 0.045
let blockH = p4Size.height + gap + canSize.height
let blockBottom = (S - blockH) / 2

// CAN 先画（下方），再画 P4（上方）
canText.draw(at: NSPoint(x: (S - canSize.width) / 2, y: blockBottom))
p4.draw(at: NSPoint(x: (S - p4Size.width) / 2, y: blockBottom + canSize.height + gap))

NSGraphicsContext.restoreGraphicsState()

// 输出 PNG
let cgImage = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
let data = rep.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(rep.pixelsWide)x\(rep.pixelsHigh)")
