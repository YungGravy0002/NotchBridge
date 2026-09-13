#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CARD_PREVIEW_DIR="$PWD/notes/weekly-card"
CARD_PREVIEW_APP="$CARD_PREVIEW_DIR/WeeklyCardPreview.app"
mkdir -p "$CARD_PREVIEW_APP/Contents/MacOS" "$CARD_PREVIEW_APP/Contents/Resources"
cp Resources/notchbridge_logo.png "$CARD_PREVIEW_APP/Contents/Resources/"
cp -R Resources/*.lproj "$CARD_PREVIEW_APP/Contents/Resources/"
cat > "$CARD_PREVIEW_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WeeklyCardPreview</string>
<key>CFBundleIdentifier</key><string>com.alecmarinov.NotchBridge.WeeklyCardPreview</string>
<key>CFBundleName</key><string>WeeklyCardPreview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
CARD_SOURCES=()
while IFS= read -r file; do CARD_SOURCES+=("$file"); done < <(find Sources -name '*.swift' ! -name 'App.swift' | sort)
swiftc -O -target "$(uname -m)-apple-macos13.0" -parse-as-library \
  -framework SwiftUI -framework AppKit -framework ServiceManagement \
  -o "$CARD_PREVIEW_APP/Contents/MacOS/WeeklyCardPreview" \
  "${CARD_SOURCES[@]}" Tests/WeeklyCardRenderHarness.swift
NOTCHBRIDGE_DEMO=1 "$CARD_PREVIEW_APP/Contents/MacOS/WeeklyCardPreview" "${1:-$CARD_PREVIEW_DIR/renders}"
