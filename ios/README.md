# P4CAN for iOS

把 P4-CAN 控制器自带的网页仪表盘包成一个原生 iOS App。网页仍由设备提供（`http://192.168.4.1`），
App 只负责：全屏容器、本地网络权限、连不上时的原生引导页、设置项与缓存管理。

## 目录

```
P4CAN-iOS/
├── P4CAN.xcodeproj/          # Xcode 工程（含共享 scheme）
├── P4CAN/
│   ├── P4CANApp.swift        # @main
│   ├── AppModel.swift        # 设备探活、地址持久化、屏幕常亮
│   ├── RootView.swift        # 在线→网页 / 离线→引导页
│   ├── DeviceWebView.swift   # WKWebView 封装（下拉刷新、外链处理）
│   ├── ConnectView.swift     # 连接引导（步骤、跳转 WiFi、手动 IP、排查）
│   ├── SettingsView.swift    # 设置面板（材质 sheet）
│   ├── Theme.swift           # 设计令牌 / 背景 / 内容卡片 / 滚动边缘
│   ├── Glass.swift           # 液态玻璃组件（仅控制层）
│   ├── ZhPatch.swift         # 读取随包的汉化脚本
│   ├── PreviewView.swift     # 离线界面预览（WKWebView 装 preview.html）
│   ├── preview.html          # 示例页面：自写，不含上游代码，带 DEMO 标注
│   ├── zh-bilingual.js       # 汉化脚本本体（打包前从 ../i18n/ 同步，勿单独改）
│   ├── Info.plist            # ATS 例外、本地网络权限说明
│   └── Assets.xcassets/      # AppIcon(1024) / AccentColor / LaunchBg
├── tools/make-icon.py        # 图标流水线：源图 → 1024 满铺 → AppIcon + 预览 + icns
├── 图标/                     # 图标成品、多尺寸、深浅桌面预览、AppIcon.icns
├── make-icon.swift           # 早期图标生成脚本（已由 tools/make-icon.py 取代）
├── build-ipa.sh              # 编译 + 打未签名 ipa
├── Preview/                  # macOS 离屏渲染器（看版式，不入包）
├── MacPreview/               # macOS 真窗口预览（看玻璃，不入包）
└── dist/                     # 产物
```

## 构建

```bash
cd P4CAN-iOS
./build-ipa.sh              # 默认 Release，产出 dist/P4CAN-1.2.0-unsigned.ipa
./build-ipa.sh Debug        # Debug 版
```

脚本先把 `../i18n/zh-bilingual.js` 同步到 `P4CAN/zh-bilingual.js`（唯一来源是 i18n 那份，
改文案只动它），再用 `CODE_SIGNING_ALLOWED=NO` 编出真机 arm64 包，按 `Payload/` 结构压成 ipa。
产物**未签名**，需要用 Sideloadly / AltStore / Xcode 以你自己的 Apple ID 签名后安装。

> `OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` 是为了在本机受限环境下让
> `swift-plugin-server` 能展开 `@State` 等宏；在正常 Xcode 里打开工程不需要它。

## 关键实现

| 点 | 做法 |
|---|---|
| 明文 HTTP | `Info.plist` 里 `NSAllowsArbitraryLoads` + `NSAllowsLocalNetworking` |
| 本地网络权限 | `NSLocalNetworkUsageDescription`，iOS 14+ 首次访问会弹窗 |
| 连通性判定 | 每 3 秒 GET `/api/wifi/status`，2.5s 超时；成功才切到网页层 |
| 网页持久化 | `WKWebsiteDataStore.default()`，localStorage 与 cookie 跨启动保留 |
| 中文界面 | `ZhPatch` 读出随包的 `zh-bilingual.js`，`WKUserScript` 在 `documentEnd` 注入；`documentStart` 先把页面压透明，注入完淡入，1.2s 兜底防止白屏 |
| 避免重复翻译 | 补丁里有单例守卫（`__p4zhBooted` / `p4zh-style`），固件已内置汉化时注入的那份直接退出 |
| 离线预览 | 连接页「界面预览」→ `PreviewView` 用 `WKWebView.loadFileURL` 加载包内 `preview.html`；不注册 `p4canApp` 通道，补丁也就不会往示例页插入口行 |
| 外链 | 非 http(s) scheme 交给系统，`target=_blank` 留在应用内打开 |
| 屏幕常亮 | 仅在线且开关打开时 `isIdleTimerDisabled = true` |
| 刷新 | 下拉手势（UIRefreshControl）+ 设置里的「重新加载」 |
| 玻璃 | 控制层统一走 `glassSurface(_:tint:interactive:)`；iOS 26+ 用 `glassEffect`，低版本回退 `ultraThinMaterial` |
| 控件高度 | 底部主按钮与圆形图标钮共用 `Metrics.controlHeight` = 46，并排时高度与中心线始终一致 |
| 外观 | `AppAppearance`（跟随系统 / 浅色 / 深色）存 `p4can.appearance`，设置面板可即时切换 |
| 原生设置入口 | 汉化固件：网页"设置 → 系统 → P4-CAN App"一行回调 `p4canApp`；原厂固件没有该行时，探测 3 次后启用**长按页面 0.7 秒**，并飘一次提示条 |
| 滚动边缘 | iOS 26 的 `scrollEdgeEffectStyle(.soft, for: .top)`，旧系统无操作 |
| 图标 | 源图（玻璃 T）四边是奶油白、圆角 26%，比 iOS 遮罩的 22.4% 更圆，直接塞进去四角会露白；`tools/make-icon.py` 按方块圆角挖空后用扩散把边框色补进四角，输出 1024 满铺、无 alpha 的 PNG |

## 配哪种固件都行，界面都是中文

页面仍然全部来自设备 `http://192.168.4.1/`，但 App 会把 `zh-bilingual.js` 注进去，
所以**原厂英文固件也能显示中文**：

| 刷的固件 | 界面语言 | 功能 | 进 App 设置 |
|---|---|---|---|
| 原厂 v3.29.3 | 中文（App 注入） | 全部正常 | 长按页面 0.7 秒（首次进页面会提示一次） |
| 打了汉化补丁的 v3.29.3 | 中文（固件自带） | 全部正常 | 网页"设置 → 系统 → P4-CAN App" |

两条路径互不打架：补丁开头加了单例守卫，固件已经内置汉化时（`window.__p4zhBooted` 或
`#p4zh-style` 已存在），App 注入的这份直接 `return`，页面元素只被标记一次。

汉化只改页面：加 `data-p4zh` 属性由 CSS `::after` 画中文，原文保留；不拦截请求、不改事件、
不动固件逻辑。App 注入时同样如此，只是把这一步从"编译进固件"挪到了"加载后补一层"。

App 设置里 **语言 → 中文界面** 可以关掉，关掉后重新加载即为原始英文页面。

### 没有设备时：界面预览

连接页第二张卡片是「界面预览」，打开的是包里的 `preview.html`——**自写的示例页面**，
顶部固定标 `DEMO · 示例数据，未连接设备`，数据全部写死，不发任何报文、不访问网络。
底部导航可切 Home / Devices / Settings / LAB，开关能点，用来演示或提前熟悉界面。

示例页里的文案特意用上游仪表盘的真实词条（`Steering` / `Nag Killer` / `RUNNING` / `BODY` …），
所以它同样会被 `zh-bilingual.js` 翻译——关掉中文开关再看一次，就能直观对比双语并列的效果。

> 想在本机看"原厂固件"下的样子：`UNPATCHED=1 bash demo.sh`（这时页面里没有任何中文，
> 正好用来看注入前后的差别）。

## 版本

- App 1.2.0 (3)：新增「界面预览」，没连设备也能看示例界面
- App 1.1.0 (2)：App 侧中文注入（原厂固件也显示中文）+ 语言开关
- 适配固件 P4-CAN Universal v3.29.3
- 最低 iOS 16.0，iPhone / iPad 通用，支持横屏
- iOS 26+ 启用 Liquid Glass；旧系统自动回退材质，版式与信息层级不变

## 视觉规范

玻璃只用于**控制层**（浮动按钮、底部操作条、失败横幅），内容层一律用标准材质卡片——这是 HIG 对
Liquid Glass 的硬性要求。色板、圆角（32/24/16/14 同心）、8pt 栅格与字号层级集中在 `Theme.swift`。
设计稿见 [液态玻璃设计稿](https://kaiser-dmr.github.io/p4can-zh-ios/liquid-glass-design.html)
（源文件 `docs/liquid-glass-design.html`），安装与使用见仓库根目录 [`README.md`](../README.md)。

### 底部操作条

- 主按钮（打开无线局域网设置）与右侧刷新键同为 **46pt 高**，由 `Metrics.controlHeight` 统一，
  外层 `HStack` 再锁一次高度，避免玻璃的视觉外扩造成错位。
- 主按钮是**无色磨砂玻璃 + 淡青 tint**，不是 `.glassProminent` 的实心填充；
  主次由品牌色图标与字重表达，材质与圆钮完全同源。
- 窄屏与辅助功能字号：`ViewThatFits` 先保文字，放不下就降级为纯图标；
  字号 ≥ `.accessibility3` 时直接收成图标按钮，保证高度不膨胀、不截字。

### 背景与明暗

- 背景是**纯色磨砂**：单一纯色（深 `#0B0D11` / 浅 `#F4F6F9`）+ 一层极细噪点，
  没有彩色光晕也没有渐变亮带。噪点用固定种子的 `SplitMix64` 生成两张 `Path` 后各填一次，
  背景重绘时颗粒不会闪，也不逐点 `fill`。
- 全部颜色走 `Color.adaptive(_:_:)`（`UIColor` / `NSColor` 动态色），亮暗两套各自独立，
  浅色下品牌青绿压深到约 4.5:1，避免亮青在白底上糊掉。
- 外观设置存 `p4can.appearance`。进入仪表盘后强制深色——设备网页本身是深色的，
  浅色状态栏压上去读不清。

## 图标

```bash
python3 tools/make-icon.py ~/Pictures/qk9WgCu3EB8TmHAR.webp
```

- 源图是"奶油白底 + 玻璃方块 + 字母"，方块圆角约 26%，比 iOS 遮罩的 22.4% 更圆。
  直接当图标用，四个角会在遮罩内露出奶油白边（`图标/` 里留了对比可以看）。
- 脚本先按方块自身的圆角把四角挖空，再用扩散（反复模糊 + 回填已知像素）把边框高光顺进角里，
  得到满铺画面；输出 RGB、无 alpha 的 1024 PNG（iOS 要求无透明通道）。
- 同时产出 `图标/icon-{180,120,60,40}.png`、深浅两张桌面预览，以及给 Mac 预览包用的
  `AppIcon.icns`（按 macOS 惯例留 10% 边距、自带投影）。
- 换图标只需替换源图重跑；`make-icon.swift` 是早期的占位图标脚本，已不再使用。

## 在电脑上跑起来（看真实玻璃）

```bash
cd P4CAN-iOS/MacPreview
./preview.sh
```

同一个 SwiftUI 视图编成 macOS 窗口跑。macOS 26+ 用与 iOS 26 相同的 Liquid Glass 合成，
所以这里的玻璃是系统实时渲染的：顶部圆键、底部操作条的模糊、边缘高光、按下形变都能看到。
窗口顶部有状态切换（探测中 / 未连接 / 已连接）与明暗切换（太阳 / 月亮），
选择都会存进 UserDefaults，下次启动保持。预览窗口还补了 34pt 底部安全区，
让底部玻璃条的位置与 iPhone 上一致。

`preview.sh` 的编译命令带 `-D P4CAN_PREVIEW`，因此 `AppModel` 里那个只用于注入状态的
`previewState(_:)` 才存在；iOS 包不会编进这段代码。

**macOS 与 iOS 的差异**（别拿窗口当 iPhone 看）：

- 安全区是补出来的（`safeAreaPadding(.bottom, 34)`），顶部仍比真机少一截；也没有圆角屏幕
- 设置面板用的是 macOS `Form`，`MacPreview` 里加了 `.formStyle(.grouped)` 才接近 iOS 的 inset grouped；
  按钮仍是 macOS 的胶囊样式，不是 iOS 的整行样式
- 滚动条是 macOS 的浮动指示器

## 预览限制

`Preview/`（离屏渲染）只能校验版式：`glassEffect` 在 `ImageRenderer` 里会整块丢弃，
`TextField` / `ProgressView` 会画成黄底红斜杠占位符，`dynamicTypeSize` 不缩放字号——都是渲染器限制。

进程内也抓不到 SwiftUI 的绘制结果：`cacheDisplay(in:to:)`、`CALayer.render(in:)` 都只拿到 AppKit 那层
（控制条画出来了，内容区是白的），因为 SwiftUI 内容由窗口服务器合成；`CGWindowListCreateImage`
在新 SDK 已移除，`SCScreenshotManager` 会挂在屏幕录制授权上。

要看真实效果就用上面的 `MacPreview` 窗口，或用 `screencapture -l <windowid>` 截该窗口。
