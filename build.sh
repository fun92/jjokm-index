#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="쪼꼼 인덱스"
VERSION="1.2.3"
APP="$ROOT/dist/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
CACHE="$ROOT/.build-cache"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$CACHE"

if [[ ! -f "$ROOT/Assets/JjokkomIndex.icns" ]]; then
  (cd "$ROOT" && xcrun swift -module-cache-path "$CACHE/swift-script" "$ROOT/scripts/generate-app-icon.swift")
fi

CLANG_MODULE_CACHE_PATH="$CACHE/clang" \
SWIFT_MODULE_CACHE_PATH="$CACHE/swift" \
xcrun swiftc "$ROOT/Sources/main.swift" \
  -framework Cocoa \
  -module-cache-path "$CACHE/swift" \
  -o "$MACOS/JjokkomIndex"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Assets/JjokkomIndex.icns" "$RESOURCES/JjokkomIndex.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" >/dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "$APP"
