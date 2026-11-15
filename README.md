# Mashil-app

마실 웹(`D:\code\Mashil-web`)을 Flutter로 감싼 모바일 앱과, 화장실 공공데이터 표준화 작업의 설계 문서를 둔다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/01-requirements.md](docs/01-requirements.md) | 요구사항 정의서: 기능·비기능, 데이터 표준, 법률·스토어 요건, 현행 갭, 마일스톤, 미결 사항 |
| [docs/02-erd.md](docs/02-erd.md) | ERD (목표 스키마), 제약·인덱스, 표준 값 결정 규칙 |
| [docs/03-class-diagram.md](docs/03-class-diagram.md) | 클래스 다이어그램: 도메인, 정규화 파이프라인, API 서비스, Flutter 셸 + JS 브리지 프로토콜 |
| [docs/04-sequence-diagrams.md](docs/04-sequence-diagrams.md) | 시퀀스 다이어그램 14종 |
| [docs/05-operations.md](docs/05-operations.md) | 운영 설계: 일일 데이터 갱신, 무중단 배포, 점검 모드 |
| [docs/06-data-profile.md](docs/06-data-profile.md) | LOCALDATA 전국파일 프로파일링 결과 (P0) |
| [docs/07-ui-design.md](docs/07-ui-design.md) | UI 디자인 결정: 타일 방향, 색 토큰(라이트/다크), 서체, 앱 아이콘 사양 |
| [docs/08-infrastructure.md](docs/08-infrastructure.md) | 배포 인프라 설계: 구성도, 네트워크·보안, 배포 파이프라인, 백업·복구, 감시, 출시 체크리스트 |

다이어그램은 Mermaid로 작성했다. VS Code(Markdown Preview Mermaid Support 확장)나 GitHub에서 렌더링된다.

## 관련 저장소

- 웹 프런트: `D:\code\Mashil-web` (Vite + React 19 + MUI)
- 백엔드: `D:\code\C#\Mashil` (ASP.NET Core 10 + EF Core + PostGIS, `tools/Mashil.CsvImport`)

## 개발 환경

Flutter **3.47 이상** (개발·CI 는 3.50.0, Dart 3.14). 그보다 낮으면 `flutter pub get` 이 "Flutter SDK version" 오류로 멈춘다. `flutter upgrade` 로 올리고, iOS 는 그다음 `cd app/ios && pod install`.

## 사용한 오픈소스 (Flutter 앱, `app/`)

버전은 `app/pubspec.lock` 에 실제로 받은 것 (2026-11-16). 라이선스는 각 패키지의 LICENSE 파일 기준.

### 앱에 들어가는 것

| 패키지 | 버전 | 라이선스 | 쓰는 곳 |
|---|---|---|---|
| [Flutter SDK](https://github.com/flutter/flutter) (+ `flutter_localizations`) | 3.50.0 | BSD-3-Clause | 앱 프레임워크, 다국어 |
| [intl](https://pub.dev/packages/intl) | 0.20.3 | BSD-3-Clause | 다국어 문구 (ARB) |
| [material_ui](https://pub.dev/packages/material_ui) | 1.11.0 | BSD-3-Clause | 네이티브 화면 위젯 |
| [cupertino_icons](https://pub.dev/packages/cupertino_icons) | 1.0.9 | MIT | iOS 아이콘 |
| [webview_flutter](https://pub.dev/packages/webview_flutter) (+ `_android` 4.14.1, `_wkwebview` 3.27.2) | 4.14.1 | BSD-3-Clause | 마실 웹을 띄우는 웹뷰 |
| [geolocator](https://pub.dev/packages/geolocator) | 14.0.1 | MIT | 현재 위치 (JS 브리지 `getLocation`) |
| [permission_handler](https://pub.dev/packages/permission_handler) | 13.0.2 | MIT | 위치 권한, 설정 앱 열기 |
| [url_launcher](https://pub.dev/packages/url_launcher) | 6.3.3 | BSD-3-Clause | 카카오맵 길찾기, 전화, 외부 링크 |
| [connectivity_plus](https://pub.dev/packages/connectivity_plus) | 7.3.2 | BSD-3-Clause | 오프라인 화면, 다시 연결되면 재시도 |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | 10.2.2 | BSD-3-Clause | 앱 버전 (업데이트 안내) |
| [kakao_flutter_sdk_user](https://pub.dev/packages/kakao_flutter_sdk_user) | 2.1.0 | Apache-2.0 | 카카오 로그인 |
| [google_sign_in](https://pub.dev/packages/google_sign_in) | 7.2.0 | BSD-3-Clause | Google 로그인 |
| [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) | 8.2.0 | MIT | Apple 로그인 |
| [http](https://pub.dev/packages/http) | 1.6.0 | BSD-3-Clause | 버전 확인 API 호출 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 2.5.6 | BSD-3-Clause | 앱 언어 저장 |
| [crypto](https://pub.dev/packages/crypto) | 3.0.8 | BSD-3-Clause | 로그인 nonce 해시 |

### 개발 도구

| 패키지 | 버전 | 라이선스 | 쓰는 곳 |
|---|---|---|---|
| [flutter_lints](https://pub.dev/packages/flutter_lints) | 6.0.0 | BSD-3-Clause | `flutter analyze` 규칙 |
| `flutter_test` (Flutter SDK) | 3.50.0 | BSD-3-Clause | 단위 테스트 |
| GitHub Actions (`actions/checkout`, `subosito/flutter-action`) | — | MIT | CI (`.github/workflows/ci.yml`) |
| [Mermaid](https://github.com/mermaid-js/mermaid) | — | MIT | `docs/` 다이어그램 (GitHub 이 렌더링) |

앱이 띄우는 웹과 백엔드의 오픈소스는 각 저장소 README 에 있다 (Mashil-Front, Mashil-Back).

## 외부 서비스

| 항목 | 쓰는 곳 | 조건 |
|---|---|---|
| Kakao 로그인, Google 로그인, Sign in with Apple | 소셜 로그인 | 각 제공자 약관. 앱 키는 `env/*.json`, `ios/Flutter/Secrets.xcconfig` (저장소에 넣지 않음) |
| [카카오맵](https://map.kakao.com/) 앱·웹 | 길찾기 | 카카오맵 이용약관 |

