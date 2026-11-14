# 마실 앱 (Flutter 셸)

웹(Mashil-web)을 웹뷰로 띄우고, 웹이 할 수 없는 일을 네이티브로 처리한다 (P5, APP-01~12):
위치 권한·GPS, 카카오맵 길찾기, 뒤로가기, 오류·오프라인 화면, 외부 링크·전화, 버전 확인, **네이티브 소셜 로그인**.

웹뷰 안에서는 OAuth 를 하지 않는다 (Google 이 임베디드 웹뷰 로그인을 막음). 웹이 브리지로 `signIn` 을 부르면 앱이 SDK 로 로그인하고 토큰을 돌려준다. 웹은 그 토큰을 백엔드 `POST /api/auth/oauth/{provider}` 로 보낸다.

## 준비

- Flutter 3.50 이상 (`D:\tools\flutter`). 기존 `D:\flutter`(3.3.1)는 이 프로젝트에 쓰지 않는다
- Android SDK (Android Studio 의 SDK, cmdline-tools 포함), JDK 는 Android Studio 의 `jbr`

```powershell
$env:Path = "D:\tools\flutter\bin;$env:Path"
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
```

> `D:\tools\flutter` 를 git 이 "dubious ownership" 으로 막으면 `git config --global --add safe.directory D:/tools/flutter`.

## 실행 (에뮬레이터 + 로컬 백엔드)

1. 백엔드 API 를 개발 모드로 띄운다 (`http://localhost:5099`, 에뮬레이터에서는 `http://10.0.2.2:5099`)
2. 환경 파일을 만든다 — 백엔드 user-secrets 의 카카오 네이티브 앱 키를 옮겨 담는다 (값은 출력하지 않음, gitignore)
   ```
   python tool/make_dev_env.py
   ```
3. 실행
   ```
   flutter run --dart-define-from-file=env/dev.json
   ```

기본 첫 화면은 백엔드의 브리지 테스트 페이지 `/dev/bridge` 다 (웹 없이 브리지·로그인을 시험).

웹(vite)을 띄우려면:

```powershell
# 웹 저장소에서: vite 는 기본으로 [::1] 에만 떠서 에뮬레이터(10.0.2.2 → 127.0.0.1)가 못 붙는다
npm run dev -- --host 127.0.0.1
# 앱 쪽
python tool/make_dev_env.py --web http://10.0.2.2:5173
```

카카오 지도 JS SDK 는 카카오 콘솔 [플랫폼] → Web 에 등록된 도메인에서만 열린다 (`http://localhost:5173`, `http://10.0.2.2:5173` 등록됨). 등록 안 된 주소면 SDK 가 401 을 돌려줘 "Kakao Maps SDK 스크립트 로드 실패" 가 뜬다.

## 카카오 콘솔 (Android)

[앱] → [플랫폼] → Android 에 등록:

| 항목 | 값 |
|---|---|
| 패키지명 | `kr.mashil.mashil` (임시 — Q7 에서 확정하면 `android/app/build.gradle.kts` 의 `applicationId` 와 함께 바꾼다) |
| 키 해시 | 디버그 키: `python tool/kakao_key_hash.py` 로 출력. 릴리스·Play 앱 서명 키도 나중에 추가 |

카카오톡이 없는 기기(에뮬레이터)는 카카오계정 로그인(Custom Tabs)으로 넘어간다.

## 환경 값 (`env/*.json`, `--dart-define-from-file`)

| 키 | 설명 |
|---|---|
| `WEB_BASE_URL` | 웹뷰 첫 주소 |
| `API_BASE_URL` | 버전 확인 등 앱이 직접 부르는 API |
| `ALLOWED_HOSTS` | 웹뷰 안에서 열 추가 호스트 (쉼표). 나머지는 외부 브라우저 |
| `KAKAO_NATIVE_APP_KEY` | 카카오 네이티브 앱 키. Android 리다이렉트 스킴에도 쓰인다 (Gradle 이 dart-defines 에서 읽음) |
| `GOOGLE_SERVER_CLIENT_ID` | Google **웹** 클라이언트 ID (Android 에서 ID Token 의 aud). 비우면 Google 버튼 없음 |
| `GOOGLE_IOS_CLIENT_ID` | Google iOS 클라이언트 ID |

iOS 는 `ios/Flutter/Secrets.xcconfig` (gitignore) 에 `KAKAO_NATIVE_APP_KEY=...` 를 둔다. Sign in with Apple 은 iOS 에서만 노출 (STO-04).

## JS 브리지

- 웹 → 앱: `window.MashilBridge.postMessage(JSON.stringify({ requestId, method, params }))`
- 앱 → 웹: `window.__mashilBridgeReply(requestId, result)`
- 페이지 로드가 끝나면 앱이 `window` 에 `mashilbridgeready` 이벤트를 보낸다. UA 끝에 `MashilApp/<버전> (<android|ios>)`
- 허용 호스트(`WEB_BASE_URL`·`API_BASE_URL`·`ALLOWED_HOSTS`)에서 연 페이지의 메시지만 처리한다

| method | params | 응답 |
|---|---|---|
| `getAppInfo` | — | `{ ok, version, platform, providers, language }` |
| `getLocation` | — | `{ ok, lat, lng, accuracy }` / `{ ok:false, reason: denied·deniedForever·serviceDisabled·timeout }` |
| `openSettings` | — | `{ ok }` |
| `openDirections` | `{ lat, lng, name }` | `{ ok, app: kakaomap·web }` |
| `signIn` | `{ provider: kakao·google·apple, nonce }` | `{ ok, provider, idToken?, accessToken?, authorizationCode?, displayName? }` / `{ ok:false, reason: cancelled·failed·busy·unknownProvider }` |
| `signOut` | `{ provider }` | `{ ok }` |
| `setLanguage` | `{ language: ko·en }` | `{ ok, language }` / `{ ok:false, reason: unsupportedLanguage }` |

### 웹 쪽 구현 (`src/lib/nativeBridge.ts` 예시)

```ts
type Reply = Record<string, unknown> & { ok: boolean };
const pending = new Map<string, (r: Reply) => void>();
(window as any).__mashilBridgeReply = (id: string, r: Reply) => { pending.get(id)?.(r); pending.delete(id); };

export const isApp = () => typeof (window as any).MashilBridge?.postMessage === 'function';

export function callNative(method: string, params: object = {}, timeoutMs = 120_000): Promise<Reply> {
  return new Promise((resolve, reject) => {
    if (!isApp()) return reject(new Error('not in app'));
    const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    pending.set(id, resolve);
    setTimeout(() => pending.delete(id) && reject(new Error(`timeout: ${method}`)), timeoutMs);
    (window as any).MashilBridge.postMessage(JSON.stringify({ requestId: id, method, params }));
  });
}

// 로그인: nonce → 앱 SDK 로그인 → 서버 교환
export async function signInWithApp(provider: 'kakao' | 'google' | 'apple') {
  const { nonce } = await (await fetch('/api/auth/nonce')).json();
  const c = await callNative('signIn', { provider, nonce });
  if (!c.ok) return c; // cancelled 등
  const res = await fetch(`/api/auth/oauth/${provider}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: c.idToken, accessToken: c.accessToken, authorizationCode: c.authorizationCode, nonce, device: 'android', displayName: c.displayName }),
  });
  return res.json(); // { accessToken, refreshToken, consentRequired, ... }
}
```

위치는 `isApp()` 이면 `callNative('getLocation')`, 아니면 `navigator.geolocation` 으로 폴백한다 (APP-03).

## 다국어 (ko / en)

- 앱 네이티브 문구(오류 화면, 업데이트 안내, 뒤로가기 안내): `lib/l10n/app_ko.arb`(기준), `app_en.arb`. 빌드 시 `AppLocalizations` 가 생성된다 (`l10n.yaml`, 직접 만들려면 `flutter gen-l10n`). 지원하지 않는 언어는 한국어
- Android 앱 이름: `res/values/strings.xml`(Mashil), `res/values-ko/strings.xml`(마실)
- iOS: `Info.plist` 의 `CFBundleLocalizations` 에 ko·en. 앱 이름·위치 권한 안내문 번역(`InfoPlist.strings`)은 Xcode 에서 Localization 을 추가해야 해서 아직 안 함
- 언어의 기준은 웹이다. 웹(Mashil-web `src/i18n`)은 메뉴에서 고른 언어 → 기기 언어 순으로 정하고, 페이지를 열 때와 언어를 바꿀 때마다 브리지 `setLanguage` 로 앱에 알린다 (`src/i18n/syncAppLanguage.ts`)
- 앱은 받은 언어로 네이티브 문구를 바꾸고 저장한다 (`lib/services/app_language.dart`, SharedPreferences `app_language`). 다음 실행에는 웹이 뜨기 전(오류 화면 등)에도 그 언어. 한 번도 받은 적이 없으면 기기 언어

## 테스트

```
flutter analyze
flutter test
```

브리지 처리(`MashilJsBridge`), 탐색 정책, 버전 비교는 단위 테스트로 확인한다. 실제 SDK 로그인·위치·외부 앱은 에뮬레이터에서 `/dev/bridge` 로 확인한다.
