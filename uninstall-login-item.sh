#!/usr/bin/env bash
set -euo pipefail

LABEL="app.jjokkom.index.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST"
fi

echo "쪼꼼 인덱스 로그인 자동 열기 설정이 해제되었습니다."
