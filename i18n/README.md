# 中英双语补丁

给 [P4can-universal-unlock](https://github.com/06066060606060/P4can-universal-unlock) 的仪表盘加中文注释：
**保留英文原文，在下面补一行小号中文**。

上游页面没有任何中文，`dashboard_source.html` 里的文案是硬编码的（约 880 条静态文案 + 若干运行时拼接句），
也没有 i18n 层，所以中文只能靠这份补丁注入。

## 文件

| 文件 | 作用 |
|---|---|
| `zh-bilingual.js` | 补丁本体：`ZH` 词典（850 条）+ `RULES` 正则规则 + 给元素打 `data-p4zh` 属性，中文由 CSS `::after` 渲染 |
| `apply_zh.py` | 把补丁注入 `dashboard_source.html`，可选重生成 `index_html.h`（幂等，可反复跑） |

## 用法

```bash
# 需要先自己 clone 上游固件仓库
git clone https://github.com/06066060606060/P4can-universal-unlock.git

# 注入并重建固件页面数据（index_html.h 是页面 gzip 后的字节数组，必须重生成）
python3 apply_zh.py ./P4can-universal-unlock --build

# 还原成纯英文
python3 apply_zh.py ./P4can-universal-unlock --revert --build
```

注入块由 `<!--P4ZH-BEGIN-->` / `<!--P4ZH-END-->` 包住，重复执行只替换这一段。
之后按上游原来的流程用 arduino-cli 编译烧录，固件其它代码一行不动。

### 也可以不刷固件：由 iOS App 注入

同一份 `zh-bilingual.js` 也被打进了 iOS App（`ios/P4CAN/zh-bilingual.js`，打包时自动从本目录同步），
App 用 `WKUserScript` 在页面加载完成后把它注进去。所以**原厂英文固件也能显示中文**，不用动板子。

- 脚本开头有单例守卫：`window.__p4zhBooted` 或 `#p4zh-style` 已存在时直接 `return`。
  这样"固件已内置补丁 + App 又注入"也不会跑两套 `MutationObserver` 互相抢。
- 注入是在 HTML 解析之后，会先闪一下英文，所以 App 在 `documentStart` 先把页面压透明，
  注入完再淡入；1.2 秒兜底定时器保证脚本出问题时不会白屏。
- 这段逻辑在 `ios/P4CAN/DeviceWebView.swift`，改文案仍然只改这里的 `zh-bilingual.js`。

## 原理

没有改任何逻辑，只做"加属性"：

- 遍历所有文本节点，命中词典就给该元素加 `data-p4zh="中文"`，中文由
  `[data-p4zh]::after { content: attr(data-p4zh) }` 画在旁边 —— 所以是**双语并列**，不是替换。
- 唯一真正改字的是 `<select>` 的 `<option>`（CSS 伪元素在系统下拉框里不渲染），原文存在
  `data-zh-orig` 里，`--revert` 时还原。
- 不拦截 `fetch` / `XHR`、不覆写原型、不碰 `localStorage`、不改任何事件处理；`<script>`、`<style>`、
  输入框、徽标都明确跳过。重渲染后靠 `MutationObserver` 重扫，跑在手机上，不占板子 CPU。

## 覆盖率

v1 用 class 白名单，只覆盖 112/884 个节点；v2 改成"遍历文本节点 + 词典精确匹配"，不依赖 class，
上游改版只要文案没变就一直生效。

**已译**：首次开机选车型、固件升级提示、底部导航、首页（状态行 / 模式 / 三个指标 / 三个开关 / CAN 卡片 /
R79 条）、设置页全部功能行、LAB 研究与诊断面板、设备页、无线设置、危险操作确认弹窗、各字段说明长句。

**仍然保持英文**（有意为之，不是漏翻）：

| 内容 | 原因 |
|---|---|
| `RUNNING` / `STOPPED` 徽标 | 只有 7px 高、十几个像素宽，中文必溢出卡片；同一行第三句已用中文说明状态 |
| `BODY` / `CHASSIS` / `PARTY` 总线名 | 紧随 `CAN 1/2/3`，加中文会把右侧徽标挤出卡片；第三行已有「车身 / 底盘 / 派对」 |
| `0x3F8`、`0x399`、bit47 这类寄存器名 | 与上游讨论、抓包工具对照时需要原样 |
| 数值：`+132.45`、`183`、`38 ms`、`-52 dBm` | 数字，无需翻译 |
| `P4-CAN`、`S3XY`、`YL` / `YJ` / `3H` | 品牌与型号代号 |

## 体积影响

| | html | gzip（编进固件的就是这份） |
|---|---|---|
| 原始 | 363,346 | 82,091 |
| 汉化后 | 432,638 | 108,154 |

多 26 KB。分区 `app5M_fat24M_32MB`（4.8 MB APP）占用约 2.2%，软 AP 首屏多 0.1~0.2 秒，之后走浏览器缓存。

## 排版处理

几个必须知道的 CSS 决策，都是实际踩出来的：

- `.pageTitle` / `.mode` / `.h1` 强制 `display:block`，否则 `Settings设置` 会粘连、`Steering` 的中文跑到右下角
- `.badge` 与 `.homeBusMeta` 走"替换"而不是"追加"：前者空间不够，后者双语会把卡片撑到三行
- `.btn.primary` / `.setupPrimary` 里的中文改成 `rgba(255,255,255,.72)`，否则灰色中文在深色按钮上几乎看不见
- 首页三个速控卡片（Nag Killer / Auto Blinker / TLSSC）用 `SHORT` 短词表（`Nag Killer → 防脱手`），
  标题后的中文留 4px 间距并降到 72% 不透明度，副标题中文单独成行 —— 否则会出现 `TLSSC红绿灯` 粘连、
  以及「等待 NOA」被截成「等待 ...」并把开关挤出卡片
- 空状态徽标用 `BADGE` 两字表

## 想加词条

改 `zh-bilingual.js` 里的 `ZH` 表：键是页面上的英文原文（**必须一字不差，含标点与空格**），值是中文。
改完重跑 `apply_zh.py --build`。

运行时拼接的句子（含变量）加不进词典，要加到 `RULES` 里：

```js
[/^(\d+)\s*ms since frame$/, function (m) { return '距上帧 ' + m[1] + ' 毫秒'; }]
```

## 临时关掉

浏览器控制台：

```js
p4zh(false)   // 关，恢复纯英文
p4zh(true)    // 开
```

## 已知限制

- 中文是 `::after` 伪元素，**不能被选中复制，Ctrl+F 也搜不到中文**（只能搜英文）。这是不改动原 DOM 的代价。
- 依赖文本节点结构（元素内只能有一段文字，允许同级有 svg 图标）。若"某段文案没翻译"，先看它是不是被
  `children.length > 1` 的容器包着。
- 只验证过 Chrome / Safari 现代版本以及 iOS WKWebView；网页本来就只给手机浏览器用，兼容性不成问题。
