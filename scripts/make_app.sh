#!/usr/bin/env bash
#
# Builds DigDug.app — a double-clickable macOS app bundle — from the SwiftPM
# release binary, with a generated icon. Output: build/DigDug.app
#
# Usage:
#   scripts/make_app.sh            # build the .app into ./build
#   scripts/make_app.sh --install  # also copy it to /Applications
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="DigDug"
BUNDLE_ID="com.psalomone.digdug"
VERSION="1.0.0"
OUT_DIR="$PROJECT_DIR/build"
APP="$OUT_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Building release binary"
swift build -c release --product "$APP_NAME"
BIN="$(swift build -c release --product "$APP_NAME" --show-bin-path)/$APP_NAME"
[ -f "$BIN" ] || { echo "release binary not found at $BIN"; exit 1; }

echo "==> Assembling bundle skeleton"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$APP_NAME"

echo "==> Preparing icon"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CUSTOM_ICON="$PROJECT_DIR/Resources/DigDug.png"
if [ -f "$CUSTOM_ICON" ]; then
    echo "    using Resources/DigDug.png (rounded + padded to macOS shape)"
    swift "$PROJECT_DIR/scripts/round_icon.swift" "$CUSTOM_ICON" "$WORK/icon_1024.png"
else
    echo "    generating shovel icon"
    swift "$PROJECT_DIR/scripts/generate_icon.swift" "$WORK/icon_1024.png"
fi

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; label="${spec##*:}"
    sips -z "$px" "$px" "$WORK/icon_1024.png" --out "$ICONSET/icon_${label}.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

echo "==> Writing Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "    (codesign skipped)"

echo "==> Built: $APP"

if [ "${1:-}" = "--install" ]; then
    echo "==> Installing to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/$APP_NAME.app"
    echo "==> Installed: /Applications/$APP_NAME.app"
fi
