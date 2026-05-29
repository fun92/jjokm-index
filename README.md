# 쪼꼼 인덱스

맥 화면 오른쪽에 작은 하트 버튼으로 숨어 있다가, 클릭하면 노란 메모지가 튀어나오는 사이드 메모 앱입니다.

## 주요 기능

- 접힌 상태에서는 작은 `💛` 버튼만 표시
- 오른쪽 가장자리 근처로 마우스를 가져가면 하트가 선명하게 표시
- 메뉴바의 `💛`로 언제든 다시 열기
- 메뉴바에서 로그인 시 자동 열기 켜기/끄기
- 메뉴바에서 왼쪽/오른쪽 위치 전환
- 메뉴바에서 메모 고정 켜기/끄기
- 하트 버튼을 위아래로 드래그해서 위치 조정
- 여러 메모 탭: 선택한 탭만 살짝 넓어짐
- 메모 자동 저장
- 굵게/기울임/밑줄/글머리 서식
- macOS 색상 선택창으로 글자 색 지정
- `Aa` 버튼으로 글자 크기 슬라이더 열기
- 메모 추가/삭제

메모 데이터는 `~/Library/Application Support/JjokkomIndex/memos.json`에 저장됩니다.

## 설치

GitHub Releases에서 최신 `.zip` 파일을 내려받은 뒤 압축을 풀고 `쪼꼼 인덱스.app`을 `Applications` 폴더로 옮기면 됩니다.

처음 실행할 때 macOS가 경고를 보이면 앱을 우클릭한 뒤 `열기`를 선택하세요. 현재 배포판은 개발자 공증 전이라 이 안내가 필요할 수 있습니다.

압축을 iCloud Drive 안에서 풀었다면 앱을 그 자리에서 바로 실행하지 말고 반드시 `Applications` 폴더로 옮긴 뒤 실행하세요. `.app`은 폴더처럼 생긴 번들이라 iCloud 동기화 중에는 열리지 않거나 `쪼꼼 인덱스 2` 같은 중복 항목이 생길 수 있습니다.

## 직접 빌드

```bash
./build.sh
open "dist/쪼꼼 인덱스.app"
```

iCloud/File Provider 폴더에서 앱 실행이 막히면 임시 로컬 폴더에서 실행할 수 있습니다.

```bash
./run-local.sh
```

## 릴리즈 패키지 만들기

```bash
./package.sh
```

결과물은 `release/` 폴더에 생성됩니다.

## 로그인 시 자동 열기

앱을 `Applications` 폴더로 옮긴 뒤 아래 스크립트를 실행하면 로그인할 때 자동으로 열립니다.

```bash
./install-login-item.sh
```

해제하려면 아래 스크립트를 실행합니다.

```bash
./uninstall-login-item.sh
```

## 배포 메모

- 현재 빌드는 ad-hoc 서명입니다.
- 경고 없는 공개 배포를 하려면 Apple Developer ID 서명과 notarization이 필요합니다.
- GitHub Releases에는 `release/jjokkom-index-1.2.1.zip` 파일을 올리면 됩니다.
