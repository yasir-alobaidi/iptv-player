# Bijou's Google Play listing

What goes in Play Console → **Grow users → Store presence → Main store
listing** (docs/play/README.md, step 5). Default language: **English
(United States) – en-US**. The words follow docs/05 "Brand": a player for
what the user brings, with nothing of its own to watch; never "IPTV",
never "free channels", no service, channel or broadcaster names.

Only what the Android app does is promised: no casting and no downloads
(desktop only), no local video library (not on Android). If the phone
version gains **Playlist file** (an M3U from the device), add "or a
playlist file" after "a playlist link (M3U)".

Counts are characters as Play counts them (letters, spaces, bullets and
line breaks; checked with Python's `len()`).

## App name (29 of 30)

```
Bijou: Your own little cinema
```

## Short description (76 of 80)

```
A calm video player for the playlists, guides and services you already have.
```

## Full description (1,637 of 4,000)

```
Bijou is your own little cinema: a calm, quick video player for what you already have.

It comes with nothing to watch of its own. You bring the pictures: a playlist link (M3U), a program guide (XMLTV) if you have one, or the server address, username and password of a service you subscribe to. Bijou gathers them into one tidy place, with live channels, movies and series each in a room of their own.

LIVE CHANNELS
• A clear list by category; hide the categories you never watch
• Change channel in a moment
• What's on now and next, when your source has a program guide

MOVIES AND SERIES
• Posters, details, seasons and episodes
• Pick up where you stopped, to the second
• Subtitles and audio tracks, named plainly

EVERYWHERE IN THE APP
• Favorites, watch history and one search across everything you added
• Messy names tidied for display, and a neat tile where a logo is missing
• Calm, dark screens that keep the picture first

ON YOUR TV
Bijou is at home on Google TV and Android TV. Every screen works with the remote's arrows and OK, it has its own on-screen keyboard, playback stops when you leave, and the picture can match your TV's frame rate for smooth motion.

PRIVATE BY DESIGN
• No account to create, no ads, no tracking, no analytics
• Your passwords are kept encrypted on your device
• Bijou connects only to the sources you add, and to the pictures and streams they point to. Nothing is ever sent to us.

PLEASE NOTE
Bijou doesn't provide, sell or recommend any channels, movies, series or subscriptions. It plays only what you add, from sources you choose, and you're responsible for having the right to watch it.
```

## Category, contact, tags

| Field | Value |
|---|---|
| App or game | App |
| Category | **Video Players & Editors** |
| Tags | Up to five from Play's own list (Store presence → Store settings → Tags). Pick the ones closest to: video player, media player, TV. Don't pick anything about live TV channels, sports or news content. |
| Email (required, shown publicly) | `[contact email]` |
| Website (optional) | `https://github.com/yasir-alobaidi/iptv-player` |
| Phone (optional) | leave empty |
| Privacy policy | see docs/play/README.md, step 7 |

Play has no keywords field: search reads the name and the two
descriptions. Don't add a list of keywords to the description (Play's
metadata policy calls that keyword stuffing).

## Graphics

All in `design/brand/play/`, drawn by `tools/brand/make_icons.py`:

| Play asks for | File |
|---|---|
| App icon, 512 × 512, 32-bit PNG | `icon-512.png` |
| Feature graphic, 1024 × 500, no alpha | `feature-graphic-1024x500.png` |
| Android TV banner, 1280 × 720, no alpha | `tv-banner-1280x720.png` |

Feature graphic alt text (140 at most): `The Bijou name and "Your own
little cinema" beside a large faceted jewel shaped like a play button`.

**Screenshots** are taken from the app (see docs/play/README.md, step
6): phone, 7- and 10-inch tablet, Chromebook and TV. They show only the
demo playlist's open movies and test signals, or Bijou's empty states:
never a real channel, a broadcaster's logo or a film someone else owns.
