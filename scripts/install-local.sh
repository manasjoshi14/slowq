#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlowQ"
BUNDLE_ID="io.github.manas.SlowQ"
SIGN_REQUIREMENT="designated => identifier \"${BUNDLE_ID}\""
APP_BUNDLE="/tmp/${APP_NAME}.app"
TARGET_APP="/Applications/${APP_NAME}.app"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp ".build/release/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>SlowQ needs Input Monitoring permission to intercept Cmd+Q and prevent accidental quits.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - -r="$SIGN_REQUIREMENT" "$APP_BUNDLE"

osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
rm -rf "$TARGET_APP"
cp -R "$APP_BUNDLE" "$TARGET_APP"
open "$TARGET_APP" >/dev/null 2>&1 || true

echo "Installed and launched: $TARGET_APP"
echo "If protection is still inactive, run:"
echo "  tccutil reset All ${BUNDLE_ID}"
