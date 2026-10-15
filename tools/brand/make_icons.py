#!/usr/bin/env python3
"""Bijou's icon, drawn from one set of coordinates (docs/05 "Brand").

A trillion, the triangular cut of a jewel, pointing right: the jewel is
the play button. Its nine crown facets are lit from the top left, on the
default accent's tile. Smaller, they merge: one band along each edge
under 64 px, the triangle alone under 32 px (JewelPainter and
JewelDetail in lib/design/components/app_mark.dart draw the same).

Writes, from the repository's root (`python3 tools/brand/make_icons.py`):
- design/brand/bijou_icon.svg: the master, for docs and packaging;
- linux/packaging/icons/hicolor/<n>x<n>/apps/<app id>.png and
  scalable/apps/<app id>.svg (the desktop entry's icon, Phase 10);
- windows/runner/resources/app_icon.ico (16 to 256 px);
- android/app/src/main/res/mipmap-<density>/ic_launcher.png (48 to
  192 px; Android before 8) and drawable-xhdpi/banner.png (Google TV's
  320 x 180 home screen banner, what its app row shows: the round icon
  and the name on the dark background);
- mipmap-<density>/ic_launcher_round.png, the round icon before
  Android 8;
- the adaptive icon Android 8 and up draws, round on Google TV (the
  user: "more circular, same logo"): mipmap-anydpi-v26/ic_launcher.xml
  and ic_launcher_round.xml, the accent's gradient as its background
  (drawable/ic_launcher_background.xml) and the jewel alone as its
  foreground (mipmap-<density>/ic_launcher_foreground.png, 108 dp);
- design/brand/bijou_icon_1024.png and bijou_sizes.png (a look at
  every size).

Needs Pillow; nothing else. Re-run it after changing the drawing.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

APP_ID = "io.github.yasiralobaidi.iptvplayer"

# The default accent (lib/design/tokens.dart: AppAccent.blue).
ACCENT = (0x5B, 0x8C, 0xFF)
DEEP = (0x3A, 0x5F, 0xD0)
WHITE = (0xFF, 0xFF, 0xFF)

# A 1024-unit canvas.
TILE = (64, 64, 960, 960)
TILE_RADIUS = 208


# The trillion's corners, clockwise from the top left; the second is the
# play button's point.
CORNERS = [(304, 260), (752, 512), (304, 764)]

# The table is the outline at this scale about its middle.
TABLE_SCALE = 0.5

# How dark each face is (the deep accent over white), lit from the top
# left: each edge's three crown facets, clockwise from the top edge and
# from its first corner; and each edge's one band, when they merge.
FACET_SHADE = [(0.00, 0.08, 0.14), (0.37, 0.29, 0.44), (0.27, 0.17, 0.09)]
BAND_SHADE = [0.14, 0.46, 0.26]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def detail(tile):
    """How much of the cut shows on a tile [tile] pixels wide."""
    if tile >= 56:
        return "full"
    if tile >= 28:
        return "bands"
    return "flat"


def facets(level):
    """The jewel's faces at [level], back to front: (corners, shade)."""
    faces = [(CORNERS, 0.0)]
    if level == "flat":
        return faces
    middle = (sum(c[0] for c in CORNERS) / 3, sum(c[1] for c in CORNERS) / 3)
    table = [lerp(middle, c, TABLE_SCALE) for c in CORNERS]
    for i in range(3):
        j = (i + 1) % 3
        a, b, ta, tb = CORNERS[i], CORNERS[j], table[i], table[j]
        if level == "bands":
            faces.append(([a, b, tb, ta], BAND_SHADE[i]))
            continue
        half = lerp(a, b, 0.5)
        first, between, last = FACET_SHADE[i]
        faces += [([a, half, ta], first), ([ta, half, tb], between), ([half, b, tb], last)]
    faces.append((table, 0.0))
    return faces


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(w, h):
    """The accent's diagonal gradient, from the top left to its deep
    shade at the bottom right."""
    grad = Image.new("RGB", (w, h))
    gd = ImageDraw.Draw(grad)
    steps = 256
    span = w + h
    for i in range(steps):
        t = i / (steps - 1)
        gd.polygon(
            [
                (0, span * i / steps),
                (span * i / steps, 0),
                (span * (i + 1) / steps, 0),
                (0, span * (i + 1) / steps),
            ],
            fill=mix(ACCENT, DEEP, t),
        )
    return grad


def draw(size, tile=True):
    """The icon at [size]; with no [tile], the jewel alone on nothing."""
    k = 8  # supersampling
    s = 1024 * k
    scale = s / 1024

    def pt(p):
        return (p[0] * scale, p[1] * scale)

    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    if tile:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [v * scale for v in TILE], radius=TILE_RADIUS * scale, fill=255
        )
        image.paste(gradient(s, s), (0, 0), mask)

    d = ImageDraw.Draw(image)
    for corners, shade in facets(detail(size * (TILE[2] - TILE[0]) / 1024)):
        d.polygon([pt(p) for p in corners], fill=mix(WHITE, DEEP, shade))

    return image.resize((size, size), Image.LANCZOS)


def svg():
    def points(ps):
        return " ".join(f"{x:.1f},{y:.1f}".replace(".0,", ",").removesuffix(".0") for x, y in ps)

    faces = "\n".join(
        f'    <polygon points="{points(corners)}" fill="#{"%02X%02X%02X" % mix(WHITE, DEEP, shade)}"/>'
        for corners, shade in facets("full")
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <title>Bijou</title>
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#5B8CFF"/>
      <stop offset="1" stop-color="#3A5FD0"/>
    </linearGradient>
  </defs>
  <rect x="64" y="64" width="896" height="896" rx="{TILE_RADIUS}" fill="url(#tile)"/>
  <g>
{faces}
  </g>
</svg>
"""


# Android's launcher densities (48 dp).
ANDROID_ICONS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

BANNER = (320, 180)

# An adaptive icon's layers are 108 dp; a launcher shows the middle 72 dp
# through its mask, and only the middle 66 dp is sure to show.
ANDROID_LAYERS = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
LAYER_DP = 108
VISIBLE_DP = 72


def foreground(n):
    """The adaptive icon's foreground at [n] px (108 dp): the jewel where
    the tile's icon has it, the tile's 896 units scaled to the 72 dp the
    mask shows, so the round icon reads as the square one does."""
    canvas = round(n * VISIBLE_DP / LAYER_DP * 1024 / (TILE[2] - TILE[0]))
    jewel = draw(canvas, tile=False)
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer.alpha_composite(jewel, ((n - canvas) // 2, (n - canvas) // 2))
    return layer


def round_icon(n):
    """The round icon before Android 8 (no adaptive icons there): the
    adaptive one as a launcher masks it, drawn at [n] px."""
    k = 4
    layer = round(n * k * LAYER_DP / VISIBLE_DP)
    icon = gradient(layer, layer).convert("RGBA")
    icon.alpha_composite(foreground(layer))
    o = (layer - n * k) // 2
    icon = icon.crop((o, o, o + n * k, o + n * k))
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, n * k - 1, n * k - 1], fill=255)
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out.resize((n, n), Image.LANCZOS)


ADAPTIVE = """<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand/make_icons.py: Bijou's icon, masked by the
     launcher (round on Google TV). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

BACKGROUND = """<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand/make_icons.py: the accent's gradient, from the
     top left to its deep shade (the tile's). -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="315"
        android:endColor="#%02X%02X%02X"
        android:startColor="#%02X%02X%02X" />
</shape>
""" % (DEEP + ACCENT)


# The banner's ground: the dark look's background (AppColors.bg) lifted
# a little at the top, so the card stands off Google TV's dark home.
BANNER_TOP = (0x1A, 0x20, 0x2C)
BANNER_BOTTOM = (0x0A, 0x0C, 0x10)


def banner(font_path):
    """Google TV's home screen banner, the picture its app row shows (not
    the launcher icon): the round icon and the name, white, centred as one
    on the dark background, edge to edge (the launcher rounds the card's
    corners). The user asked for the round icon there (2026-10-15)."""
    k = 4
    w, h = BANNER[0] * k, BANNER[1] * k
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=mix(BANNER_TOP, BANNER_BOTTOM, y / (h - 1)))
    badge = round_icon(112 * k)
    font = ImageFont.truetype(font_path, 50 * k)
    font.set_variation_by_axes([700])
    text_left, _, text_right, _ = d.textbbox((0, 0), "Bijou", font=font, anchor="ls")
    _, cap_top, _, _ = d.textbbox((0, 0), "B", font=font, anchor="ls")
    gap = 20 * k
    group = badge.width + gap + (text_right - text_left)
    x = (w - group) / 2
    middle = h / 2
    image.alpha_composite(badge, (round(x), round(middle - badge.height / 2)))
    # The capitals' middle on the circle's.
    d.text(
        (x + badge.width + gap - text_left, middle - cap_top / 2),
        "Bijou",
        font=font,
        fill=WHITE,
        anchor="ls",
    )
    return image.resize(BANNER, Image.LANCZOS)


def main():
    root = os.getcwd()
    if not os.path.exists(os.path.join(root, "pubspec.yaml")):
        sys.exit("Run from the repository's root.")

    def out(*parts):
        path = os.path.join(root, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        return path

    master = svg()
    for path in [
        out("design", "brand", "bijou_icon.svg"),
        out("linux", "packaging", "icons", "hicolor", "scalable", "apps", f"{APP_ID}.svg"),
    ]:
        with open(path, "w") as f:
            f.write(master)

    for n in [16, 24, 32, 48, 64, 128, 256, 512]:
        draw(n).save(out("linux", "packaging", "icons", "hicolor", f"{n}x{n}", "apps", f"{APP_ID}.png"))

    ico = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    big = draw(256)
    # Pillow writes each size from the frame given for it.
    frames = {n: draw(n) for n in ico}
    big.save(
        out("windows", "runner", "resources", "app_icon.ico"),
        sizes=[(n, n) for n in ico],
        append_images=[frames[n] for n in ico if n != 256],
    )

    res = ("android", "app", "src", "main", "res")
    for density, n in ANDROID_ICONS.items():
        draw(n).save(out(*res, f"mipmap-{density}", "ic_launcher.png"))
        round_icon(n).save(out(*res, f"mipmap-{density}", "ic_launcher_round.png"))
    for density, n in ANDROID_LAYERS.items():
        foreground(n).save(out(*res, f"mipmap-{density}", "ic_launcher_foreground.png"))
    for name in ["ic_launcher.xml", "ic_launcher_round.xml"]:
        with open(out(*res, "mipmap-anydpi-v26", name), "w") as f:
            f.write(ADAPTIVE)
    with open(out(*res, "drawable", "ic_launcher_background.xml"), "w") as f:
        f.write(BACKGROUND)
    banner(os.path.join(root, "assets", "fonts", "Manrope[wght].ttf")).save(
        out(*res, "drawable-xhdpi", "banner.png")
    )

    draw(1024).save(out("design", "brand", "bijou_icon_1024.png"))
    sheet_sizes = [16, 24, 32, 48, 64, 128, 256]
    sheet = Image.new("RGBA", (sum(sheet_sizes) + 40 * len(sheet_sizes) + 40, 336), (10, 12, 16, 255))
    x = 40
    for n in sheet_sizes:
        sheet.alpha_composite(draw(n), (x, 296 - n))
        x += n + 40
    sheet.save(out("design", "brand", "bijou_sizes.png"))


if __name__ == "__main__":
    main()
