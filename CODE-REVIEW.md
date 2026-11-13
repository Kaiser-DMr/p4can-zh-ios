# P4-CAN iOS 外壳 · 代码审查报告

审查对象：`ios/P4CAN/*`（10 个 Swift 文件，1,971 行）+ `Info.plist` + 构建脚本
审查日期：2026-11-13
审查范围：SwiftUI 组件、UIKit 互操作（WKWebView）、布局与多尺寸适配、Apple HIG、无障碍、代码结构/复用/性能、核心功能实测

---

## 0. 结论摘要

| 严重度 | 数量 | 含义 |
|---|---|---|
| **P1（应尽快修）** | 6 | 有真实用户可见缺陷：深色模式设置失效、驾驶中被踢出仪表盘、VoiceOver 点不到按钮、对比度不达标、错误输入后永久卡死、点击区域不足 |
| **P2（本迭代内修）** | 9 | 复用性/性能/多设备适配/可维护性问题，不会立刻坏但持续产生成本 |
| **P3（择机）** | 7 | 命名、魔法数字、无效配置、词典缺口等细节 |

**总体判断**：工程完成度高，构建零警告、资源打包正确、汉化链路实测有效（汉字 0 → 6,322）、HIG 大方向把握准确（控制层用玻璃、内容层用材质、44pt 触控目标、8pt 栅格、无汉堡菜单、modal 有取消路径）。主要短板集中在**状态机的边界处理**、**无障碍细节**和**跨设备/字号的自适应**这三块，而不是架构本身。

三个最值得先动的地方：

1. `Info.plist` 的 `UIUserInterfaceStyle = Dark` 与设置里的「跟随系统」语义直接冲突（P1-1）。
2. 探活失败就把整个 WebView 卸载回连接页，驾驶中网络抖一下界面就没了（P1-2）。
3. 失败提示条用 `.accessibilityElement(children: .combine)` 包住了「重试」按钮，VoiceOver 下按钮不可点（P1-3）。

---

## 1. 审查方法与可复现证据

| 项目 | 命令 | 结果 |
|---|---|---|
| 编译（模拟器 SDK） | `xcodebuild -project P4CAN.xcodeproj -scheme P4CAN -sdk iphonesimulator build` | **BUILD SUCCEEDED** |
| 编译警告 | `swiftc -typecheck -target arm64-apple-ios16.0 P4CAN/*.swift` | **0 warning / 0 error** |
| 资源打包 | `ls .app/` | `preview.html` 13,929 B、`zh-bilingual.js` 71,767 B 均在包内 |
| 汉化源一致性 | `md5 i18n/zh-bilingual.js ios/P4CAN/zh-bilingual.js` | 一致（`34ed6b02…`） |
| IPA 完整性 | `shasum -a 256 dist/P4CAN-1.3.0-unsigned.ipa` | `2efcc48e…ce23c`，与 README 记录一致 |
| 布局离屏渲染 | `swiftc Preview/main.swift … && ./p4render` | 393×852、320×568 五张图，见 §4 |
| 汉化 A/B 实测 | 模拟设备 + 注入代理 + 无头 Chrome | 见 §3 |

---

## 2. 核心功能验证结果

### 2.1 汉化链路（App 侧注入）——**通过**

用 `mock_device.py` 起真实仪表盘，再通过代理在 `</body>` 前注入包内的 `ios/P4CAN/zh-bilingual.js`（等价于 `WKUserScript` 的 `.atDocumentEnd`），统计去除 `<script>/<style>` 后的可见文本：

| 场景 | 汉字数 | 英文词数 | 判定 |
|---|---|---|---|
| 原厂英文固件（UNPATCHED）+ 不注入 | 0 | 3,219 | 基线 |
| 原厂英文固件 + App 注入 | **6,322** | 298 | ✅ 翻译生效，英文残留降 90.7% |
| 已打补丁固件 + 不注入 | 76 | 3,184 | 补丁仅提供了语言切换入口，默认仍英文 |
| 已打补丁固件 + App 注入 | **6,322** | 298 | ✅ 与上一行收敛到同一数值 |

关键结论：两条路径的汉字数**完全相等**（6,322），说明单例守卫 + 让位逻辑正常工作，**没有出现叠加翻译**（若叠加会接近 12,644）。这是 v1.3.0 相对 v1.2.0 的核心修复，实测确认已生效。

### 2.2 注入后的布局——**通过**

393px 宽下截图检查：三张快捷卡片（防眩手 / 打灯 / 红绿灯）仍为**三列**，CAN1/CAN2/CAN3 三列徽标（实体 / 实时 / 待命）未被中文撑破，无文字溢出、无中英混排错乱。v1.2.0 时代"英文残留把三列撑成两列"的问题没有回归。

### 2.3 发现的功能性缺口（汉化层，非 iOS 代码但属交付体验）

中文模式下仍有可见英文：

| 残留文本 | 次数 | 说明 |
|---|---|---|
| `Unavailable` | 8 | 最影响观感的一处，应为「不可用 / 无数据」 |
| `Pedal Response sends one immediate best-effort 0x334 one-shot from the freshest stock template when the selection…` | 1 | LAB 页整段说明未命中词典 |
| `Classic steering torque table injection while AP is active.` | 1 | 同上 |
| `Torque table` / `MODE A` | 各 1–2 | 同上 |

其余残留（`CAN` `Wi-Fi` `Model` `NOA` `TWAI` `NVS` `Autopilot` `BODY/CHASSIS/PARTY`）为技术术语，保留英文是合理选择。

---

## 3. P1 问题（有真实用户可见缺陷）

### P1-1 「跟随系统」永远等于深色 —— `Info.plist` 与设置项语义冲突

**位置**：`P4CAN/Info.plist:65-66`、`RootView.swift:13-16`、`Theme.swift:140-146`

```xml
<key>UIUserInterfaceStyle</key>
<string>Dark</string>   <!-- 应用级强制深色 -->
```

```swift
private var activeScheme: ColorScheme? {
    if model.state.isOnline { return .dark }
    return (AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme   // system -> nil
}
```

**机理**：`UIUserInterfaceStyle` 是**应用级** override（Apple 文档明确：忽略用户偏好，整个 App 恒定该外观）。`.preferredColorScheme(.light/.dark)` 是**呈现级** override，优先级高于应用级，所以显式选浅色/深色能生效；但 `.system` 返回 `nil`，SwiftUI 不下发 override，色彩方案回落到应用级 = 永远 Dark。

**影响**：系统处于浅色模式的用户在设置里选「跟随系统」，App 仍全深色，且这个选项看起来"没反应"。这属于设置项失效，不是审美问题。

**建议**：删掉 `UIUserInterfaceStyle`，改为用 `UILaunchScreen` 已有的 `LaunchBg` 承载启动闪屏；真机首帧闪白如不可接受，再在 `RootView` 之外补一个深色 cover。

```xml
<!-- 删除 -->
<key>UIUserInterfaceStyle</key><string>Dark</string>
```

**验证**（30 秒）：系统切浅色 → App 设置选「跟随系统」→ 连接页应为浅色卡片 + 深色文字。

**同类无效配置**：`UIStatusBarStyle`（`Info.plist:50-51`）在 `UIViewControllerBasedStatusBarAppearance = true` 时被系统忽略，属死键，可一并删除或补注释说明保留原因。

---

### P1-2 探活失败即卸载 WebView —— 驾驶中网络抖一下仪表盘就没了

**位置**：`RootView.swift:22-28`、`AppModel.swift:129-160`

```swift
if model.state.isOnline { webLayer } else { ConnectView() }   // 二选一，非黑即白
```

```swift
} catch {
    let msg = Self.describe(error)
    if state != .offline(msg) { state = .offline(msg); applyIdleTimer() }   // 任何一次失败都置 offline
}
```

探活每 3 秒一次、超时 2.5 秒。设备在返回 430 KB 大页面期间 CPU 吃紧，一次请求超时就会：

1. `state = .offline` → `RootView` 立刻把 `DeviceWebView` 换成 `ConnectView`（动画 0.25s）；
2. WebView 被销毁，页面状态、滚动位置、用户正在看的 LAB 面板全部丢失；
3. 3 秒后探活成功 → 重新创建 WebView → **重新下载 430 KB 页面 + 重新跑一遍汉化注入**（含 1.2s hold 与淡入）。

**双重副作用**：体感是"仪表盘闪一下又从头加载"，流量与 CPU 也白烧；在行车场景下这属于可用性事故。

**建议**：进入过在线状态后，失败只降级为顶部提示条，不卸载 WebView。

```swift
// AppModel
private(set) var hasBeenOnline = false      // probe 成功时置 true，只增不减

// RootView
if model.state.isOnline || model.hasBeenOnline {
    webLayer          // 保活
} else {
    ConnectView()
}
```
并把 `probe()` 的失败分支改为「3 次连续失败才置 offline」，避免单次抖动。

---

### P1-3 失败提示条吞掉「重试」按钮 —— VoiceOver 下不可点

**位置**：`RootView.swift:106-134`

```swift
private func failureBanner(_ msg: String) -> some View {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
        Text(msg)
        Spacer(minLength: 6)
        Button("重试") { … }          // ← 可交互子元素
    }
    …
    .accessibilityElement(children: .combine)   // ← 把子元素合并成一个静态元素
}
```

**机理**：`children: .combine` 会把子树合并成**单一无障碍元素**，子元素的 `Button` 语义与 action 不再单独暴露。结果：VoiceOver 读到"警告 连接超时，设备未响应 重试"但**滑不到、也双击不了重试按钮**，而这是页面上唯一的恢复手段。

**建议**：容器含可交互子元素时用 `.contain`，或直接去掉修饰符（HStack 默认就是容器语义）。

```swift
.accessibilityElement(children: .contain)
```

**同类复核**：`ConnectView.swift:118`（statusCard，无按钮，`.combine` 可保留）、`:198`（stepRow，无按钮）、`:367`（helpItem，无按钮）、`SettingsView.swift:74`（statusSection，无按钮）——只有 `failureBanner` 这一处是真的缺陷。

---

### P1-4 浅色模式品牌色对比度 4.09:1，未达 4.5:1

**位置**：`Theme.swift:53-56`

```swift
// 品牌青绿。深色下用亮青，浅色下压深，保证正文对比度 ≥ 4.5:1。
static let accentLight = RGBA(r: 0.043, g: 0.529, b: 0.471)
```

实测（WCAG 2.1 相对亮度公式）：

| 前景 | 背景 | 对比度 | 要求 | 判定 |
|---|---|---|---|---|
| `accentLight` | `baseLight` | **4.09 : 1** | 4.5 | ❌ |
| `accentLight` | 卡片材质（浅） | **4.29 : 1** | 4.5 | ❌ |
| `accentDark` | `baseDark` | 11.08 : 1 | 4.5 | ✅ |
| `.tertiary`（30% 白） | `baseDark` | **2.63 : 1** | 4.5 | ❌ |
| `.tertiary` | 卡片材质（深） | **2.71 : 1** | 4.5 | ❌ |
| `.secondary`（60% 白） | `baseDark` | 7.27 : 1 | 4.5 | ✅ |

**受影响的文本**（均 < 18pt，须按 4.5:1 判）：

- `ConnectView.swift:190` 密码 `12345678`（footnote，accent）
- `ConnectView.swift:255` 「恢复默认」（footnote，accent）
- `SettingsView.swift:151/218` 操作按钮（accent）
- `ConnectView.swift:370-378` 页脚版本号（caption2，**tertiary**，两行 11pt 文本）
- `RootView.swift:126` 「重试」（accent，但位于玻璃上，实际略好）

注释里"保证 ≥ 4.5:1"的结论对深色成立、对浅色不成立。

**建议**：把 `accentLight` 压深一档即可同时满足底与卡片（不改色相，仍是同一个青绿）：

```swift
static let accentLight = RGBA(r: 0.035, g: 0.470, b: 0.415)   // base 4.98:1 / card 5.22:1
```

`.tertiary` 的 11pt 页脚改为 `.secondary`（7.27:1），或新增 `Theme.mutedText` = 55% 白。

> 计算脚本：`python3` + 标准 sRGB→线性化 + `(L1+0.05)/(L2+0.05)`，可复现。

---

### P1-5 非法地址 → 永久「正在查找设备」（无反馈死路）

**位置**：`AppModel.swift:89-97`、`129-132`

```swift
var normalizedHost: String { … }   // 只剥 scheme 和路径，不校验字符

private func probe() async {
    probeCount += 1
    guard let url = URL(string: "http://\(normalizedHost)/api/wifi/status") else { return }  // ← 静默返回
    …
}
```

用户输入 `192.168.4.1 abc` 或带不可编码字符时：`URL(string:)` 返回 `nil` → **提前 return，`state` 永远停在 `.probing`** → 界面永远转圈显示"正在查找设备"，既不报错也不超时，用户只能猜。

更糟的是 `baseURL`（`:99-102`）在同一输入下会**静默回落到默认 IP**，于是"状态卡显示的是坏地址，实际探的是默认地址"，两处行为不一致。

**建议**：在 `probe()` 的 guard 失败分支给出明确状态，并在 `applyHost` 做输入校验。

```swift
guard let url = URL(string: "http://\(normalizedHost)/api/wifi/status") else {
    state = .offline("地址格式不正确，请填写 IP 或 IP:端口")
    applyIdleTimer()
    return
}
```

`baseURL` 也应对同一 `normalizedHost` 保持一致（或标注 fallback 原因），避免"显示与实际不一致"。

---

### P1-6 预览页关闭按钮 32×32，低于 44pt 触控下限

**位置**：`PreviewView.swift:29-42`

```swift
.frame(width: 32, height: 32)     // 点击区域只有 32pt
.background(.ultraThinMaterial, in: Circle())
```

HIG 明确要求可点击目标 ≥ 44×44pt；这里既没有 `.contentShape` 外扩，也没有 `.padding` 撑大命中区。同类问题：`ConnectView` 的 `GlassIconButton` 已用 46pt（正确），`PreviewView` 是全项目唯一的例外。而预览页是**全屏 modal**，关闭按钮是唯一出口，命中率低的代价更高。

**建议**：

```swift
Image(systemName: "xmark")
    .font(.system(size: 13, weight: .bold))
    .frame(width: 44, height: 44)                 // 命中区 44
    .background(.ultraThinMaterial, in: Circle())
    .contentShape(Circle())
```
视觉上如需保持 32pt 的胶囊，用 `.background` 尺寸与 `.frame` 分离即可。另外应补 `.contentShape` 与 `.accessibilityLabel`（已有 label ✓）。

---

## 4. P2 问题（复用性 / 性能 / 多设备 / 可维护性）

### P2-1 连接页地址与设置页不同步

**位置**：`ConnectView.swift:47`

```swift
.onAppear { draftHost = model.host }   // 只在首次出现时同步
```

`ConnectView` 在 `RootView` 的 `ZStack` 里常驻，打开设置 sheet 不会重建它。于是在设置里改了地址并「保存并重新连接」、返回连接页后，**输入框仍显示旧地址**，而 `model.host` 已是新值——用户看到的和实际探测的不是同一个东西。

**建议**：双向同步，而不是一次性快照。

```swift
.onAppear { draftHost = model.host }
.onChange(of: model.host) { draftHost = $0 }
```

### P2-2 版本号在 3 处硬编码

`ConnectView.swift:372` `"App 1.3.0 (4) · 固件 P4-CAN Universal v3.29.3"`、`SettingsView.swift:233` `"1.3.0 (4)"`、`build-ipa.sh:8` `VERSION="1.3.0"`，而工程里 `MARKETING_VERSION = 1.3.0` / `CURRENT_PROJECT_VERSION = 4` 才是真源。发版时漏改任一处的概率不低（v1.2.0→v1.3.0 已经手工同步过 3 次）。

**建议**：单一来源。

```swift
enum AppInfo {
    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
```
`build-ipa.sh` 也从 `xcodebuild -showBuildSettings` 读 `MARKETING_VERSION`，不要重复声明。

### P2-3 网页仪表盘完全不响应 Dynamic Type

`zh-bilingual.js` 用真实文本节点（v1.3.0 的改进）——可选中、可搜索、VoiceOver 可读，这点做得对。但**字号**完全由页面 CSS 决定：系统字号调到最大，仪表盘文字纹丝不动。原生部分（连接页、设置页）支持 Dynamic Type，进入仪表盘后突然不支持，体验断层。

**建议**：注入一段 `documentStart` 脚本，把系统字号映射成 `documentElement.style.fontSize` 或 `-webkit-text-size-adjust`，用 `traitCollection.preferredContentSizeCategory` 驱动；字号变化时通过 `WKNavigationDelegate`/`traitCollectionDidChange` 重注入。

### P2-4 离屏渲染工具根本没验证 Dynamic Type（工具缺陷）

`Preview/main.swift:33-40` 用 `.environment(\.dynamicTypeSize, …)` 覆盖字号，但实测：

```
md5 connect-se.png      = a953c408…   (typeSize: .large)
md5 connect-se-ax5.png  = a953c408…   (typeSize: .accessibility5)   ← 与上一行完全一致
```

**两张图字节完全相同**，`connect-ax2` 与默认图也仅差 45 字节。说明 `ImageRenderer` 下该环境值未生效，`connect-ax2/ax5` 这两张「辅助功能大字号检查图」**一直是无效证据**。同时 `p4StaticLayout` 用 `.clipped()` 把溢出内容裁掉，也看不到"内容是否溢出"——恰好把要测的问题藏起来了。

**建议**：改用 XCUITest + 真机/模拟器截图（`XCUIScreen.main.screenshot()`），或在渲染前用 `UIFontMetrics(forTextStyle:).scaledValue(for:)` 自算尺寸断言；`p4StaticLayout` 分支改为不裁剪 + 打印内容高度以便比对目标高度，并加一条断言：`contentHeight <= 目标高度`。

### P2-5 内容层卡片叠 material + shadow，滚动成本偏高

`Theme.swift:232-256`：每张 `SurfaceCard` = `.regularMaterial`（实时背景模糊）+ 独立阴影（radius 14–20）。连接页在 ScrollView 里叠 6 张，滚动时每张都要重算模糊与阴影。iPhone SE 这类老机型上容易掉帧；深色下阴影几乎不可见，属于"花了钱没买到效果"。

**建议**：内容层改用不透明微填充（`Color.adaptive(白 2%/黑 40%)`）+ 现有 hairline 描边，去掉 `.shadow`；玻璃只留在控制层——这也正好符合注释里自己引用的 HIG 原则（"玻璃属于控制层"）。顺带删掉每张卡片的 `@Environment(\.colorScheme)`。

### P2-6 `FrostGrain` 用 Canvas 逐点画椭圆

`Theme.swift:171-207`：393×852 @ step 7 → 约 6,776 个椭圆；iPad 12.9"（1024×1366）→ 约 **28,000** 个。虽然只画一次、种子固定不闪，但每次外观切换/尺寸变化都要重算，iPad 首帧有可见卡顿。

**建议**：把噪点渲染成 64×64 的 `tileImage` 缓存（`ImageRenderer` 一次性生成），再用 `Image(...).resizable(resizingMode: .tile)` 平铺；或按 `UIScreen.scale` 预生成 PNG 资源。成本从 O(面积) 降到 O(1)。

### P2-7 声明支持 iPad 与横屏，但没有任何适配

`TARGETED_DEVICE_FAMILY = "1,2"` + `Info.plist` 四个方向全开，但：

- 连接页无 `maxWidth` 约束 → iPad 横屏（1366pt）下卡片被拉成整屏宽，正文行长超过 HIG 建议的可读宽度（~60–75 字符）；
- `SettingsView` 在 iPad 上是居中的 form sheet，但 `Form` 行宽无约束；
- 横屏 iPhone（852×393）下 `padding(.top, 64) + padding(.bottom, 148)` 吃掉 212pt，可视内容只剩 181pt，首屏几乎看不到一张完整卡片；
- `PreviewView` 全屏 webview 在横屏下没有降级策略。

**建议**（二选一）：

- 若目标只是车载手机使用：`TARGETED_DEVICE_FAMILY = 1`，`Info.plist` 只留 Portrait，把问题消灭在配置层；
- 若要保留 iPad：给内容加 `.frame(maxWidth: 560)` + `ScrollView` 居中，横屏时把 `top/bottom` 留白改为按 `verticalSizeClass` 分支。

### P2-8 后台仍以 3 秒间隔轮询

`AppModel.swift:110-118` 的 `probeTask` 只在 `stopProbing()` 时取消，而全项目没有 `scenePhase` 监听。App 进后台后循环继续（挂起后恢复即立刻再探），既耗电又会在回到前台瞬间产生一次状态翻转（进而触发 P1-2）。

**建议**：

```swift
@Environment(\.scenePhase) private var scenePhase
…
.onChange(of: scenePhase) { phase in
    phase == .active ? model.startProbing() : model.stopProbing()
}
```
回到前台时 `probeOnce()` 一次即可。

### P2-9 零测试 + 无注入缝

全项目 0 个测试文件。`AppModel` 里 `session` 是 `private let` 且在 `init` 内构造，无法替换 → 探活状态机（`.probing/.online/.offline` 迁移、`describe(_:)` 的错误映射）这些**最适合单测的纯逻辑**一个都测不了。

**建议**：最小改造 —— `init(session: URLSession = .shared, defaults: UserDefaults = .standard)`，把 `describe(_:)`（已是 static，可直接测）与 `probe()` 的判定逻辑抽成 `LinkProbe` 值类型。先补 3 个用例：401 → 仍 online、超时 → offline 文案、非法地址 → offline。

---

## 5. P3 问题（细节与一致性）

| # | 位置 | 问题 | 建议 |
|---|---|---|---|
| P3-1 | `AppModel.swift:17-20` | `LinkState.reason` 计算属性从未被使用（`ConnectView:144` 的 `reason` 是模式绑定，遮蔽了它） | 删除 |
| P3-2 | `Theme.swift:63-66` | `Theme.sky` 未被任何视图引用 | 删除或标注用途 |
| P3-3 | `AppModel.swift:189-192` | `markOnlineAgain()` 无调用点 | 删除 |
| P3-4 | `RootView.swift:7`、`DeviceWebView.swift:23` | `isLoading` 只写不读（没有任何加载 UI 消费它） | 要么接骨架屏，要么删掉这条绑定（每条导航回调都会白白触发一次 SwiftUI diff） |
| P3-5 | `AppModel.swift:54` | `lastSuccess` 只写不读 | 与 P1-2 的 `hasBeenOnline` 合并使用 |
| P3-6 | `Theme.swift:305-311` | `p4ScrollEdgeSoft` 只判 `#available(iOS 26.0, *)`；`GlassSurface.swift:17` 判的是 `(iOS 26.0, macOS 26.0, *)`。在 macOS 目标下前者恒真，macOS <26 会踩到不存在的 API | 统一为双平台可用性判断 |
| P3-7 | `DeviceWebView.swift:50`、`PreviewView.swift:65` | `isInspectable = true` 在 Release 包里也开着，任何人接 Mac 即可调试内嵌页面 | 包进 `#if DEBUG` |
| P3-8 | `ConnectView.swift:351` | `helpItem(_ title: String, _ body: String)` 的参数名 `body` 遮蔽了 `var body` | 改名 `detail` |
| P3-9 | `ConnectView.swift:29-30` | `64` / `148` 魔法数字，横屏与 iPad 下不自洽 | 提到 `Metrics.floatingTopInset` / `floatingBottomInset`，或改用 `safeAreaInset` |
| P3-10 | `ConnectView.swift:30`、`RootView.swift` | 页脚"App 1.3.0 (4) · 固件 v3.29.3"把固件版本也写死了，而固件版本只有连上设备才知道 | 改成从 `/api/status` 读，或删掉 |
| P3-11 | `ConnectView.swift:424-444` | `App-Prefs:root=WIFI` 是私有 scheme，上架必被拒 | 侧载分发可接受，但应在 README 注明"仅侧载"，或直接改为 `UIApplication.openSettingsURLString` |
| P3-12 | `ConnectView.swift:138-147` | `.online` 分支的 `statusDetail`（"正在加载仪表盘"）实际不可达——一旦 online，`RootView` 立刻换掉 `ConnectView` | 删除该分支或改为 transition 期间的过渡态说明 |
| P3-13 | `Assets.xcassets/AppIcon` | 只有 1024 universal 一张，没有 iOS 18 的 dark/tinted 变体（`docs/screenshots/icon-dark.png` 存在但没进 asset） | 补 `appearances` 条目 |
| P3-14 | `LaunchBg.colorset` | 只有一套深色值；浅色模式下启动闪屏为深色 → 进 App 闪一下 | 补 light 变体，或统一走深色启动 + 首帧 cover |

---

## 6. HIG / 无障碍逐项核对

| 检查项 | 状态 | 证据 |
|---|---|---|
| 触控目标 ≥ 44pt | ⚠️ 1 处不达标 | `GlassIconButton` 46 ✓、`ActionButton` 46 ✓、`minHeight: minTap` 多处 ✓；`PreviewView` 关闭键 32 ✗（P1-6） |
| VoiceOver 标签 | ✅ 基本完整 | 图标按钮、状态卡、预览入口、section header 均有 label / `.isHeader`；装饰性 Circle 均 `accessibilityHidden` ✓ |
| VoiceOver 可操作性 | ❌ 1 处 | `failureBanner` 的 `.combine` 吞掉重试按钮（P1-3） |
| Dynamic Type | ⚠️ 部分 | 原生界面用语义字体（`.body/.footnote/.caption2`）✓；`ActionButton` 在 `>= .accessibility3` 降级为图标，避免撑破胶囊 ✓；但网页仪表盘不响应（P2-3），且验证手段失效（P2-4） |
| 对比度 4.5:1（正文） | ❌ 浅色不达标 | accentLight 4.09、tertiary 2.63（P1-4） |
| 非文本对比 3:1（图标/圆点） | ✅ | warn 浅色 3.90、danger 5.18，均 >3 |
| 不单靠颜色传达状态 | ✅ | 状态卡有文字（已连接/未连接）+ 色点；徽标有文字 |
| 深色模式 | ⚠️ | 两套色值齐备、`Theme.adaptive` 用 trait 解析 ✓；但应用级强制深色与设置冲突（P1-1） |
| 减少动效 / 减弱透明度 | ⚠️ | 材质与 `glassEffect` 由系统自动降级 ✓；但 `GlassPressStyle` 的 0.94 缩放与 chevron 旋转未读 `accessibilityReduceMotion` |
| 无汉堡菜单 / TabBar 导航 | ✅ | 单根 Shell，未引入抽屉；底部控制条为操作而非导航 |
| 不遮挡系统返回手势 | ✅ | 未定义 `interactivePopGestureRecognizer` 相关逻辑；`allowsBackForwardNavigationGestures = false` 仅作用于 webview 历史 |
| 权限在上下文中请求 | ✅ | 无启动即弹窗；`NSLocalNetworkUsageDescription` 已有文案，首次访问即触发，属上下文触发 |
| Modal 必有取消路径 | ✅ | `SettingsView`：完成按钮 + dragIndicator + detents；`PreviewView`：关闭键（但命中区偏小） |
| 不用全屏 spinner | ✅ | 状态卡内联 `ProgressView`，非全屏遮罩 |
| 8pt 栅格 / 同心圆角 | ✅ | `Metrics` 全为 4/6/10/16/20/24/28；圆角 32→24→16→14 递减 |
| 语义化颜色 | ⚠️ | `Theme.accent/base/warn/danger` 走 adaptive ✓；但 `GlassSurface` 内硬编码 `.white/.black` 透明度描边，未走语义色（玻璃高光可接受，建议注释说明） |
| 安全区域 | ✅ | 交互元素均在安全区内；`ignoresSafeArea` 只用于背景与 webview 底边 |

---

## 7. 布局与多设备适配分析

已渲染验证的尺寸（`Preview/out/`）：

| 尺寸 | 设备 | 结果 |
|---|---|---|
| 393×852 @3x | iPhone 15/16 | 布局完整，六张卡片 + 页脚全可见；底部控制条未参与离屏渲染（见下） |
| 320×568 @2x | iPhone SE 1st | 内容溢出，需滚动（真实 App 是 ScrollView，符合预期）；顶部标题被裁是离屏渲染的裁剪行为，不是真机表现 |

**离屏渲染的两处盲区**（影响本次审查的完整度，需在工具上补）：

1. `GlassCluster` → `GlassEffectContainer` 在 `ImageRenderer` 下**不产生像素**：截图里顶部设置按钮与底部整条控制栏**完全缺失**。也就是说三张 `docs/screenshots/connect-*.png` 里最关键的玻璃控件并未经过离屏验证，只能靠 MacPreview 实窗口人工看。
2. `.regularMaterial` 与 `TextField`/`ProgressView` 在离屏渲染下分别退化为不透明灰块与"禁止"符号（截图中的黄色斜杠图标）——属工具限制，不是产品缺陷，但会让自动化截图比对完全失效。

**跨尺寸的真实风险**（代码推断，需真机确认）：

- 横屏 iPhone：`top 64 + bottom 148` 固定留白 + 6 张卡片 → 首屏仅 181pt 可视，需大量滚动；
- iPad：无 `maxWidth`，行长过宽（P2-7）；
- `ActionButton` 的 `ViewThatFits` + `compact` 双保险设计得不错，`Metrics.controlHeight` 固定 46 与 `.frame(height:)` 锁高配合正确，大字号下不会撑破——这一处是本项目适配做得最好的地方。

---

## 8. 代码结构与复用性

**做得好的**：

- 设计令牌集中在 `Theme`/`Metrics`，没有散落的魔法色值（除玻璃高光）；
- `GlassSurface` 用 `ViewModifier` 封装 iOS 26 / 旧系统两套实现，调用侧零分支；
- `ZhPatch` 把"资源是否存在"与"如何注入"解耦，缺资源时优雅降级；
- 注入脚本用单例守卫 + 让位上游语言层，多路径不叠加（实测已证）。

**可优化**：

| 项 | 现状 | 建议 |
|---|---|---|
| `ConnectView` 449 行 | 6 个 section 全在一个文件，含 5 个私有子视图与 3 个动作方法 | 按 section 拆成 `ConnectHeader` / `LinkStatusCard` / `ConnectStepsCard` / `DeviceAddressCard` / `TroubleshootingCard`，`ConnectView` 只负责编排 |
| 失败提示条 ×3 | `RootView.failureBanner`、`MacPreview/WebPane.swift:118-137` 内联版、`RootView.settingsHintCapsule` 同构 | 抽 `GlassBanner(icon:text:actionTitle:action:)` 到 `Glass.swift` |
| `DeviceWebView` / `DeviceWebPane` | 两个 Coordinator 各自实现 load/sync/fail，逻辑约 90% 重复 | 抽平台无关的 `WebPageState`（`lastToken/lastURL/sync` 纯逻辑），两侧只保留 representable 壳 |
| `DeviceWebView.installZH` 被 `PreviewView` 直接调用 | 预览页依赖连接页的类型，耦合方向反了 | 抽 `WebInjection.install(into:enabled:)` 独立类型，两边都依赖它 |
| 地址编辑逻辑 ×2 | `ConnectView.addressSection` 与 `SettingsView.deviceSection` 各自实现"去空白 → 校验 → 写 model → 重探" | 抽 `HostEditor`（含校验与错误文案，正好落地 P1-5） |
| `holdScript`/`revealScript` 内联多行 JS | 硬编码在 Swift 字符串里，改文案要改代码 | 移到 `Resources/` 下作为 .js 资源，与 `zh-bilingual.js` 同管 |
| 魔法时间 | `1.2s` hold、`60ms` reveal、`1.2/0.9×3` 行探测、`3s` 轮询、`6s` 提示 | 集中到 `enum Timing`，便于按设备调参 |
| 本地化 | 全部中文字面量，`CFBundleDevelopmentRegion = zh_CN` | 若要出海，尽早迁 String Catalog；现在至少把长文案（设置页 footer）移到常量文件 |

---

## 9. 建议修复顺序

**第一批（1–2 小时，全在 P1，改动局部、风险低）**

1. 删 `UIUserInterfaceStyle`（P1-1）→ 真机 30 秒验证浅色。
2. `failureBanner` 改 `.contain`（P1-3）→ VoiceOver 走查一次。
3. `accentLight` 压深 + 页脚改 `.secondary`（P1-4）→ 用本文的对比度脚本复算。
4. `PreviewView` 关闭键 44pt（P1-6）。
5. `probe()` 非法地址给出 offline（P1-5）。
6. WebView 保活（P1-2）→ 这是体验收益最大的一条，建议连同上一条一起改，然后跑一次"断网 10 秒"回归。

**第二批（半天，P2 中影响体验的）**

7. `onChange(of: model.host)` 同步（P2-1）。
8. 版本号单一来源（P2-2）。
9. `scenePhase` 暂停轮询（P2-8）。
10. 卡片去 material+shadow（P2-5）→ 用 SE 真机对比滚动帧率。

**第三批（结构性，可排到下一版）**

11. 拆 `ConnectView`、抽 `GlassBanner` / `WebInjection` / `HostEditor`（§8）。
12. 补 `AppModel` 依赖注入 + 3 个状态机单测（P2-9）。
13. 用 XCUITest 取代失效的离屏大字号验证（P2-4），并给 iPad/横屏定方案（P2-7）。
14. 词典补齐 `Unavailable` 等 5 条残留（§2.3），重跑 `tools/build_dashboard.py`。

---

## 10. 未能验证、需真机确认的三项

| 项 | 原因 | 建议验证方式 |
|---|---|---|
| 「跟随系统」是否为深色（P1-1） | 无真机/模拟器实例（`xcrun simctl` 无可用设备），`Info.plist` 不被 macOS 预览读取 | 系统切浅色 → 设置选「跟随系统」→ 看连接页背景 |
| `.combine` 是否真的吞掉按钮（P1-3） | 同上，VoiceOver 行为只能真机走查 | 断网进仪表盘 → 触发失败条 → VoiceOver 左右滑动找「重试」 |
| iOS 16 真机 `glassSurface` 回退观感 | 预览环境为 macOS 26，只走到了 `glassEffect` 分支 | iOS 16 设备装包，确认 `ultraThinMaterial` 版本的描边/阴影不脏 |

---

*本报告的全部结论均可由 §1 的命令复现；涉及"需真机确认"的三项已单独标注，未混入确定结论。*
