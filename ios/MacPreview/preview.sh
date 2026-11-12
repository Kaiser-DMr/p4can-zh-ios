#!/bin/bash
# 在 Mac 上编译并运行预览窗口（同一套 SwiftUI 视图，非模拟器）。
# 需要 macOS 26+ 才能看到真实的液态玻璃合成效果。
#
# 每次重建整个 .app 包：Info.plist 里有明文连接许可（ATS），
# 手工改 plist 会让 ad-hoc 签名失效，WebKit 的子进程会直接起不来（表现为白/黑屏）。
set -e
cd "$(dirname "$0")"

APP=P4CANPreview.app
SDK=$(xcrun --sdk macosx --show-sdk-path)

echo "==> 重建应用包"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Dock 里显示应用图标（由 tools/make-icon.py 生成）
[ -f ../图标/AppIcon.icns ] && cp ../图标/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleIdentifier</key><string>com.p4can.preview</string>
	<key>CFBundleName</key><string>P4CAN 预览</string>
	<key>CFBundleDisplayName</key><string>P4CAN 预览</string>
	<key>CFBundleExecutable</key><string>P4CANPreview</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key><true/>
		<key>NSAllowsLocalNetworking</key><true/>
	</dict>
</dict>
</plist>
PLIST

echo "==> 编译"
xcrun swiftc -parse-as-library -swift-version 5 -disable-sandbox \
  -D P4CAN_PREVIEW \
  -sdk "$SDK" -target arm64-apple-macos26.0 \
  ../P4CAN/Theme.swift ../P4CAN/Glass.swift ../P4CAN/AppModel.swift \
  ../P4CAN/ConnectView.swift ../P4CAN/SettingsView.swift WebPane.swift main.swift \
  -o "$APP/Contents/MacOS/P4CANPreview"

echo "==> 签名（ad-hoc）"
codesign --force -s - "$APP" >/dev/null 2>&1

echo "==> 启动"
pkill -f P4CANPreview 2>/dev/null || true
sleep 0.3
open -n "$APP"

echo "完成。窗口标题：P4CAN 运行预览"
echo "日志：/tmp/p4can-preview.log"
