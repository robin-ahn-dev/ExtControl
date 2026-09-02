#!/bin/bash
# Baut die App und packt sie als gestaltetes DMG nach dist/ExtControl-<version>.dmg
# (Hintergrundbild, Icon-Positionen, Volume-Icon, Drag-nach-Applications)
set -euo pipefail
cd "$(dirname "$0")"

NAME="ExtControl"
VERSION="${1:-1.0}"
DMG="dist/$NAME-$VERSION.dmg"
BG="Resources/dmg-background.tiff"

WINDOW_W=620
WINDOW_H=400
ICON_SIZE=120
TITLEBAR_H=40          # Finder-Titelleiste; bounds gilt fürs ganze Fenster
APP_POS_X=158
APP_POS_Y=212
LINK_POS_X=462
LINK_POS_Y=212

./build_app.sh

[ -f "$BG" ] || swift tools/MakeDMGBackground.swift "$BG"

STAGE="$(mktemp -d)"
RW="$(mktemp -u).dmg"

cp -R "dist/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$BG" "$STAGE/.background/background.tiff"

# Auf CI (kein Finder verfügbar) das eingecheckte Layout verwenden
SKIP_FINDER=0
if [ -n "${CI:-}" ] || [ "${NO_FINDER:-0}" = "1" ]; then
    if [ -f Resources/dmg-DS_Store ]; then
        cp Resources/dmg-DS_Store "$STAGE/.DS_Store"
        SKIP_FINDER=1
        echo "Finder-Styling übersprungen, nutze Resources/dmg-DS_Store"
    else
        echo "Warnung: kein Resources/dmg-DS_Store — DMG ohne Layout" >&2
        SKIP_FINDER=1
    fi
fi

SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 30 ))
hdiutil create -srcfolder "$STAGE" -volname "$NAME" -fs HFS+ \
    -size "${SIZE_MB}m" -format UDRW -ov "$RW" >/dev/null

# Altes Volume gleichen Namens aushängen, sonst mountet es als "$NAME 1"
if [ -d "/Volumes/$NAME" ]; then
    hdiutil detach "/Volumes/$NAME" -quiet || true
fi

MOUNT="$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | grep -Eo '/Volumes/.*' | head -1)"
VOLNAME="$(basename "$MOUNT")"
trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true' EXIT

if [ "$SKIP_FINDER" = "0" ]; then
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {180, 140, ${WINDOW_W} + 180, ${WINDOW_H} + ${TITLEBAR_H} + 140}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 12
        set background picture of viewOptions to POSIX file "$MOUNT/.background/background.tiff"
        set position of item "$NAME.app" of container window to {$APP_POS_X, $APP_POS_Y}
        set position of item "Applications" of container window to {$LINK_POS_X, $LINK_POS_Y}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Layout für spätere CI-Builds sichern
cp "$MOUNT/.DS_Store" Resources/dmg-DS_Store
fi

# Volume-Icon setzen (Icon des Laufwerks im Finder)
cp Resources/AppIcon.icns "$MOUNT/.VolumeIcon.icns"
if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$MOUNT"
    SetFile -a V "$MOUNT/.VolumeIcon.icns"
fi

sync
hdiutil detach "$MOUNT" -quiet
trap - EXIT

rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"
rm -rf "$STAGE"

echo "fertig: $DMG ($(du -h "$DMG" | cut -f1))"
