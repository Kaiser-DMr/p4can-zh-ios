# 设备不在时，怎么看"连上之后"的页面

用本机把固件里的真实仪表盘跑起来，再让预览窗口以"已连接"状态嵌进去。
没有任何硬件，看到的就是真机上同一份 HTML + 同一套原生外壳。

> 前置条件：本仓库不含上游固件，需要先把
> [P4can-universal-unlock](https://github.com/06066060606060/P4can-universal-unlock)
> clone 到本仓库旁边（或上一级），并跑过 `i18n/apply_zh.py` 注入中文。
> 服务会自动找 `P4-CAN-Universal*` / `P4can-universal-unlock*` 目录；
> 找不到就用环境变量指定：`P4CAN_FW=/path/to/firmware python3 mock_device.py 8899`。

```bash
cd ios/demo
bash demo.sh
```

- 预览窗口顶部三段：`探测中 / 未连接 / 已连接`，右侧太阳/月亮切深浅色。
- 想直接进设置页：`START_PAGE=settings bash demo.sh`（也可以 `lab` / `devices`）。
- 想直接停在页面某一处：加 `SCROLL_TO`，值是 CSS 选择器，`bottom` 表示滚到底：

  ```bash
  START_PAGE=settings SCROLL_TO='#p4canAppRow' bash demo.sh   # 停在 P4-CAN App 那一行
  SCROLL_TO=bottom bash demo.sh                               # 滚到页面最底
  ```

- 想看**原厂固件**下 App 的样子（纯英文、没有原生入口行）：`UNPATCHED=1 bash demo.sh`。
  服务会把汉化补丁那一整块从页面里去掉再发出去，体积正好回到 363,346 字节。
- 手机与这台 Mac 在同一 Wi-Fi 时，Safari 打开 `http://<Mac 的 IP>:8899` 能看到同一页面，
  适合在伸手真机上感受滚动与字号。
- 退出按 `Ctrl+C`，模拟服务会一起关掉。

## 里面是什么

| 文件 | 作用 |
| --- | --- |
| `mock_device.py` | 把 `dashboard_source.html` 起成 HTTP 服务，并按一份固定的"一车一板在跑"的遥测应答 `/api/*` |
| `demo.sh` | 起服务 + 编译/启动预览窗口，并把预览切到"已连接" |

模拟的是一台 **24 款 Model Y**：profile `Model Y Legacy`、`Body + Chassis + Party`、
`STALK · 0x249`、三路 CAN 全部 RUNNING，S3XY 两块按钮在线，NAG/自动变道相关遥测按
AP 激活状态给出。

> 只用于界面演示：`POST` 类接口一律返回成功但不改状态，不会真的发 CAN 帧。

## 和 App 里一致的两处细节

1. **没有原生浮动按钮**。设备网页自带一条悬浮底部导航和大量右侧开关，
   任何固定位置的玻璃按钮都会压住控件；原生设置改成网页"设置 → 系统"里的一行
   `P4-CAN App`，点击由 `p4canApp` 消息通道回调原生打开 App 设置。
   重新加载用下拉刷新（原生已挂 `UIRefreshControl`）。
2. **中英双语**由 `../../i18n/zh-bilingual.js` 注入，模拟服务直接读注入后的
   `dashboard_source.html`，所以看到的汉化与刷进板子的完全一致。

> 页面是编译进固件的（`dashboard_source.html` → `tools/build_dashboard.py` → `index_html.h`），
> 改了汉化或样式之后要重新生成这个头文件再编译烧录，真机才会变。

## 成品截图

`../演示截图/` 下是"已连接"状态的五张手机屏截图（已去掉预览窗口的切换条）：
首页深色 / 首页浅色 / 设置页深色 / 设置页浅色 / LAB 深色。
