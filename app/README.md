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

서체 파일을 한 번 만든다 (서울남산체는 재배포 금지라 저장소에 없다. 없으면 빌드가 실패한다):

```
pip install fonttools brotli
python tool/make_fonts.py
```

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
| 패키지명 | `dev.ironhiro.mashil` (2026-11-26 확정, Q7. Play 에 처음 올리면 바꿀 수 없다. iOS 번들 ID 도 같다) |
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

### 아이폰에서 테스트 (Mac)

개발 서버는 윈도우 PC 에 그대로 두고, Mac 은 앱을 빌드해 아이폰에 올리기만 한다. PC·Mac·아이폰이 같은 와이파이여야 한다.

**PC (개발 서버)**
1. vite 를 와이파이에서 보이게 띄운다: `npm run dev -- --host 0.0.0.0 --port 5173`. 처음이면 Windows 방화벽 창에서 **개인 네트워크** 허용. API 는 vite 가 `/api` 로 프록시하므로 따로 열 필요 없다
2. PC 의 와이파이 IP 확인 (`ipconfig` 의 IPv4, 예: `192.168.0.10`)
3. 카카오 콘솔 [플랫폼] → Web 에 `http://<PC IP>:5173` 추가 (지도 JS SDK). 카카오 로그인까지 볼 거면 [플랫폼] → iOS 에 번들 ID `dev.ironhiro.mashil` 추가

**Mac (한 번만)**
1. Xcode (App Store), Flutter, CocoaPods (`brew install cocoapods`) 설치, `flutter doctor` 로 iOS 항목 확인
2. 저장소를 받고 `app/` 에서 `flutter pub get`
3. 키 파일 두 개를 직접 만든다 (git 에 없음, 메신저·메일로 키를 보내지 말 것):
   - `env/ios.json`: `env/example.json` 을 복사해 `WEB_BASE_URL`·`API_BASE_URL` 을 `http://<PC IP>:5173`, `KAKAO_NATIVE_APP_KEY` 를 채운다 (Google 은 비워도 됨)
   - `ios/Flutter/Secrets.xcconfig`: `KAKAO_NATIVE_APP_KEY=<같은 키>`
4. `open ios/Runner.xcworkspace` → Runner 타깃 → Signing & Capabilities → Team 에 내 Apple ID (무료 개인 팀 가능)

**아이폰**
1. USB 로 Mac 에 연결하고 "이 컴퓨터 신뢰"
2. 설정 → 개인정보 보호 및 보안 → **개발자 모드** 켜기 (재시동)
3. Mac 에서 `flutter run --dart-define-from-file=env/ios.json` (기기가 여러 개면 `-d <기기>`)
4. 처음 실행 때 "신뢰하지 않는 개발자"가 뜨면 설정 → 일반 → VPN 및 기기 관리 → 내 Apple ID → 신뢰

무료 개인 팀으로 설치한 앱은 7일 뒤 열리지 않는다 (다시 `flutter run`). 무료 팀은 Sign in with Apple 기능을 쓸 수 없어서 애플 로그인은 실패한다.

## JS 브리지

- 웹 → 앱: `window.MashilBridge.postMessage(JSON.stringify({ requestId, method, params }))`
- 앱 → 웹: `window.__mashilBridgeReply(requestId, result)`
- 페이지 로드가 끝나면 앱이 `window` 에 `mashilbridgeready` 이벤트를 보낸다. UA 끝에 `MashilApp/<버전> (<android|ios>)`
- 허용 호스트(`WEB_BASE_URL`·`API_BASE_URL`·`ALLOWED_HOSTS`)에서 연 페이지의 메시지만 처리한다

| method | params | 응답 |
|---|---|---|
| `getAppInfo` | — | `{ ok, version, platform, providers, language }` |
| `getLocation` | `{ maximumAgeMs?, highAccuracy?, timeoutMs? }` | `{ ok, lat, lng, accuracy, cached }` / `{ ok:false, reason: denied·deniedForever·serviceDisabled·timeout }`. `maximumAgeMs` 안의 마지막 위치면 바로 (`cached: true`) |
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

위치는 `isApp()` 이면 `callNative('getLocation')`, 아니면 `navigator.geolocation` 으로 폴백한다 (APP-03). 홈은 먼저 10분 안의 기억된 위치로 지도를 그리고, 그것이 기억값이었으면 뒤에서 정밀하게 다시 재어 30m 넘게 달라졌을 때만 옮긴다.

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
