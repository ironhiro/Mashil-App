"""Build the app's fonts into assets/fonts (not committed). Same typefaces as the web.

    pip install fonttools brotli
    python tool/make_fonts.py            # once after cloning; CI runs it too

- Seoul Namsan M / B / EB (Korean): downloaded from seoul.go.kr and subset to
  the 11,172 Hangul syllables, compatibility jamo and punctuation, as TTF
  (Flutter can't read woff2). The licence allows free use but forbids
  selling, paid transfer and unauthorised redistribution, so the files stay
  out of git (Mashil-Front tool/make_fonts.py does the same for the web).
- Overpass 500 / 700 / 800 (Latin and figures, SIL OFL 1.1): static
  instances from the official variable font on google/fonts, Latin subset.

The app uses them only on its own screens (splash, offline, error,
maintenance, update dialog); everything else is the web view.
"""
from __future__ import annotations

import io
import sys
import urllib.request
import zipfile
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts"

SEOUL_ZIP = "https://www.seoul.go.kr/upload/seoul/font/seoul_font3.zip"
SEOUL_WEIGHTS = ("SeoulNamsanM", "SeoulNamsanB", "SeoulNamsanEB")
HANGUL = (
    list(range(0xAC00, 0xD7A4))  # Hangul syllables
    + list(range(0x3131, 0x318F))  # compatibility jamo
    + list(range(0x3000, 0x3020))  # CJK punctuation
    + list(range(0x2010, 0x2030))  # general punctuation
    + [0x00B7, 0x2026, 0xFF5E]
)

OVERPASS_URL = "https://github.com/google/fonts/raw/main/ofl/overpass/Overpass%5Bwght%5D.ttf"
OVERPASS_WEIGHTS = {"Overpass-Medium": 500, "Overpass-Bold": 700, "Overpass-ExtraBold": 800}
LATIN = list(range(0x20, 0x7F)) + list(range(0xA0, 0x100)) + [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x20A9]


def download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req, timeout=300).read()


def subset_save(font: TTFont, unicodes: list[int], dst: Path) -> None:
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=unicodes)
    sub.subset(font)
    font.flavor = None
    font.save(str(dst))
    print(dst.relative_to(OUT.parent.parent), dst.stat().st_size)


def main() -> int:
    wanted = [f"{w}.ttf" for w in SEOUL_WEIGHTS] + [f"{w}.ttf" for w in OVERPASS_WEIGHTS]
    if all((OUT / f).exists() for f in wanted) and "--force" not in sys.argv:
        print("fonts already built (use --force to rebuild)")
        return 0
    OUT.mkdir(parents=True, exist_ok=True)

    print("downloading", SEOUL_ZIP)
    z = zipfile.ZipFile(io.BytesIO(download(SEOUL_ZIP)))
    found = set()
    for info in z.infolist():
        name = info.filename.rsplit("/", 1)[-1]
        stem = name.rsplit(".", 1)[0]
        if stem in SEOUL_WEIGHTS and name.endswith(".ttf"):
            subset_save(TTFont(io.BytesIO(z.read(info))), HANGUL, OUT / f"{stem}.ttf")
            found.add(stem)
    if found != set(SEOUL_WEIGHTS):
        print("missing in zip:", set(SEOUL_WEIGHTS) - found, file=sys.stderr)
        return 1

    print("downloading", OVERPASS_URL)
    variable = download(OVERPASS_URL)
    for stem, wght in OVERPASS_WEIGHTS.items():
        static = instancer.instantiateVariableFont(TTFont(io.BytesIO(variable)), {"wght": wght})
        subset_save(static, LATIN, OUT / f"{stem}.ttf")
    return 0


if __name__ == "__main__":
    sys.exit(main())
