#!/usr/bin/env python3
"""Bijou's icon, drawn from one set of coordinates (docs/05 "Brand").

A trillion, the triangular cut of a jewel, pointing right: the jewel is
the play button. Its nine crown facets are lit from the top left, on the
default accent's tile. Smaller, they merge: one band along each edge
under 64 px, the triangle alone under 32 px (JewelPainter and
JewelDetail in lib/design/components/app_mark.dart draw the same).

The jewel is Bijou's mark inside the app and outside it: the launcher,
the dock, the taskbar, the TV's circle and banner (the user, giving
Bijou to others: "I need it with the original name Bijou and also with
the original gerated blue logo"; ADR-057). The cover photo,
design/brand/faisal.jpeg, stays as a TV build's icon on request
(`--dart-define=BIJOU_ICON=cover`, the Living Room's "FAISAL TV"; ADR-041
had it everywhere outside), its head framed in a circle (COVER_MIDDLE,
COVER_DIAMETER).

Writes, from the repository's root (`python3 tools/brand/make_icons.py`):
- design/brand/bijou_icon.svg (the master), bijou_icon_1024.png and
  bijou_sizes.png (a look at every size);
- linux/packaging/icons/hicolor/<n>x<n>/apps/<app id>.png and
  scalable/apps/<app id>.svg (the desktop entry's icon);
- windows/runner/resources/app_icon.ico (16 to 256 px);
- for Android, three sets the build picks from (`appIcon`, `appBanner`
  in android/app/build.gradle.kts): Bijou's (`ic_launcher*`, `banner`),
  Bijou Beta's with an amber BETA pill (`ic_launcher_beta*`,
  `banner_beta`), and the cover's (`ic_launcher_cover*`, `banner_cover`).
  Each: mipmap-<density>/<name>.png and <name>_round.png (48 to 192 px,
  round; Android before 8); the adaptive icon Android 8 and up draws, and
  what Google TV's "Your apps" row shows, in a circle (ADR-028):
  mipmap-anydpi-v26/<name>.xml and <name>_round.xml over a background
  (the accent's gradient under the jewel, drawable/
  ic_launcher_background.xml; dark under the photo,
  ic_launcher_cover_background.xml) and a 108 dp layer (mipmap-<density>/
  <name>_foreground.png); and drawable-xhdpi/<banner>.png, the 320 x 180
  banner a leanback launcher's app cards show;
- the Android launch splash's mark (drawable-<density>/splash_mark.png,
  240 dp: Android 12 and up would show the launcher's icon there).

Needs Pillow; nothing else. Re-run it after changing the drawing or the
photo.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

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

# Android 12's launch splash: a 240 dp icon, its middle 160 dp shown in a
# circle, as an adaptive icon's 108 and 72.
SPLASH_ICONS = {"mdpi": 240, "hdpi": 360, "xhdpi": 480, "xxhdpi": 720, "xxxhdpi": 960}


def foreground(n):
    """The jewel alone at [n] px, sized as an adaptive icon's 108 dp
    layer: the tile's 896 units scaled to the 72 dp a mask shows, so the
    round icon reads as the square one does (the adaptive icon's layer,
    and the launch splash's mark)."""
    canvas = round(n * VISIBLE_DP / LAYER_DP * 1024 / (TILE[2] - TILE[0]))
    jewel = draw(canvas, tile=False)
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer.alpha_composite(jewel, ((n - canvas) // 2, (n - canvas) // 2))
    return layer


def jewel_layer(n, beta=False):
    """The adaptive icon's foreground at [n] px: the jewel, and Beta's
    pill inside the circle a launcher shows."""
    layer = foreground(n)
    if beta:
        side = round(n * VISIBLE_DP / LAYER_DP)
        o = (n - side) // 2
        middle = layer.crop((o, o, o + side, o + side))
        beta_pill(middle)
        layer.paste(middle, (o, o))
    return layer


def tile_icon(n, beta=False):
    """The square icon before Android 8 ([draw]'s tile), with Beta's pill."""
    icon = draw(n * 4)
    if beta:
        beta_pill(icon)
    return icon.resize((n, n), Image.LANCZOS)


def round_icon(n, beta=False):
    """The round icon before Android 8 (no adaptive icons there): the
    adaptive one as a launcher masks it, drawn at [n] px."""
    k = 4
    layer = round(n * k * LAYER_DP / VISIBLE_DP)
    icon = gradient(layer, layer).convert("RGBA")
    icon.alpha_composite(foreground(layer))
    o = (layer - n * k) // 2
    icon = icon.crop((o, o, o + n * k, o + n * k))
    if beta:
        beta_pill(icon)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, n * k - 1, n * k - 1], fill=255)
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out.resize((n, n), Image.LANCZOS)


ADAPTIVE = """<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand/make_icons.py: %s, masked by the launcher
     (round on Google TV). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/%s" />
    <foreground android:drawable="@mipmap/%s_foreground" />
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

COVER_BACKGROUND = """<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand/make_icons.py: under the cover's layer, which
     covers it (the dark look's background, AppColors.bg). -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FF0A0C10" />
</shape>
"""

# The banner's ground: the dark look's background (AppColors.bg) lifted
# a little at the top, so the card stands off Google TV's dark home.
BANNER_TOP = (0x1A, 0x20, 0x2C)
BANNER_BOTTOM = (0x0A, 0x0C, 0x10)


def banner(beta=False):
    """The 320 x 180 banner a leanback launcher's app cards show (Google
    TV's "Your apps" row shows the adaptive icon in a circle instead,
    ADR-028): the round icon and the name, white, centred as one on the
    dark background, edge to edge (the launcher rounds the card's
    corners)."""
    k = 4
    w, h = BANNER[0] * k, BANNER[1] * k
    image = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(image)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=mix(BANNER_TOP, BANNER_BOTTOM, y / (h - 1)))
    name = "Bijou Beta" if beta else "Bijou"
    # Bijou's sizes; a longer name shrinks the badge and the name together
    # until the two fit with a margin each side.
    scale = 1.0
    while True:
        badge_side = round(112 * k * scale)
        font = ImageFont.truetype(_font_path(), round(50 * k * scale))
        font.set_variation_by_axes([700])
        text_left, _, text_right, _ = d.textbbox((0, 0), name, font=font, anchor="ls")
        gap = round(20 * k * scale)
        group = badge_side + gap + (text_right - text_left)
        if group <= w * 0.84 or scale < 0.5:
            break
        scale *= 0.95
    badge = round_icon(badge_side, beta=beta)
    _, cap_top, _, _ = d.textbbox((0, 0), "B", font=font, anchor="ls")
    x = (w - group) / 2
    middle = h / 2
    image.alpha_composite(badge, (round(x), round(middle - badge.height / 2)))
    # The capitals' middle on the circle's.
    d.text(
        (x + badge.width + gap - text_left, middle - cap_top / 2),
        name,
        font=font,
        fill=WHITE,
        anchor="ls",
    )
    return image.resize(BANNER, Image.LANCZOS)


# The cover (the user: "I want it to be the cover image of the app on the
# PC and the tv from outside only not inside the app"): the photo every
# icon outside the app shows — the launcher's, the dock's, the taskbar's,
# the TV's banner. Inside the app, the jewel stays Bijou's mark; the TV's
# launch splash shows the jewel too.
COVER = ("design", "brand", "faisal.jpeg")

# The circle the round icons show, in the photo's pixels: its middle and
# diameter. The head (hair to chin, ear to ear) fits in its middle 66/72,
# an adaptive icon's safe zone, with the eyes a little above the middle.
# Measured on the photo; move these if the photo changes.
COVER_MIDDLE = (380, 560)
COVER_DIAMETER = 660

# Beta's mark (ADR-034's "Bijou Beta" beside "Bijou" on the TV): the
# pill's amber (AppColors.warning) under dark text.
BETA_PILL = (0xF5, 0xB8, 0x4B)
BETA_TEXT = (0x0A, 0x0C, 0x10)


def cover_photo(root):
    return Image.open(os.path.join(root, *COVER)).convert("RGB")


def cover_region(photo, size, middle, padding_blur=24):
    """A [size] x [size] square of [photo] around [middle] (its pixels),
    where the photo runs out filled by itself enlarged and blurred, so a
    crop past an edge has no hard border."""
    w, h = size
    x0 = round(middle[0] - w / 2)
    y0 = round(middle[1] - h / 2)
    inside = 0 <= x0 and 0 <= y0 and x0 + w <= photo.width and y0 + h <= photo.height
    if inside:
        return photo.crop((x0, y0, x0 + w, y0 + h))
    scale = max(w / photo.width, h / photo.height) * 1.25
    back = photo.resize(
        (round(photo.width * scale), round(photo.height * scale)), Image.LANCZOS
    ).filter(ImageFilter.GaussianBlur(padding_blur))
    canvas = Image.new("RGB", (w, h))
    canvas.paste(
        back,
        (
            round(w / 2 - middle[0] * scale),
            round(h / 2 - middle[1] * scale),
        ),
    )
    # The photo's own edges fade into the blur where it runs out.
    fade = max(1, round(min(w, h) * 0.06))
    mask = Image.new("L", photo.size, 255)
    d = ImageDraw.Draw(mask)
    for i in range(fade):
        v = round(255 * i / fade)
        left, top = (x0 < 0, y0 < 0)
        right, bottom = (x0 + w > photo.width, y0 + h > photo.height)
        box = [
            i if left else -1,
            i if top else -1,
            photo.width - 1 - i if right else photo.width,
            photo.height - 1 - i if bottom else photo.height,
        ]
        d.rectangle(box, outline=v)
    canvas.paste(photo, (-x0, -y0), mask)
    return canvas


def beta_pill(image, width_share=0.42, bottom_share=0.88):
    """Beta's "BETA" pill on [image], centred, its bottom at
    [bottom_share] of the height (inside a circle's safe zone)."""
    w, h = image.size
    d = ImageDraw.Draw(image)
    pill_w = w * width_share
    pill_h = pill_w * 0.38
    x0 = (w - pill_w) / 2
    y1 = h * bottom_share
    y0 = y1 - pill_h
    d.rounded_rectangle([x0, y0, x0 + pill_w, y1], radius=pill_h / 2, fill=BETA_PILL)
    font = ImageFont.truetype(_font_path(), round(pill_h * 0.62))
    font.set_variation_by_axes([800])
    d.text(((x0 + x0 + pill_w) / 2, (y0 + y1) / 2), "BETA", font=font, fill=BETA_TEXT, anchor="mm")
    return image


def _font_path():
    return os.path.join(os.getcwd(), "assets", "fonts", "Manrope[wght].ttf")


def cover_round(photo, n, beta=False):
    """The photo in a circle at [n] px, transparent round it: the dock's,
    the taskbar's and Android's round icon."""
    k = 4
    side = n * k
    crop = cover_region(photo, (COVER_DIAMETER, COVER_DIAMETER), COVER_MIDDLE)
    icon = crop.resize((side, side), Image.LANCZOS).convert("RGBA")
    if beta:
        beta_pill(icon)
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, side - 1, side - 1], fill=255)
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out.resize((n, n), Image.LANCZOS)


def cover_layer(photo, n, beta=False):
    """The adaptive icon's layer at [n] px (108 dp, opaque): the circle's
    72 dp in its middle, the photo carried on to the edges (a launcher
    may move or stretch the layer under its mask)."""
    side = round(COVER_DIAMETER * LAYER_DP / VISIBLE_DP)
    layer = cover_region(photo, (side, side), COVER_MIDDLE).convert("RGBA")
    if beta:
        o = (side - COVER_DIAMETER) // 2
        middle = layer.crop((o, o, o + COVER_DIAMETER, o + COVER_DIAMETER))
        beta_pill(middle)
        layer.paste(middle, (o, o))
    return layer.resize((n, n), Image.LANCZOS)


def cover_banner(photo, beta=False):
    """The 320 x 180 banner a leanback launcher's app cards show (Google
    TV's "Your apps" row shows the round icon instead, ADR-028): the
    photo edge to edge, its whole width, the head from hair to chin in
    the card's height (the launcher rounds the corners and writes the
    name under it)."""
    w = photo.width
    h = round(w * BANNER[1] / BANNER[0])
    crop = cover_region(photo, (w, h), (w / 2, COVER_MIDDLE[1] - 50))
    image = crop.resize((BANNER[0] * 4, BANNER[1] * 4), Image.LANCZOS).convert("RGBA")
    if beta:
        d = ImageDraw.Draw(image)
        pill_h = 26 * 4
        font = ImageFont.truetype(_font_path(), round(pill_h * 0.62))
        font.set_variation_by_axes([800])
        left, _, right, _ = d.textbbox((0, 0), "BETA", font=font)
        pill_w = right - left + pill_h
        x0, y0 = 14 * 4, 14 * 4
        d.rounded_rectangle([x0, y0, x0 + pill_w, y0 + pill_h], radius=pill_h / 2, fill=BETA_PILL)
        d.text((x0 + pill_w / 2, y0 + pill_h / 2), "BETA", font=font, fill=BETA_TEXT, anchor="mm")
    return image.resize(BANNER, Image.LANCZOS)


def main():
    root = os.getcwd()
    if not os.path.exists(os.path.join(root, "pubspec.yaml")):
        sys.exit("Run from the repository's root.")

    def out(*parts):
        path = os.path.join(root, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        return path

    def write(text, *parts):
        with open(out(*parts), "w") as f:
            f.write(text)

    # Inside: the jewel.
    write(svg(), "design", "brand", "bijou_icon.svg")
    draw(1024).save(out("design", "brand", "bijou_icon_1024.png"))
    sheet_sizes = [16, 24, 32, 48, 64, 128, 256]
    sheet = Image.new("RGBA", (sum(sheet_sizes) + 40 * len(sheet_sizes) + 40, 336), (10, 12, 16, 255))
    x = 40
    for n in sheet_sizes:
        sheet.alpha_composite(draw(n), (x, 296 - n))
        x += n + 40
    sheet.save(out("design", "brand", "bijou_sizes.png"))

    # Outside: the jewel too (ADR-057).
    hicolor = ("linux", "packaging", "icons", "hicolor")
    write(svg(), *hicolor, "scalable", "apps", f"{APP_ID}.svg")
    for n in [16, 24, 32, 48, 64, 128, 256, 512]:
        draw(n).save(out(*hicolor, f"{n}x{n}", "apps", f"{APP_ID}.png"))

    ico = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    # Pillow writes each size from the frame given for it.
    frames = {n: draw(n) for n in ico}
    frames[256].save(
        out("windows", "runner", "resources", "app_icon.ico"),
        sizes=[(n, n) for n in ico],
        append_images=[frames[n] for n in ico if n != 256],
    )

    res = ("android", "app", "src", "main", "res")

    def android_set(name, background, layer, square_one, round_one, banner_image, banner_name, what):
        for density, n in ANDROID_ICONS.items():
            square_one(n).save(out(*res, f"mipmap-{density}", f"{name}.png"))
            round_one(n).save(out(*res, f"mipmap-{density}", f"{name}_round.png"))
        for density, n in ANDROID_LAYERS.items():
            layer(n).save(out(*res, f"mipmap-{density}", f"{name}_foreground.png"))
        adaptive = ADAPTIVE % (what, background, name)
        for suffix in ["", "_round"]:
            write(adaptive, *res, "mipmap-anydpi-v26", f"{name}{suffix}.xml")
        banner_image.save(out(*res, "drawable-xhdpi", f"{banner_name}.png"))

    write(BACKGROUND, *res, "drawable", "ic_launcher_background.xml")
    write(COVER_BACKGROUND, *res, "drawable", "ic_launcher_cover_background.xml")
    android_set(
        "ic_launcher", "ic_launcher_background", jewel_layer, draw, round_icon,
        banner(), "banner", "Bijou's jewel",
    )
    android_set(
        "ic_launcher_beta", "ic_launcher_background",
        lambda n: jewel_layer(n, beta=True), lambda n: tile_icon(n, beta=True),
        lambda n: round_icon(n, beta=True),
        banner(beta=True), "banner_beta", "Bijou Beta's jewel and pill",
    )
    photo = cover_photo(root)
    android_set(
        "ic_launcher_cover", "ic_launcher_cover_background",
        lambda n: cover_layer(photo, n), lambda n: cover_round(photo, n),
        lambda n: cover_round(photo, n),
        cover_banner(photo), "banner_cover", "the cover",
    )

    # The launch splash (Android 12 and up draws the launcher's icon
    # unless told otherwise): the jewel, on the accent's circle.
    for density, n in SPLASH_ICONS.items():
        foreground(n).save(out(*res, f"drawable-{density}", "splash_mark.png"))


if __name__ == "__main__":
    main()
