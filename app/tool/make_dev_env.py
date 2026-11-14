"""env/dev.json 을 만든다: 백엔드 user-secrets 의 카카오 네이티브 앱 키(OAuth:Kakao:Audiences:0)를 옮겨 담는다.

키 값은 화면에 출력하지 않는다. env/dev.json 은 gitignore 대상.

    python tool/make_dev_env.py            # 에뮬레이터용 (PC = 10.0.2.2)
    python tool/make_dev_env.py --web http://10.0.2.2:5173   # vite 개발 서버를 띄울 때
"""
import argparse
import json
import os
import pathlib
import sys

SECRETS_ID = "mashil-api-3f7e82a4-e2c8-4f6e-9d1a-1b9c54a6f8a2"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--web", default="http://10.0.2.2:5099/dev/bridge", help="웹뷰가 처음 여는 주소")
    ap.add_argument("--api", default="http://10.0.2.2:5099")
    args = ap.parse_args()

    secrets = pathlib.Path(os.environ["APPDATA"]) / "Microsoft" / "UserSecrets" / SECRETS_ID / "secrets.json"
    data = json.loads(secrets.read_text(encoding="utf-8-sig"))
    kakao = (((data.get("OAuth") or {}).get("Kakao") or {}).get("Audiences") or [None])[0]
    if not kakao:
        # user-secrets 를 평평한 키("OAuth:Kakao:Audiences:0")로 저장한 경우
        kakao = data.get("OAuth:Kakao:Audiences:0")
    if not kakao:
        print("OAuth:Kakao:Audiences:0 (네이티브 앱 키)가 user-secrets 에 없습니다.", file=sys.stderr)
        return 1

    google = (data.get("OAuth") or {}).get("Google") or {}
    env = {
        "WEB_BASE_URL": args.web,
        "API_BASE_URL": args.api,
        "ALLOWED_HOSTS": "",
        "KAKAO_NATIVE_APP_KEY": kakao,
        "GOOGLE_SERVER_CLIENT_ID": (google.get("ClientIds") or [""])[0],
        "GOOGLE_IOS_CLIENT_ID": "",
    }
    out = pathlib.Path(__file__).resolve().parent.parent / "env" / "dev.json"
    out.write_text(json.dumps(env, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{out} 작성 (카카오 키 {len(kakao)}자, 값은 출력하지 않음)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
