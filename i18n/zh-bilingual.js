/* P4-CAN 中英双语补丁 v2 · 850 条
 * 注入位置：dashboard_source.html 的 </body> 之前，然后 build_dashboard.py 重生成 index_html.h。
 * v2 变更：不再依赖 class 白名单，改为遍历所有文本节点 + 词典精确匹配，
 *          因此新加的界面元素只要文案在词典里就会自动有中文。
 * 英文原文保持不变，中文用 CSS ::after 追加；<option> 例外，直接改文本。
 * 控制台执行 p4zh(false) 可即时切回纯英文。
 * v2.1：加单例守卫——同一个页面只启动一次。固件已内置本补丁时，
 *       iOS App 侧注入的同一份脚本会直接退出，避免两套 MutationObserver 互相打架。
 */
(function () {
  // 已经启动过（固件内置的那份先跑了）或样式已存在，就不再重复启动。
  if (window.__p4zhBooted || document.getElementById('p4zh-style')) {
    window.__p4zhOwner = window.__p4zhOwner || 'firmware';
    return;
  }
  window.__p4zhBooted = true;
  window.__p4zhOwner = 'self';

  var ZH = {
    "AP": "AP",
    "EU": "欧版",
    "ON": "开",
    "On": "开",
    "US": "美国",
    "2 s": "2 秒",
    "5 s": "5 秒",
    "EXP": "实验",
    "LAB": "实验室",
    "NAG": "防脱手",
    "OFF": "关",
    "Off": "关",
    "ago": "前",
    "10 s": "10 秒",
    "15 s": "15 秒",
    "BODY": "车身",
    "BOTH": "两路",
    "Back": "返回",
    "Body": "车身",
    "DARK": "深色",
    "Fail": "失败",
    "GATE": "闸门",
    "Gate": "闸门",
    "Gear": "挡位",
    "Home": "首页",
    "IDLE": "空闲",
    "LEFT": "左",
    "LIVE": "实时",
    "LONG": "长按",
    "Lane": "车道",
    "Long": "长按",
    "Mode": "模式",
    "NONE": "无",
    "None": "未设置",
    "RSSI": "信号强度",
    "Rear": "后",
    "Save": "保存",
    "Show": "显示",
    "TEST": "测试",
    "Apply": "应用",
    "Brake": "刹车",
    "CHILL": "轻松",
    "Error": "错误",
    "Front": "前",
    "INPUT": "输入",
    "KOREA": "韩国",
    "LIGHT": "浅色",
    "PARTY": "派对",
    "READY": "就绪",
    "RIGHT": "右",
    "Retry": "重试",
    "SPORT": "运动",
    "STATE": "状态",
    "STOCK": "原厂",
    "Saved": "已保存",
    "TLSSC": "红绿灯",
    "TLSSc": "红绿灯",
    "TX OK": "发送成功",
    "Wi-Fi": "Wi-Fi",
    "250 ms": "250 毫秒",
    "500 ms": "500 毫秒",
    "ACTIVE": "生效中",
    "B6 ACK": "B6 应答",
    "Cancel": "取消",
    "Change": "更改",
    "DANGER": "危险",
    "DEVICE": "设备",
    "DOUBLE": "双击",
    "Device": "设备",
    "Double": "双击",
    "MODE —": "模式 —",
    "Memory": "内存",
    "Mode 1": "模式 1",
    "Mode 2": "模式 2",
    "Mode A": "模式 A",
    "Mode B": "模式 B",
    "Mode C": "模式 C",
    "Mode H": "模式 H",
    "Mode —": "模式 —",
    "NORMAL": "正常",
    "Remove": "移除",
    "Rename": "重命名",
    "SINGLE": "单击",
    "SYSTEM": "系统",
    "Secure": "加密",
    "Single": "单击",
    "Status": "状态",
    "System": "系统",
    "US · 0": "美国 · 0",
    "Uptime": "运行时间",
    "WARMUP": "预热",
    "button": "按钮",
    "events": "个事件",
    "1000 ms": "1000 毫秒",
    "ADV EAP": "高级 EAP",
    "AP GATE": "AP 闸门",
    "AP only": "仅 AP",
    "BLE CSV": "蓝牙数据 CSV",
    "Blinker": "转向灯",
    "CHASSIS": "底盘",
    "Capture": "抓包",
    "Chassis": "底盘",
    "Connect": "连接",
    "Devices": "设备",
    "Enabled": "已启用",
    "FORCE 0": "强制 0",
    "LABEL A": "标签 A",
    "LABEL B": "标签 B",
    "LABEL C": "标签 C",
    "LABEL D": "标签 D",
    "Last TX": "最后发送",
    "MAD MAX": "极限",
    "MINIMAL": "最小",
    "NO DATA": "无数据",
    "OFF · 0": "关 · 0",
    "OFF · —": "关 · —",
    "Offline": "离线",
    "REDUCED": "减弱",
    "RUNNING": "运行中",
    "Reduced": "减弱",
    "Saving…": "保存中…",
    "Session": "会话",
    "Standby": "待机",
    "Storage": "存储",
    "WAITING": "等待",
    "Waiting": "等待中",
    "0x24A RX": "0x24A 接收",
    "Attempts": "尝试次数",
    "BEHAVIOR": "行为",
    "BURST MS": "脉冲时长（毫秒）",
    "Behavior": "行为",
    "Continue": "继续",
    "Discover": "搜索",
    "Failures": "失败次数",
    "Features": "功能",
    "Firmware": "固件",
    "LAB Menu": "LAB 菜单",
    "Loading…": "加载中…",
    "NAG MODE": "防脱手模式",
    "NOA only": "仅 NOA",
    "PAUSE MS": "间歇时长（毫秒）",
    "PROTOCOL": "协议",
    "Periodic": "周期发送",
    "R79 GATE": "R79 闸门",
    "R79 Mode": "R79 模式",
    "SETTINGS": "设置",
    "SNAPSHOT": "快照",
    "STANDARD": "标准",
    "Settings": "设置",
    "Signal —": "信号 —",
    "Snapshot": "快照",
    "Steering": "自动转向",
    "Waveform": "波形",
    "Wireless": "无线",
    "0x247 raw": "0x247 原始值",
    "0x249 raw": "0x249 原始值",
    "0x370 raw": "0x370 原始值",
    "0x389 raw": "0x389 原始值",
    "0x399 raw": "0x399 原始值",
    "0x5D9 raw": "0x5D9 原始值",
    "2 ms WAIT": "2 毫秒等待",
    "ALC STATE": "变道状态",
    "ALC state": "变道状态",
    "AP Policy": "AP 策略",
    "Applying…": "应用中…",
    "BLE stack": "蓝牙协议栈",
    "Connected": "已连接",
    "Countdown": "倒计时",
    "EU UNLOCK": "欧版解锁",
    "KOREA · 7": "韩国 · 7",
    "LOOK DOWN": "低头",
    "Last path": "最后路径",
    "Last skip": "最近跳过",
    "Model Y L": "长轴版",
    "R79 bit18": "R79 bit18",
    "RECONNECT": "重连",
    "Raw Value": "原始值",
    "Raw state": "原始状态",
    "Remaining": "剩余",
    "SEND ONCE": "只发一次",
    "SIDE LOOK": "看侧面",
    "Stock raw": "原厂原始值",
    "TARGET ID": "目标 ID",
    "TEC / REC": "TEC / REC 错误计数",
    "Transport": "传输",
    "/ 3 paired": "/ 3 只已配对",
    "AGGRESSIVE": "激进",
    "AP Unknown": "AP 状态未知",
    "Add Button": "+ 添加按钮",
    "Add Torque": "附加扭矩",
    "Appearance": "外观",
    "Auto armed": "自动就绪",
    "Banned Car": "被封禁车辆",
    "Body 0x39B": "车身 0x39B",
    "CONNECTION": "连接",
    "Connection": "连接",
    "FIRST BOOT": "首次开机",
    "Gate state": "闸门状态",
    "Long press": "长按",
    "Map region": "地图区域",
    "NAG KILLER": "防脱手",
    "NAG Method": "防脱手方式",
    "Nag Killer": "防脱手提醒 NAG",
    "Navigating": "领航中",
    "PRE BUFFER": "前置缓冲",
    "PRE WINDOW": "前置窗口",
    "Party + VH": "派对 + VH",
    "R79 Status": "R79 状态",
    "Rebooting…": "重启中…",
    "Reconnects": "重连次数",
    "Road Class": "道路等级",
    "S3XY / BLE": "S3XY / 蓝牙",
    "Save Delay": "保存延迟",
    "Stalk Down": "拨杆下压两次",
    "Turn stalk": "转向拨杆",
    "0x239 age —": "0x239 时效 —",
    "ALWAYS HO=1": "始终 HO=1",
    "AP STATE ID": "AP 状态 ID",
    "Active turn": "当前转向",
    "BLE connect": "蓝牙连接",
    "Connecting…": "连接中…",
    "Default OFF": "默认关闭",
    "Diagnostics": "诊断",
    "LAST RESULT": "最近结果",
    "LIVE ENGINE": "实时引擎",
    "Lane Change": "变道",
    "Last TX raw": "最后发送原始值",
    "Last notify": "最后通知",
    "Left Volume": "左侧音量",
    "MINIMAL · 1": "最小 · 1",
    "NEW ZEALAND": "新西兰",
    "OFF · STOCK": "关 · 原厂",
    "PERFORMANCE": "性能",
    "POST WINDOW": "后置窗口",
    "R79 TX · OK": "R79 发送 · 正常",
    "RECOMMENDED": "推荐",
    "Reset Stats": "重置统计",
    "Right Speed": "右侧车速",
    "S3XY Button": "S3XY 按钮",
    "STEERING ID": "转向 ID",
    "STOCK 0x334": "原厂 0x334",
    "STOCK A / B": "原厂 A / B",
    "STOCK BIT19": "原厂 BIT19",
    "STOCK BIT47": "原厂 BIT47",
    "Save Labels": "保存标签",
    "Turn signal": "转向灯",
    "+ Add Button": "+ 添加按钮",
    "0x3F8 RX age": "0x3F8 接收时效",
    "350 ms BURST": "350 毫秒脉冲",
    "ACTION STATE": "动作状态",
    "AP DELAY (S)": "AP 延时（秒）",
    "AP ownership": "AP 占用状态",
    "AVAILABILITY": "可用性",
    "Apply Timing": "应用时序",
    "Auto Blinker": "自动打灯",
    "Auto Connect": "自动连接",
    "CAN 1 · BODY": "CAN 1 · 车身",
    "CAPTURE MODE": "抓包模式",
    "Cancel pause": "取消暂停",
    "Double press": "双击",
    "FOLLOW PHONE": "跟随手机",
    "Gate-blocked": "闸门阻断次数",
    "INTERVAL (S)": "间隔（秒）",
    "Live monitor": "实时监视",
    "Mode H event": "模式 H 事件",
    "OBSERVED IDs": "已观察 ID",
    "REDUCED · 10": "减弱 · 10",
    "Reset Mode A": "重置模式 A",
    "Retry Status": "重试状态",
    "S3XY Buttons": "S3XY 按钮组",
    "Scroll Click": "滚轮单击",
    "Single press": "单击",
    "TESLA UNLOCK": "特斯拉解锁",
    "TX OK / FAIL": "发送成功 / 失败",
    "WAIT MAX (s)": "等待上限（秒）",
    "WAIT MIN (s)": "等待下限（秒）",
    "ACTIVE SOURCE": "当前来源",
    "Autopilot off": "Autopilot 未开启",
    "Bit 18 policy": "Bit 18 策略",
    "CAN 3 · PARTY": "CAN 3 · 派对",
    "CAPTURE STATE": "抓包状态",
    "Captured data": "已抓数据",
    "Chassis 0x399": "底盘 0x399",
    "Choose Action": "选择动作",
    "Clear BLE Log": "清空 BLE 日志",
    "Continuous AP": "AP 连续接管",
    "Country / Map": "国家 / 地图",
    "Default STOCK": "默认原厂",
    "ENGINE OUTPUT": "引擎输出",
    "ERASE ALL NVS": "清空全部 NVS",
    "Erase All NVS": "清空全部 NVS",
    "Factory Reset": "恢复出厂设置",
    "Forget Device": "忽略设备",
    "Injection Bus": "注入总线",
    "Last TX block": "最近发送阻断",
    "Mode H Tuning": "模式 H 调参",
    "Mode H output": "模式 H 输出",
    "Network state": "网络状态",
    "No frames yet": "尚未收到帧",
    "PHASE / EVENT": "阶段 / 事件",
    "Profile route": "车型路由",
    "Queue RX / TX": "接收 / 发送队列",
    "RUNTIME STATE": "运行状态",
    "Reboot P4-CAN": "重启 P4-CAN",
    "Reconnecting…": "重连中…",
    "Request state": "请求状态",
    "S3XY Button L": "S3XY 按钮 L",
    "S3XY Button R": "S3XY 按钮 R",
    "SCREEN GLANCE": "瞥屏幕",
    "STALK · 0x249": "有拨杆 · 0x249",
    "STANDARD · 20": "标准 · 20",
    "STOCK / STOCK": "原厂 / 原厂",
    "STOCK CARRIER": "原厂载波",
    "Saved 3D49 ID": "已存 3D49 ID",
    "Select a mode": "选择一个模式",
    "Session TX OK": "本会话发送成功",
    "Snapshot plan": "快照计划",
    "Stop Behavior": "停车行为",
    "Summon Status": "召唤状态",
    "TLSSC Restore": "红绿灯恢复",
    "TSL9 Sequence": "TSL9 序列",
    "V12 / V13 HW3": "V12 / V13 HW3",
    "0x249 checksum": "0x249 校验和",
    "AP active only": "仅 AP 激活时",
    "Active · Ready": "生效 · 就绪",
    "BLUETOOTH DATA": "蓝牙数据",
    "BUS OFF events": "总线关闭次数",
    "BUTTON ACTIONS": "按键动作",
    "CURRENT / LAST": "当前 / 上次",
    "Choose Setting": "选择设置",
    "Confirmed gear": "已确认挡位",
    "Country preset": "国家预设",
    "Delay after AP": "AP 后延时",
    "Drive Response": "行驶响应",
    "FRONT · NORMAL": "正视 · 正常",
    "GPS Road Match": "GPS 道路匹配",
    "HANDSON RATE %": "手握注入占比 %",
    "Hands-On state": "握持状态值",
    "INJECTION GATE": "注入闸门",
    "Initialization": "初始化",
    "Last forced TX": "最后强制发送",
    "Mode 1 MUX1 TX": "模式 1 MUX1 发送",
    "Model 3 Legacy": "Model 3 老款",
    "Model Y Legacy": "Model Y 老款",
    "Off Ramp L / R": "出口匝道 左 / 右",
    "Paired Buttons": "已配对按钮",
    "Pedal Response": "油门响应",
    "Priority state": "优先级状态",
    "R79 AP Control": "R79 AP 控制",
    "RAW TRANSITION": "原始跳变",
    "REMAINING POST": "剩余后置窗口",
    "Research Tools": "研究工具",
    "Reset Settings": "重置设置",
    "SEGMENTS / MAX": "分段数 / 上限",
    "SESSION ORIGIN": "会话初始值",
    "SESSION TARGET": "会话目标值",
    "Selected input": "所选输入",
    "Selected regen": "所选回收强度",
    "Settings ready": "设置就绪",
    "THRESHOLD HO=1": "阈值 HO=1",
    "ULC Blind Spot": "变道盲区策略",
    "Upload & Flash": "上传并烧录",
    "0x24A freshness": "0x24A 新鲜度",
    "0x293 TX Target": "0x293 发送目标",
    "Add S3XY Button": "添加 S3XY 按钮",
    "Attempt → READY": "尝试 → 就绪",
    "Autopilot · FSD": "Autopilot · 完全自动驾驶",
    "Block during AP": "AP 期间阻断",
    "CAN 2 · CHASSIS": "CAN 2 · 底盘",
    "COMPOSITOR GATE": "合成闸门",
    "Cancel Wait (s)": "取消等待（秒）",
    "Choose a method": "选择一种方式",
    "Firmware Update": "固件更新",
    "Hands-On Policy": "手握策略",
    "ISA Suppression": "ISA 提示音抑制",
    "Ignore AP State": "忽略 AP 状态",
    "Injection · R79": "R79 注入",
    "Last TX attempt": "最后发送尝试",
    "Last ULC result": "最近变道确认结果",
    "Last auto trace": "最近自动连接轨迹",
    "MUX2 DELAY (MS)": "MUX2 延时（毫秒）",
    "Model Y Juniper": "Model Y 焕新版",
    "Save Wait Times": "保存等待时间",
    "Steering torque": "转向扭矩",
    "Stock 0x3C2 age": "原厂 0x3C2 时效",
    "Stock raw / age": "原厂原始值 / 时效",
    "Stock torque Nm": "原车扭矩",
    "TIERED HO=1 / 2": "分级 HO=1 / 2",
    "ULC Off-Highway": "变道非高速标志",
    "Waiting for NOA": "等待 NOA",
    "0x239 View Range": "0x239 可视距离",
    "AP Accel / Regen": "AP 加速 / 动能回收",
    "BLE address type": "蓝牙地址类型",
    "BLE log capacity": "蓝牙日志容量",
    "Bluetooth Master": "蓝牙总开关",
    "Bluetooth is off": "蓝牙已关闭",
    "Boot Capture CSV": "启动抓包 CSV",
    "CARRIER MAX (Nm)": "载波上限（Nm）",
    "CARRIER MIN (Nm)": "载波下限（Nm）",
    "Choose .bin file": "选择 .bin 文件",
    "Confirm & Reboot": "确认并重启",
    "Connect manually": "手动连接",
    "FAST ECHO · 0 ms": "快速回显 · 0 毫秒",
    "Fixed R79 Policy": "固定 R79 策略",
    "Model 3 Highland": "Model 3 焕新版",
    "No file selected": "未选择文件",
    "OPPOSITE CARRIER": "反向载波",
    "R79 manual latch": "R79 人工锁存",
    "RESCUE DELAY (s)": "救援延时（秒）",
    "Re-engage Method": "接回方式",
    "Rebooting P4-CAN": "正在重启 P4-CAN",
    "SIGNAL DELAY (s)": "打灯延时（秒）",
    "Signal Send Mode": "打灯发送方式",
    "Signal readiness": "信号就绪情况",
    "3D49 NVS verified": "3D49 NVS 已校验",
    "Auto Speed Scroll": "自动滚动车速",
    "Block on Highways": "高速上阻断",
    "Bond repair armed": "配对修复已就绪",
    "Choose one method": "选择一种方式",
    "Controlled Access": "封闭道路",
    "Dashboard address": "仪表盘地址",
    "Entire AP session": "整个 AP 会话",
    "FRONT · NO TORQUE": "正视 · 无扭矩",
    "HARD PAUSE · 0-TX": "硬暂停 · 不发送",
    "Hard Reinitialize": "硬重初始化",
    "Highway confirmed": "已确认高速",
    "Human interaction": "人为干预",
    "Identity recovery": "身份恢复",
    "Last TX / max gap": "最后发送 / 最大间隔",
    "Last cancellation": "最近一次取消",
    "Legacy TSL9 Route": "老款 TSL9 路由",
    "Loading settings…": "载入设置…",
    "NOA stabilization": "NOA 稳定等待",
    "Notify / unparsed": "通知 / 未解析",
    "ON · Dashboard AP": "开 · 仪表盘热点",
    "PRE ready / slots": "前置就绪 / 槽位",
    "Preparing upload…": "准备上传…",
    "R79 Stock Monitor": "R79 原厂监视",
    "R79 TX · Reason —": "R79 发送 · 原因 —",
    "RX signal details": "接收信号详情",
    "S3XY Auto Connect": "S3XY 自动连接",
    "Send B6 Handshake": "发送 B6 握手",
    "System Stats JSON": "系统统计 JSON",
    "TSL9 Input Assist": "TSL9 输入辅助",
    "Torque · existing": "扭矩 · 现有",
    "Vehicle functions": "车辆功能",
    "WI-FI NAME (SSID)": "Wi-Fi 名称（SSID）",
    "Waiting / blocked": "等待 / 被阻断",
    "Wireless Settings": "无线设置",
    "0x238 status / age": "0x238 状态 / 时效",
    "0x3F8 TX OK / FAIL": "0x3F8 发送成功 / 失败",
    "ALC direction gate": "变道方向闸门",
    "Arduino-ESP32 core": "Arduino-ESP32 核心版本",
    "Auto link failures": "自动连接失败",
    "CAN mode / bitrate": "CAN 模式 / 波特率",
    "Clear TX OK / FAIL": "清除发送成功 / 失败",
    "DRIVER INTERACTION": "驾驶员交互",
    "Door Button Cancel": "车门按键取消",
    "Driver Window Test": "主驾车窗测试",
    "Gate-blocked A / B": "闸门阻断 A / B",
    "Largest heap block": "最大可用堆块",
    "NAG · ADV EAP · EU": "防脱手 · 高级 EAP · 欧版",
    "NOA Start Wait (s)": "NOA 启动等待（秒）",
    "PROFILE SETUP MODE": "车型配置模式",
    "Periodic OK / FAIL": "周期发送成功 / 失败",
    "REFRACTORY MAX (s)": "不应期上限（秒）",
    "REFRACTORY MIN (s)": "不应期下限（秒）",
    "Registered Buttons": "已注册按钮",
    "Requests / blocked": "请求 / 被阻断",
    "Restart controller": "重启控制器",
    "Runtime / template": "运行 / 模板",
    "SAMPLES / CAPACITY": "采样 / 容量",
    "TLSSC Highway Gate": "红绿灯高速闸门",
    "TORQUE + LOOK AWAY": "扭矩 + 分神",
    "TOTAL TX OK / FAIL": "累计发送成功 / 失败",
    "TX CAN B OK / FAIL": "CAN B 发送成功 / 失败",
    "TX queue now / max": "发送队列当前 / 上限",
    "Total TX OK / FAIL": "累计发送成功 / 失败",
    "WI-FI / ESP-HOSTED": "Wi-Fi / ESP-HOSTED",
    "WI-FI ACCESS POINT": "Wi-Fi 热点",
    "0x334 age / blocked": "0x334 时效 / 被阻断",
    "ACA / SPR freshness": "ACA / SPR 新鲜度",
    "ADVANCED PARAMETERS": "高级参数",
    "AP state / validity": "AP 状态 / 有效性",
    "Advanced Parameters": "高级参数",
    "Apply Mode H Tuning": "应用模式 H 参数",
    "Blocked mux0 frames": "被阻断的 mux0 帧",
    "Checking Bluetooth…": "检查蓝牙…",
    "Continuous Override": "持续覆盖",
    "Current application": "当前应用",
    "Global Auto Connect": "全局自动连接",
    "HO=1 THRESHOLD (Nm)": "HO=1 阈值（Nm）",
    "HO=2 THRESHOLD (Nm)": "HO=2 阈值（Nm）",
    "Highway transitions": "高速状态切换",
    "Notify subscription": "通知订阅",
    "Pause While Stopped": "停车时暂停",
    "R79 bit47 · RX → TX": "R79 bit47 · 收 → 发",
    "RX missed / overrun": "接收丢失 / 溢出",
    "STOCK / FORCED BIT1": "原厂 / 强制后 bit1",
    "Saved S3XY registry": "已存 S3XY 注册表",
    "Scroll Double Click": "滚轮双击",
    "Template / age / RX": "模板 / 时效 / 接收",
    "Wireless Settings ›": "无线设置 ›",
    "0x293 TX A OK / FAIL": "0x293 发送 A 成功 / 失败",
    "0x293 TX B OK / FAIL": "0x293 发送 B 成功 / 失败",
    "AUTO last transition": "自动最近跳变",
    "Apply Wi-Fi Settings": "应用 Wi-Fi 设置",
    "Boot bonds / current": "开机配对数 / 当前",
    "CAN Research Capture": "CAN 研究抓包",
    "Driving State · live": "行车状态 · 实时",
    "Inputs sent / failed": "已发输入 / 失败",
    "Last forced TX / age": "最后强制发送 / 时效",
    "Last recovery reason": "最近恢复原因",
    "No devices connected": "没有已连接设备",
    "POST-MUX2 DELAY (MS)": "MUX2 后延时（毫秒）",
    "Periodic Right Speed": "周期右滚车速",
    "Regenerative Braking": "动能回收制动",
    "Reset Bluetooth Data": "重置蓝牙数据",
    "Reset NVS · Keep BLE": "重置 NVS · 保留 BLE",
    "Road Context Monitor": "道路环境监视",
    "Select your vehicle.": "选择你的车型",
    "Send once after MUX2": "MUX2 之后发一次",
    "Stack / heap / flash": "栈 / 堆 / Flash",
    "Stock ULC Blind Spot": "原厂变道盲区值",
    "Summon load shedding": "召唤降载",
    "TX queued / rejected": "发送排队 / 被拒",
    "Vehicle speed / gate": "车速 / 闸门",
    "Visual Speed Control": "视觉限速控制",
    "WARNING — BANNED CAR": "警告 — 封禁车辆",
    "Waiting for CAN data": "等待 CAN 数据",
    "All devices connected": "全部设备已连接",
    "Autopilot · Autosteer": "Autopilot · 自动转向",
    "BLE stack initialized": "蓝牙协议栈已初始化",
    "CAN B · CHASSIS · raw": "CAN B · 底盘 · 原始值",
    "Cancel Profile Change": "取消更改车型",
    "Choose warning states": "选择警告状态",
    "Data Refresh Interval": "数据刷新间隔",
    "Download Research CSV": "下载抓包 CSV",
    "Follows phone setting": "跟随手机设置",
    "I Understand — Enable": "我已了解 — 开启",
    "MAJOR FIRMWARE UPDATE": "固件重大更新",
    "Mode H phase / motion": "模式 H 阶段 / 运动",
    "PERIODIC INTERVAL (S)": "周期间隔（秒）",
    "PRIMARY PEAK MAX (Nm)": "主峰值上限（Nm）",
    "PRIMARY PEAK MIN (Nm)": "主峰值下限（Nm）",
    "Reset Current Profile": "重置当前参数集",
    "S3XY ULC TX OK / FAIL": "S3XY 变道确认发送成功 / 失败",
    "Save Profile & Reboot": "保存配置并重启",
    "Secure · Auto connect": "安全 · 自动连接",
    "V8.2 Original · 4 → 1": "V8.2 原始 · 4 → 1",
    "View R79 send status.": "查看 R79 发送状态。",
    "Visual Warning Rescue": "视觉警告救援",
    "Apply Before AP Starts": "AP 启动前就应用",
    "BODY + CHASSIS + PARTY": "车身 + 底盘 + 派对",
    "CAN A stock / age / RX": "CAN A 原厂帧 / 时效 / 接收",
    "CAN B stock / age / RX": "CAN B 原厂帧 / 时效 / 接收",
    "DANGER — TLSSC RESTORE": "危险 — 红绿灯恢复",
    "Dashboard access point": "仪表盘热点",
    "Diagnostics / Recovery": "诊断 / 恢复",
    "Heap current / minimum": "堆内存 当前 / 最低",
    "Last segment snapshots": "末段快照",
    "Loading session state…": "正在载入会话状态…",
    "MUX1 RX / TX OK / FAIL": "MUX1 接收 / 发送成功 / 失败",
    "NAG Continuity Monitor": "防脱手连续性监视",
    "Pause TLSSC During NOA": "NOA 期间暂停红绿灯功能",
    "RAW PRE ring / archive": "原始前置环形缓冲 / 归档",
    "RX 0x238 / 0x7FF A / B": "接收 0x238 / 0x7FF A / B",
    "Reset Feature Settings": "重置功能设置",
    "Steering wheel buttons": "方向盘按键",
    "Three native CAN buses": "三路原生 CAN 总线",
    "WAITING FOR 0x3FD MUX1": "等待 0x3FD MUX1",
    "500 kbit/s on each bus.": "每路总线 500 kbit/s。",
    "Auto Lane Change Enable": "自动变道使能",
    "CONFIRM VEHICLE PROFILE": "确认车型配置",
    "Current Bluetooth state": "当前蓝牙状态",
    "Current profile runtime": "当前参数集运行态",
    "Driver Monitoring bit43": "驾驶员监控 bit43",
    "Loading saved settings…": "正在载入已保存设置…",
    "Mode 2 MUX2 reinjection": "模式 2 MUX2 补发",
    "No paired S3XY buttons.": "还没有已配对的 S3XY 按钮。",
    "RAW PRE actual coverage": "原始前置实际覆盖",
    "RESET FIRMWARE SETTINGS": "重置固件设置",
    "Remote startup evidence": "远程启动证据",
    "Reset Setup · Keep S3XY": "重置配置 · 保留 S3XY",
    "Security · Auto connect": "安全 · 自动连接",
    "Selected / last applied": "已选 / 最后应用",
    "Selected bus · RX / age": "所选总线 · 接收 / 时效",
    "Stock → requested bit49": "原厂 → 请求位 bit49",
    "TLSSC ownership / clear": "红绿灯占用 / 清除",
    "0x239 Virtual Lane Width": "0x239 虚拟车道宽度",
    "AUTO LEFT OPEN / BLOCKED": "自动左开 / 被阻断",
    "Auto exact hits / misses": "自动精确命中 / 未命中",
    "CAN 1 BODY · TX20 / RX21": "CAN 1 车身 · 发20 / 收21",
    "Confirm-Free Lane Change": "无需确认变道",
    "Extended · 2 / 3 / 4 → 1": "扩展 · 2 / 3 / 4 → 1",
    "Hosted host / C6 version": "Hosted 主机 / C6 版本",
    "Off-Highway TX OK / FAIL": "非高速发送成功 / 失败",
    "Quiet arm / fire / guard": "静默期 / 触发 / 保护",
    "VEHICLE FUNCTIONS PAUSED": "车辆功能已暂停",
    "0x247 · bus / age / count": "0x247 · 总线 / 时效 / 计数",
    "0x389 · bus / age / count": "0x389 · 总线 / 时效 / 计数",
    "0x3F8 gate-blocked frames": "0x3F8 被闸门阻断帧数",
    "0x5D9 · bus / age / count": "0x5D9 · 总线 / 时效 / 计数",
    "CAN 3 PARTY · TX26 / RX27": "CAN 3 派对 · 发26 / 收27",
    "Checking vehicle profile.": "正在检查车型配置。",
    "Choose injection behavior": "选择注入行为",
    "Disable Driver Monitoring": "关闭驾驶员监控",
    "Driver Monitoring Capture": "驾驶员监控抓包",
    "Fast attempts / OK / FAIL": "快速尝试 / 成功 / 失败",
    "Identity probes / matches": "身份探测 / 匹配",
    "Stock-follow TX OK / FAIL": "跟随原厂发送成功 / 失败",
    "Summon Heartbeat Override": "召唤心跳覆盖",
    "TWAI controller / TX / RX": "TWAI 控制器 / 发送 / 接收",
    "Bond persist still missing": "配对信息仍未持久化",
    "Gate-blocked target frames": "被闸门阻断的目标帧",
    "Match your vehicle setting": "与车辆设置保持一致",
    "RECOVERY · ALL THREE BUSES": "恢复 · 三路总线",
    "Recovery starts / failures": "恢复启动 / 失败",
    "Reset CAN Research Capture": "重置 CAN 抓包",
    "Skip stopped / speed stale": "跳过：停车 / 车速失效",
    "TX block TWAI / send error": "发送阻断：TWAI / 发送错误",
    "Applied / TX fail / blocked": "已应用 / 发送失败 / 被阻断",
    "Applies while R79 is active": "R79 激活期间生效",
    "Auto Blinker waits for NOA.": "打灯功能需 NOA 生效。",
    "CAN 2 CHASSIS · TX22 / RX23": "CAN 2 底盘 · 发22 / 收23",
    "Global Auto Connect is off.": "全局自动连接已关闭。",
    "Last interaction transition": "最近一次交互跳变",
    "Profile status unavailable.": "车型状态不可用。",
    "RESET NVS · KEEP S3XY & BLE": "重置 NVS · 保留 S3XY 与蓝牙",
    "Ready to add an S3XY Button": "可以添加 S3XY 按钮",
    "S3XY ULC accepted / blocked": "S3XY 变道确认 接受 / 阻断",
    "TORQUE TABLE · B2 / B3 / Nm": "扭矩表 · B2 / B3 / Nm",
    "Task stack HWM · RX workers": "任务栈峰值 · 接收任务",
    "Already-banned vehicles only": "仅限已被封禁的车辆",
    "Bond repair attempts / READY": "配对修复尝试 / 就绪",
    "Disable Visual Speed Control": "关闭视觉限速控制",
    "Flash successful · rebooting": "烧录成功 · 正在重启",
    "Home updates · default 0.5 s": "首页刷新 · 默认 0.5 秒",
    "Mode 1 Post-MUX2 reinjection": "模式 1 MUX2 后补发",
    "PRE 2 s · trigger · POST 5 s": "前 2 秒 · 触发 · 后 5 秒",
    "Received frames / last frame": "已收帧 / 最后一帧",
    "Requests / ignored / dropped": "请求 / 忽略 / 丢弃",
    "Test window opening in Park.": "在 P 挡测试开窗。",
    "Two-bit field · 0, 1, 2 or 3": "两比特字段 · 0、1、2、3",
    "Block or delay R79 during AP.": "AP 期间阻断或延后 R79。",
    "Controller state / status age": "控制器状态 / 状态时效",
    "I Understand — Enable Restore": "我已了解 — 开启恢复",
    "Identity rebinds / mismatches": "身份重绑 / 不匹配",
    "Loading vehicle capabilities…": "载入车型能力…",
    "Receive calls / latest result": "接收调用 / 最新结果",
    "Select an option to apply it.": "选择一个选项后应用。",
    "Apply Wi-Fi Settings · Unsaved": "应用 Wi-Fi 设置 · 未保存",
    "Download Driver Monitoring CSV": "下载驾驶员监控 CSV",
    "Keep Hands-On downgrade active": "保持手握降级生效",
    "OPEN DRIVER WINDOW · AUTO DOWN": "打开主驾车窗 · 自动下降",
    "Record driver-monitor signals.": "记录驾驶员监控信号。",
    "Requests / completed / blocked": "请求 / 完成 / 被阻断",
    "Separate setting · default OFF": "独立设置 · 默认关闭",
    "TX block fresh / epoch / mutex": "发送阻断：不新鲜 / 纪元变更 / 互斥锁",
    "Test Summon heartbeat signals.": "测试召唤心跳信号。",
    "Allow R79 During Manual Driving": "人工驾驶时也允许 R79",
    "BODY + CHASSIS + PARTY · 3 TWAI": "车身 + 底盘 + 派对 · 3 路原生 TWAI",
    "Change country and map signals.": "修改国家与地图信号。",
    "Immediate one-shot TX OK / FAIL": "即时单次发送成功 / 失败",
    "Reset Driver Monitoring Capture": "重置驾驶员监控抓包",
    "Settings unavailable · retrying": "设置不可用 · 重试中",
    "✓ NAG · ✓ ADV EAP · ✓ EU UNLOCK": "✓ 防脱手 · ✓ 高级 EAP · ✓ 欧版解锁",
    "Install an application .bin file": "安装应用 .bin 固件",
    "Instant on/off · pairings saved.": "即时开关，配对信息保留。",
    "Navigate on Autopilot is active.": "领航辅助已激活。",
    "No buttons are currently paired.": "当前没有已配对按钮。",
    "RX 0x118 / 0x186 / 0x399 / 0x3F8": "接收 0x118 / 0x186 / 0x399 / 0x3F8",
    "Record and download CAN signals.": "记录并下载 CAN 报文。",
    "Task stack HWM · Sup / Web / BLE": "任务栈峰值 · 监督 / Web / 蓝牙",
    "Test lane-change enable signals.": "测试变道使能信号。",
    "Vehicle profile · locked at boot": "车型配置 · 开机锁定",
    "Waiting for Autopilot to engage.": "等待 Autopilot 接合。",
    "Autopilot · Navigate on Autopilot": "Autopilot · 领航辅助",
    "Choose a firmware file to upload.": "选择要上传的固件文件。",
    "Emergency flush / retry OK / FAIL": "紧急冲刷 / 重试成功 / 失败",
    "Hard reinitializations / failures": "硬重初始化 / 失败",
    "OFF keeps the default AP behavior": "关闭则保持默认 AP 行为",
    "Record driver-monitoring signals.": "记录驾驶员监控信号。",
    "Request visual speed control off.": "请求关闭视觉限速控制。",
    "Skip AP invalid / inactive / HO>1": "跳过：AP 无效 / 未激活 / HO>1",
    "TSL9 RX / modified / TX OK / FAIL": "TSL9 接收 / 已改写 / 发送成功 / 失败",
    "Timing, CAN IDs and torque values": "时序、CAN ID 与扭矩参数",
    "Use the selected AP input method.": "使用所选的 AP 接回方式。",
    "AUTO qualified / segments / merged": "自动合格 / 分段 / 合并",
    "Autopilot · Autosteer (restricted)": "Autopilot · 自动转向（受限）",
    "BODY + CHASSIS + PARTY · VH = BODY": "车身 + 底盘 + 派对 · VH = 车身",
    "Shed total / PARK / READY / ACTIVE": "降载累计 / P挡 / 就绪 / 激活",
    "Bluetooth, S3XY reconnect and Wi-Fi": "蓝牙、S3XY 重连与 Wi-Fi",
    "Choose the CAN bus for this request": "选择本次请求使用的 CAN 总线",
    "One or more buttons need attention.": "有按钮需要处理。",
    "PRE 0 · trigger 0 rows · POST 0 / 4": "前置 0 · 触发 0 行 · 后置 0 / 4",
    "STALK · turn signal transport 0x249": "有拨杆 · 转向灯通道 0x249",
    "Also applies to S3XY blinker buttons": "同样作用于 S3XY 转向灯按钮",
    "Mode 1 / 2 · manual D/R suppression.": "模式 1 / 2 · 人工 D/R 挡抑制。",
    "Peak, wait, refractory and HO policy": "峰值、等待、不应期与握持策略",
    "Save failed · restored saved settings": "保存失败 · 已恢复原设置",
    "Always applies to S3XY blinker buttons": "始终作用于 S3XY 转向灯按钮",
    "Applies during Autopilot · default OFF": "Autopilot 期间生效 · 默认关闭",
    "Auto Lane Change Enable · EXPERIMENTAL": "自动变道使能 · 实验",
    "CAN B · CHASSIS · bit1 / Hz / age / RX": "CAN B · 底盘 · bit1 / 频率 / 时效 / 接收",
    "Counters, boot capture and system logs": "计数器、启动抓包与系统日志",
    "Mode H tuning and live engine monitor.": "模式 H 调节与实时引擎监视。",
    "Applies with the next vehicle CAN frame": "随下一帧车辆 CAN 生效",
    "Model 3 Highland · Turn Signal Controls": "Model 3 焕新版 · 转向灯控制",
    "Reconnects saved buttons automatically.": "自动重连已保存的按钮。",
    "S3XY Buttons paired directly to P4-CAN.": "S3XY 按钮直连 P4-CAN。",
    "STALKLESS · turn signal transport 0x3C2": "无拨杆 · 转向灯通道 0x3C2",
    "Torque mode · pause at confirmed 0 km/h": "扭矩模式 · 确认 0 km/h 时暂停",
    "0x399 · bus · DAS hands-on / age / count": "0x399 · 总线 · DAS 手握状态 / 时效 / 计数",
    "Choose the R79 override mode and timing.": "选择 R79 覆盖模式与时机。",
    "Bus errors / arbitration lost / TX failed": "总线错误 / 仲裁丢失 / 发送失败",
    "Choose the generated right-scroll sequence": "选择生成的右滚序列",
    "NEW PASSWORD · LEAVE BLANK TO KEEP CURRENT": "新密码 · 留空则保持当前密码",
    "Re-engage AP after a signaled lane change.": "打灯变道后自动重新接回 AP。",
    "Reset firmware settings to their defaults?": "要把固件设置恢复默认吗？",
    "Select what this button gesture should do.": "选择这个按键动作要做什么。",
    "Signal automatically for NOA lane changes.": "NOA 变道时自动打灯。",
    "BLE state, button input counters and errors": "蓝牙状态、按键计数与错误",
    "Optional one-shot · no retry or queue flush": "可选单次发送 · 不重试、不清队列",
    "Override the off-highway ULC flag during AP": "AP 期间覆盖非高速变道标志",
    "R79 retry scheduled / OK / FAIL / exhausted": "R79 重试 已排程 / 成功 / 失败 / 用尽",
    "Reduce ISA warning chimes during Autopilot.": "降低 AP 期间的车速提示音。",
    "Values are loaded from the selected preset.": "数值来自所选预设。",
    "View the current Summon session and status.": "查看当前召唤会话与状态。",
    "Change acceleration response for this drive.": "改变本次行车的加速响应。",
    "Erase all settings, Wi-Fi and paired buttons": "清空全部设置、Wi-Fi 与已配对按钮",
    "The selected mode behavior will appear here.": "所选模式的行为说明会显示在这里。",
    "Remove the saved registry entry and BLE bond.": "删除已保存的注册项与蓝牙配对信息。",
    "Reset features · keep vehicle and connections": "重置功能 · 保留车型与连接",
    "Show experimental controls and capture tools.": "显示实验性控制与抓包工具。",
    "Warning-only · random 2–3 s · +1 / 0 / −1 / 0": "仅警告时 · 随机 2–3 秒 · +1 / 0 / −1 / 0",
    "Choose the map region independently of country": "地图区域可独立于国家选择",
    "Connection settings are managed automatically.": "连接设置自动管理。",
    "Mode H profile tuning and live engine monitor.": "模式 H 参数调节与实时引擎监视。",
    "Reconnect this button after boot or link loss.": "开机或断链后自动重连这只按钮。",
    "Use S3XY buttons for assigned vehicle actions.": "用 S3XY 按钮执行指定车辆动作。",
    "Change your vehicle selection here when needed.": "需要时可在此更改车型选择。",
    "OFF · AP ACTIVE ONLY · current/default behavior": "关 · 仅 AP 激活时 · 当前默认行为",
    "Set the off-highway ALC flag while AP is active": "AP 激活时置非高速变道标志",
    "Pause TLSSC on confirmed controlled-access roads": "确认处于封闭高速路段时暂停红绿灯功能",
    "Reduce steering-wheel reminders during Autopilot.": "减少 AP 期间的握方向盘提醒。",
    "Select the ULC blind-spot configuration during AP": "选择 AP 期间的变道盲区策略",
    "0x370 · bus · EPAS hands-on / torque / age / count": "0x370 · 总线 · EPAS 手握 / 扭矩 / 时效 / 计数",
    "Reset vehicle, Wi-Fi and features · keep S3XY data": "重置车型、Wi-Fi 与功能 · 保留 S3XY 数据",
    "Show restore controls for already-banned vehicles.": "为已被封禁的车辆显示恢复选项。",
    "Use Chill acceleration and chosen regen during AP.": "AP 期间使用「轻松」加速与所选回收强度。",
    "Vehicle functions, wireless and device management.": "车辆功能、无线与设备管理。",
    "Applying vehicle profile before CAN initialization…": "正在应用车型配置，随后初始化 CAN…",
    "Keep TLSSC in Autosteer; release it when NOA starts": "Autosteer 时保留红绿灯功能，NOA 启动后释放",
    "Legacy Model 3 / Y · OFF: bit47 FORCE 1 · ON: STOCK": "老款 Model 3 / Y · 关：bit47 强制 1 · 开：原厂",
    "Try the TLSSC restore override on a banned vehicle.": "在被封禁车辆上尝试红绿灯恢复覆盖。",
    "Applies immediately · STOCK uses the vehicle setting": "立即生效 · 原厂沿用车辆设置",
    "DO NOT ENABLE unless this vehicle is already banned.": "除非本车已被封禁，否则不要开启。",
    "Torque mode · periodic during AP and on new warnings": "扭矩模式 · AP 期间周期发送，出现新警告时也发",
    "Use CHILL acceleration and selected regen during AP.": "AP 期间使用「轻松」加速与所选回收强度。",
    "Cancel a lane change with the front door-open button.": "用前门开门按键取消变道。",
    "Request cabin-camera monitoring off during Autopilot.": "请求在 AP 期间关闭车内摄像头监控。",
    "Research tools. Read-only unless marked experimental.": "研究工具。除标注实验性外均为只读。",
    "Request traffic-light and stop-sign control during AP.": "请求在 AP 期间启用红绿灯与停止标志控制。",
    "DAS visual warning starts a delayed direct PRIMARY peak": "DAS 视觉警告触发一次延时主峰值",
    "Keep warning assist · add a regular AP-active injection": "保留警告辅助，并追加 AP 期间的常规注入",
    "This returns P4-CAN to the first-boot vehicle selector.": "这会让 P4-CAN 回到首次开机的车型选择界面。",
    "View detected Summon activity, gear and source signals.": "查看检测到的召唤活动、挡位与来源信号。",
    "Please select the exact vehicle model before continuing.": "请选择准确车型后继续。",
    "Applies the selected raw value to every valid stock frame": "把所选原始值套用到每一帧有效原厂帧",
    "One route only · Chassis state observation remains active": "只能选一条路由 · 底盘状态观察仍启用",
    "Configure this button without exposing low-level BLE data.": "配置这只按钮，不暴露底层蓝牙数据。",
    "Global Auto Connect can be changed in Settings → Wireless.": "全局自动连接可在「设置 → 无线」中修改。",
    "Return to Profile Setup without pairing Sexy Buttons again?": "回到车型配置，且不用重新配对 S3XY 按钮？",
    "Verify the exact vehicle and CAN topology before rebooting.": "重启前请核对车型与 CAN 拓扑。",
    "full 2-bit HO overwrite · generated value is capped at HO=2": "完整两比特 HO 覆写 · 生成值上限为 HO=2",
    "Set R79 behavior during AP and manual driving independently.": "分别设置 AP 期间与人工驾驶时的 R79 行为。",
    "Enabling this option will result in the vehicle being banned.": "开启此选项会导致车辆被封禁。",
    "Read-only production status for the selected R79 transmitter.": "当前 R79 发送通道的只读运行状态。",
    "Read-only values from the latest real CAN B 0x3FD MUX1 frame.": "取自最新真实 CAN B 0x3FD MUX1 帧的只读数值。",
    "Auto Blinker is inactive while Confirm-Free Lane Change is on.": "开启免确认变道时，自动转向灯不生效。",
    "Choose steering-torque output or a TSL9 Hands-On signal override.": "选择输出转向扭矩，或改用 TSL9 手握信号覆盖。",
    "P4-CAN has been upgraded to the new Universal firmware architecture.": "P4-CAN 已升级到新的 Universal 固件架构。",
    "Re-engage AP after a signaled lane change when the vehicle is ready.": "打灯变道完成且车辆就绪后，自动重新接回 AP。",
    "Torque A/B/C/H only · default OFF · other safety gates remain active": "仅扭矩 A/B/C/H 适用 · 默认关闭 · 其他安全闸门仍然生效",
    "Enable only if this vehicle is already banned or restricted by Tesla.": "仅当本车已被特斯拉封禁或限制时才可开启。",
    "Tap a button to configure actions, connection behavior or diagnostics.": "点按按钮可配置动作、连接行为或诊断。",
    "Independent from Confirm-Free 0x3F8 target · same-bus stock template only": "与「无需确认」的 0x3F8 目标独立 · 只用同总线原厂帧作模板",
    "Vehicle functions start only after you save the setup and P4-CAN restarts.": "保存配置并重启 P4-CAN 后，车辆功能才会启动。",
    "0x238 UI_driverAssistMapData reference interpretation. Freshness limit 2 s.": "0x238 辅助驾驶地图数据的参考解读，新鲜度上限 2 秒。",
    "0x3F8 UI_driverAssistControl · UI_summonHeartbeat bits 2–3 · raw values 0–3.": "0x3F8 辅助驾驶控制 · 召唤心跳 bits 2–3 · 原始值 0–3。",
    "I confirm this vehicle is already banned and I understand the warning above.": "我确认本车已被封禁，并已了解上述警告。",
    "BODY + CHASSIS + PARTY research recorder with automatic multi-segment re-arm.": "车身 + 底盘 + 派对三路研究记录器，支持多段自动续录。",
    "Mode 1 / Mode 2 · bit19=0 · bit47 follows HW3 policy · manual D/R suppression": "模式 1 / 模式 2 · bit19=0 · bit47 按 HW3 策略 · 人工 D/R 抑制",
    "S3XY devices, BLE bonds and button mappings are preserved and are not erased.": "S3XY 设备、蓝牙配对与按键映射会保留，不会被清除。",
    "Transport and scheduler are fixed in v3.7. Bit 18 is configured from Settings.": "传输与调度在 v3.7 中已固定。Bit 18 在设置页配置。",
    "0x293 UI_chassisControl · UI_autoLaneChangeEnable bits 24–25 → raw 1 · AP active": "0x293 底盘控制 · 自动变道使能位 24–25 → 原始值 1 · 仅 AP 激活",
    "Saved Body is unavailable for this topology. Select Chassis to use this request.": "当前拓扑下保存的「车身」不可用，请选「底盘」以使用此请求。",
    "Manage Bluetooth, automatic S3XY reconnection and the dashboard Wi-Fi connection.": "管理蓝牙、S3XY 自动重连与仪表盘 Wi-Fi。",
    "Low-level BLE and input diagnostics. These values are not required for normal use.": "底层蓝牙与按键诊断。正常使用不需要看这些数值。",
    "Vehicle profile, Wi-Fi, NAG/features, LAB, diagnostics and schema markers are cleared.": "车型、Wi-Fi、防脱手与功能设置、LAB、诊断与版本标记都会被清除。",
    "After reboot, reconnect to the default P4-CAN Wi-Fi and select the vehicle profile again.": "重启后请重新连接默认的 P4-CAN Wi-Fi，并重新选择车型。",
    "Upload an Arduino application .bin. P4-CAN reboots automatically after a successful flash.": "上传 Arduino 应用 .bin，烧录成功后 P4-CAN 会自动重启。",
    "Check controller health, Bluetooth and CAN communication. Recovery actions are listed below.": "检查控制器、蓝牙与 CAN 通信，恢复操作见下方。",
    "Highland exists in both configurations. Select what is physically installed on this vehicle.": "Highland 有两种配置，请按车上实际安装的选择。",
    "Select the vehicle. All profiles use BODY, CHASSIS and PARTY on three native TWAI controllers.": "所有车型都使用 BODY、CHASSIS、PARTY 三路原生 TWAI 控制器。",
    "ON bypasses only manual D/R suppression. Existing AP policy and transport safety remain active.": "开启仅绕过人工 D/R 挡的抑制，AP 策略与传输安全仍然生效。",
    "Select the acceleration response for this drive. It clears in Park or after a controller restart.": "选择本次行车的加速响应。挂 P 挡或控制器重启后清除。",
    "Remove all S3XY devices, action mappings, BLE bonds and cached discovery data, then restart P4-CAN.": "删除全部 S3XY 设备、动作映射、蓝牙配对与缓存，然后重启 P4-CAN。",
    "Current AP-session TX continuity and skip/block reasons. AP state uses validity, not an age timeout.": "当前 AP 会话的发送连续性与跳过/阻断原因。AP 状态看的是有效性，不是超时。",
    "The selected vehicle profile, Wi-Fi access-point settings and stored BUS OFF evidence are preserved.": "所选车型、Wi-Fi 热点设置与已存的 BUS OFF 记录会保留。",
    "A/B test for stationary Hands-On warnings. Speed stale and move-confirming states remain hard-paused.": "针对静止时手握警告的 A/B 测试。车速失效与等待确认移动的状态仍然硬暂停。",
    "S3XY registry, button mappings, Bluetooth Master / Auto Connect settings and BLE bonds are preserved.": "S3XY 注册表、按键映射、蓝牙总开关 / 自动连接设置与配对信息会保留。",
    "CAN transmission and injection remain disabled until a vehicle profile is selected and P4-CAN reboots.": "在选择车型并重启 P4-CAN 之前，CAN 发送与注入保持关闭。",
    "Configure confirmation, off-highway flags and the blind-spot setting. Controls share one CAN B output.": "配置变道确认、非高速标志与盲区策略。这三项共用一个 CAN B 输出。",
    "Monitoring only. Values are sampled before the R79 overlay applies bit19=0 and the selected bit47 policy.": "仅监视。数值在 R79 覆写（bit19=0 与所选 bit47 策略）之前采样。",
    "SNAPSHOT: latest state sets · RAW: actual BODY + CHASSIS + PARTY RX frames. Recorder never transmits CAN.": "快照：最新状态集；原始：车身 + 底盘 + 派对的实际接收帧。记录器从不发送 CAN。",
    "Experimental 0x293 UI_autoLaneChangeEnable injection. Independent from the production CAN B 0x3F8 compositor.": "实验性的 0x293 自动变道使能注入，与正式的 CAN B 0x3F8 合成器互不影响。",
    "Model YL only · PARK required · clones fresh CAN B 0x3C2 MUX0 and sets byte 6 bits [3:2] to Auto Down value 2.": "仅 Model YL · 需挂 P 挡 · 克隆 CAN B 上新鲜的 0x3C2 MUX0，把 byte6 的 bits[3:2] 设为「自动下降」值 2。",
    "A vehicle profile is required before P4-CAN can initialize CAN functions. Choose the exact vehicle family below.": "P4-CAN 初始化 CAN 前必须先选车型，请从下方选择准确的车型系列。",
    "Production feature. A manual LAB PedalMap target remains RAM-only and resumes after AP Accel / Regen releases 0x334.": "正式功能。LAB 里手动设置的油门映射只存在内存中，AP 加速/回收释放 0x334 后会恢复。",
    "Trigger a turn signal for a detected NOA lane change after the selected delay. Startup and cancel waits are separate.": "检测到 NOA 变道后，延时自动打转向灯。启动等待与取消等待分别设置。",
    "Set the traffic-light and stop-sign control flag during AP. Highway and NOA options release the override when blocked.": "AP 期间设置红绿灯与停止标志控制位。高速与 NOA 选项在被阻断时释放覆盖。",
    "Model YL defaults to Single TX; other supported Model 3/Y profiles default to 350ms Burst until a saved selection exists.": "Model YL 默认只发一次；其他受支持的 Model 3/Y 在有保存选择之前默认 350 毫秒脉冲。",
    "ALL VEHICLES · READ ONLY · watches 0x389 / 0x5D9 / 0x247 / 0x399 / 0x370 on both CAN A and CAN B · fixed PRE 2 s + POST 5 s.": "全部车型 · 只读 · 同时监视 CAN A 与 CAN B 上的 0x389 / 0x5D9 / 0x247 / 0x399 / 0x370 · 固定前置 2 秒 + 后置 5 秒。",
    "This setting exposes TLSSC Restore controls. Enabling Banned Car by itself does not activate TLSSC Restore CAN transmission.": "此设置只是开放红绿灯恢复功能。仅开启「封禁车辆」本身不会启动红绿灯恢复的 CAN 发送。",
    "Previous firmware settings and saved configuration have been erased to prevent incompatible settings from being carried over.": "旧固件设置与存档已清除，避免不兼容配置被沿用。",
    "STOPPED only · event engine stays paused. STOCK CARRIER preserves stock torque + stock HO and advances only counter/checksum.": "仅停车时 · 事件引擎保持暂停。「原厂载波」保留原厂扭矩与原厂 HO，只推进计数器与校验和。",
    "This control is intended only for vehicles that are already banned/restricted. It must not be enabled on a non-banned vehicle.": "此功能只针对已被封禁或限制的车辆，严禁在正常车辆上开启。",
    "Available means the required signals are fresh and valid. It does not mean AP is ready to engage or that an input was accepted.": "「可用」只表示所需信号新鲜有效，不代表 AP 已可接合，也不代表车辆接受了输入。",
    "Use CHILL acceleration and your selected regen setting during Autosteer or NOA. The manual drive response resumes after AP exits.": "Autosteer 或 NOA 期间使用「轻松」加速与所选回收强度。AP 退出后恢复人工驾驶的响应设置。",
    "Changing the vehicle profile is applied only at the next boot. CAN TX is blocked before the new profile is committed and P4-CAN reboots.": "更改车型只在下次开机生效；新配置提交并重启前，CAN 发送保持阻断。",
    "Stalk Down pulls the stalk down twice. Choose the click or double click method that matches your vehicle's Autopilot activation setting.": "「拨杆下压」会连拉两次拨杆。请选择与你车机 Autopilot 激活设置一致的单击或双击方式。",
    "Bluetooth Master and Global Auto Connect settings are preserved. Bluetooth must be ON to fully remove the controller's BLE bond database.": "蓝牙总开关与全局自动连接设置会保留。要彻底清除控制器的蓝牙配对库，蓝牙必须处于开启状态。",
    "Requests 0x3FD MUX1 bit49=0 while fresh AP state is active. OFF preserves stock. Vehicle acceptance and sign-related slowing effects are unverified.": "AP 状态新鲜有效时，向 0x3FD MUX1 的 bit49 写 0。关闭则保持原厂值。车辆是否接受、以及与标志牌识别减速的相互影响尚未验证。",
    "Experimental actuator test · 0x3C2 MUX0 · byte 6 bits [3:2] · two stock-synchronized press frames. Keep the driver window path clear. No setting is saved.": "实验性执行器测试 · 0x3C2 MUX0 · byte6 bits[3:2] · 两帧与原厂同步的按下帧。请确保主驾车窗行程内无遮挡。不保存任何设置。",
    "The vehicle profile, firmware settings, stored BUS OFF evidence, S3XY registry and BLE bonds are erased. After reboot, P4-CAN returns to Profile Setup Mode.": "车型、固件设置、已存 BUS OFF 记录、S3XY 注册表与蓝牙配对都会被清除。重启后 P4-CAN 回到车型配置模式。",
    "All vehicle profiles with a valid CAN topology. Overrides follow fresh stock frames on the same bus while R79 is ACTIVE. Vehicle behavior remains unverified.": "所有拓扑有效的车型均可用。R79 处于 ACTIVE 时，覆盖跟随同总线的新鲜原厂帧。车辆实际行为尚未验证。",
    "HO=3 is never generated. In THRESHOLD HO=1 mode, HO=2 threshold is stored but not used. In TIERED mode, torque below the HO=1 threshold keeps the accepted stock HO field.": "永不生成 HO=3。阈值 HO=1 模式下 HO=2 阈值会被保存但不生效。分级模式下，低于 HO=1 阈值的扭矩沿用已接受的原厂 HO 值。",
    "Session-only experimental override. It is OFF after every reboot and CAN full-recovery. Other 0x3F8 fields are preserved and existing transport safety checks remain active.": "仅本次会话生效的实验覆盖。每次重启与 CAN 完全恢复后都会关闭。其他 0x3F8 字段保留，原有传输安全检查仍然生效。",
    "Feature settings are reset, LAB Menu returns to OFF, and Banned Car / TLSSC Restore return to OFF. BUS OFF evidence is deleted only by Reset Stats. This action cannot be undone.": "功能设置会被重置，LAB 菜单回到关闭，「封禁车辆 / 红绿灯恢复」也回到关闭。BUS OFF 记录只有在「重置统计」时才会删除。此操作不可撤销。",
    "Confirm-Free clears 0x3F8 bit 1. ULC Off-Highway controls bit 15, ULC Blind Spot controls bits 52–53, and Off-Highway ALC controls bit 56. One CAN B compositor applies the selected fields to each fresh stock frame.": "「无需确认」清除 0x3F8 的 bit1；「变道非高速标志」控制 bit15；「变道盲区策略」控制 bit52–53；「非高速变道」控制 bit56。同一个 CAN B 合成器把所选字段套用到每一帧新鲜原厂帧。",
    "0x238 route: Model YL · CAN B VH; standard Body + Chassis · CAN A Body and CAN B Chassis; standard Party + Chassis · CAN B Chassis. 0x7FF follows actual RX on CAN A or B. No frame is created for a missing stock source.": "0x238 路由：Model YL 走 CAN B 的 VH；标准「车身 + 底盘」走 CAN A 车身与 CAN B 底盘；标准「派对 + 底盘」走 CAN B 底盘。0x7FF 跟随 CAN A 或 B 上实际收到的帧。原厂源帧缺失时不会凭空造帧。",
    "Receive calls show that the RX task is polling. ESP_ERR_TIMEOUT means no frame was available on that call; it is normal on an idle bus. RUNNING alone does not confirm reception. Counters above describe the current session.": "接收调用说明接收任务在轮询。ESP_ERR_TIMEOUT 表示这次调用没有取到帧，总线空闲时属正常。仅看 RUNNING 不能证明真的收到了帧。上面的计数器只反映本次上电会话。",
    "RX-only research recorder. SNAPSHOT stores periodic state sets; RAW TRANSITION stores actual CAN A and CAN B receive frames with a rolling PRE window. It never transmits CAN. Captured data clears after restart. Download it first.": "纯接收的研究记录器。快照保存周期性状态集；原始跳变保存 CAN A 与 CAN B 的实际接收帧并带滚动前置窗口。它从不发送 CAN。抓到的数据在重启后清空，请先下载。",
    "Wi-Fi settings are saved in NVS and preserved by Reset Feature Settings. Applying a change restarts only the access point, not CAN, BLE or the MCU. Reconnect to the new Wi-Fi if iPhone Auto-Join is disabled; the dashboard will resume automatically.": "Wi-Fi 设置保存在 NVS 中，「重置功能设置」不会清除。应用更改只会重启热点，不会重启 CAN、蓝牙或主控。若 iPhone 关掉了自动加入，需要手动连新 Wi-Fi，之后仪表盘会自动恢复。",
    "WAIT + REFRACTORY · every eligible stock 0x370 RX draws a new carrier magnitude. Non-zero stock is mirrored to the opposite sign with |stock| + carrier. |stock| ≤ 0.05 Nm passes through unchanged. Primary events are 80% negative / 20% positive. Rescue cancels if the visual warning clears before its delay.": "等待 + 不应期 · 每一帧符合条件的 0x370 原厂接收都会重新抽取载波幅值。非零原厂扭矩按相反符号镜像，幅值为 |原厂| + 载波。|原厂| ≤ 0.05 Nm 时原样透传。主事件 80% 为负向、20% 为正向。若视觉警告在延时前消失，救援即取消。",
    "Country and map region can be selected independently. Country STOCK preserves the original values; US selects 840 / US, KOREA 410 / KR, and NEW ZEALAND 554 / NZ. Map STOCK preserves the original region; US selects 0 and KOREA 7. Country affects 0x238 and 0x7FF page 1; map region affects only 0x7FF page 3. Left/right-hand-drive and invalid or unknown stock values are preserved.": "国家与地图区域可独立选择。国家选原厂则保留原值；美国写 840 / US，韩国 410 / KR，新西兰 554 / NZ。地图选原厂则保留原区域；美国写 0，韩国写 7。国家影响 0x238 与 0x7FF 第 1 页；地图区域只影响 0x7FF 第 3 页。左右舵信息以及无效或未知的原厂值都会保留。",
    "Start each test condition immediately after pressing A–F. A = normal front view, B = short screen glance, C = sustained side look, D = look down, E = steering torque while looking away, F = front view with no intentional steering torque. All tracked IDs are observed on both physical CAN buses. Decoded interaction / hands-on / EPAS values are best-effort research fields; raw bytes plus the recorded CAN A/B and bus role are authoritative. This recorder is RX-only and never transmits CAN. Captured data clears after restart. Download it first.": "按下 A–F 后立刻开始对应动作。A = 正常正视前方，B = 短暂瞥一眼屏幕，C = 持续看侧面，D = 低头，E = 分神时施加转向扭矩，F = 正视且不刻意施加扭矩。所有被跟踪的 ID 都会在两路物理 CAN 上同时观察。解码出的交互 / 手握 / EPAS 数值只作研究参考，原始字节加上记录的 CAN A/B 与总线角色才是准的。本记录器只接收、从不发送 CAN。抓到的数据重启后清空，请先下载。",
    "Pedal Response sends one immediate best-effort 0x334 one-shot from the freshest stock template when the selector changes, then remains a volatile drive-session override using the normal stock-follow overlay. Selecting STOCK releases it immediately. CHILL, SPORT and PERFORMANCE remain armed for the current drive and are cleared by a positively observed Park gear or by P4-CAN reboot. CAN recovery does not write or restore a PedalMap value. AP Accel / Regen is now configured under Settings. When it is active it temporarily owns outgoing 0x334; the manual session target remains in RAM and resumes after AP exits.": "油门响应在选项变化时，会用最新的原厂模板立即发一帧尽力而为的 0x334，之后作为本次行车的临时覆盖跟随原厂帧。选「原厂」会立即释放。轻松 / 运动 / 性能 会保持到本次行车结束，被明确观察到的 P 挡或 P4-CAN 重启清除。CAN 恢复不会写入或还原油门映射值。AP 加速 / 回收 现在在设置里配置，激活时会临时占用 0x334，人工会话目标留在内存中，AP 退出后恢复。",
  };

  /* 首页三个方块太窄，用更短的词 */
  /* 徽标只有十几像素宽，用两字短词 */
  var BADGE = {
    "RUNNING": "运行",
    "STOPPED": "停止",
    "BUS OFF": "总线关",
    "RECOVERING": "恢复",
    "NO DATA": "无数据",
    "LIVE": "实时",
    "WAITING": "等待"
  };

  var SHORT = {
    "Nag Killer": "防脱手",
    "Auto Blinker": "打灯",
    "TLSSc": "红绿灯",
    "Off-Highway ALC": "非高速"
  };

  var ON = true;
  var STYLE_ID = 'p4zh-style';

  function injectStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var st = document.createElement('style');
    st.id = STYLE_ID;
    st.textContent =
      '[data-p4zh]::after{content:attr(data-p4zh);font-weight:500;letter-spacing:0;' +
      'text-transform:none;color:var(--muted,#8c8c88);opacity:.95}' +
      '[data-p4zh-v="l"]::after{display:block;font-size:11px;line-height:1.35;' +
      'margin-top:2px;white-space:normal}' +
      '[data-p4zh-v="s"]::after{display:inline;font-size:9px;line-height:1.2;' +
      'margin-left:3px;white-space:nowrap;opacity:.85}' +
      '.pageTitle[data-p4zh]::after,.pageSub[data-p4zh]::after{display:block;font-size:13px;' +
      'letter-spacing:.5px;opacity:1;margin-top:4px}' +
      '.paneltitle[data-p4zh]::after,.panelHero[data-p4zh]::after{display:block;font-size:12px;opacity:1}' +
      '.setupTitle[data-p4zh]::after{display:block;font-size:15px;opacity:1;margin-top:6px}' +
      'h1[data-p4zh]::after{display:block;font-size:14px;opacity:1}' +
      '.listdesc[data-p4zh]::after,.sectionnote[data-p4zh]::after{font-size:10.5px;color:#7a7a76}' +
      '.btn[data-p4zh]::after,.setupPrimary[data-p4zh]::after,.setupSecondary[data-p4zh]::after{' +
      'display:block;font-size:9.5px;margin-top:1px}' +
      '.btn.primary[data-p4zh]::after,.setupPrimary[data-p4zh]::after{color:rgba(255,255,255,.72)}' +
      '.homeBusVal[data-p4zh]::after,.value[data-p4zh]::after,' +
      '.statusTag[data-p4zh]::after,.labValueV[data-p4zh]::after{' +
      'display:block;font-size:8.5px;margin:1px 0 0;opacity:.9}' +
      '.mode[data-p4zh]::after{display:block;font-size:14px;letter-spacing:0;margin-top:2px;opacity:.85}' +
      '.homeMetaK[data-p4zh]::after{display:block;font-size:8px;margin:1px 0 0;opacity:.85}' +
      '.homeBusTop{gap:5px}.homeBusName{min-width:0;white-space:nowrap;overflow:hidden}' +
      '.homeBusMeta[data-p4zh]{font-size:0!important;line-height:0!important}' +
      '.homeBusMeta[data-p4zh]::after{content:attr(data-p4zh)!important;display:block!important;' +
      'font-size:8.5px!important;line-height:1.3!important;white-space:normal!important;' +
      'color:var(--muted,#8c8c88)!important;opacity:1!important;margin:0!important}' +
      '.navbtn[data-p4zh]::after{margin-left:2px;font-size:8px}' +
      /* 标题后面的中文用一点间距隔开，别和英文黏成 "TLSSC红绿灯" */
      '.quickMini .qt[data-p4zh]::after{display:inline;font-size:8px;margin-left:4px;' +
      'opacity:.72;white-space:nowrap!important;max-width:100%;overflow:hidden;' +
      'text-overflow:ellipsis;vertical-align:baseline}' +
      /* 副标题整句本来就长，中文换到下一行独占整条宽度，避免截成 "等待 ..." */
      '.quickMini .qs[data-p4zh]::after{display:block;font-size:7.5px;margin:1px 0 0;' +
      'opacity:.8;white-space:nowrap!important;max-width:100%;overflow:hidden;' +
      'text-overflow:ellipsis;line-height:1.25}' +
      /* 三个速控块只有 ~100pt 宽，副标题塞进中文后容易撑破卡片，
         这里统一单行截断，并让开关靠底，避免压到文字上。 */
      '.quickMini{overflow:hidden}' +
      '.quickMini .qs{min-height:10px}' +
      '.quickMini .toggle{margin-top:auto!important}';
    (document.head || document.documentElement).appendChild(st);
  }

  /* 运行时拼接出来的句子，词典匹配不到时用规则兜底 */
  var RULES = [
    [/^(BODY|CHASSIS|PARTY) · (RUNNING|WAITING|NO DATA|STALE|LIVE)$/, function (m) {
      var b = { BODY: '车身', CHASSIS: '底盘', PARTY: '派对' }[m[1]] || m[1];
      var s = { RUNNING: '运行中', WAITING: '等待', 'NO DATA': '无数据', STALE: '失效', LIVE: '实时' }[m[2]] || m[2];
      return b + ' · ' + s;
    }],
    [/^CAN ([123]) · (BODY|CHASSIS|PARTY)$/, function (m) {
      return 'CAN ' + m[1] + ' · ' + ({ BODY: '车身', CHASSIS: '底盘', PARTY: '派对' }[m[2]] || m[2]);
    }],
    [/^(\d+(?:\.\d+)?)\s*ms since frame$/, function (m) { return '距上帧 ' + m[1] + ' 毫秒'; }],
    [/^(BODY|CHASSIS|PARTY) · (.+?) ([\d.]+) (ms|s) since (?:last )?frame$/, function (m) {
      var b = { BODY: '车身', CHASSIS: '底盘', PARTY: '派对' }[m[1]] || m[1];
      var s = { STOPPED: '已停止', RUNNING: '运行中', 'BUS OFF': '总线关闭', RECOVERING: '恢复中' }[m[2]] || m[2];
      return b + ' · ' + s + ' · 距上帧 ' + m[3] + (m[4] === 'ms' ? ' 毫秒' : ' 秒');
    }],
    [/^(\d+(?:\.\d+)?)\s*s since frame$/, function (m) { return '距上帧 ' + m[1] + ' 秒'; }],
    [/^(\d+)\s*events?$/, function (m) { return m[1] + ' 个事件'; }],
    [/^(\d+)\s*\/\s*3 paired$/, function (m) { return m[1] + ' / 3 已配对'; }],
    [/^(\d+(?:\.\d+)?)\s*ms$/, function (m) { return m[1] + ' 毫秒'; }]
  ];

  function translate(raw) {
    var z = ZH[raw];
    if (z) return z;
    for (var i = 0; i < RULES.length; i++) {
      var m = raw.match(RULES[i][0]);
      if (m) { var r = RULES[i][1](m); if (r) return r; }
    }
    return null;
  }

  function norm(s) { return (s || '').replace(/\s+/g, ' ').trim(); }

  /* 文本节点是否是父元素里"唯一有意义"的文字（允许同级有 svg 图标） */
  function soleText(node) {
    var p = node.parentElement;
    if (!p) return false;
    for (var c = p.firstChild; c; c = c.nextSibling) {
      if (c === node) continue;
      if (c.nodeType === 3) { if (norm(c.nodeValue)) return false; }
      else if (c.nodeType === 1) {
        if (c.tagName.toLowerCase() === 'svg') continue;
        if (norm(c.textContent)) return false;
      }
    }
    return true;
  }

  function handle(node) {
    var el = node.parentElement;
    if (!el || !el.tagName) return;
    var tag = el.tagName;
    if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEXTAREA') return;
    if (el.namespaceURI && el.namespaceURI.indexOf('svg') !== -1) return;
    if (el.hasAttribute('data-p4zh-skip')) return;
    /* 总线名后的 BODY/CHASSIS 不译：卡片第三行已有中文，避免挤掉徽标 */
    if (el.className && String(el.className).indexOf('homeBusRole') !== -1) return;
    /* 徽标只有 7px 高、十几个像素宽，中文必溢出；第三行已用中文说明状态 */
    if (el.className && String(el.className).indexOf('badge') !== -1) return;

    var raw = norm(node.nodeValue);
    if (raw.length < 2 || raw.length > 600) return;
    if (!soleText(node)) return;

    if (tag === 'OPTION') {
      var orig = el.getAttribute('data-zh-orig');
      if (orig === null) { el.setAttribute('data-zh-orig', raw); orig = raw; }
      var z = translate(orig);
      if (z && norm(el.textContent) !== z) el.textContent = z;
      return;
    }

    var zh = translate(raw);
    if (!zh) {
      if (el.hasAttribute('data-p4zh')) {
        el.removeAttribute('data-p4zh');
        el.removeAttribute('data-p4zh-v');
      }
      return;
    }
    if (el.closest && el.closest('.quickMini') && SHORT[raw]) zh = SHORT[raw];
    if (el.className && String(el.className).indexOf('badge') !== -1 && BADGE[raw]) zh = BADGE[raw];
    var kind = raw.length > 12 ? 'l' : 's';
    if (el.getAttribute('data-p4zh') !== zh) el.setAttribute('data-p4zh', zh);
    if (el.getAttribute('data-p4zh-v') !== kind) el.setAttribute('data-p4zh-v', kind);
  }

  function sweep() {
    if (!ON || !document.body) return;
    var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var n;
    while ((n = w.nextNode())) handle(n);
  }

  var timer = null;
  function schedule() {
    if (timer) return;
    timer = setTimeout(function () { timer = null; sweep(); }, 180);
  }

  function boot() {
    injectStyle();
    sweep();
    var mo = new MutationObserver(function (muts) {
      for (var i = 0; i < muts.length; i++) {
        if (muts[i].type === 'attributes') continue;
        schedule();
        return;
      }
    });
    mo.observe(document.body, { childList: true, subtree: true, characterData: true });
    window.__p4zhMO = mo;
    window.p4zhSweep = sweep;
  }

  window.__p4zhDict = ZH;

  window.p4zh = function (on) {
    ON = !!on;
    document.body.classList.toggle('p4zh-off', !ON);
    if (!ON) {
      var els = document.querySelectorAll('[data-p4zh]');
      for (var i = 0; i < els.length; i++) {
        els[i].removeAttribute('data-p4zh');
        els[i].removeAttribute('data-p4zh-v');
      }
      var opts = document.querySelectorAll('[data-zh-orig]');
      for (var j = 0; j < opts.length; j++) opts[j].textContent = opts[j].getAttribute('data-zh-orig');
    } else {
      sweep();
    }
    return ON;
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();

/* ---------- P4-CAN App 外壳桥（只在 App 内生效，浏览器里整段跳过） ----------
 * 设备网页自带一条悬浮底部导航与大量右侧开关，原生悬浮按钮压上去会盖住控件。
 * 因此原生入口改成"设置 → 系统"里的一行，点了由 WKWebView 把消息回传给 App，
 * 由 App 打开自己的原生设置面板（地址 / 外观 / 缓存）。纯浏览器打开时不加这一行。
 */
(function () {
  var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.p4canApp;
  if (!bridge) return;

  function build() {
    if (document.getElementById('p4canAppRow')) return;
    var anchor = document.getElementById('rebootRow');
    if (!anchor || !anchor.parentNode) return;
    var row = document.createElement('div');
    row.className = 'listrow clickable';
    row.id = 'p4canAppRow';
    row.innerHTML =
      '<div><div class="listkey">P4-CAN App</div>' +
      '<div class="listdesc">App settings · 应用设置（地址 / 外观 / 缓存）</div></div>' +
      '<span class="chev">›</span>';
    row.onclick = function () { bridge.postMessage('settings'); };
    anchor.parentNode.insertBefore(row, anchor.nextSibling);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
  // 设置页是重渲染出来的，页面切回来后再补一次
  setTimeout(build, 1200);
  document.addEventListener('click', function () { setTimeout(build, 300); }, true);
})();
