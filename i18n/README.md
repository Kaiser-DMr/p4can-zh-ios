# 中文补丁

给 [P4can-universal-unlock](https://github.com/06066060606060/P4can-universal-unlock) 的仪表盘加中文：
**加载后把页面上的英文换成中文，一行命令就能还原**。英文仍是默认，补丁不启动时页面一个字都不变。

上游页面没有任何中文，`dashboard_source.html` 里的文案是硬编码的（约 880 条静态文案 + 若干运行时拼接句），
也没有 i18n 层，所以中文只能靠这份补丁注入。

## 文件

| 文件 | 作用 |
|---|---|
| `zh-bilingual.js` | 补丁本体：`ZH` 词典（853 条）+ `RULES` 正则规则 + 文本替换引擎（WeakMap 记原文，可还原） |
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

没有改任何逻辑，只换文字：

- 遍历文本节点，把空白归一后**与词典整段精确比对**；命中就改写 `node.nodeValue`。
  原文存进 WeakMap，所以既能 `p4zh(false)` 逐字还原，也不会把页面自己刷新的数值当成原文。
- 夹在句子中间的一小段（例如 `Last TX` + `<span>96 毫秒</span>` + `ago`），只有在它本身正好是
  一条完整词条时才替换 —— 避免把 "Turn signal Off" 翻成半中半英。
- `placeholder` / `title` / `aria-label` 同样处理。
- 中文与左右邻居都是汉字时自动收掉空格，否则会渲染成 "96 毫秒 前"。
- 不拦截 `fetch` / `XHR`、不覆写原型、不碰 `localStorage`、不改任何事件处理；`<script>`、`<style>`、
  输入框都明确跳过。重渲染后靠 `MutationObserver` 补扫：字符变化当场处理（不排队，否则英文会先画出来闪一下），
  整段重渲染走 180ms 防抖。跑在手机上，不占板子 CPU。

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

v2 是伪元素追加，为了让"多出来的一行中文"不挤坏卡片，堆了一整套 CSS。v3 改成替换之后那些全部删掉了，
现在只注入一条规则：

```css
[data-zh]{letter-spacing:0!important}
```

仪表盘给大写英文压了字距，汉字会被拉开（"转 向 灯"），这条把它抹平。除此之外**不加任何布局样式** ——
页面上只有一份文字，不存在"多一行撑破卡片"的问题。

还留着的两个微调：

- 首页三个速控卡（Nag Killer / Auto Blinker / TLSSC）用 `SHORT` 短词表（`Nag Killer → 防脱手`），
  因为那三块只有约 100pt 宽
- 徽标只收 `BADGE` 里的两字短词（`RUNNING → 运行`），长的宁可不翻，避免撑破 7px 高的胶囊

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

- 依赖文本节点结构：整段文字在一个节点里才走精确匹配；被 `<b>`、`<br>` 切碎的长句只能翻其中的完整片段，
  所以偶尔会看到"最后发送 96 毫秒前"这种中英混排的残句。
- 页面若在翻译后重新写入英文（轮询刷新），会在同一帧内再翻回来，肉眼看不到中间态。
- 只验证过 Chrome / Safari 现代版本以及 iOS WKWebView；网页本来就只给手机浏览器用，兼容性不成问题。
