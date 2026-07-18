#!/usr/bin/env bash
set -euo pipefail

# Builds the release binary and assembles it into a real .app bundle in
# ~/Applications, since this package has no Xcode project — it's built and
# wrapped by hand. Re-signs ad-hoc each time, which means macOS will
# re-prompt for Keychain access to the saved server credentials on first
# launch after every rebuild (the code identity changes each time) — that's
# expected, not a bug.

cd "$(dirname "$0")/.."

APP_NAME="AudiobookOffline"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
BUNDLE_ID="com.shayne.audiobookoffline"

echo "Building release binary..."
swift build -c release

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/${APP_NAME}" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

touch "$APP_DIR"

echo "Done: $APP_DIR"
