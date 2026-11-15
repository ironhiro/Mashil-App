"""Generate Mashil "open door" app icons (docs/07-ui-design.md section 6).

Run from anywhere:  python tool/make_icons.py
Writes Android launcher / adaptive / monochrome / splash PNGs and the iOS
AppIcon set. Geometry is defined on the 100x100 design grid.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
IOS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Pantone 286 C (남자 화장실 파랑) 바탕, Pantone 485 C (여자 화장실 빨강) 손잡이.
# 둘을 섞지 않고 역할로 나눈다 (docs/07 §2).
BG = (0x00, 0x33, 0xA0, 255)  # Pantone 286 C
RED = (0xDA, 0x29, 0x1C, 255)  # Pantone 485 C
LIGHT = (0xA9, 0xC0, 0xF2, 255)  # 문 안쪽 빛: 286 C 를 밝힌 것
FLOOR = (0xA9, 0xC0, 0xF2, round(255 * 0.35))
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
SS = 4  # supersampling factor

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

FULL = dict(frame=(33, 22, 67, 80), leaf=[(33, 22), (55, 28), (55, 75), (33, 80)])
SMALL = dict(frame=(31, 20, 69, 82), leaf=[(31, 20), (56, 27), (56, 76), (31, 82)])
FLOOR_POLY = [(55, 77), (67, 80), (80, 94), (57, 94)]
HANDLE = (50, 53, 2.8)


class Canvas:
    """Supersampled RGBA canvas; maps grid units -> pixels via scale/offset."""

    def __init__(self, px, scale=None, ox=0.0, oy=0.0, bg=CLEAR):
        self.px = px
        self.k = px * SS / 100 if scale is None else scale * SS
        self.ox, self.oy = ox * SS, oy * SS
        self.img = Image.new("RGBA", (px * SS, px * SS), bg)

    def p(self, x, y):
        return (self.ox + x * self.k, self.oy + y * self.k)

    def layer(self, fn):
        # draw on a separate layer and alpha-composite (for translucent fills)
        lay = Image.new("RGBA", self.img.size, CLEAR)
        fn(ImageDraw.Draw(lay))
        self.img = Image.alpha_composite(self.img, lay)

    def rect(self, box, fill, r=0.0, outline=None, width=0.0):
        x0, y0 = self.p(box[0], box[1])
        x1, y1 = self.p(box[2], box[3])
        kw = dict(fill=fill)
        if outline is not None:
            kw = dict(fill=None, outline=outline, width=max(1, round(width * self.k)))
        self.layer(lambda d: d.rounded_rectangle((x0, y0, x1, y1), radius=r * self.k, **kw))

    def poly(self, pts, fill):
        self.layer(lambda d: d.polygon([self.p(*q) for q in pts], fill=fill))

    def circle(self, cx, cy, r, fill):
        x, y = self.p(cx, cy)
        rr = r * self.k
        self.layer(lambda d: d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=fill))

    def cut_circle(self, cx, cy, r):
        # punch a transparent hole
        x, y = self.p(cx, cy)
        rr = r * self.k
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
        alpha = self.img.getchannel("A")
        alpha.paste(0, mask=mask)
        self.img.putalpha(alpha)

    def out(self, rgb=False):
        im = self.img.resize((self.px, self.px), Image.LANCZOS)
        return im.convert("RGB") if rgb else im


def variant(px):
    """Size simplification rules from the spec."""
    return dict(
        floor=px >= 60,
        handle=px > 29,
        geom=FULL if px > 29 else SMALL,
        radius=0 if px <= 16 else 2,
    )


def door(c, v, frame_fill=LIGHT, leaf_fill=WHITE, handle_fill=RED, floor=None):
    g = v["geom"]
    if floor if floor is not None else v["floor"]:
        c.poly(FLOOR_POLY, FLOOR)
    c.rect(g["frame"], frame_fill, r=v["radius"])
    c.poly(g["leaf"], leaf_fill)
    if v["handle"]:
        if handle_fill is None:
            c.cut_circle(*HANDLE)
        else:
            c.circle(*HANDLE, handle_fill)


def full_icon(px, rounded=True):
    """Full app icon. rounded=False -> full-bleed square (iOS masks it)."""
    c = Canvas(px, bg=CLEAR if rounded else BG)
    if rounded:
        c.rect((0, 0, 100, 100), BG, r=22)
    door(c, variant(px))
    return c.out(rgb=not rounded)


# Adaptive foreground: 108dp canvas, grid scaled to 82% (0.82 * 108/100 dp
# per grid unit), content centred so the door sits inside the 66dp safe zone.
AD_SCALE = 0.82 * 108 / 100
AD_CX, AD_CY = 51, 53  # grid point placed at canvas centre (54dp)


def adaptive(px, kind):
    s = px / 108  # px per dp
    k = AD_SCALE * s
    c = Canvas(px, scale=k, ox=54 * s - AD_CX * k, oy=54 * s - AD_CY * k)
    v = variant(200)  # full detail
    if kind == "fg":
        door(c, v)
    else:  # monochrome: leaf filled + frame 3-unit outline, handle cut out
        g = v["geom"]
        x0, y0, x1, y1 = g["frame"]
        c.rect((x0 - 1.5, y0 - 1.5, x1 + 1.5, y1 + 1.5), None, r=3.5, outline=WHITE, width=3)
        c.poly(g["leaf"], WHITE)
        c.cut_circle(*HANDLE)
    return c.out()


# 닫힌 문: 문짝이 문틀을 다 덮고, 손잡이는 오른쪽 끝 안쪽 (lib/shell/splash_gate.dart 의 시작 프레임과 같다)
CLOSED = dict(frame=FULL["frame"], leaf=[(33, 22), (67, 22), (67, 80), (33, 80)])
CLOSED_HANDLE = (62, 53, 2.8)


def glyph(px_canvas, door_h_px, night, closed=False):
    """Splash door glyph on transparent bg, centred on the door frame.
    closed=True: 시스템 스플래시용 닫힌 문. 앱이 뜨면 Flutter 가 이 문을 이어받아 연다."""
    g = CLOSED if closed else FULL
    handle = CLOSED_HANDLE if closed else HANDLE
    x0, y0, x1, y1 = g["frame"]
    k = door_h_px / (y1 - y0 + 3)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    c = Canvas(px_canvas, scale=k, ox=px_canvas / 2 - cx * k, oy=px_canvas / 2 - cy * k)
    if night:  # dark launch bg: light frame, white leaf
        c.rect(g["frame"], LIGHT, r=2)
        c.poly(g["leaf"], WHITE)
    else:  # light launch bg (paper #EDF0F4): blue outlined glyph (흰 문은 밝은 바탕에 묻힌다)
        c.rect((x0 - 1.5, y0 - 1.5, x1 + 1.5, y1 + 1.5), None, r=3.5, outline=BG, width=3)
        c.poly(g["leaf"], BG)
    c.circle(*handle, RED)
    return c.out()


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    print(path.relative_to(ROOT), im.size)


def main():
    for name, d in DENSITIES.items():
        mip = RES / f"mipmap-{name}"
        save(full_icon(round(48 * d)), mip / "ic_launcher.png")
        save(adaptive(round(108 * d), "fg"), mip / "ic_launcher_foreground.png")
        save(adaptive(round(108 * d), "mono"), mip / "ic_launcher_monochrome.png")
        for night in (False, True):
            q = "-night" if night else ""
            # legacy launch screen: 96dp bitmap, door ~80dp tall
            save(glyph(round(96 * d), 80 * d, night, closed=True), RES / f"drawable{q}-{name}/launch_icon.png")
            # Android 12 splash: 240dp icon area, content inside 160dp circle
            save(glyph(round(240 * d), 110 * d, night, closed=True), RES / f"drawable{q}-{name}/splash_icon.png")

    import json

    contents = json.loads((IOS / "Contents.json").read_text(encoding="utf-8"))
    for img in contents["images"]:
        size = float(img["size"].split("x")[0])
        scale = int(img["scale"].rstrip("x"))
        save(full_icon(round(size * scale), rounded=False), IOS / img["filename"])


if __name__ == "__main__":
    main()
