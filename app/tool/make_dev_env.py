"""개발용 환경 파일을 만든다: 백엔드 user-secrets 의 키를 옮겨 담는다.

- 카카오 네이티브 앱 키: OAuth:Kakao:Audiences:0
- Google 웹 클라이언트 ID: OAuth:Google:ClientIds:0, iOS 클라이언트 ID: OAuth:Google:IosClientId (있으면)

키 값은 화면에 출력하지 않는다. 만든 파일은 모두 gitignore 대상.

    python tool/make_dev_env.py                      # Android 에뮬레이터 (PC = 10.0.2.2) → env/dev.json
    python tool/make_dev_env.py --web http://10.0.2.2:5173
    python tool/make_dev_env.py --ios                # iOS 시뮬레이터 (Mac = localhost, vite :5173)
                                                     #   → env/ios-sim.json + ios/Flutter/Secrets.xcconfig
    python tool/make_dev_env.py --ios --host 192.168.0.10 --out ios   # 실제 아이폰 → env/ios.json

user-secrets 가 이 컴퓨터에 없으면 키를 비운 채로 만든다 (카카오·Google 로그인만 안 됨).
"""
import argparse
import json
import os
import pathlib
import sys

SECRETS_ID = "mashil-api-3f7e82a4-e2c8-4f6e-9d1a-1b9c54a6f8a2"
APP = pathlib.Path(__file__).resolve().parent.parent


def secrets_path() -> pathlib.Path:
    if os.name == "nt":
        return pathlib.Path(os.environ["APPDATA"]) / "Microsoft" / "UserSecrets" / SECRETS_ID / "secrets.json"
    return pathlib.Path.home() / ".microsoft" / "usersecrets" / SECRETS_ID / "secrets.json"


def secret(data: dict, path: str) -> str:
    """user-secrets 는 중첩 객체로도, 평평한 키("OAuth:Kakao:Audiences:0")로도 저장된다."""
    if path in data:
        return str(data[path] or "")
    node: object = data
    for part in path.split(":"):
        if isinstance(node, list) and part.isdigit():
            node = node[int(part)] if int(part) < len(node) else None
        elif isinstance(node, dict):
            node = node.get(part)
        else:
            node = None
    return str(node or "")


def reversed_client_id(client_id: str) -> str:
    """Google iOS 클라이언트 ID(xxx.apps.googleusercontent.com) → URL 스킴(com.googleusercontent.apps.xxx)."""
    return ".".join(reversed(client_id.split("."))) if client_id else ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ios", action="store_true", help="iOS 용: 기본 주소를 localhost 로, Secrets.xcconfig 도 만든다")
    ap.add_argument("--host", help="개발 서버 주소 (기본: Android 10.0.2.2, iOS localhost)")
    ap.add_argument("--web", help="웹뷰가 처음 여는 주소 (기본: Android 는 /dev/bridge, iOS 는 vite :5173)")
    ap.add_argument("--api", help="앱이 직접 부르는 API (기본: Android :5099, iOS 는 웹과 같음 — vite 가 /api 프록시)")
    ap.add_argument("--out", help="env/<이름>.json (기본: Android dev, iOS ios-sim)")
    args = ap.parse_args()

    host = args.host or ("localhost" if args.ios else "10.0.2.2")
    if args.ios:
        web = args.web or f"http://{host}:5173"
        api = args.api or web
    else:
        web = args.web or f"http://{host}:5099/dev/bridge"
        api = args.api or f"http://{host}:5099"

    path = secrets_path()
    data = json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else {}
    if not data:
        print(f"user-secrets 가 없습니다 ({path}). 키를 비운 채로 만듭니다.", file=sys.stderr)
    kakao = secret(data, "OAuth:Kakao:Audiences:0")
    google_server = secret(data, "OAuth:Google:ClientIds:0")
    google_ios = secret(data, "OAuth:Google:IosClientId")
    if data and not kakao:
        print("OAuth:Kakao:Audiences:0 (네이티브 앱 키)가 user-secrets 에 없습니다. 카카오 로그인은 안 됩니다.", file=sys.stderr)

    env = {
        "WEB_BASE_URL": web,
        "API_BASE_URL": api,
        "ALLOWED_HOSTS": "",
        "KAKAO_NATIVE_APP_KEY": kakao,
        "GOOGLE_SERVER_CLIENT_ID": google_server,
        "GOOGLE_IOS_CLIENT_ID": google_ios,
        # 개발은 Google 테스트 광고 (단위·앱 ID 를 비우면 테스트 ID). 실제 ID 는 프로덕션 env 에만
        "ADS_ENABLED": "true",
        "ADMOB_BANNER_ID": "",
        "ADMOB_APP_ID_ANDROID": "",
    }
    out = APP / "env" / f"{args.out or ('ios-sim' if args.ios else 'dev')}.json"
    out.write_text(json.dumps(env, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{out} 작성 (카카오 키 {len(kakao)}자, Google iOS {'있음' if google_ios else '없음'}, 값은 출력하지 않음)")

    if args.ios:
        # Info.plist 의 URL 스킴(kakao{키}, Google 역순 ID)이 이 값을 쓴다. env json 과 같은 키여야 한다.
        xc = APP / "ios" / "Flutter" / "Secrets.xcconfig"
        xc.write_text(
            "// tool/make_dev_env.py --ios 가 만든다 (gitignore). env/*.json 과 같은 키.\n"
            f"KAKAO_NATIVE_APP_KEY={kakao}\n"
            f"GOOGLE_REVERSED_CLIENT_ID={reversed_client_id(google_ios)}\n",
            encoding="utf-8",
        )
        print(f"{xc} 작성")
    return 0


if __name__ == "__main__":
    sys.exit(main())
