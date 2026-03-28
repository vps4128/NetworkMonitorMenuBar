#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="NetworkMonitorMenuBar"
VERSION="${1:-1.0.2}"
APP_DIR="dist/${APP_NAME}.app"
BIN_PATH=".build/release/${APP_NAME}"
DMG_SRC="dist/dmg-src"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"
ICON_SRC="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns"
ICON_NAME="AppIcon.icns"

swift build -c release

rm -rf "$APP_DIR" "$DMG_SRC" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DMG_SRC"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "$ICON_SRC" "$APP_DIR/Contents/Resources/${ICON_NAME}"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.zyg.networkmonitor</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

cp -R "$APP_DIR" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_SRC" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "DMG: $ROOT_DIR/$DMG_PATH"
