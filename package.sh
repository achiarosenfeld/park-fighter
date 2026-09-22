#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) ParkFighter.app and wraps it in a drag-to-install
# disk image (plus a zip, for anyone who prefers one).
# Usage: ./package.sh
set -euo pipefail
cd "$(dirname "$0")"

APPNAME="ParkFighter"
DISPLAY="Park Fighter"
SRC=(Sources/ParkFighter/*.swift)
FRAMEWORKS=(-framework AppKit -framework QuartzCore -framework ApplicationServices)
MIN=13.0

rm -rf dist
mkdir -p dist/arch

echo "Compiling arm64…"
swiftc -O -target arm64-apple-macosx$MIN -o "dist/arch/$APPNAME-arm64" "${SRC[@]}" "${FRAMEWORKS[@]}"
echo "Compiling x86_64…"
swiftc -O -target x86_64-apple-macosx$MIN -o "dist/arch/$APPNAME-x86_64" "${SRC[@]}" "${FRAMEWORKS[@]}"

echo "Merging into a universal binary…"
lipo -create -output "dist/arch/$APPNAME" "dist/arch/$APPNAME-arm64" "dist/arch/$APPNAME-x86_64"

STAGE="dist/$DISPLAY"
APP="$STAGE/$APPNAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "dist/arch/$APPNAME" "$APP/Contents/MacOS/$APPNAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/head.png ]] && cp Resources/head.png "$APP/Contents/Resources/head.png"

echo "Rendering the icon…"
ICONSET=dist/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  "dist/arch/$APPNAME" --render-icon "$ICONSET/icon_${s}x${s}.png" $s
  "dist/arch/$APPNAME" --render-icon "$ICONSET/icon_${s}x${s}@2x.png" $((s*2))
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=1 "$APP" 2>&1 | sed 's/^/  /'

cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
Park Fighter
============

A pixel-art brawler lives on top of your screen. He walks around at random, stands on the tops
of your open windows, rides them when you drag them, and every so often picks a fight with one:
taunts it, punches it until it rattles, kicks it across the desk, then stomps it closed and
celebrates.

INSTALL
  Drag ParkFighter.app into your Applications folder, then double-click it.
  There is no window - look for the boxing glove in the menu bar at the top right.

FIRST LAUNCH: macOS WILL BLOCK IT
  This app is not signed with a paid Apple developer certificate, so macOS refuses to open it
  the first time and says it "cannot be opened because Apple cannot check it for malicious
  software". This is expected. To allow it:

    1. Double-click the app. Click Done on the warning.
    2. Open System Settings > Privacy & Security.
    3. Scroll down. There is a line about ParkFighter being blocked.
       Click "Open Anyway", then confirm with Touch ID or your password.
    4. Double-click the app again. It opens from now on.

  Faster alternative, if you are comfortable with Terminal:

    xattr -dr com.apple.quarantine /Applications/ParkFighter.app

ACCESSIBILITY PERMISSION
  Rattling, shoving, minimising and closing windows all go through the macOS Accessibility API,
  so you get asked for permission the first time he throws a punch. Until you grant it he just
  shadow-boxes. System Settings > Privacy & Security > Accessibility > allow ParkFighter.

  Closing goes through the window's own red close button, so apps still get to ask you about
  unsaved work. If that is still too much, turn off "Let him close windows" in the menu.

USING IT
  Everything is in the menu bar:
    Pick a fight right now   starts a beatdown on the nearest window
    Taunt                    come at me
    Beat up my windows       punching, kicking and shoving
    Let him close windows    adds the closing and minimising finishers
    Nap time                 he sits down and leaves you alone
    Size                     Small / Normal / Large / Huge
    Quit

REQUIREMENTS
  macOS 13 Ventura or newer. Apple Silicon and Intel.

WHAT IT DOES NOT DO
  No network access, no data collection, no login items. It draws on screen, reads the positions
  of open windows, and moves or closes windows when you have allowed it to. Quitting from the
  menu removes it completely; delete the app to uninstall.
TXT

echo "Building the disk image…"
DMGROOT=dist/dmgroot
rm -rf "$DMGROOT"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
cp "$STAGE/READ ME FIRST.txt" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$DMGROOT/.VolumeIcon.icns"
SetFile -a C "$DMGROOT" 2>/dev/null || true

DMG="dist/$DISPLAY.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "$DISPLAY" -srcfolder "$DMGROOT" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$DMGROOT"

echo "Zipping…"
ZIP="dist/$APPNAME-mac.zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGE" "$ZIP"

echo
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/$APPNAME")"
echo "Disk image:    $DMG  ($(du -h "$DMG" | cut -f1))"
echo "Shareable zip: $ZIP  ($(du -h "$ZIP" | cut -f1))"
