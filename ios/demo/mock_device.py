#!/usr/bin/env python3
"""
P4-CAN 设备模拟器（离线演示用）

把固件里的真实仪表盘 dashboard_source.html 用 HTTP 起在本地，并把 /api/* 接口
用一份固定的（一车一板在跑）遥测数据应答，这样在没有硬件的情况下，手机/预览窗口
连上来就是"已连接"的真实界面，而不是一堆 Unavailable。

用法：
    python3 mock_device.py            # 默认 127.0.0.1:8899
    python3 mock_device.py 8899       # 指定端口
    BIND=0.0.0.0 python3 mock_device.py   # 局域网内真机 iPhone 也能连

注意：只用于界面演示，不会真的发 CAN 帧。
"""

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))


def find_firmware():
    """找上游固件目录（本仓库不包含它，需要自己 clone 到旁边）。

    优先级：环境变量 P4CAN_FW > 本仓库根目录/上一级的 P4-CAN-Universal*
    """
    env = os.environ.get("P4CAN_FW", "").strip()
    if env:
        return os.path.abspath(os.path.expanduser(env))
    import glob
    for root in (os.path.join(HERE, "..", ".."), os.path.join(HERE, "..", "..", ".."),
                 os.getcwd()):
        for pat in ("P4-CAN-Universal*", "P4can-universal-unlock*"):
            for hit in sorted(glob.glob(os.path.join(root, pat))):
                if os.path.isfile(os.path.join(hit, "dashboard_source.html")):
                    return os.path.abspath(hit)
    return os.path.abspath(os.path.join(HERE, "..", "..", "P4-CAN-Universal-v3.29.3"))


FW = find_firmware()
DASHBOARD = os.path.join(FW, "dashboard_source.html")
FONT_DIR = os.path.join(FW, "fonts")

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
BIND = os.environ.get("BIND", "127.0.0.1")
# 演示时可直接打开某个页面：START_PAGE=settings / lab / devices
START_PAGE = os.environ.get("START_PAGE", "").strip()

# UNPATCHED=1：按"原厂固件"的样子发页面——去掉汉化补丁那一整块，
# 用来验证 App 在没打补丁的设备上如何降级（英文界面 + 长按兜底入口）。
UNPATCHED = os.environ.get("UNPATCHED", "").strip() not in ("", "0", "false")


def read_dashboard_html():
    with open(DASHBOARD, "rb") as f:
        html = f.read().decode("utf8", "replace")
    if UNPATCHED:
        i = html.find("<!--P4ZH-BEGIN-->")
        j = html.find("<!--P4ZH-END-->")
        if i >= 0 and j > i:
            html = html[:i] + html[j + len("<!--P4ZH-END-->"):]
    return html

# 演示时定位到某一处：SCROLL_TO="#p4canAppRow" / ".quickStrip" / "bottom"
# 页面是异步重渲染的，所以在点完导航后再等一拍，并把元素滚到可视区中间。
_SCROLL_TARGET = os.environ.get("SCROLL_TO", "").strip()
if _SCROLL_TARGET == "bottom":
    SCROLL_JS = "setTimeout(function(){window.scrollTo(0,document.body.scrollHeight);},600);"
elif _SCROLL_TARGET:
    SCROLL_JS = (
        "setTimeout(function(){var t=document.querySelector(%r);"
        "if(t)t.scrollIntoView({block:'center'});},700);" % _SCROLL_TARGET
    )
else:
    SCROLL_JS = ""

# 车况：24 款 Model Y（Model Y Legacy / BODY+CHASSIS / ALT 转向灯）
PROFILE_STATUS = {
    "setupMode": False,
    "nvsError": False,
    "profile": 3,
    "topology": 2,
    "turn": 1,
    "topologyName": "Body + Chassis + Party",
    "canB": "CAN B · CHASSIS",
    "nagSupported": True,
    "nagTorqueSupported": True,
    "nagTsl9Supported": False,
    "advancedEapSupported": True,
    "euUnlockSupported": True,
    "pedalMapSupported": True,
    "apDriveProfileSupported": True,
    "apDriveProfileRegenRaw": 10,
    "bannedSupported": True,
    "tlsscRestoreSupported": True,
    "migrationNotice": False,
}

FEATURE_STATUS = {
    "lab": True,
    "s3xy": True,
    "doorCancel": True,
    "banned": False,
    "tlsscRestore": False,
    "apDriveProfile": True,
    "apDriveProfileSupported": True,
    "apDriveProfileRegenRaw": 10,
    "pedalMapSupported": True,
    "bannedSupported": True,
    "tlsscRestoreSupported": True,
}

WIFI_STATUS = {
    "ssid": "P4-CAN-8F2C",
    "ip": "192.168.4.1",
    "passwordIsDefault": True,
    "mode": "AP",
}

NAG_CONFIG = {
    "enabled": True,
    "mode": 0,
    "method": 0,
    "ignoreApState": False,
    "pauseAtZero": True,
}

NAG_STATS = {
    "torque": 1.24,
    "apActive": True,
    "dasState": 3,
    "dasStateValid": True,
    "dasAgeMs": 118,
    "canAState": 1,
    "stoppedGate": False,
    "stopCarrierActive": False,
    "lastTxAgeMs": 96,
    "maxTxGapMs": 102,
    "sessionTxOk": 18342,
    "lastSkip": "NONE",
    "lastSkipAgeMs": 999999,
    "vehicleSpeedValid": True,
    "vehicleSpeedKph": 62.4,
    "vehicleSpeedFresh": True,
    "skipStopped": 0,
    "skipSpeedStale": 0,
    "skipApInvalid": 0,
    "skipApInactive": 0,
    "skipHandsOn": 0,
    "blockFreshMask": 0,
    "blockEpoch": 0,
    "blockMutex": 0,
    "blockNativeANotReady": 0,
    "sendError": 0,
    "lastTxBlock": "NONE",
    "lastTxBlockAgeMs": 999999,
    "humanEventCount": 0,
}

BLINK_STATS = {
    "enabled": True,
    "dasState": 3,
    "dasStateValid": True,
    "displayState": 3,
    "displayStateValid": True,
    "delayMs": 300,
    "noaStabilizationSeconds": 10,
    "cancelPauseSeconds": 20,
    "cancelPaused": False,
    "autoArmed": False,
    "autoRemainMs": 0,
    "autoRetryInMs": 0,
    "autoRetryCount": 0,
    "autoWaitingEligibility": False,
    "behaviorType": "STALK",
    "alcState": 8,
    "alcValid": True,
    "alcDirectionAllowed": True,
    "pendingAlcAllowed": False,
    "visualFresh": True,
    "visualAgeMs": 92,
    "activeTurn": 0,
    "seen249": True,
    "cksumSelfTest": True,
    "txMode": 0,
    "txActiveSource": "NONE",
    "txLastSource": "NONE",
    "txLastResult": "OK",
    "txLastDirection": 0,
    "txRequests": 0,
    "txBlocked": 0,
    "txOk": 0,
    "txFail": 0,
    "realRaw": "0x249 · 6A 00 00 00 00 00 00 00",
    "visualDebugRx": 0,
}


def snapshot(groups: str):
    fast = {
        "nag": {
            "torque": NAG_STATS["torque"],
            "apActive": True,
            "handsOnState": 2,
            "stoppedGate": False,
            "stopCarrierActive": False,
            "canAState": 1,
            "dasState": 3,
            "dasStateValid": True,
            "dasAgeMs": 118,
        },
        "blink": BLINK_STATS,
        "summon": {"canState": 1, "canStateName": "RUNNING", "tlssc": False},
        "cantraffic": {
            "can1State": 1, "can1Ready": True,
            "can1TrafficSeen": True, "can1TrafficOnline": True, "can1TrafficAgeMs": 38,
            "can2State": 1, "can2Ready": True,
            "can2TrafficSeen": True, "can2TrafficOnline": True, "can2TrafficAgeMs": 62,
            "can3State": 1, "can3Ready": True,
            "can3TrafficSeen": True, "can3TrafficOnline": True, "can3TrafficAgeMs": 51,
        },
        "r79": {
            "state": "RUNNING",
            "reason": "AP active · injecting",
            "txOk": 4211,
            "txFail": 0,
            "lastTxAgeMs": 96,
        },
    }
    slow = {
        "blink": {"enabled": True},
        "summon": {"tlssc": False},
        "s3xy": {
            "bluetoothEnabled": True,
            "pairedCount": 2,
            "connectedCount": 2,
            "autoEnabled": True,
        },
        "r79": fast["r79"],
        "lab3f8": {"alcMode": 0},
        "system": {"fwVersion": "3.29.3"},
    }
    if "lab-lite" in groups:
        return {"r79": fast["r79"], "alc": {
            "alcValid": True, "alcRaw": 8,
            "lane239Valid": True, "lane239AgeMs": 88,
            "leftLaneExists": 1, "leftLineUsageRaw": 2, "leftForkRaw": 0,
            "rightLaneExists": 1, "rightLineUsageRaw": 2, "rightForkRaw": 0,
        }}
    if "settings-lite" in groups:
        return {
            "system": {"fwVersion": "3.29.3"},
            "blink": {"enabled": True},
            "summon": {"tlssc": False},
            "s3xy": slow["s3xy"],
            "lab3f8": {"alcMode": 0},
        }
    if "home-fast" in groups:
        out = {"fast": fast}
        if "slow=1" in groups or "slow" in groups:
            out["slow"] = slow
        return out
    return {"fast": fast, "slow": slow}


SYSTEM_STATS = {
    "fwVersion": "3.29.3",
    "uptimeMs": 1_284_000,
    "freeHeap": 214_336,
    "freePsram": 12_582_912,
    "taskStackMinFree": 4_120,
    "can": {"body": "RUNNING", "chassis": "RUNNING", "party": "RUNNING"},
}

CONTINUOUS_AP_CONFIG = {
    "enabled": False,
    "active": False,
    "supported": True,
}

ISA_CONFIG = {"enabled": False, "supported": True}
DRIVER_MONITORING_CONFIG = {"enabled": False, "supported": True, "uncertain": False}
VISION_CONTROL = {"enabled": False, "supported": True, "requests": 0}
ULC_STATS = {"enabled": False, "valid": True, "canAState": 1}
R79_STATS = {"state": "RUNNING", "txOk": 4211, "txFail": 0, "lastTxAgeMs": 96}
COUNTRY_STATS = {"override": False, "mode": "OFF", "supported": True}
OTA_STATUS = {"attempt": 1, "inProgress": False, "ok": True}
S3_STATS = {
    "bluetoothEnabled": True,
    "autoEnabled": True,
    "devices": [
        {"slot": 1, "name": "S3XY Button · A", "connected": True, "rssi": -54, "battery": 92},
        {"slot": 2, "name": "S3XY Button · B", "connected": True, "rssi": -61, "battery": 78},
    ],
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # 只打错误，别刷屏
        pass

    # --- helpers -----------------------------------------------------------

    def send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path, ctype):
        try:
            with open(path, "rb") as f:
                body = f.read()
        except OSError:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    # --- routing -----------------------------------------------------------

    def do_GET(self):
        path = urlparse(self.path).path

        if path in ("/", "/index.html"):
            html = read_dashboard_html()
            if START_PAGE or SCROLL_JS:
                jump = (
                    '<script>setTimeout(function(){'
                    'var b=document.querySelector(\'.navbtn[data-page="%s"]\');'
                    "if(b)b.click();%s},900);</script>" % (START_PAGE, SCROLL_JS)
                )
                # 必须插到最后一个 </body> 前：汉化补丁的注释里也出现过这个词
                head, sep, tail = html.rpartition("</body>")
                html = head + jump + sep + tail
            body = html.encode("utf8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return

        if path.startswith("/fonts/"):
            name = os.path.basename(path)
            if "mono" in name:
                return self.send_file(os.path.join(FONT_DIR, "geist-mono-latin.woff2"), "font/woff2")
            return self.send_file(os.path.join(FONT_DIR, "geist-latin.woff2"), "font/woff2")

        if path == "/api/wifi/status":
            return self.send_json(WIFI_STATUS)
        if path == "/api/profile/status":
            return self.send_json(PROFILE_STATUS)
        if path == "/api/features/status":
            return self.send_json(FEATURE_STATUS)
        if path == "/api/nag/config":
            return self.send_json(NAG_CONFIG)
        if path == "/api/nag/stats":
            return self.send_json(NAG_STATS)
        if path == "/api/blinkA/stats":
            return self.send_json(BLINK_STATS)
        if path == "/api/system/stats":
            return self.send_json(SYSTEM_STATS)
        if path == "/api/continuous-ap/config":
            return self.send_json(CONTINUOUS_AP_CONFIG)
        if path == "/api/isa-suppression/config":
            return self.send_json(ISA_CONFIG)
        if path == "/api/driver-monitoring/config":
            return self.send_json(DRIVER_MONITORING_CONFIG)
        if path == "/api/vision-control/stats":
            return self.send_json(VISION_CONTROL)
        if path == "/api/ulc/stats":
            return self.send_json(ULC_STATS)
        if path == "/api/r79/stats":
            return self.send_json(R79_STATS)
        if path == "/api/country/stats":
            return self.send_json(COUNTRY_STATS)
        if path == "/api/ota/status":
            return self.send_json(OTA_STATUS)
        if path == "/api/s3xy/stats":
            return self.send_json(S3_STATS)
        if path == "/api/snapshot":
            return self.send_json(snapshot(self.path))

        if path.startswith("/api/"):
            return self.send_json({})

        if path == "/apple-touch-icon.png":
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/api/profile/select":
            return self.send_json({"ok": True, "rebooting": True})
        # 演示模式：命令一律"成功"，但不改状态
        return self.send_json({"ok": True})


def main():
    if not os.path.exists(DASHBOARD):
        sys.exit(
            f"找不到仪表盘源文件：{DASHBOARD}\n"
            "先把上游固件 clone 到本仓库旁边，或用环境变量指定：\n"
            "  git clone https://github.com/06066060606060/P4can-universal-unlock.git\n"
            "  P4CAN_FW=/path/to/P4can-universal-unlock python3 mock_device.py 8899")
    srv = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"P4-CAN 模拟设备已启动 → http://{'127.0.0.1' if BIND == '0.0.0.0' else BIND}:{PORT}/")
    print(f"仪表盘：{DASHBOARD}")
    print("按 Ctrl+C 退出")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")


if __name__ == "__main__":
    main()
