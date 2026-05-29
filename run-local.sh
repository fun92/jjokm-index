#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="/private/tmp/쪼꼼 인덱스.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
CACHE="/private/tmp/jjokm-index-cache"

pkill -f "/JjokmIndex.app/Contents/MacOS/JjokmIndex" 2>/dev/null || true
pkill -f "쪼꼼 인덱스.app/Contents/MacOS/JjokmIndex" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$CACHE/clang" "$CACHE/swift"

CLANG_MODULE_CACHE_PATH="$CACHE/clang" \
SWIFT_MODULE_CACHE_PATH="$CACHE/swift" \
xcrun swiftc "$ROOT/Sources/main.swift" \
  -framework Cocoa \
  -module-cache-path "$CACHE/swift" \
  -o "$MACOS/JjokmIndex"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null
open "$APP"
