#!/usr/bin/env bash
# 编译 P4CAN iOS App 并打成未签名 .ipa
# 用法: ./build-ipa.sh [Debug|Release]
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="P4CAN"
VERSION="1.0.0"
CONF="${1:-Release}"

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
