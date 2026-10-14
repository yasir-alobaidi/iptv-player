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
  192 px) and drawable-xhdpi/banner.png (Google TV's 320 x 180 home
  screen banner: the jewel and the name on the accent);
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


def banner(font_path):
    """Google TV's home screen banner: the jewel and the name, white on
    the accent, edge to edge (the launcher rounds its corners), the two
    centred as one."""
    k = 4
    w, h = BANNER[0] * k, BANNER[1] * k
    image = gradient(w, h).convert("RGBA")
    jewel = draw(124 * k, tile=False)
    # The part of the jewel's square it fills (CORNERS' bounds).
    xs, ys = [c[0] for c in CORNERS], [c[1] for c in CORNERS]
    jl, jt, jr, jb = (v * jewel.width / 1024 for v in (min(xs), min(ys), max(xs), max(ys)))
    font = ImageFont.truetype(font_path, 54 * k)
    font.set_variation_by_axes([700])
    d = ImageDraw.Draw(image)
    text_left, _, text_right, _ = d.textbbox((0, 0), "Bijou", font=font, anchor="ls")
    _, cap_top, _, _ = d.textbbox((0, 0), "B", font=font, anchor="ls")
    gap = 18 * k
    group = (jr - jl) + gap + (text_right - text_left)
    x = (w - group) / 2
    middle = h / 2
    image.alpha_composite(jewel, (round(x - jl), round(middle - (jt + jb) / 2)))
    # The capitals' middle on the jewel's.
    d.text(
        (x + (jr - jl) + gap - text_left, middle - cap_top / 2),
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
