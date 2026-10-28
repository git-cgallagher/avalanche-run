#!/usr/bin/env bash
# Packages build/Avalanche Run.app into a drag-to-Applications disk image: build/AvalancheRun-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Avalanche Run.app"
[[ -d "$APP" ]] || ./build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
DMG="build/AvalancheRun-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Avalanche Run" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG"
