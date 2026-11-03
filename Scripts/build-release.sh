#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?请设置固定的 Developer ID Application 签名证书名称或 SHA-1}"
: "${DEVELOPMENT_TEAM:?请设置该证书所属的 Apple Developer Team ID}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "发布版本不能使用 ad-hoc 签名。" >&2
    exit 1
fi
xcodebuild -project ClipboardHistory.xcodeproj \
    -scheme ClipboardHistory -configuration Release \
    -derivedDataPath build/release \
    CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp" build
app="build/release/Build/Products/Release/ClipboardHistory.app"
codesign --verify --deep --strict "$app"
codesign -d -r- "$app"
echo "发布应用：$app"
