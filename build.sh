#!/bin/zsh
# Builds ParkFighter.app into ./build. Usage: ./build.sh [--run] [extra args passed to the app]
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release 2>&1 | grep -v '^\[' || true
BIN=.build/release/ParkFighter
[[ -x "$BIN" ]] || { echo "build failed"; exit 1; }

APP=build/ParkFighter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ParkFighter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/head.png ]] && cp Resources/head.png "$APP/Contents/Resources/head.png"

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  "$BIN" --render-icon "$ICONSET/icon_${s}x${s}.png" $s
  "$BIN" --render-icon "$ICONSET/icon_${s}x${s}@2x.png" $((s*2))
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
  shift
  pkill -x ParkFighter 2>/dev/null || true
  open "$APP" ${@:+--args "$@"}
fi
