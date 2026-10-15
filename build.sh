#!/bin/zsh
# Builds Holdit.app next to this script.
set -e
cd "$(dirname "$0")"

APP=Holdit.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon (same tray symbol as the menu bar)
ICONSET="$(mktemp -d)/Holdit.iconset"
swift Tools/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Holdit.icns"
rm -rf "$(dirname "$ICONSET")"

swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos13.0" \
  -o "$APP/Contents/MacOS/Holdit" \
  Sources/*.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Holdit</string>
    <key>CFBundleDisplayName</key><string>Holdit</string>
    <key>CFBundleIdentifier</key><string>com.local.holdit</string>
    <key>CFBundleExecutable</key><string>Holdit</string>
    <key>CFBundleIconFile</key><string>Holdit</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $(pwd)/$APP"
