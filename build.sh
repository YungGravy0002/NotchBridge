#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="NotchBridge"
BUNDLE_ID="com.alecmarinov.NotchBridge"
VERSION="$(cat VERSION)"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: VERSION must be X.Y.Z (got '$VERSION')" >&2
  exit 1
fi
BUILD_DIR="./build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp ./Resources/claude_logo.pdf "$RES_DIR/claude_logo.pdf"
cp ./Resources/openai_logo.pdf "$RES_DIR/openai_logo.pdf"
cp ./Resources/ThirdPartyNotices.txt "$RES_DIR/ThirdPartyNotices.txt"
cp ./Resources/notchbridge_logo.png "$RES_DIR/notchbridge_logo.png"
cp ./Resources/NotchBridge.icns "$RES_DIR/NotchBridge.icns"
cp ./scripts/recover-claude-usage.sh "$RES_DIR/recover-claude-usage.sh"
find ./Resources -maxdepth 1 -type d -name '*.lproj' -exec cp -R {} "$RES_DIR/" \;

SWIFT_SOURCES=$(find Sources -name '*.swift' | sort)

# Universal binary, macOS 13 (Ventura) minimum. swiftc can't emit a
# multi-arch Mach-O directly, so compile each slice and lipo them.
DEPLOYMENT_TARGET="13.0"
ARM64_BIN="$BUILD_DIR/$APP_NAME-arm64"
X86_64_BIN="$BUILD_DIR/$APP_NAME-x86_64"

for arch_pair in "arm64:$ARM64_BIN" "x86_64:$X86_64_BIN"; do
  arch="${arch_pair%%:*}"
  out="${arch_pair##*:}"
  swiftc \
    -target "${arch}-apple-macos${DEPLOYMENT_TARGET}" \
    -O \
    -parse-as-library \
    -framework SwiftUI \
    -framework AppKit \
    -framework ServiceManagement \
    -o "$out" \
    $SWIFT_SOURCES
done

lipo -create "$ARM64_BIN" "$X86_64_BIN" -output "$MACOS_DIR/$APP_NAME"
rm "$ARM64_BIN" "$X86_64_BIN"

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>NotchBridge</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>NotchBridge</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>$DEPLOYMENT_TARGET</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Eric Park (CodexIsland) and Alec Marinov (NotchBridge). MIT licensed.</string>
</dict>
</plist>
EOF

echo "✓ built $APP_DIR ($VERSION)"
