#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="쪼꼼 인덱스"
VERSION="1.2.10"
APP="$ROOT/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT/release"
ZIP="$RELEASE_DIR/jjokkom-index-$VERSION.zip"

"$ROOT/build.sh" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

ditto -c -k --keepParent "$APP" "$ZIP"
cp "$ROOT/install-login-item.sh" "$RELEASE_DIR/install-login-item.sh"
cp "$ROOT/uninstall-login-item.sh" "$RELEASE_DIR/uninstall-login-item.sh"
chmod +x "$RELEASE_DIR/install-login-item.sh" "$RELEASE_DIR/uninstall-login-item.sh"

cat > "$RELEASE_DIR/README-설치.txt" <<TXT
쪼꼼 인덱스 $VERSION

1. zip 파일 압축을 풉니다.
2. "쪼꼼 인덱스.app"을 Applications 폴더로 옮깁니다.
3. 처음 실행 시 macOS 경고가 보이면 앱을 우클릭한 뒤 "열기"를 선택합니다.

주의:
iCloud Drive 안에서 앱을 바로 실행하지 마세요.
압축을 iCloud 폴더에서 풀었다면 "쪼꼼 인덱스.app"을 Applications 폴더로 먼저 옮긴 뒤 실행하세요.
동기화 중에는 앱이 안 열리거나 "쪼꼼 인덱스 2" 같은 중복 항목이 생길 수 있습니다.

로그인 시 자동으로 열기:
install-login-item.sh 실행

자동 열기 해제:
uninstall-login-item.sh 실행

메모 데이터 위치:
~/Library/Application Support/JjokkomIndex/memos.json
TXT

echo "$ZIP"
