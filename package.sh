#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="빼꼼 인덱스"
VERSION="1.1.0"
APP="$ROOT/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT/release"
ZIP="$RELEASE_DIR/빼꼼-인덱스-$VERSION.zip"

"$ROOT/build.sh" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

ditto -c -k --keepParent "$APP" "$ZIP"

cat > "$RELEASE_DIR/README-설치.txt" <<TXT
빼꼼 인덱스 $VERSION

1. zip 파일 압축을 풉니다.
2. "빼꼼 인덱스.app"을 Applications 폴더로 옮깁니다.
3. 처음 실행 시 macOS 경고가 보이면 앱을 우클릭한 뒤 "열기"를 선택합니다.

메모 데이터 위치:
~/Library/Application Support/BeKkomIndex/memos.json
TXT

echo "$ZIP"
