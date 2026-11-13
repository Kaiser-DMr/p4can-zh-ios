#!/bin/bash
# 探活状态机回归检查：把 AppModel 编成 macOS 可执行文件直接跑。
# 不依赖 XCTest，也不需要模拟器。
set -e
cd "$(dirname "$0")/.."

SDK=$(xcrun --sdk macosx --show-sdk-path)
OUT=$(mktemp -d)/probecheck

echo "==> 编译（macOS，仅 AppModel + 检查用例）"
xcrun swiftc -swift-version 5 -parse-as-library -disable-sandbox \
  -sdk "$SDK" -target arm64-apple-macos26.0 \
  P4CAN/AppModel.swift tests/ProbeStateCheck.swift \
  -o "$OUT"

echo "==> 运行"
"$OUT"
