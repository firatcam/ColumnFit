#!/usr/bin/env python3
"""Generates the ColumnFit app icon (iconset PNGs + .icns + 1024px preview).

Usage:  python3 scripts/make-icon.py        (needs: pip install pillow)
Output: Resources/AppIcon.iconset/*.png, Resources/AppIcon.icns, assets/icon-1024.png
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2                      # supersampling factor
W = 1024 * S


def sc(v):
    return int(round(v * S))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rrect(draw, box, r, **kw):
    draw.rounded_rectangle([sc(box[0]), sc(box[1]), sc(box[2]), sc(box[3])], radius=sc(r), **kw)


def build():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # --- soft drop shadow of the icon body -------------------------------
    sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    rrect(ImageDraw.Draw(sh), (100, 116, 924, 940), 185, fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(sc(16)))
    img = Image.alpha_composite(img, sh)

    # --- body: vertical blue gradient squircle ---------------------------
    top, bot = (86, 196, 255), (33, 92, 232)
    grad = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(sc(100), sc(924)):
        t = (y - sc(100)) / sc(824)
        gd.line([(0, y), (W, y)], fill=lerp(top, bot, t) + (255,))
    mask = Image.new("L", (W, W), 0)
    rrect(ImageDraw.Draw(mask), (100, 100, 924, 924), 185, fill=255)
    body = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    img = Image.alpha_composite(img, body)

    # --- Finder-like window card -----------------------------------------
    cx0, cy0, cx1, cy1 = 176, 262, 848, 770
    csh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    rrect(ImageDraw.Draw(csh), (cx0, cy0 + 14, cx1, cy1 + 14), 46, fill=(8, 30, 90, 110))
    csh = csh.filter(ImageFilter.GaussianBlur(sc(14)))
    img = Image.alpha_composite(img, csh)

    card = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    rrect(d, (cx0, cy0, cx1, cy1), 46, fill=(250, 251, 254, 255))

    # title bar
    bar_h = 74
    bar = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    rrect(bd, (cx0, cy0, cx1, cy1), 46, fill=(236, 240, 247, 255))
    clip = Image.new("L", (W, W), 0)
    ImageDraw.Draw(clip).rectangle([sc(cx0), sc(cy0), sc(cx1), sc(cy0 + bar_h)], fill=255)
    card.paste(bar, (0, 0), clip)
    d = ImageDraw.Draw(card)
    d.line([(sc(cx0), sc(cy0 + bar_h)), (sc(cx1), sc(cy0 + bar_h))], fill=(214, 220, 232, 255), width=sc(3))
    for i, col in enumerate([(255, 95, 87), (254, 188, 46), (40, 200, 64)]):
        x = cx0 + 44 + i * 44
        y = cy0 + bar_h / 2
        d.ellipse([sc(x - 14), sc(y - 14), sc(x + 14), sc(y + 14)], fill=col + (255,))

    # --- three columns ----------------------------------------------------
    body_top, body_bot = cy0 + bar_h, cy1
    div1, div2 = 392, 600                      # column dividers (x)
    line = (214, 220, 232, 255)
    d.line([(sc(div1), sc(body_top)), (sc(div1), sc(body_bot))], fill=line, width=sc(3))
    d.line([(sc(div2), sc(body_top)), (sc(div2), sc(body_bot))], fill=line, width=sc(3))

    row_gray = (205, 213, 227, 255)
    blue = (36, 110, 245, 255)

    def rows(x0, x1, selected=None, n=6):
        y = body_top + 28
        for i in range(n):
            r = (x0 + 18, y, x1 - 18, y + 46)
            if i == selected:
                rrect(d, r, 12, fill=blue)
                rrect(d, (r[0] + 16, r[1] + 15, r[0] + 16 + (r[2] - r[0]) * 0.55, r[1] + 31), 8,
                      fill=(255, 255, 255, 235))
            else:
                w = (r[2] - r[0]) * (0.80 - 0.09 * (i % 3))
                rrect(d, (r[0] + 16, r[1] + 15, r[0] + 16 + w, r[1] + 31), 8, fill=row_gray)
            y += 62

    rows(cx0, div1, selected=1)
    rows(div1, div2, selected=2)
    rows(div2, cx1, selected=None, n=5)

    img = Image.alpha_composite(img, card)
    d = ImageDraw.Draw(img)

    # --- resize handle (double arrow) on the divider ----------------------
    hx, hy, hr = div2, 640, 78
    hsh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(hsh).ellipse([sc(hx - hr), sc(hy - hr + 10), sc(hx + hr), sc(hy + hr + 10)], fill=(0, 20, 80, 130))
    hsh = hsh.filter(ImageFilter.GaussianBlur(sc(10)))
    img = Image.alpha_composite(img, hsh)
    d = ImageDraw.Draw(img)
    d.ellipse([sc(hx - hr - 8), sc(hy - hr - 8), sc(hx + hr + 8), sc(hy + hr + 8)], fill=(250, 251, 254, 255))
    d.ellipse([sc(hx - hr), sc(hy - hr), sc(hx + hr), sc(hy + hr)], fill=(30, 100, 240, 255))

    # arrow: shaft + two heads
    white = (255, 255, 255, 255)
    shaft = 52
    d.rounded_rectangle([sc(hx - shaft), sc(hy - 7), sc(hx + shaft), sc(hy + 7)], radius=sc(7), fill=white)
    head = 30
    d.polygon([(sc(hx - shaft - 14), sc(hy)), (sc(hx - shaft + 16), sc(hy - head)), (sc(hx - shaft + 16), sc(hy + head))], fill=white)
    d.polygon([(sc(hx + shaft + 14), sc(hy)), (sc(hx + shaft - 16), sc(hy - head)), (sc(hx + shaft - 16), sc(hy + head))], fill=white)

    return img.resize((1024, 1024), Image.LANCZOS)


def main():
    icon = build()
    os.makedirs(os.path.join(ROOT, "assets"), exist_ok=True)
    icon.save(os.path.join(ROOT, "assets", "icon-1024.png"))

    iconset = os.path.join(ROOT, "Resources", "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    spec = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
    for base, scale in spec:
        px = base * scale
        name = f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png"
        icon.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))

    # Convenience .icns (build.sh prefers `iconutil` on macOS when it is available)
    try:
        icon.save(os.path.join(ROOT, "Resources", "AppIcon.icns"), format="ICNS",
                  sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
    except Exception as exc:                      # pragma: no cover
        print("ICNS export skipped:", exc)
    print("Icon files written.")


if __name__ == "__main__":
    main()
