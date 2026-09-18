# 05 — Design system & UX

**Visual reference (Claude Design canvas):** https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99
Screens: Live TV, Full-screen player, Guide, Movie details, Series details, Onboarding (Connect, Sync, Pick categories), Cast device picker, Casting, Home, Movies grid (Series uses the same grid), Search, Library, Library · Downloads, Settings · Downloads and library, Favorites, Google TV Home (v2). Working source files: `design/*.dc.html` + `design/canvas.json` (`design/iptv-player-ui.html` is a generated bundle — don't hand-edit it). If the canvas was edited in the browser, read it back before changing the working files.
Implement screens to match the canvas. This document is the source of truth for token values and behavior.
Not on the canvas yet: Settings sections other than Downloads and library, the Categories manager (reuse the Pick categories layout), and the Welcome onboarding step. Build these from the text below with the canvas's components and tokens; put a simple ASCII layout sketch in the phase plan and get it approved before building.

## Principles
1. **Content first.** Artwork, logos, and video lead; chrome recedes.
2. **Calm and dark.** Dark theme is the default and first-class.
3. **Focus is always obvious.** Loud, consistent, animated focus on every interactive element.
4. **No dead ends.** Every empty or error state offers the next action.
5. **Fast feels fast.** Skeletons within 100 ms, optimistic updates for favorite/hide, no spinners inside lists.
6. **Messy data, clean display.** Cleaned channel names, generated tiles for missing logos, junk categories hidden.

## Tokens (lib/design/tokens.dart)
### Color — dark (default)
| Token | Value | Use |
|---|---|---|
| bg | #0A0C10 | app background |
| surface1 | #11141A | rails, panels |
| surface2 | #171B23 | cards, rows |
| surface3 | #1F2430 | hover, menus, raised cards |
| border | #2A3040 | dividers, outlines |
| textPrimary | #F3F5F9 | titles, body |
| textSecondary | #A7AFBD | metadata |
| textTertiary | #6C7485 | hints, timestamps |
| accent | #5B8CFF | primary actions, focus ring, progress |
| accentPressed | #4A78E6 | pressed state |
| onAccent | #FFFFFF | text on accent |
| live | #FF4D5E | LIVE badge |
| success | #2FD27A | Original badge, connected |
| warning | #FFB547 | Transcoded badge, expiring account |
| danger | #FF5C5C | errors |
| scrim | #000000 at 60 % | overlays over video |
| osdGradient | #000000 0 % → 85 % | top/bottom OSD gradients |

User-selectable accent: Blue #5B8CFF (default), Violet #8B6CFF, Teal #22C3B5, Amber #FFB020, Rose #FF5C8A. Light theme is out of scope for v1, but tokens must allow adding it.

### Typography (bundled Manrope; JetBrains Mono for technical text)
| Style | Size / line | Weight | Use |
|---|---|---|---|
| display | 40 / 48 | 700 | details page titles |
| h1 | 28 / 36 | 700 | screen titles |
| h2 | 22 / 30 | 700, −0.2 tracking | section headers |
| h3 | 18 / 26 | 600 | card and dialog titles |
| titleSmall | 17 / 24 | 800 | rail and card titles on the canvas |
| body | 15 / 22 | 400 | general text |
| bodyStrong | 15 / 22 | 700 | list primary text |
| button | 15 / 22 | 800 | buttons |
| label | 14 / 20 | 600 | field labels, nav rail labels |
| buttonSmall | 14 / 20 | 800 | small buttons |
| caption | 13 / 18 | 500 | metadata |
| labelSmall | 12 / 16 | 600 | chips, dense metadata |
| micro | 11 / 14 | 600, +0.4 tracking, uppercase | badges |
| mono | 13 / 18 | 500 | stream info, diagnostics |

h2 and bodyStrong are 700, not 600, and the 17 / 14 / 12 px styles exist at all, because the canvas draws them that way (ADR-008). A variable font takes its weight from `fontVariations`, so `copyWith(fontWeight:)` alone changes nothing — go through the token.
Tabular figures for times, channel numbers, durations.

### Spacing, radius, elevation, density
- Spacing: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64
- Radius: xs 6 (badges) · sm 8 (inputs, rows) · **control 10 (buttons, inputs, rows — the canvas's radius; ADR-008)** · md 12 (cards) · lg 16 (dialogs, player) · pill 999
- Elevation: surface steps + 1 px borders; shadows only on floating menus/dialogs (0 12 32 rgba(0,0,0,.45))
- Density: Comfortable (default, row 56) / Compact (row 44)

### Motion
| Token | Duration | Curve | Use |
|---|---|---|---|
| fast | 120 ms | easeOut | hover, press, focus ring |
| base | 200 ms | easeOutCubic | panels, overlays |
| slow | 320 ms | easeInOutCubic | page transitions, hero |
| osd | 180 ms in / 240 ms out | easeOut | player OSD |
"Reduce motion" setting: durations 0–80 ms, no scale effects, no shimmer.

## Focus system (keyboard now, TV remote later)
- `FocusableSurface` wraps every interactive element: a **2 px accent ring with a 4 px glow at 25 %** (the canvas's values; ADR-008), **stroked outside the control** rather than drawn as a box shadow — a shadow is a filled rectangle behind the box, so on a transparent ghost button it fills the control instead of outlining it. On accent-filled surfaces the ring inverts to `textPrimary` with a 5 px glow at 35 %, because accent-on-accent is invisible. Tiles/cards scale to 1.03 (rows stay 1.0); the surface lightens one step
- Directional navigation with `FocusTraversalGroup` and directional focus intents; each pane is a group; Left/Right moves between panes; each pane remembers its last focused item
- Enter/Space activate · Esc back/close · Menu key or Shift+F10 opens the item menu
- **Where focus goes after a destination change** — the gesture decides, because switching a branch pulls focus into the new route's scope and it has to be placed deliberately either way:
  - a destination *shortcut* (Ctrl+1 … Ctrl+7, Ctrl+,) means "take me there", so focus lands on the first control of the screen that opened. Nobody should have to Tab back into the content after asking to go somewhere
  - Enter or Space on a **nav rail item** is the opposite gesture — the user is working in the rail and wants to keep browsing it — so the item they pressed keeps focus, and ↑ ↓ still walk the rail
- **Esc means "leave what you stepped into", in this order:** close whatever is open (search overlay, dialog, menu) → if focus is in the chrome (nav rail or top bar), return it to where the user was in the screen → if focus is already in the screen, do nothing. Esc never navigates to another destination: a keyboard user who is only exploring the chrome must not lose their place
- Mouse hover shows the hover style without stealing keyboard focus

## Core components (lib/design/components/)
AppButton (primary/secondary/ghost/danger; S/M/L; leading icon) · IconButton (tooltip with shortcut hint) · TextField (clear, validation, password reveal) · SearchField (Ctrl+K hint) · Chip / FilterChip · Badge (LIVE, SD/HD/FHD/4K, Original/Converted audio/Transcoded, NEW, Catch-up, Downloaded) · ChannelLogo (logo or generated monogram tile: initials on a color derived from the name hash) · ChannelRow (number, logo, name, now title, a 72 px progress bar **on the title line** after the ellipsized title as the canvas draws it — on the row's bottom edge it strikes through the title, favorite star) · PosterCard (2:3, rating, progress, focus scale) · LandscapeCard (16:9 for episodes and continue watching) · SectionHeader (title + See all) · HorizontalRail (virtualized, edge arrows on hover) · Skeletons (row, poster, card, text; reduced-motion aware) · EmptyState · ErrorState (human message, Retry, Details disclosure) · Banner (info/warning/error) · Toast (bottom center, 3 s, optional action) · Dialog / Sheet · Menu / ContextMenu · SegmentedControl · Slider (volume; seek with time bubble) · ProgressBar (3 px, rounded) · Kbd (keycap) · Tooltip · CastingBar · QualityBadge · ReconnectingPill · DownloadButton (Download → Queued → progress ring with % → Downloaded ✓; Paused and Failed states; menu: pause, cancel, delete download) · DownloadRow (artwork, title, S · E, progress bar, speed, time left, size, state; pause/resume/cancel/retry, Show in folder) · StorageMeter (downloads size and free disk space)

## App shell (desktop)
- **Nav rail** (72 px collapsed / 240 px expanded, remembered across restarts): app mark, Home, Live TV, Guide, Movies, Series, Favorites, Library, spacer, collapse toggle, Settings; active item gets a 3 px accent indicator bar at the rail's edge. **There is no Search item in the rail** — the canvas has none, and search is the top bar's field plus Ctrl+K / `/` (ADR-008). The collapse toggle is an addition to the canvas, which draws none; it sits above Settings. The indicator is always in the tree and transparent when unselected: a conditional sibling next to a focusable subtree destroys its focus node on every selection change
- **Top bar** (64 px, per the canvas; ADR-008): screen title · source switcher (chip with source name + account status dot) · global search (380 × 40 field, radius 10, with a Ctrl+K keycap) · sync status ("Syncing channels · 12,340") · download indicator (while downloads run: "↓ 2 · 34 %"; opens Library → Downloads) · cast button
- **Casting bar** (64 px, bottom; only while casting)
- Minimum window 1024 × 640. Below 1280 px: rail collapses and preview details compress. At 1600 px and above: wider preview pane.

## Screens
### 1. Onboarding
Welcome (name, one-line value, "Add your first source") → Choose type (three large cards: Xtream Codes / M3U URL / M3U file) → Credentials form with inline validation and "Test connection" → result card (Active · expires Nov 3, 2026 · 2 connections · server time zone) → Sync progress (animated steps with live counts: Categories ✓ · Channels 12,340 · Movies 8,021 · Series 1,204 · Guide continues in background) → "Pick what you watch" (category groups clustered by country/language prefix, search, select all/none; hidden ones can be shown later) → Home.

As built (Phase 2 step 6; decisions in ADR-009):
- **Routes:** a launch with no source opens on **Welcome** (`/welcome`, the approved sketch: one centred 560 px card). "Add your first source" pushes **Connect** (`/add-source`), so Back and Esc return to Welcome. "Open a file instead" opens the file dialog first and lands on Connect with M3U file selected and the path filled in. Start sync goes (not pushes) to **Sync** (`/source-setup/:id`), which has nothing behind it: Esc can't abandon a sync half-way. **Pick categories** is pushed on top of Sync; Back returns to the finished sync; Finish goes Home.
- **Frame:** every page after Welcome has the canvas header (36 px app mark, step indicator Source · Connect · Sync · Pick categories), a 34/42 title (`text.hero`), a subtitle, and a footer with the back action at the left and the forward action at the right edge. Forward actions carry a trailing arrow (`AppButton.trailingIcon`). Below 1100 px wide the margins drop to 32 px and Connect goes to one column, the result card under the form, scrolled into view when a test finishes.
- **Connect:** the three type cards are radio buttons (`ChoiceCard`). Focus starts in the first field. Errors appear once the user first tries to test, then follow the text. Messages: "Enter the server address." / "Enter a web address, like http://line.example.tv:8080." / "Enter the playlist URL." / "Choose a playlist file." / "Enter your username." / "Enter your password." A pasted `get.php` / `player_api.php` link in the server field is taken apart into server, username and password, with a helper line saying so. Name, User-Agent, guide link and live format (TS/HLS) sit behind "Advanced"; the name defaults to the server's host or the file's name. Enter in any field tests, or starts once a test has passed. The primary button is **Test connection** until a test passes, then **Start sync** (focused) with **Test again** beside it; any edit to what was tested (not a cursor move) goes back to Test connection.
- **Result card** (right column): before a test, what the test will do; while testing, a spinner and "Trying <host>"; after, **Connected** (Xtream: account status with a dot, expiry with "in N days" and amber under a week, connections, formats, time zone, and a warning banner for an account that isn't Active; M3U: entries, what they hold, the file's size) or a failure titled by kind — Sign-in refused, Access refused, Can't reach the server (the offline state), Not an Xtream panel / Not a playlist, File not found, Couldn't connect — with the redacted detail behind Details.
- **Sync:** the canvas rows. Xtream: Account, Categories, Channels, Movies, Series; a playlist: Playlist, Channels, Movies, Series (with episodes), whose counts grow together. The bar says what is happening ("Downloading movies" indeterminate, then "Saving movies 58%"). Rows not reached say "Waiting". There is **no TV guide row** until Phase 4 brings the guide: the canvas's "keeps loading in the background" would not be true yet. On success the bar turns green, "Done in 42 s." shows and focus moves to Pick categories; nothing advances on its own. On failure: an error banner, the stage that failed marked red, **Retry** (focused) and **Change details**. Cancel and Change details remove the half-added source and return to Connect filled in as it was.
- **Pick categories:** a tab per kind that has anything, with its category count; a 300 px filter; Select all / Select none at the right, acting on what the filter shows. Categories cluster by their leading tag (`UK | Sports`, `|AR| MBC`, `[FR] Cinéma`; a tag only one category uses is no cluster), groups in the provider's order, "No country tag" last, the first group open. Each group header has two targets: its checkbox (on, mixed, off) flips the whole group; the rest opens or closes it. Tiles show the name without its tag, and the whole tile is the switch, saved as it is flipped and shown at once. Filtering keeps each match in its cluster and opens every matching group. One cluster only: no header, a plain grid. Items without a category are always shown, and the footer says how many.

### 2. Home
Rows: Continue Watching (landscape cards with progress) · Favorite Channels (logo tiles with now title + progress) · Recently Watched Channels · Recently Added Movies · Recently Added Series. First run without history: hero card "Start watching" → Live TV.

### 3. Live TV (primary screen)
- **Categories pane** (260 px): Favorites pinned, All channels, then visible categories with counts; type-to-filter
- **Channels pane** (flex): virtualized ChannelRows; sticky filter field; sort by number/name; Enter = fullscreen; F = favorite; context menu (favorite, hide, rename, cast)
- **Preview pane** (~40 %): rounded 16:9 player with LIVE badge; now block (title, time range, progress, 3-line description) and next line; actions: Fullscreen, Favorite, Cast, Catch-up (if available)
- Moving selection previews after a 350 ms debounce. Optional muted preview setting.

### 4. Full-screen player
- OSD hides after 3 s without input; any input shows it; cursor hides with OSD
- Top gradient: channel logo, number, name, LIVE badge, resolution badge, clock
- Bottom gradient: now title, time range, progress; next program; controls: Play/Pause (VOD), −10 s / +10 s (VOD), Audio, Subtitles, Aspect, Stream info, Cast, Exit fullscreen; VOD seek bar with time bubble
- Left arrow opens a translucent channel panel for zapping without leaving fullscreen
- Up/Down zap with a top channel banner; digits open the number overlay; Backspace = last channel
- ReconnectingPill top center; failure card center (Retry / Next channel / Details)
- Double-click toggles fullscreen

### 5. Guide (EPG grid)
Header: day selector (Today, Tomorrow, weekdays), Now button, category filter. Grid: sticky channel column (logo + name, 220 px), time ruler with 30-minute ticks (1 hour = 240 px), program cells (title + time; current program highlighted; past programs dimmed), red vertical now line. 2D virtualization. Arrow keys move between programs; Enter opens a detail sheet (title, time, description, category; Watch, Catch-up).

### 6. Movies
Category chips + sort (Recently added / Name / Rating) + in-grid filter. PosterCard grid (min width 160 px), image fade-in, skeleton grid.
**Movie details:** blurred backdrop (or poster-derived gradient), poster, title, year · runtime · rating · genres, plot, director/cast; Play or Resume (with progress), Start over, Download, Favorite, Cast. Once downloaded, Play uses the local file and the poster shows the Downloaded badge.

### 7. Series
Same grid. **Series details:** backdrop, poster, title, metadata, plot, Favorite; season tabs with "Download season"; episode rows with 16:9 still, "S1 · E3", title, runtime, progress, DownloadButton, description on focus; primary button "Continue S2 · E4".

### 8. Favorites
Tabs: Channels (drag to reorder, groups) · Movies · Series. Empty: "Press F on anything to add it here."

### 9. Library
Movies and shows stored on this computer: downloads from IPTV sources and the user's own folders (behavior in docs/09).
- Tabs: Movies · Series · Videos (unsorted) · Downloads · Folders. Filter chips: All · Downloaded · Local folders. Same PosterCard / LandscapeCard grids as Movies and Series; items show a Downloaded badge or their folder name; unavailable items are dimmed with "Drive not connected"
- **Downloads:** active and queued DownloadRows (drag to reorder), Pause all / Resume all, recently finished, failed with Retry; StorageMeter at the bottom ("Downloads 42.3 GB · 118 GB free"). Empty: "Nothing downloading. Press D on a movie or episode to download it."
- **Folders:** Add folder (picker, or drop a folder on the window), folder list with item counts and last scan, Rescan. First run: "Add a folder with your own movies and shows" [Add folder]
- **Item menu:** Play / Resume, Cast, Show in folder, Edit details (title, year, type, show, season, episode), Hide, Remove from library, Delete file (confirmation; moves to the trash)
- **Offline:** when the internet is down, Home shows a Banner "You're offline — downloads and local files still play" [Open Library]

### 10. Search (Ctrl+K anywhere)
Overlay with instant results (150 ms debounce), grouped: Channels · On TV now & upcoming · Movies · Series · Library. Keyboard navigable. Recent searches.

### 11. Casting
Device picker dialog: scanning indicator, devices with icon, name, model, status; "Add by IP address"; "Device not showing?" help (same network, firewall, guest Wi-Fi). Casting view replaces the player: artwork/logo, "Playing on Living Room TV", title, now/next, QualityBadge with tooltip, play/pause, volume, Stop casting. Movies, episodes, and library items also get a seek bar; a seek past the part the relay has ready shows "Preparing…" for a few seconds.

### 12. Settings
Left sub-navigation: Sources (list; add, edit, refresh, remove; account details) · Playback (buffer preset, hardware decoding, deinterlace, preferred audio/subtitle languages, live format TS/HLS, User-Agent) · Casting (known devices with HEVC override, Dolby passthrough, low-latency mode, firewall help) · Downloads & library (download folder, downloads at a time, speed limit, resume on launch, keep awake while downloading, library folders with Rescan, hidden items) · Guide (EPG URLs, refresh time, retention days, time offset, channel mapping) · Categories (hide/reorder/rename per source) · Appearance (accent, density, reduce motion, 12/24 h clock) · Keyboard shortcuts · Data (clear image cache, clear guide, export/import settings) · About & diagnostics (version, log viewer, Copy diagnostics — redacted)

## Keyboard shortcuts (desktop)
| Key | Action |
|---|---|
| Ctrl+K or / | Search |
| Space | Play / pause |
| F, or Enter on a channel | Fullscreen |
| Esc | Back / exit fullscreen / close dialog |
| ↑ ↓ · PageUp PageDown | Previous / next channel (player) |
| ← → | Seek 10 s (VOD) · ← opens channel panel (live) |
| Shift + ← → | Seek 60 s |
| 0–9 | Channel number entry |
| Backspace | Last channel |
| M | Mute |
| A / S | Cycle audio / subtitles |
| I | Stream info |
| G | Guide |
| C | Cast |
| D | Download (movie or episode) |
| Ctrl+1 … Ctrl+7 | Home / Live TV / Guide / Movies / Series / Favorites / Library (focus follows into the screen) |
| Ctrl+, | Settings (focus follows into the screen) |

## States & microcopy
- Loading: skeletons that match the final layout
- Empty: specific + action ("No channels in this category." [Show hidden categories])
- Errors: human first line, optional Details:
  - "This channel isn't responding. We tried 6 times." [Retry] [Next channel]
  - "Your provider allows 1 connection and it's in use. Stop playback on other devices and try again."
  - "Your subscription expired on Nov 3, 2026."
  - "Can't reach the server. Check your internet connection."
  - "Not enough disk space. Free up 3.2 GB or choose another download folder."
  - "This movie is no longer available from your provider."
- Info toasts: "Downloads paused while you watch — your provider allows 1 connection."
- Background success toasts: "Guide updated · 142 channels matched" · "Download finished · <title>" [Play]
- Thousands separators; times follow locale and the 12/24 h setting

## Accessibility
- Text contrast ≥ 4.5:1 on its surface; focus ring ≥ 3:1 against surface and content
- All icon buttons have semantic labels and tooltips (tooltips show shortcuts)
- Minimum hit target 40 × 40 px
- Layouts hold at OS text scale 100 / 115 / 130 %

## Channel name cleanup (display only; raw name kept)
Strip leading country/language tags (`UK:`, `US |`, `[EN]`, `|AR|`) and trailing quality tags (HD, FHD, UHD, 4K, SD, H265 — shown as a badge instead); collapse whitespace; decode HTML entities. Users can rename any channel.
