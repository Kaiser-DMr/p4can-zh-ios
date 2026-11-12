#!/usr/bin/env bash
# 编译 P4CAN iOS App 并打成未签名 .ipa
# 用法: ./build-ipa.sh [Debug|Release]
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="P4CAN"
VERSION="1.1.0"
CONF="${1:-Release}"

# 汉化脚本的唯一来源是 ../i18n/zh-bilingual.js，打包前同步进 App 资源目录，
# 避免两份文件各改各的。改完文案只需动 i18n/ 那份。
SYNC_FROM="../i18n/zh-bilingual.js"
SYNC_TO="P4CAN/zh-bilingual.js"
if [ -f "$SYNC_FROM" ]; then
  cp "$SYNC_FROM" "$SYNC_TO"
  echo "==> 同步汉化脚本: $SYNC_TO ($(wc -c < "$SYNC_TO" | tr -d ' ') 字节)"
else
  echo "!! 找不到 $SYNC_FROM，App 将以无汉化状态打包"
fi

echo "==> 编译 ${APP_NAME} (${CONF} / iphoneos / 未签名)"
xcodebuild -project P4CAN.xcodeproj \
  -scheme P4CAN \
  -configuration "$CONF" \
  -sdk iphoneos \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' \
  build | tail -3

APP=".build/Build/Products/${CONF}-iphoneos/${APP_NAME}.app"
[ -d "$APP" ] || { echo "!! 找不到产物 $APP"; exit 1; }

rm -rf Payload dist
mkdir -p Payload dist
cp -R "$APP" Payload/
zip -qry "dist/${APP_NAME}-${VERSION}-unsigned.ipa" Payload
rm -rf Payload

echo "==> 完成: dist/${APP_NAME}-${VERSION}-unsigned.ipa"
ls -lh "dist/${APP_NAME}-${VERSION}-unsigned.ipa"
