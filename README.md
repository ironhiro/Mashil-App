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
