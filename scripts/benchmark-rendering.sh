#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/notchbridge-render-benchmark.XXXXXX")
trap 'rm -rf "$OUT_DIR"' EXIT
APP="$OUT_DIR/RenderingBenchmark.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/*_logo.* "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.alecmarinov.NotchBridge.RenderingBenchmark</string>
<key>CFBundleExecutable</key><string>RenderingBenchmark</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
swiftc -O -whole-module-optimization -target "$(uname -m)-apple-macos13.0" -parse-as-library \
  -framework SwiftUI -framework AppKit -framework ServiceManagement \
  -o "$APP/Contents/MacOS/RenderingBenchmark" \
  $(find Sources -name '*.swift' ! -name 'App.swift' ! -name 'OverviewView.swift' | sort) \
  "${RENDER_BENCHMARK_OVERVIEW_SOURCE:-Sources/Views/OverviewView.swift}" "${1:-Tests/RenderingBenchmark.swift}"
NOTCHBRIDGE_DEMO=1 "$APP/Contents/MacOS/RenderingBenchmark"
