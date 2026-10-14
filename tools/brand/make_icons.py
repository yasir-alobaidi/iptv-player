#!/usr/bin/env python3
"""Bijou's icon, drawn from one set of coordinates (docs/05 "Brand").

An emerald-cut jewel seen from above, its step facets lit from the top
left, a play button in its table, on the default accent's tile. Small
sizes (32 px and under) drop the facets and grow the jewel, so the play
button still reads at 16 px.

Writes, from the repository's root (`python3 tools/brand/make_icons.py`):
- design/brand/bijou_icon.svg: the master, for docs and packaging;
- linux/packaging/icons/hicolor/<n>x<n>/apps/<app id>.png and
  scalable/apps/<app id>.svg (the desktop entry's icon, Phase 10);
- windows/runner/resources/app_icon.ico (16 to 256 px);
- design/brand/bijou_icon_1024.png and bijou_sizes.png (a look at
  every size).

Needs Pillow; nothing else. Re-run it after changing the drawing.
"""

import os
import sys

from PIL import Image, ImageDraw

APP_ID = "io.github.yasiralobaidi.iptvplayer"

# The default accent (lib/design/tokens.dart: AppAccent.blue).
ACCENT = (0x5B, 0x8C, 0xFF)
DEEP = (0x3A, 0x5F, 0xD0)
WHITE = (0xFF, 0xFF, 0xFF)

# A 1024-unit canvas.
TILE = (64, 64, 960, 960)
TILE_RADIUS = 208


def octagon(x0, y0, x1, y1, c):
    return [
        (x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
        (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c),
    ]


def geometry(small):
    """The jewel's outline, its table, and the play button's corners."""
    if small:
        outer = octagon(176, 248, 848, 776, 150)
        table = octagon(276, 336, 748, 672, 104)
        play = [(440, 392), (440, 632), (648, 512)]
    else:
        outer = octagon(232, 288, 792, 736, 100)
        table = octagon(312, 368, 712, 656, 66)
        play = [(452, 412), (452, 612), (625, 512)]
    return outer, table, play


# How dark each step facet is (the deep accent over white), from the top
# edge clockwise: lit from the top left.
FACET_SHADE = [0.00, 0.10, 0.16, 0.24, 0.30, 0.20, 0.10, 0.04]


def rounded(play, r):
    """The play button's corners moved in by twice [r] (a 60-degree
    corner's inset), so a disc of [r] at each gives back its size."""
    cx = sum(p[0] for p in play) / 3
    cy = sum(p[1] for p in play) / 3
    inset = []
    for x, y in play:
        dx, dy = cx - x, cy - y
        n = (dx * dx + dy * dy) ** 0.5
        inset.append((x + dx / n * 2 * r, y + dy / n * 2 * r))
    return inset


PLAY_RADIUS = {True: 34, False: 22}


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw(size):
    small = size <= 32
    k = 8  # supersampling
    s = 1024 * k
    scale = s / 1024

    def pt(p):
        return (p[0] * scale, p[1] * scale)

    # The tile: a diagonal gradient from the accent to its deep shade.
    grad = Image.new("RGB", (s, s))
    gd = ImageDraw.Draw(grad)
    steps = 256
    for i in range(steps):
        t = i / (steps - 1)
        gd.polygon(
            [
                (0, 2 * s * i / steps),
                (2 * s * i / steps, 0),
                (2 * s * (i + 1) / steps, 0),
                (0, 2 * s * (i + 1) / steps),
            ],
            fill=mix(ACCENT, DEEP, t),
        )
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [v * scale for v in TILE], radius=TILE_RADIUS * scale, fill=255
    )
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    image.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(image)
    outer, table, play = geometry(small)
    d.polygon([pt(p) for p in outer], fill=WHITE)
    if small:
        # No lines at this size: the lower facets alone, darker, so it
        # still reads as a jewel rather than a box.
        for i in (3, 4, 5):
            facet = [outer[i], outer[(i + 1) % 8], table[(i + 1) % 8], table[i]]
            d.polygon([pt(p) for p in facet], fill=mix(WHITE, DEEP, 0.34))
    else:
        for i in range(8):
            facet = [outer[i], outer[(i + 1) % 8], table[(i + 1) % 8], table[i]]
            d.polygon([pt(p) for p in facet], fill=mix(WHITE, DEEP, FACET_SHADE[i]))
        d.polygon([pt(p) for p in table], fill=WHITE)
        line = mix(WHITE, DEEP, 0.38)
        width = max(1, round(5 * scale))
        for i in range(8):
            d.line([pt(outer[i]), pt(table[i])], fill=line, width=width)
        d.line([pt(p) for p in table + [table[0]]], fill=line, width=width)

    # The play button, its corners rounded: the triangle drawn smaller,
    # then grown by a disc at each corner and a band along each edge.
    r = PLAY_RADIUS[small] * scale
    corners = [pt(p) for p in rounded(play, PLAY_RADIUS[small])]
    d.polygon(corners, fill=DEEP)
    for x, y in corners:
        d.ellipse([x - r, y - r, x + r, y + r], fill=DEEP)
    for i in range(3):
        d.line([corners[i], corners[(i + 1) % 3]], fill=DEEP, width=round(2 * r))

    return image.resize((size, size), Image.LANCZOS)


def svg():
    outer, table, play = geometry(False)

    def points(ps):
        return " ".join(f"{x:.1f},{y:.1f}".replace(".0,", ",").removesuffix(".0") for x, y in ps)

    facets = "\n".join(
        f'    <polygon points="{points([outer[i], outer[(i + 1) % 8], table[(i + 1) % 8], table[i]])}" '
        f'fill="#{"%02X%02X%02X" % mix(WHITE, DEEP, FACET_SHADE[i])}"/>'
        for i in range(8)
    )
    edges = "\n".join(
        f'    <line x1="{outer[i][0]}" y1="{outer[i][1]}" x2="{table[i][0]}" y2="{table[i][1]}"/>'
        for i in range(8)
    )
    line = "#%02X%02X%02X" % mix(WHITE, DEEP, 0.38)
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
    <polygon points="{points(outer)}" fill="#FFFFFF"/>
{facets}
    <polygon points="{points(table)}" fill="#FFFFFF"/>
  </g>
  <g stroke="{line}" stroke-width="5" fill="none">
{edges}
    <polygon points="{points(table)}"/>
  </g>
  <polygon points="{points(rounded(play, PLAY_RADIUS[False]))}" fill="#3A5FD0" stroke="#3A5FD0" stroke-width="{2 * PLAY_RADIUS[False]}" stroke-linejoin="round"/>
</svg>
"""


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
