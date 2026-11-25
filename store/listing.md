# Play 스토어 등록 정보 (2026-11-25 점검판)

Play 글자 수 제한: 앱 이름 30자, 간단한 설명 80자, 자세한 설명 4,000자.

2026-11-18 초안에서 코드와 운영 데이터에 맞춰 고친 것:
- 화장실 수: "약 6만 곳" → "5만 곳이 넘는". 운영 스냅샷(`/api/toilets/snapshot`) 2026-11-25 기준 53,586곳.
- 추천: "평점과 후기" → "평점과 거리". 출시 빌드는 회원 기능이 꺼져 있어(`VITE_ACCOUNTS` 기본 off) 댓글이 보이지 않는다.
- 제보: 출시 빌드(Mashil-web `d2a5dcc`, 11-24)는 회원 기능과 함께 **제보 탭·정보 고치기 링크·제보 화면을 모두 숨긴다**. 설명에서 제보를 빼고, "이용자 제보로 바로잡아요"·"앱에서 알려 주세요"도 고쳤다. 제보 스크린샷은 지웠다.
- 위치: 제보가 없으므로 위치는 기기 밖으로 나가지 않는다 (근처 찾기는 기기 안, 서버 도보 경로 꺼짐). "서버로 보내지 않아요" 문구를 그대로 쓸 수 있다.
- 로그인: 첫 실행 로그인 화면도 이 커밋에서 없어진다. **운영 서버는 아직 11-20 버전이라 로그인 화면이 뜬다 (2026-11-25 에뮬레이터 확인). 배포 후 올린다.**
- 방향 안내: 출시 빌드는 서버 도보 경로가 꺼져 있다(`VITE_WALK_ROUTE`). 직선 방향 안내만 적는다. README 의 파란 경로 화면은 쓰지 않는다.

---

## 한국어 (기본)

### 앱 이름 (16자)
마실 - 내 주변 화장실 찾기

### 간단한 설명 (34자)
지금 열려 있는 가까운 화장실을 찾아요. 전국 5만 곳 이상.

### 자세한 설명

급할 때, 가장 가까운 화장실이 지금 열려 있는지부터 알려 드려요.

마실은 전국 공중화장실과 개방화장실 5만 곳이 넘는 곳을 지도와 목록으로 보여 주는 앱이에요. 행정안전부 공공데이터(LOCALDATA 공중화장실 정보)를 매일 받아 정리해요.

■ 지금 열려 있는지 한눈에
· 요일과 공휴일까지 따져서 "24시간", "22:00까지", "곧 닫힘", "닫힘"으로 보여 줘요.
· 지도 핀의 모양과 색만 봐도 열림 상태를 알 수 있어요.
· 닫기까지 남은 시간도 알려 드려요.

■ 원하는 화장실만 골라서
· 지금 열린 곳, 24시간 개방
· 남자, 여자, 장애인, 어린이 시설
· 검색 반경 500m부터 5km까지
· 이름이나 주소로 검색 (두 글자부터 바로 찾아요)
· 평점과 거리를 함께 본 "지금 가기 좋은 곳" 추천

■ 가기 전에 확인하는 상세 정보
· 요일별 개방 시간과 공휴일 개방 여부
· 남녀 칸 수, 소변기 수, 장애인·어린이용 시설
· 비상벨, 입구 CCTV, 기저귀 교환대
· 주소 복사, 전화 걸기, 공유하기 (카카오톡 등)

■ 가는 길
· 앱 안에서 화장실 방향과 거리, 걷는 시간을 바로 확인
· 카카오맵으로 도보·자동차 길찾기

■ 별점으로 함께
· 다녀온 화장실에 별점을 남겨 다른 사람에게 알려 주세요. 가입이나 로그인은 필요 없어요.

■ 내 위치는 내 휴대폰 안에서만
현재 위치는 휴대폰 안에서 가까운 화장실을 찾는 데만 쓰고, 서버로 보내거나 저장하지 않아요. 위치 권한을 허용하지 않아도 지도를 옮기거나 검색해서 쓸 수 있어요.

■ 누구나 편하게
· 한국어, English, 日本語, 简体中文, 繁體中文
· 다크 모드, 태블릿과 가로 화면 지원
· 화면 읽기(TalkBack) 지원

화장실 정보는 공공데이터를 바탕으로 하며 실제와 다를 수 있어요. 틀린 정보를 발견하면 문의 이메일로 알려 주세요.

---

## English

### App name (29 chars)
Mashil: Find Restrooms Nearby

### Short description (74 chars)
Find the nearest restroom that's open now. Over 50,000 across South Korea.

### Full description

When you need one fast, Mashil shows the nearest restroom that's open right now.

Mashil maps over 50,000 public and open-access restrooms across South Korea. The data comes from the Korean government's public restroom dataset (LOCALDATA), refreshed daily.

■ Open now, at a glance
· Opening hours by weekday and public holiday: "24 hours", "Open until 22:00", "Closing soon", "Closed".
· Map pins show the status by shape and color.
· See how long until it closes.

■ Only the restrooms you need
· Open now, open 24 hours
· Men's, women's, accessible and children's facilities
· Search radius from 500 m to 5 km
· Search by name or address
· "Good to go now" picks based on ratings and distance

■ Check before you go
· Opening hours for each day and holidays
· Number of stalls and urinals, accessible and children's facilities
· Emergency bell, entrance CCTV, diaper changing table
· Copy the address, call, or share

■ Getting there
· See the direction, distance and walking time in the app
· Walking or driving directions in KakaoMap

■ Rate as you go
· Leave a star rating for others. No sign-up or login needed.

■ Your location stays on your phone
Your location is only used on your phone to find nearby restrooms. It is never sent to or stored on our servers. Without location permission you can still move the map or search.

■ For everyone
· Korean, English, Japanese, Simplified and Traditional Chinese
· Dark mode, tablet and landscape layouts
· Screen reader (TalkBack) support

Restroom information is based on public data and may differ from reality. If something is wrong, please let us know by email.

---

## Play 콘솔 설정

| 항목 | 값 |
|---|---|
| 앱 카테고리 | 지도/내비게이션 (Maps & Navigation) |
| 태그 | 지도, 생활 |
| 연락처 이메일 | (정해 주세요. 약관의 문의 이메일과 같게) |
| 웹사이트 | https://toilets.ironhiro.dev (선택) |
| 개인정보처리방침 | https://toilets.ironhiro.dev/terms/Privacy |
| 광고 포함 | 아니요 (광고 SDK가 들어가는 빌드부터 "예") |
| 앱 액세스 권한 | 모든 기능을 로그인 없이 쓸 수 있음 (회원 기능 꺼짐) |
| 타겟층 | 18세 이상 (아동 대상 아님. 13세 미만을 넣으면 가족 정책 심사가 붙는다) |

### 콘텐츠 등급 설문
- 출시 빌드는 댓글·제보가 꺼져 있어 이용자끼리 글을 주고받는 기능이 없다. 별점(숫자)만 있다.
  → "사용자 간 상호작용/콘텐츠 공유": **아니요** 로 답해도 맞다. 회원·댓글을 켜는 빌드부터 "예"로 바꾼다.
- 위치 공유(다른 사용자에게 내 위치 표시): 없음.

### 데이터 보안 (Data safety) 초안
Play 기준은 "기기 밖으로 나가면 수집"이다. 위치는 기기 밖으로 나가지 않으므로 **수집 안 함**. 회원·제보를 켜는 빌드부터 위치(제보의 "내 위치로 입력"), 사용자 생성 콘텐츠, 계정 정보를 추가한다.

| 데이터 유형 | 수집 | 공유 | 선택/필수 | 목적 | 근거 |
|---|---|---|---|---|---|
| 앱 활동 > 앱 상호작용 | 예 | 아니요 | 선택 | 앱 기능 | 별점 |
| 기기 또는 기타 ID | 예 | 아니요 | 선택 | 앱 기능, 사기 방지 | 별점용 무작위 기기 키(`X-Mashil-Device`, 서버에는 해시만). 광고 ID 아님 |
| 앱 정보 및 성능 > 비정상 종료 로그, 진단 | 예 | 아니요 | 필수 | 분석(오류 해결) | Sentry. 서비스 제공업체 전송은 "공유"가 아님 |

- 전송 중 암호화: 예 (HTTPS)
- 데이터 삭제 요청 방법: 회원 기능이 꺼져 있어 계정이 없다. 별점 삭제는 문의 이메일로 받는다고 적는다.

---

## 출시 전 확인

1. **운영 서버 배포 (완료 2026-11-26, `v2026.11.25.5`, 에뮬레이터 확인)**: 웹 `d2a5dcc`, 백엔드 `7e51af4` (둘 다 11-24). 배포 전 운영은 첫 화면이 로그인이고 별점에 로그인이 필요해 이 설명과 맞지 않는다. 배포 후 데이터 지운 앱으로 첫 화면·별점·탭 구성을 다시 확인한다.
   - 회원·제보를 다시 켤 때는 제보의 "내 위치로 입력"이 좌표를 Kakao 와 서버로 보내므로, 처리방침·위치 정보 이용 안내(`Mashil-web/src/legal/documents.ts`)와 위치기반서비스 신고 여부를 먼저 다시 본다.
2. **그래픽 이미지(1024×500)**: 아직 없다. 지도 화면 + 앱 이름 한 줄 구성으로 만든다.
3. **고해상도 아이콘(512×512)**: `docs/07-ui-design.md` 앱 아이콘 사양으로 내보낸다.
4. 스크린샷: `store/screenshots/ko/` 7장, 출시 빌드로 2026-11-26 다시 찍음 (1080×1920, 하단 탭 없음, 개방 상태는 오전 10시 기준). 순서 제안: 01 지도 → 03 상세 → 07 카드·별점 → 05 방향 안내 → 06 필터 → 02 목록 → 04 시간·시설. 첫 두 장이 "지금 열린 화장실"을 보여 줘야 설치 전환이 좋다.
5. 연락처 이메일을 정하고 약관 문의 이메일과 맞춘다.
