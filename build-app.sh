#!/usr/bin/env bash
# Builds build/Avalanche Run.app from the Swift package (Command Line Tools are enough; Xcode is not needed).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/Avalanche Run.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AvalancheRun "$APP/Contents/MacOS/AvalancheRun"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
