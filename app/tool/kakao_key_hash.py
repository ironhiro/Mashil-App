"""카카오 콘솔 Android 플랫폼에 등록할 키 해시 = base64(SHA-1(서명 인증서)).

    python tool/kakao_key_hash.py                       # 디버그 키 (~/.android/debug.keystore)
    python tool/kakao_key_hash.py --keystore release.jks --alias upload --storepass ...

키 해시는 공개해도 되는 값이다 (인증서 지문).
"""
import argparse
import base64
import hashlib
import os
import pathlib
import subprocess
import sys

JBR_KEYTOOL = pathlib.Path(r"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keystore", default=str(pathlib.Path.home() / ".android" / "debug.keystore"))
    ap.add_argument("--alias", default="androiddebugkey")
    ap.add_argument("--storepass", default="android")
    args = ap.parse_args()

    keytool = str(JBR_KEYTOOL) if JBR_KEYTOOL.exists() else "keytool"
    if not os.path.exists(args.keystore):
        print(f"키스토어가 없습니다: {args.keystore} (디버그 빌드를 한 번 하면 생긴다)", file=sys.stderr)
        return 1
    der = subprocess.run(
        [keytool, "-exportcert", "-alias", args.alias, "-keystore", args.keystore, "-storepass", args.storepass],
        check=True, capture_output=True,
    ).stdout
    print(base64.b64encode(hashlib.sha1(der).digest()).decode())
    return 0


if __name__ == "__main__":
    sys.exit(main())
