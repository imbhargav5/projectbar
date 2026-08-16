#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Configuration must be debug or release" >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="$ROOT_DIR/.build/package/ProjectBar.app"
FINAL_APP="$ROOT_DIR/ProjectBar.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/Contents/MacOS" "$STAGE_DIR/Contents/Resources"
cp "$BIN_DIR/ProjectBar" "$STAGE_DIR/Contents/MacOS/ProjectBar"

cat > "$STAGE_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ProjectBar</string>
    <key>CFBundleDisplayName</key>
    <string>ProjectBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.imbhargav5.projectbar</string>
    <key>CFBundleExecutable</key>
    <string>ProjectBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$STAGE_DIR"
rm -rf "$FINAL_APP"
mv "$STAGE_DIR" "$FINAL_APP"
codesign --verify --deep --strict "$FINAL_APP"
echo "Packaged $FINAL_APP"
