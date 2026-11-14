# 마실 시퀀스 다이어그램

| # | 시나리오 | 관련 요구사항 |
|---|---|---|
| SD-01 | 앱 시작과 버전 체크 | APP-01, APP-06, APP-09 |
| SD-02 | 위치 브리지와 근접 검색 | APP-02, APP-03, MAP-01, MAP-05 |
| SD-03 | 외부 길찾기 | APP-04, APP-07 |
| SD-04 | 데이터 임포트와 정규화 | DATA-01~16 |
| SD-05 | 정규화 이슈 검수 (매핑 사전 등록) | DATA-12, DATA-13, ADM-03 |
| SD-06 | 변경 요청 승인 반영 | CR-03, DATA-11 |
| SD-07 | 댓글 신고와 사용자 차단 | UGC-02~05 |
| SD-08 | 계정 삭제 (IdP 재인증, 연결 해제) | USR-03 |
| SD-09 | OAuth 로그인·자동 가입 (앱) | USR-01, USR-02, APP-12, STO-04 |
| SD-10 | OAuth 로그인 (일반 웹 브라우저) | USR-04 |
| SD-11 | 토큰 갱신 (Refresh 회전) | USR-02, NFR-05 |
| SD-12 | 일일 자동 갱신 (다운로드, 사전 검증, 무중단 반영) | DATA-15, DATA-18~23 |
| SD-13 | 무중단 배포 | OPS-01~04, OPS-06 |
| SD-14 | 점검 모드 | OPS-05, ADM-06 |

> SD-04는 정규화 처리 자체(행 단위)를 보여주고, SD-12는 그 바깥의 일일 실행 흐름(락, 다운로드, 검증, 누락 처리, 알림)을 보여준다.

---

## SD-01. 앱 시작과 버전 체크

```mermaid
sequenceDiagram
    autonumber
    actor U as 사용자
    participant App as MashilApp
    participant SC as StartupController
    participant Net as ConnectivityService
    participant API as Mashil.Api
    participant Shell as WebShellScreen
    participant Web as Mashil-web

    U->>App: 앱 실행
    App->>SC: run()
    SC->>Net: isOnline()
    alt 오프라인
        Net-->>SC: false
        SC-->>App: Offline
        App-->>U: ErrorScreen (재시도)
    else 온라인
        Net-->>SC: true
        SC->>API: GET /api/app/version?platform=ios
        API-->>SC: minSupported, latest, storeUrl
        alt 현재 버전 < minSupported
            SC-->>App: ForceUpdate
            App-->>U: UpdateDialog(force) - 스토어 이동만 가능
        else 현재 버전 < latest
            SC-->>App: SoftUpdate
            App-->>U: UpdateDialog(나중에 가능)
            App->>Shell: 표시
        else 최신
            SC-->>App: Ok
            App->>Shell: 표시
        end
        Shell->>Web: loadRequest(webBaseUrl)
        alt 로드 실패 (onWebResourceError)
            Shell-->>U: ErrorScreen (재시도)
        else 성공
            Web-->>Shell: onPageFinished
            Shell-->>U: 지도 화면
        end
    end
```

## SD-02. 위치 브리지와 근접 검색

```mermaid
sequenceDiagram
    autonumber
    actor U as 사용자
    participant Web as Mashil-web (WebView)
    participant Br as MashilJsBridge
    participant Loc as LocationService
    participant OS as OS 위치 서비스
    participant API as Mashil.Api
    participant OSS as OpenStatusService
    participant DB as Postgres/PostGIS

    U->>Web: 홈 진입
    Web->>Web: nativeBridge.isAvailable()
    alt 앱 환경
        Web->>Br: postMessage(getLocation)
        Br->>Loc: ensurePermission()
        Loc->>OS: 권한 확인 / 요청
        alt 허용
            OS-->>Loc: granted
            Loc->>OS: getCurrentPosition()
            OS-->>Loc: lat, lng, accuracy
            Loc-->>Br: LatLng
            Br-->>Web: __mashilBridgeReply(ok, lat, lng)
        else 거부
            OS-->>Loc: denied / deniedForever
            Loc-->>Br: null
            Br-->>Web: __mashilBridgeReply(ok=false, reason)
            Web-->>U: "기본 위치로 보기" / 설정 열기 안내
        end
    else 일반 브라우저
        Web->>Web: navigator.geolocation 폴백
    end

    Web->>API: GET /api/toilets/near?lat&lng&radiusM&limit
    Note over API: 위경도는 쿼리에만 사용, 저장 및 로그 기록 안 함 (NFR-06)
    API->>DB: ST_DWithin(location, point, radius) AND status='Active'
    DB-->>API: toilets + opening_schedules
    loop 각 화장실
        API->>OSS: Evaluate(toilet, nowKst)
        OSS-->>API: OpenStatus
    end
    API-->>Web: ToiletNear[] (schedule, openStatus 포함)
    Web-->>U: 지도 마커 + 개방 상태 뱃지
```

## SD-03. 외부 길찾기

```mermaid
sequenceDiagram
    autonumber
    actor U as 사용자
    participant Web as Mashil-web (WebView)
    participant Br as MashilJsBridge
    participant L as ExternalLauncher
    participant OS as OS

    U->>Web: 상세 화면 "길찾기" 탭
    Web->>Br: postMessage(openDirections, lat, lng, name)
    Br->>L: openDirections(dest, name)
    L->>OS: canLaunch(kakaomap://route?ep=lat,lng&by=FOOT)
    alt 카카오맵 설치됨
        L->>OS: launch(kakaomap 딥링크)
        L-->>Br: app=kakaomap
    else 미설치
        L->>OS: launch(카카오맵 웹 길찾기 URL, 외부 브라우저)
        L-->>Br: app=web
    end
    Br-->>Web: __mashilBridgeReply(ok)
```

## SD-04. 데이터 임포트와 정규화

```mermaid
sequenceDiagram
    autonumber
    actor A as 관리자 / 스케줄러
    participant R as ImportRunner
    participant Ad as PublicToiletStdCsvAdapter
    participant P as NormalizationPipeline
    participant OH as OpeningHoursParser
    participant VM as IValueMappingLookup
    participant M as ToiletMerger
    participant DB as Postgres

    A->>R: RunAsync("PUBLIC_TOILET_STD", file, force=false)
    R->>R: SHA-256(file)
    R->>DB: import_runs 에서 동일 해시 조회
    alt 이미 처리됨 and force=false
        DB-->>R: 존재
        R-->>A: Skipped (동일 파일)
    else 신규
        R->>DB: INSERT import_runs(status=Running)
        loop 행마다 (500건 배치)
            Ad->>Ad: CP949 디코딩, 헤더 매핑
            Ad-->>R: SourceRow
            R->>DB: raw_toilet_records 조회 (source_id, source_key)
            alt row_hash 동일 and normalizer_version 동일
                R->>R: unchanged++ (last_seen_at 만 갱신)
            else 신규 또는 변경
                R->>DB: UPSERT raw_toilet_records(payload, row_hash)
                R->>P: Normalize(row)
                P->>P: BasicField, Kind, FacilityCount, YesNo, Phone 스텝
                P->>VM: TryGet("opening_hours", raw)
                alt 매핑 사전 hit
                    VM-->>P: canonical schedule
                else miss
                    P->>OH: Parse(openHours, detail)
                    OH-->>P: ParseOutcome(status, slots, issue?)
                end
                P->>P: CoordinateStep (범위, 뒤바뀜, 0값)
                P-->>R: NormalizationResult(draft, issues)
                R->>M: Merge(draft, existingToilet)
                M->>M: OverrideResolver 로 필드별 우선값 적용
                M-->>R: MergeOutcome
                R->>DB: UPSERT toilets, REPLACE opening_schedules(origin=Parsed)
                R->>DB: INSERT normalization_issues (기존 Open 이슈는 중복 생성 안 함)
            end
        end
        R->>DB: 이번 run 에 없던 raw 레코드 consecutive_missing++
        R->>DB: 기준 초과 시 toilets.status = Missing / Removed
        R->>DB: UPDATE import_runs(status=Succeeded, stats, field_stats)
        R-->>A: ImportReport (필드별 성공률, 미해결 Top 50)
    end

    Note over DB: 이후 GeocodeWorker 가 location 없는 행을 처리하고<br/>결과를 toilet_overrides(source=Geocode) 에 저장
```

## SD-05. 정규화 이슈 검수 (매핑 사전 등록)

```mermaid
sequenceDiagram
    autonumber
    actor A as 관리자
    participant UI as 관리자 화면 (웹)
    participant API as Mashil.Api
    participant S as NormalizationIssueService
    participant P as NormalizationPipeline
    participant O as ToiletOverrideService
    participant DB as Postgres

    A->>UI: 정규화 이슈 큐 열기 (type=Unparsed, field=opening_hours)
    UI->>API: GET /api/admin/normalization-issues?status=Open&groupBy=raw_value
    API->>DB: 원본 값별 그룹 집계
    DB-->>API: raw_value, count, sample
    API-->>UI: 목록 (예: "평일9시간(09:00~18:00)" 2건)
    A->>UI: 표준 스케줄 입력 (MON~FRI 09:00~18:00) + "같은 값 일괄 적용"
    UI->>API: POST /api/admin/normalization-issues/{id}/resolve
    API->>S: ResolveWithMappingAsync(issueId, canonical, applyToSameRaw=true)
    S->>DB: INSERT value_mappings(field, raw_value_normalized, canonical)
    S->>DB: SELECT raw_toilet_records WHERE 같은 원본 값
    loop 대상 레코드
        S->>P: Normalize(raw.payload) - 매핑 사전 hit
        P-->>S: NormalizationResult
        S->>O: RecomputeAsync(toiletId)
        O->>DB: UPDATE toilets, REPLACE opening_schedules
    end
    S->>DB: UPDATE normalization_issues SET status=Resolved, resolved_by_mapping_id
    S-->>API: 처리 건수
    API-->>UI: "N건 해결됨"
```

## SD-06. 변경 요청 승인 반영

```mermaid
sequenceDiagram
    autonumber
    actor A as 관리자
    participant API as Mashil.Api
    participant CR as ChangeRequestService
    participant O as ToiletOverrideService
    participant DB as Postgres

    A->>API: PATCH /api/admin/change-requests/{id} (approve=true, note)
    API->>CR: ApproveAsync(id, adminId, note)
    CR->>DB: BEGIN, SELECT change_requests FOR UPDATE
    alt status != Pending
        CR-->>API: 409 Conflict
    else Pending
        alt kind = Edit
            loop payload 의 변경 필드
                CR->>O: UpsertAsync(toiletId, field, value, ChangeRequest, crId)
                O->>DB: 기존 동일 source 활성 오버라이드 비활성화 후 INSERT
            end
            CR->>O: RecomputeAsync(toiletId)
            O->>DB: UPDATE toilets (우선순위 규칙 적용)
        else kind = Add
            CR->>DB: INSERT toilets(origin=UserSubmitted, management_no="USR-"+crId)
            CR->>DB: INSERT toilet_overrides(전 필드, source=ChangeRequest)
        else kind = Delete
            CR->>O: UpsertAsync(toiletId, "status", "Removed", ChangeRequest, crId)
            CR->>O: RecomputeAsync(toiletId)
        end
        CR->>DB: UPDATE change_requests SET status=Approved, reviewed_by, reviewed_at
        CR->>DB: COMMIT
        CR-->>API: 204
    end
    API-->>A: 결과

    Note over DB: 이후 재임포트 시 ToiletMerger 가 오버라이드를 다시 적용하므로<br/>승인된 수정이 유지된다 (G1 해소)
```

## SD-07. 댓글 신고와 사용자 차단

```mermaid
sequenceDiagram
    autonumber
    actor U as 회원
    actor A as 관리자
    participant Web as Mashil-web
    participant API as Mashil.Api
    participant M as ModerationService
    participant DB as Postgres

    U->>Web: 댓글 "신고" (사유 선택)
    Web->>API: POST /api/comments/{id}/reports (reason, detail)
    API->>M: ReportCommentAsync
    M->>DB: INSERT comment_reports (UK comment_id+reporter_id)
    alt 중복 신고
        DB-->>M: unique violation
        M-->>API: 409
    else 신규
        M->>DB: UPDATE comments SET report_count = report_count + 1
        opt report_count >= 자동숨김 임계값
            M->>DB: UPDATE comments SET hidden = true
        end
        M-->>API: 201
    end
    API-->>Web: 결과 토스트

    U->>Web: 작성자 "차단"
    Web->>API: POST /api/users/{userId}/block
    API->>M: BlockUserAsync(me, userId)
    M->>DB: INSERT user_blocks
    API-->>Web: 204
    Web->>API: GET /api/toilets/{id}/comments
    API->>DB: hidden=false AND user_id NOT IN (내 차단 목록)
    API-->>Web: 필터링된 댓글

    A->>Web: 신고 큐 확인
    Web->>API: GET /api/admin/comment-reports?status=Open
    A->>Web: 숨김 처리
    Web->>API: PATCH /api/admin/comments/{id} (hidden=true)
    API->>M: SetHiddenAsync
    M->>DB: UPDATE comments, comment_reports SET status=Actioned
```

## SD-08. 계정 삭제

```mermaid
sequenceDiagram
    autonumber
    actor U as 회원
    participant Web as Mashil-web (설정)
    participant API as Mashil.Api
    participant AS as AccountService
    participant DB as Postgres

    participant Br as MashilJsBridge / 네이티브 SDK
    participant V as IIdTokenVerifier
    participant IdP as IdP (Google/Kakao/Apple)

    U->>Web: 설정에서 "계정 삭제"
    Web-->>U: 확인 다이얼로그 (삭제되는 정보 안내)
    U->>Web: 확인
    Note over Web,Br: 비밀번호 대신 가입한 IdP로 재인증
    Web->>Br: signIn(provider, nonce)
    Br-->>Web: idToken / accessToken / authorizationCode
    Web->>API: DELETE /api/auth/me (provider, credential, nonce)
    API->>AS: DeleteAccountAsync(userId, provider, credential)
    AS->>V: VerifyAsync(credential, nonce)
    V-->>AS: VerifiedIdentity(subject)
    alt subject 가 내 user_identities 와 불일치
        AS-->>API: 403
    else 일치
        AS->>V: RevokeAsync(identity)
        alt Kakao
            V->>IdP: POST /v1/user/unlink (Admin 키, target_id)
        else Apple
            V->>IdP: POST /auth/revoke (저장된 refresh token 복호화)
        else Google
            V->>IdP: POST /revoke (선택)
        end
        IdP-->>V: 200
        AS->>DB: BEGIN
        AS->>DB: UPDATE user_profiles SET email=null, display_name=null, status=Deleted, deleted_at=now()
        AS->>DB: DELETE user_identities, refresh_tokens WHERE user_id
        AS->>DB: DELETE user_blocks WHERE blocker_id=userId OR blocked_id=userId
        Note over AS,DB: 평점과 댓글은 유지하되 "탈퇴한 사용자"로 표시<br/>(정책은 개인정보처리방침과 일치시킬 것)
        AS->>DB: COMMIT
        AS-->>API: 204
    end
    API-->>Web: 204
    Web->>Br: signOut(provider)
    Web->>Web: 로컬 토큰 삭제
    Web-->>U: 로그아웃 상태로 홈 이동

    Note over V,IdP: revoke 가 실패하면 탈퇴는 진행하고<br/>재시도 큐에 넣는다 (사용자를 막지 않음)
```

## SD-09. OAuth 로그인·자동 가입 (앱)

```mermaid
sequenceDiagram
    autonumber
    actor U as 사용자
    participant Web as Mashil-web (WebView)
    participant Br as MashilJsBridge
    participant SA as SocialAuthService
    participant IdP as IdP SDK (Google/Kakao/Apple)
    participant API as Mashil.Api
    participant LS as OAuthLoginService
    participant V as IIdTokenVerifier
    participant DB as Postgres

    U->>Web: 로그인 화면
    Web->>Br: getAppInfo()
    Br-->>Web: providers (iOS 면 apple 포함)
    Web-->>U: Google / Kakao / (Apple) 버튼
    U->>Web: "카카오로 시작하기"
    Web->>API: GET /api/auth/nonce
    API-->>Web: nonce (5분 유효, 1회용)
    Web->>Br: postMessage(signIn, provider=kakao, nonce)
    Br->>SA: signIn(kakao, nonce)
    SA->>IdP: 카카오톡 앱 로그인 (없으면 카카오계정 웹 로그인)
    alt 사용자 취소
        IdP-->>SA: cancelled
        SA-->>Br: 취소
        Br-->>Web: ok=false, reason=cancelled
    else 성공
        IdP-->>SA: idToken / accessToken
        SA-->>Br: SocialCredential
        Br-->>Web: __mashilBridgeReply(ok, credential)
        Web->>API: POST /api/auth/oauth/kakao (credential, nonce, device=ios)
        API->>LS: SignInAsync(Kakao, credential, nonce)
        LS->>V: VerifyAsync(credential, nonce)
        V->>V: 서명(JWKS) 또는 토큰정보 API, iss, aud, exp, nonce 검증
        alt 검증 실패
            V-->>LS: 실패
            LS-->>API: 401
        else 검증 성공
            V-->>LS: VerifiedIdentity(subject, nickname, email?)
            LS->>DB: SELECT user_identities WHERE provider=Kakao AND provider_subject=subject
            alt 기존 사용자
                LS->>DB: UPDATE last_login_at, last_used_at
            else 신규 사용자 (자동 가입)
                LS->>DB: INSERT user_profiles(display_name=nickname)
                LS->>DB: INSERT user_identities(provider, subject)
            end
            LS->>DB: INSERT refresh_tokens(hash, family_id)
            LS-->>API: LoginResult(tokens, isNewUser, consentRequired)
        end
        API-->>Web: accessToken, refreshToken, consentRequired
        opt consentRequired (신규 또는 약관 버전 변경)
            Web-->>U: 약관 / 개인정보처리방침 / 위치기반서비스 약관 동의 화면
            U->>Web: 동의
            Web->>API: POST /api/auth/consents (doc_type, version)
            API->>DB: INSERT user_consents
        end
        Web-->>U: 로그인 완료, 이전 화면 복귀
    end
```

## SD-10. OAuth 로그인 (일반 웹 브라우저)

```mermaid
sequenceDiagram
    autonumber
    actor U as 사용자
    participant Web as Mashil-web (브라우저)
    participant IdP as Google GIS / Kakao JS SDK
    participant API as Mashil.Api

    U->>Web: "Google로 시작하기"
    Web->>API: GET /api/auth/nonce
    API-->>Web: nonce
    Web->>IdP: 로그인 팝업 또는 리다이렉트 (client_id, nonce, redirect_uri)
    U->>IdP: 계정 선택 / 동의
    IdP-->>Web: idToken (Google) 또는 인가 코드 (Kakao, redirect_uri 로)
    alt Kakao 인가 코드
        Web->>API: POST /api/auth/oauth/kakao (code, redirect_uri, nonce)
        API->>IdP: 서버에서 코드를 토큰으로 교환 (client secret)
    else Google idToken
        Web->>API: POST /api/auth/oauth/google (idToken, nonce)
    end
    Note over API: 이후 검증과 가입·로그인 처리는 SD-09 와 동일
    API-->>Web: accessToken, refreshToken, consentRequired
```

## SD-11. 토큰 갱신 (Refresh 회전)

```mermaid
sequenceDiagram
    autonumber
    participant Web as Mashil-web
    participant API as Mashil.Api
    participant TI as TokenIssuer
    participant DB as Postgres

    Web->>API: GET /api/... (만료된 accessToken)
    API-->>Web: 401 (token_expired)
    Web->>API: POST /api/auth/refresh (refreshToken)
    API->>TI: RotateAsync(refreshToken)
    TI->>DB: SELECT refresh_tokens WHERE token_hash
    alt 존재하고 활성
        TI->>DB: UPDATE revoked_at=now() (기존), INSERT 새 토큰 (같은 family_id)
        TI-->>API: 새 TokenPair
        API-->>Web: accessToken, refreshToken
        Web->>API: 원래 요청 재시도
    else 이미 폐기된 토큰 재사용 (탈취 의심)
        TI->>DB: UPDATE family_id 전체 revoked_at=now()
        TI-->>API: 실패
        API-->>Web: 401 (reauth_required)
        Web->>Web: 로그아웃 처리, 로그인 화면
    else 없음 또는 만료
        API-->>Web: 401 (reauth_required)
    end
```

## SD-12. 일일 자동 갱신

```mermaid
sequenceDiagram
    autonumber
    participant Cron as Worker 스케줄러 (KST 04:30)
    participant J as DailyImportJob
    participant Lk as ImportLock
    participant F as LocalDataFileFetcher
    participant LD as LOCALDATA
    participant PV as ImportPreValidator
    participant R as ImportRunner
    participant MR as MissingRecordProcessor
    participant DB as Postgres
    participant AL as IAlertNotifier
    participant API as Mashil.Api (서비스 중)

    Cron->>J: ExecuteAsync()
    J->>Lk: ReapAbandonedAsync(30분)
    J->>Lk: TryAcquireAsync(LOCALDATA_PUBLIC_RESTROOM)
    alt 락 획득 실패
        Lk-->>J: null
        J-->>Cron: 종료 (이미 실행 중)
    else 획득
        J->>F: FetchAsync(source)
        loop 최대 3회 (지수 백오프)
            F->>LD: 전국파일 다운로드 (방식은 Q10 확인 후 확정)
            LD-->>F: 파일 또는 오류
        end
        alt 다운로드 실패
            J->>DB: INSERT import_runs(status=Failed)
            J->>AL: Notify(Error, "다운로드 실패")
        else 성공
            F-->>J: FetchedFile(sha256, size)
            J->>DB: 직전 성공 import_run 조회
            alt sha256 동일
                J->>DB: INSERT import_runs(status=Skipped)
            else 새 파일
                J->>PV: ValidateAsync(file, source, lastSuccess)
                PV->>PV: 헤더, 크기 ±30%, 행 수 -5%, 손상률 1% 검사
                alt 검증 거부
                    PV-->>J: Rejected(reason)
                    J->>DB: INSERT import_runs(status=Rejected, reject_reason)
                    J->>AL: Notify(Warning, "검증 거부 - 기존 데이터 유지")
                else 통과
                    J->>R: RunAsync(source, file, Scheduled)
                    R->>DB: INSERT import_runs(status=Running)
                    loop 500건 배치
                        R->>R: 변경 행만 정규화 (SD-04)
                        R->>DB: BEGIN - toilets UPDATE + opening_schedules 교체 - COMMIT
                        R->>Lk: HeartbeatAsync(runId)
                        API->>DB: SELECT near (MVCC, 막히지 않음)
                    end
                    R->>MR: ProcessAsync(run)
                    MR->>DB: last_seen_at < run.started_at 인 raw 의 consecutive_missing++
                    alt Removed 후보 > 전체의 1%
                        MR-->>R: PendingApproval
                        R->>DB: UPDATE import_runs(status=PendingApproval)
                        R->>AL: Notify(Warning, "대량 삭제 보류 - 관리자 승인 필요")
                    else 정상
                        MR->>DB: Missing / Removed 반영
                        R->>DB: UPDATE import_runs(status=Succeeded, stats)
                    end
                end
            end
        end
        J->>Lk: 락 해제
    end

    Note over AL: 별도 감시 - 마지막 Succeeded 가 48시간 넘으면 경고 (NFR-14)
```

## SD-13. 무중단 배포

```mermaid
sequenceDiagram
    autonumber
    actor Dev as 개발자
    participant CI as CI/CD
    participant DB as Postgres
    participant LB as 리버스 프록시 / LB
    participant A1 as API v1 (기존 x2)
    participant A2 as API v2 (신규 x2)
    participant W as Worker
    participant CDN as 웹 정적 호스팅

    Dev->>CI: main 브랜치 머지 (태그)
    CI->>CI: 빌드, 단위 테스트, 파서 회귀 코퍼스
    CI->>DB: migrations bundle 실행 (expand 만)
    Note over DB,A1: expand 스키마는 v1 코드와도 호환
    CI->>A2: v2 인스턴스 기동
    loop readiness 통과까지
        LB->>A2: GET /healthz/ready (DB 연결 확인)
    end
    LB->>LB: 트래픽을 v2 로 전환
    LB->>A1: 신규 요청 중단
    CI->>A1: SIGTERM
    A1->>A1: 진행 중 요청 마무리 (최대 30초) 후 종료
    CI->>W: Worker 교체
    Note over W: 실행 중이던 임포트가 끊겨도 멱등성과<br/>Abandoned 정리로 다음 실행에서 복구
    CI->>CDN: 새 웹 빌드 업로드 (이전 해시 에셋 7일 보존)
    CI->>CDN: index.html 원자적 교체 (no-cache)
    CI->>LB: 스모크 테스트 (near, 상세, 로그인)
    alt 실패
        CI->>LB: 트래픽을 v1 이미지로 롤백
        CI->>CDN: 이전 index.html 복원
    end
    Note over CI,DB: contract 마이그레이션 (이전 컬럼 삭제) 은<br/>다음 릴리스에서 별도로 실행
```

## SD-14. 점검 모드

```mermaid
sequenceDiagram
    autonumber
    actor Adm as 관리자
    actor U as 사용자
    participant App as Flutter 셸
    participant St as 상태 엔드포인트 (API + 정적 폴백)
    participant API as Mashil.Api
    participant DB as Postgres

    Adm->>API: PUT /api/admin/service-status (maintenance, read_only, message, until)
    API->>DB: UPDATE service_status
    API->>St: 정적 status.json 갱신 (API 다운 대비)

    U->>App: 앱 실행
    App->>St: GET /api/app/status
    alt API 응답 없음
        App->>St: GET 정적 status.json
    end
    St-->>App: maintenance, read_only, message
    alt maintenance=true, read_only=false
        App-->>U: 네이티브 점검 화면 (message, until)
    else read_only=true
        App-->>U: 정상 화면 + "일부 기능 점검 중" 배너
        U->>API: POST 댓글
        API-->>U: 503 (읽기 전용)
    else 정상
        App-->>U: 정상 화면
    end
```
