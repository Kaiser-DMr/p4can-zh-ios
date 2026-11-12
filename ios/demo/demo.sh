#!/bin/bash
# 一键起"已连接"演示：本地模拟设备 + 预览窗口
#
#   bash demo.sh            默认端口 8899
#   PORT=9000 bash demo.sh  换端口
#   START_PAGE=settings bash demo.sh   打开时直接进设置页
#
# 退出（Ctrl+C）会把模拟服务一起关掉。
set -e
cd "$(dirname "$0")"

PORT=${PORT:-8899}
export START_PAGE=${START_PAGE:-}

echo "==> 启动模拟设备 127.0.0.1:$PORT"
pkill -f "mock_device.py $PORT" 2>/dev/null || true
python3 mock_device.py "$PORT" &
MOCK_PID=$!
trap 'echo "==> 关闭模拟设备"; kill $MOCK_PID 2>/dev/null || true' EXIT INT TERM

# 等服务起来
for _ in $(seq 1 30); do
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then break; fi
  sleep 0.2
done

echo "==> 打开预览窗口（已连接）"
defaults write com.p4can.preview previewMode -int 2
defaults write com.p4can.preview previewHost -string "127.0.0.1:$PORT"

if [ ! -x ../MacPreview/P4CANPreview.app/Contents/MacOS/P4CANPreview ]; then
  echo "==> 首次运行，先编译预览"
  bash ../MacPreview/preview.sh
fi

pkill -f P4CANPreview 2>/dev/null || true
sleep 0.4
open -n ../MacPreview/P4CANPreview.app

echo
echo "已连接演示已启动："
echo "  · 预览窗口顶部可切 探测中 / 未连接 / 已连接，右侧切换深色浅色"
echo "  · 手机在同一 Wi-Fi 时，用 Safari 打开 http://<这台 Mac 的 IP>:$PORT 也能看同一页面"
echo "  · 页面里 设置 → P4-CAN App 那一行会回调原生设置（真机里就是 App 的设置面板）"
echo
echo "按 Ctrl+C 结束（同时关闭模拟设备）"
wait $MOCK_PID
