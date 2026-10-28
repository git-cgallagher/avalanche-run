#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) "build/Avalanche Run.app" from the Swift package.
# Command Line Tools are enough; Xcode is not needed.
set -euo pipefail
cd "$(dirname "$0")"

for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx14.0" --scratch-path ".build/$arch"
done

APP="build/Avalanche Run.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/AvalancheRun" \
    .build/arm64/release/AvalancheRun .build/x86_64/release/AvalancheRun
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/AvalancheRun"))"
