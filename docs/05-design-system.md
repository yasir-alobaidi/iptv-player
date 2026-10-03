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
- A list that can grow to hundreds of items (a provider's categories) is **one Tab stop**: `FocusPane(tabStop: true)` sends Tab to the nearest control below the pane and Shift+Tab to the nearest above, and the arrows move inside it. The Settings Categories manager is not one yet: nothing sits below its list, and its rows' Rename buttons are reached with Tab
- Enter/Space activate · Esc back/close · Menu key or Shift+F10 opens the item menu
- **Where focus goes after a destination change** — the gesture decides, because switching a branch pulls focus into the new route's scope and it has to be placed deliberately either way:
  - a destination *shortcut* (Ctrl+1 … Ctrl+7, Ctrl+,) means "take me there", so focus lands on the first control of the screen that opened — first in reading order, as Tab reaches it, not in the order the controls were built (Phase 5 step 8: Home's Continue watching appears above rows built before it). Nobody should have to Tab back into the content after asking to go somewhere
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
- **Pick categories:** a tab per kind that has anything, with its category count; a 300 px filter; Select all / Select none at the right, acting on what the filter shows. Categories cluster by their leading tag (`UK | Sports`, `|AR| MBC`, `[FR] Cinéma`; a tag only one category uses is no cluster), groups in the provider's order, "No country tag" last, the first group open. Each group header has two targets: its checkbox (on, mixed, off) flips the whole group; the rest opens or closes it. Tiles show the name without its tag, and the whole tile is the switch, saved as it is flipped and shown at once. Filtering keeps each match in its cluster and opens every matching group. One cluster only: no header, a plain grid. Items without a category are always shown, and the footer says how many. **The category list is one Tab stop** (`FocusPane(tabStop: true)`, Phase 2 step 8): Tab goes in to the first header or tile, the arrow keys move between tiles and headers, and Tab leaves for the footer (Back, then Finish), Shift+Tab for Select none. A real provider had 146 live categories, and Finish sat 146 Tabs away.

### 2. Home
Rows: Continue Watching (landscape cards with progress) · Favorite Channels (logo tiles with now title + progress) · Recently Watched Channels · Recently Added Movies · Recently Added Series. First run without history: hero card "Start watching" → Live TV.

As built (Phase 5 step 7; ADR-012): each row only when it has something, in that order — Continue watching across every source (4 across, "Movie · 46 min left", "S2 · E4 · 31 min left", "S2 · E5 · Up next"), Favorite channels and Recently watched channels as `ChannelTile`s (5 across: logo, the programme on now, its bar), Recently added movies and series as the grid's posters (8 across). The first-run hero (until anything was watched, a channel included) says what the source holds, with **Open Live TV** first and Browse movies (or series). Each row is one Tab stop: ←/→ by card, ↑/↓ to the nearest card of the next row, Enter resumes a Continue card at once, plays a channel full screen (back on Home it stops) or opens a poster's page in its own branch (Esc there goes back to that grid); F favorite; the menu has Remove from Continue watching and Go to series. See all on Favorite channels (Live TV on Favorites) and the Recently added rows (the grid, newest first). Ctrl+1 lands on the first card. States: no source, skeleton rows, a first sync still running, an error with Retry, nothing to show. The hero is on the app's gradient, not the newest movie's backdrop (that picture needs its details fetched).

### 3. Live TV (primary screen)
- **Categories pane** (260 px): Favorites pinned, All channels, then visible categories with counts; type-to-filter
- **Channels pane** (flex): virtualized ChannelRows; sticky filter field; sort by number/name; Enter = fullscreen; F = favorite; context menu (favorite, hide, rename, cast)
- **Preview pane** (~40 %): rounded 16:9 player with LIVE badge; now block (title, time range, progress, 3-line description) and next line; actions: Fullscreen, Favorite, Cast, Catch-up (if available)
- Moving selection previews after a 350 ms debounce. Optional muted preview setting.

As built (Phase 3 step 5; ADR-010): the canvas's widths at 1440 px (248 / flexible / 540), the preview shrinking to 380 px on a smaller window and the list's filter and sort going under its title below 560 px. Categories: Favorites, All channels, the visible categories, Uncategorized, "N categories hidden · Manage". Both lists are one Tab stop with the arrows inside; ← and → move between the panes. **A click on a channel plays it in the preview; Enter plays it full screen; F toggles the favorite** (the shortcut table's "F = fullscreen" applies in the player, not the list); the row menu has Watch, favorite, Rename…, Hide channel and Cast… (Phase 7). Now/next come from the imported guide for every row on screen (a page in one query, refreshed each minute), with the provider's short EPG behind it for the channel previewed when the guide has nothing for it (Phase 4 step 4, ADR-011). A row with nothing says "No guide information"; a gap in the guide says "Next 9:00 PM · Title" in the row and "Nothing on right now" in the preview and the player. Every state: skeletons, an error with Retry, "Getting your channels…" during a sync, "No favorites yet", "No channels in this category." with Show hidden channels, "No channels match". Leaving Live TV stops playback.

As built in Phase 6 (ADR-013): rows show the **cleaned name** with its SD / HD / FHD / 4K tag after it (the canvas's small grey tag, raised on a focused row). Under Favorites, each **favorite group** is a list of its own (sketch A), in the user's order; on a favorites list the sort's first option reads **Order**. **One channel menu** everywhere a channel is (Live TV, the Guide's menu key, Home's tiles, Favorites, Search): Watch, the favorite, Add to group… (Move to group…), Rename…, Hide channel; Live TV adds **Show hidden channels**, which draws hidden rows dimmed with a **Hidden** tag. **Hiding shows at once and says "Channel hidden · Undo"** (Ctrl+Z undoes it too). The categories pane has its own menu (Hide category with Undo, Rename…, Move up, Move down) and Alt+↑/↓; its foot reads "3 categories · 2 channels hidden · Manage", and Manage opens Settings → Categories (the Hidden channels tab when only channels are hidden). **Tab goes round the screen:** the categories (one stop) → Manage → the filter → No. / A–Z → the list (one stop) → the preview's buttons. When the mouse wheel scrolls the focused row away, the list keeps the keyboard and gives it to the first row on screen.

### 4. Full-screen player
- OSD hides after 3 s without input; any input shows it; cursor hides with OSD
- Top gradient: channel logo, number, name, LIVE badge, resolution badge, clock
- Bottom gradient: now title, time range, progress; next program; controls: Play/Pause (VOD), −10 s / +10 s (VOD), Audio, Subtitles, Aspect, Stream info, Cast, Exit fullscreen; VOD seek bar with time bubble
- Left arrow opens a translucent channel panel for zapping without leaving fullscreen
- Up/Down zap with a top channel banner; digits open the number overlay; Backspace = last channel
- ReconnectingPill top center; failure card center (Retry / Next channel / Details)
- Double-click toggles fullscreen

As built (Phase 3 step 6; ADR-010): a page of its own (`/player`) that puts the window in full screen and takes it out on Esc, leaving the stream playing in the preview. ↑/PageUp previous and ↓/PageDown next in the list Live TV shows, wrapping; the banner at once, the stream 350 ms after the last press. Digits open the number overlay with the match shown as typed. ← opens the channel panel (a window of channels around the one playing, which takes the focus; the arrows and Enter belong to it while it is open). M mute, A / S cycle audio / subtitles, I stream info (the address masked), F or a double-click toggle the window's full screen. The failure card says what went wrong in our words and the server's, with Retry, Next channel and Details. Cast (after Stream info, or C) opens the device picker; once casting, the player hands over to the casting view (Phase 7 step 7).

As built for movies and episodes (Phase 5 step 6; ADR-012): the top shows the title, "S2 · E4 · Undertow", FHD/4K and 5.1 badges and the clock; the bottom the seek bar between the elapsed and remaining time (buffered range, time bubble) with Play/Pause, −10 and +10 under it, then the live player's controls. Space plays and pauses; ←/→ 10 s and Shift+←/→ 60 s move the bar at once and seek once the keys rest; Home starts over; the seek bar is not a Tab stop (the mouse drags it). "Resumed from 24:10 · Home starts over" for 5 s; "Preparing…" while a file opens; the OSD stays up while paused, seeking or opening. At 20 s left the Next episode card counts from 10 (a bar under Play now runs down); Esc cancels it, and the end card offers Play next episode / Back to series. The failure card says movie or episode, with Retry, Next episode and Details. Esc, a destination shortcut or the end leave the player, which stops the file and saves where it was.

### 5. Guide (EPG grid)
Header: day selector (Today, Tomorrow, weekdays), Now button, category filter. Grid: sticky channel column (logo + name, 220 px), time ruler with 30-minute ticks (1 hour = 240 px), program cells (title + time; current program highlighted; past programs dimmed), red vertical now line. 2D virtualization. Arrow keys move between programs; Enter opens a detail sheet (title, time, description, category; Watch, Catch-up).

As built (Phase 4 step 6; ADR-011): the canvas's measures, all in `AppGuideTokens`. The day pills (Today, Tomorrow, then "Thu 17", up to the guide's last day, as many as fit), **Jump to now** and the category filter (All channels, Favorites, the visible categories, Uncategorized) sit in a toolbar under the shared top bar. The grid is one Tab stop and a jump to the Guide (G, Ctrl+3) lands in it on what is on now: ←/→ between programmes, moving the view when they leave it; ↑/↓ between channels at the same time; PageUp/PageDown by a screen; Home to now; Enter or a click opens the detail sheet (title; "Today · 8:00 – 10:00 PM · Sport"; channel and number; description; **Watch channel** first, then Add to / Remove from favorites; a programme that has ended says **Already finished**). Watch plays full screen and the player zaps through the Guide's list; back on the Guide the stream stops. A title that began before the view gets a ‹. A gap of 5 min or more in a channel's guide is a dashed "No information" cell; a channel with no guide is the dashed "No guide information · Match to a guide channel" row, whose Enter opens the Match… picker over the grid. A sideways wheel, Shift + the wheel or a drag move through time. A page jump fills its new rows in over a few frames, each a still block until its turn. States: no source, skeletons, no guide yet (→ Settings → Guide), a first import running or failed, a guide that has run out (Refresh guide) or starts after today, an import running over the guide in use (a thin line along the card's top and its progress in the toolbar), a failed refresh ("Offline · guide from 2 h ago"), an empty filter. Catch-up waits for the archive phase.

### 6. Movies
Category chips + sort (Recently added / Name / Rating) + in-grid filter. PosterCard grid (min width 160 px), image fade-in, skeleton grid.
As built (Phase 5 step 4; ADR-012): the canvas's header ("All movies · 27 movies", the 220 px filter, Recently added / Name / Rating remembered per kind), the chips in one sideways-scrolling row (All, Favorites, the visible categories in the user's order, Uncategorized) with More ▾ pinned at the right, and the grid at 160 px and more per card (6 across at 1280, 7 at 1440, 10 at 1920): NEW for a week, a ★ mark top-right on a favorite, the progress line on a movie in progress, and the runtime added to the focused card's line once known. The grid is one Tab stop: arrows by card, PageUp/PageDown by a screen, Home/End, F favorite, Enter opens the title, Esc comes back to the same card. States: skeleton cards, getting your movies during a sync, a source with none, an empty category, no favorites, no match (Clear filter), an error with Retry.

**Movie details:** blurred backdrop (or poster-derived gradient), poster, title, year · runtime · rating · genres, plot, director/cast; Play or Resume (with progress), Start over, Download, Favorite, Cast. Once downloaded, Play uses the local file and the poster shows the Downloaded badge.

As built (Phase 5 step 5; ADR-012): the canvas's page with the fetched parts filling in (skeleton lines until then, the reason and Retry if the first fetch fails, "No description from your provider." when there is none); Play, or Resume from 1:12:40 and Start over between a minute and 95 % — this page is the resume prompt — and the favorite (F); the progress line with the time left. Download waits for Phase 8 (not shown); Cast is an icon button after Favorite (Phase 7), casting from the place Resume would; on Series details it casts the episode the primary action would play. Esc or the "‹ Movies" chip go back to the same card.

### 7. Series
Same grid. **Series details:** backdrop, poster, title, metadata, plot, Favorite; season tabs with "Download season"; episode rows with 16:9 still, "S1 · E3", title, runtime, progress, DownloadButton, description on focus; primary button "Continue S2 · E4".

As built (Phase 5 step 5; ADR-012): the canvas's two columns; the primary action is Play S1 · E1, Continue S2 · E4 or Play again (Continue watching's rule); the page opens on the season of the episode to continue with that episode the list's first Tab stop; Enter on an episode plays it from where it was left, its menu starts over or marks it watched. Download season and the rows' download buttons wait for Phase 8.

### 8. Favorites
Tabs: Channels (drag to reorder, groups) · Movies · Series. Empty: "Press F on anything to add it here."

As built (Phase 6 steps 5–6; ADR-013): the canvas's tabs with counts; on Channels, "Drag to reorder" and **New group**; each group's header (fold chevron, NAME, count, Rename), then **UNGROUPED** once any group exists; 60 px rows with grip, number, logo, name and quality tag, what's on with its bar, the time left in a 96 px column, and the star; "Press F on any channel, movie, or series to add it here or remove it." at the foot. Groups are per source; F adds at the end of the favorites in no group; a deleted group's channels stay favorites, in Ungrouped. The list is one Tab stop: Enter plays full screen, zapping through the favorites (back here the stream stops); **F removes with Undo**, which puts it back in its place; **Alt+↑/↓** moves a channel, past a group's edge into the next, or a group from its header; on a header Enter, ← and → fold and unfold; the menu key has the channel's menu or the group's (Rename…, Move up, Move down, Delete group — which asks nothing). The mouse drags by the grip (Flutter's gap marks the landing place, not the canvas's accent line yet). The order carries into Live TV's Favorites and its groups, the player's ↑/↓ from them, and Home's Favorite channels, and survives a restart and a re-sync. Movies and Series show the favorite titles on the shared grid; Enter opens a page, F removes. States: no source, skeletons, no favorite channel yet (Open Live TV), no favorite movie or series (Open Movies / Series), an error with Retry.

### 9. Library
Movies and shows stored on this computer: downloads from IPTV sources and the user's own folders (behavior in docs/09).
- Tabs: Movies · Series · Videos (unsorted) · Downloads · Folders. Filter chips: All · Downloaded · Local folders. Same PosterCard / LandscapeCard grids as Movies and Series; items show a Downloaded badge or their folder name; unavailable items are dimmed with "Drive not connected"
- **Downloads:** active and queued DownloadRows (drag to reorder), Pause all / Resume all, recently finished, failed with Retry; StorageMeter at the bottom ("Downloads 42.3 GB · 118 GB free"). Empty: "Nothing downloading. Press D on a movie or episode to download it."
- **Folders:** Add folder (picker, or drop a folder on the window), folder list with item counts and last scan, Rescan. First run: "Add a folder with your own movies and shows" [Add folder]
- **Item menu:** Play / Resume, Cast, Show in folder, Edit details (title, year, type, show, season, episode), Hide, Remove from library, Delete file (confirmation; moves to the trash)
- **Offline:** when the internet is down, Home shows a Banner "You're offline — downloads and local files still play" [Open Library]

### 10. Search (Ctrl+K anywhere)
Overlay with instant results (150 ms debounce), grouped: Channels · On TV now & upcoming · Movies · Series · Library. Keyboard navigable. Recent searches.

As built (Phase 6 steps 3–4; ADR-013): the canvas's 760 px panel: the 64 px query bar with "6 results" and the Esc keycap; CHANNELS, ON TV NOW & UPCOMING, MOVIES, SERIES (Library comes with Phase 8), up to 5 rows each, the browsed source first and every other source after (rows name theirs when there are two or more); 52 px rows with the typed words in bold where they start a word, LIVE on a programme on now, the cursor's row raised with an Enter keycap. Each word typed must start a word of the name; accents and case don't matter; hidden channels (and a hidden category's, unless favorites) are left out. **The keyboard stays in the field:** ↑/↓ and PageUp/PageDown move the cursor, Tab / Shift+Tab jump by group, Enter opens, the menu key has the channel menu (plus Show in Live TV), Esc closes. **Enter:** a channel or a programme on now plays full screen (Esc comes back where search was opened); an upcoming programme opens the Guide on it with its sheet open; a movie or series opens its page; **Show all in Live TV / Movies / Series** opens the screen filtered by the text. The text goes into the recent searches (the last 8) when a result is opened; with no text the recent searches show (Enter searches again, Delete removes one, Clear), or "Channels, what's on now and next, movies and series, from every source." No results: "No results for "harbour"", and when hidden channels match, "2 hidden channels match." with **Show in Settings** (the Hidden channels tab). A failed search has Retry; no source, Add a source; a first sync running says the catalogue is still arriving. A search answers within 31 ms on the 50,000-channel catalogue with a 600,000-programme guide (docs/06).

### 11. Casting
Device picker dialog: scanning indicator, devices with icon, name, model, status; "Add by IP address"; "Device not showing?" help (same network, firewall, guest Wi-Fi). Casting view replaces the player: artwork/logo, "Playing on Living Room TV", title, now/next, QualityBadge with tooltip, play/pause, volume, Stop casting. Movies, episodes, and library items also get a seek bar; a seek past the part the relay has ready shows "Preparing…" for a few seconds.

As built (Phase 7 step 7; ADR-014): the canvas's `Cast device picker` and `Casting` frames and the plan's sketches A–E; tokens in `AppCastTokens`.
- **Cast:** the top bar's button (Cast, or Casting with the connected icon), the player's OSD after Stream info, Movie and Series details, the channel menu's Cast…, and **C** anywhere but a text field.
- **Picker** (540 px dialog): "Cast to a device", what will be cast; "Looking for devices on your network…" (after 10 s with none: "No devices found yet. Still looking…" and the troubleshooting list open); device rows (44 px icon tile, name, model line with what is known or learned, status: Available · Casting · Not answering · Busy · playing music, the last two dimmed); one Tab stop with the first device focused, Enter casts, Esc closes; "Add device by IP address"; "Device not showing?" with Troubleshoot. While casting, "Casting to Living Room TV" with Stop casting heads it. Banners for a build without FFmpeg and for no network.
- **Add a device by address** (sketch E): one field, a spinner while it looks, then the device found and kept, or why not.
- **Casting view:** an overlay on the content pane — the rail, top bar and bar stay, the screen under it keeps its place and Esc goes back to it while the cast goes on. The card: 360 px artwork (logo, poster or still, with the hero shadow), the kicker (PLAYING ON / CONNECTING TO / CASTING TO LIVING ROOM TV), number and name over the programme (or the title), its times and bar (a file: its place, length and seek slider, "Preparing…" while a seek starts the relay again), the QualityTag with the details line and the plan's sentence, then the controls: previous / next channel (live) or play-pause, −10 s, +10 s (files); the volume (disabled with "This TV's volume is set with its own remote" on a fixed-volume TV); Stop casting. Keys: ↑/↓ PageUp/PageDown zap (live), ←/→ seek 10 s, Space pause (files), M mute, Esc back. States (sketch D): connecting and preparing with a spinner; the Reconnecting pill; failed in docs/03's words with Try again, Play here and Details. Centred on wide windows.
- **Casting bar** (64 px, under the content): logo or monogram, the title, "Casting to Living Room TV · Original quality" (or Connecting…, Preparing…, Couldn't play, Reconnecting…), Pause for files, Stop casting; its text opens the view.
- **Live TV while casting** (sketch B): the preview pane shows what the TV plays (no stream of its own); a click chooses, "Play on Living Room TV" or Enter plays it there.
- **Toasts:** quiet fallbacks ("Now converting the audio for Living Room TV") and ends the user didn't ask for ("Living Room TV started YouTube"; "Lost the connection to Living Room TV" in the error tone).

### 12. Settings
Left sub-navigation: Sources (list; add, edit, refresh, remove; account details) · Playback (buffer preset, hardware decoding, deinterlace, preferred audio/subtitle languages, live format TS/HLS, User-Agent) · Casting (known devices with HEVC override, Dolby passthrough, low-latency mode, firewall help) · Downloads & library (download folder, downloads at a time, speed limit, resume on launch, keep awake while downloading, library folders with Rescan, hidden items) · Guide (EPG URLs, refresh time, retention days, time offset, channel mapping) · Categories (hide/reorder/rename per source) · Appearance (accent, density, reduce motion, 12/24 h clock) · Keyboard shortcuts · Data (clear image cache, clear guide, export/import settings) · About & diagnostics (version, log viewer, Copy diagnostics — redacted)

As built (Phase 2 step 7; decisions in ADR-009):
- **Frame (canvas `Settings`):** a 248 px sub-navigation card (overline "SETTINGS", 40 px items, the selected one on `surface3` with a 3 px accent bar) and the section card beside it (title `panelTitle`, a subtitle, actions at the right, a footer note). Sections a later phase builds show "Phase N" in the list and an empty state in the card. Choosing a section keeps focus in the list, as the nav rail does; Right or Tab moves into the section.
- **Sources** (the approved sketch): a card per source — drag handle; a status dot (green: last sync fine; amber: expiring within a week; red: last sync failed, expired or not Active; accent: syncing; grey: never synced); the name with a BROWSING badge on the source the switcher picked (only with two or more); at the right, type · account ("Xtream · Active · exp Nov 3", "Expired Sep 1, 2026") and "never synced" until a sync has worked; below, what it holds and when it synced ("12,340 channels · 8,021 movies · synced 12 min ago"), the live progress while a sync runs, or "Last attempt failed: <reason>" in red. Actions: **Refresh** (Retry after a failure, Sync now before a first sync, Cancel sync while running — one button, so focus stays), **Edit**, and **⋯**: Browse this source, Categories…, Account details…, Move up / Move down (Alt+↑ / Alt+↓), Remove…. Remove asks first with **Keep** focused. Account details is a dialog of everything non-secret (server, username, status, expiry with days left, connections in use, formats, time zone, live format, what it holds, the last sync, the refresh interval, when it was added). **Add source** starts the onboarding flow, which ends back here.
- **Edit source:** Connect's form without the step indicator or the type cards; the name field is out in the open (renaming is the commonest edit); the password is left empty ("Saved; leave empty to keep it"). Test connection sits beside **Save**. Save saves at once unless the server, sign-in, playlist or User-Agent changed; then it tests first ("Save tests the new details first.") and a new sign-in syncs again.
- **Categories** (the approved sketch): a source menu at the top right when there are two or more sources; tabs per kind with counts; a filter; **Show hidden** (on by default; off lists only what shows); **Provider's order** once the user has reordered; Select all / Select none over what the filter shows. A flat list of 48 px rows: drag handle, the switch with the name ("was <provider name>" after a rename), the count, and a rename button. Alt+↑ / Alt+↓ moves the focused row, past its shown neighbour when the list is filtered. Rename is a dialog with the name selected in its field; "Use provider's name" undoes a rename. Footer: "7 of 10 shown · 12 channels without a category are always shown · Hidden categories stay hidden after a re-sync."
  - **Phase 6 (ADR-013):** the list is **one Tab stop**, arrows inside; Enter or Space flips a row, Alt+↑/↓ moves it, and the menu key has Rename…, Move up and Move down (the row's rename button is the mouse's). Once a channel is hidden, a **Hidden channels** tab with its count joins Live TV · Movies · Series (sketch B): a filter, **Show all**, rows of number, logo, name, category and Show; one Tab stop, Enter shows the channel and the focus moves to the next; "Hidden channels are left out of Live TV, the Guide, Search and Home. They stay hidden after a re-sync."
- **Guide** (the approved sketch; Phase 4 step 5, ADR-011): a source menu at the top right with two or more sources. Three setting rows in Playback's layout, then the channel list:
  - **The guide refreshes by itself** when it is a day old or missing: after the launch's syncs, hourly, and after each sync, one source at a time; a finished one says "Guide updated · N channels matched" (the visible channels; the source's name too with two or more sources). A failed one says so only here; the next try waits six hours, and Refresh guide tries at once.
  - **Guide data:** where the guide comes from ("From your provider's XMLTV · updated 2 h ago" — the live guide's time, not a later failed refresh's) and "1,284 of 1,310 channels matched · 142,880 programmes until Sep 28", with **Refresh guide**. Other states in the same row: **Import guide** (primary) before the first import; the running import's line ("Importing the guide · 12.4 MB of 80.0 MB · 1,204 programmes"), a thin progress bar and **Cancel**, with "The guide in use stays until the new one is in." when there is one; a failed first import in red with **Try again**; a failed refresh in amber under the guide it left in place; a playlist that names no guide, or a source without a guide address, with **Edit source**; a locked keyring with **Try again**. An import that couldn't even start (nothing recorded) says why in a banner.
  - **Keep** (every source): a menu button, "7 days" — 1, 2, 3, 5, 7, 10 or 14 days ahead, plus yesterday. A change re-imports every source that has a guide, one at a time.
  - **Time offset · <source>:** one focus stop, ← / → (or − / +) by half an hour from −12 h to +12 h, the chevrons beside the value for the mouse, Enter back to None; a slider to assistive tech. It is saved 1.2 s after the last step, so stepping to +2 h is one re-import; leaving the page saves a step that hadn't settled.
  - **Channels:** segments **Unmatched · Matched by you · All** with counts, and a filter. Counts and lists cover the channels the user can see — hidden channels and channels in hidden categories are left out (they are still matched) — said in the footer, with "Your matches stay through every refresh and sync." Rows (56 px): number, logo, name, what it is attached to ("No guide channel", "→ BBC One · by name", "→ bbc1.uk · yours, not in this guide"), and Match… / Change. The list is one Tab stop, ↑/↓ inside, Enter on a row opens the picker; the row's button is for the mouse and not a Tab stop. After a match the list is read again and swapped in whole, so under Unmatched the matched row leaves and the focus lands on the next one. Before any guide the list is an empty state: "No guide to match against yet".
  - **The Match… picker:** a dialog titled "Match <channel>", "Now: <what it is attached to>", a search field that keeps the focus (↑/↓ and PageUp/PageDown move the highlight as in a command palette, Enter matches the highlighted one, Esc cancels), then up to 50 guide channels ranked by name against the channel's (BEST MATCH badge on an exact normalized name, CURRENT on the one it has now). **Undo my match** (only on the user's own) drops the mapping and lets the matcher decide again. A match shows at once in the row and is saved, then the source is rematched so Live TV and the player follow.
  - **From Live TV:** the preview's "No guide information" has a **Match to a guide channel** button, which opens this page for the channel's source with its picker on top.
- **Top bar:** the source chip shows the source being browsed and its dot; with two or more sources it opens a menu of them (a check on the current one) and "Manage sources…", otherwise it opens Settings → Sources. The sync line shows while any source syncs ("Syncing channels · 12,340"; "Northwind TV · Syncing movies · 8,021" with several sources). **A banner under the top bar** warns about the source being browsed: the provider refused the saved sign-in (**Edit source**), the subscription expired or the account isn't Active, or it ends within 7 days (**Open Sources**); it can be closed for the session.
- **Errors say what the server answered.** Wherever a failure is shown (Connect's result card, the Sync banner, a source card's "Last attempt failed", Account details, the error toast), a failure with an HTTP status adds `serverAnswer()`: "The server answered HTTP 503 (Service Unavailable)." after our own words. A 5xx is **Server error** / "The server answered with an error", never "Can't reach the server", which is kept for no answer at all. The technical detail stays behind **Details** (hard rule 4).
- **Casting** (Phase 7 step 7, sketch C; ADR-014): "Applies to the next thing you cast."; DEVICES — each kept device with its model and address, Forget, HEVC Automatic / Yes / No and what it learned with Reset; Dolby passthrough, Low-latency mode, Smooth interlaced; "Your TV reaches this computer on ports 38400–38499." with Firewall help; Add device by address at the top right. On Windows, before the first relay, a dialog says the firewall prompt is coming and why (once).
- **In-field buttons:** a text field's Clear button is not a Tab stop (Tab goes field to field); the Show-password toggle is, with the standard focus ring.

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
| Menu key or Shift+F10 | The focused item's menu (a channel, a category, a group, a source) |
| Alt+↑ / Alt+↓ | Move the focused item (categories, favorites, groups, sources) |
| Ctrl+Z | Undo, while the toast that offers it shows (hide, remove from favorites) |

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
- Toasts show over every screen and overlay (search, a dialog, the full-screen player), one at a time for 3 s; an action ends its toast. Optimistic changes say so with Undo: "Channel hidden · Undo", "Category hidden · Undo", "Removed <channel> from favorites · Undo" — Ctrl+Z runs it (ADR-013 step 7).
- Menus close before their item runs (120 ms fade), so nothing changes under a closing menu.
- Thousands separators; times follow locale and the 12/24 h setting

## Accessibility
- Text contrast ≥ 4.5:1 on its surface; focus ring ≥ 3:1 against surface and content
- All icon buttons have semantic labels and tooltips (tooltips show shortcuts)
- Minimum hit target 40 × 40 px
- Layouts hold at OS text scale 100 / 115 / 130 %

## Channel name cleanup (display only; raw name kept)
Strip leading country/language tags (`UK:`, `US |`, `[EN]`, `|AR|`) and trailing quality tags (HD, FHD, UHD, 4K, SD, H265 — shown as a badge instead); collapse whitespace; decode HTML entities. Users can rename any channel.

As built (Phase 6 step 1; ADR-013): the cleaned name and the badge are stored (`channels.clean_name`, `quality`), filled by sync; a screen shows the rename, else the cleaned name, else the provider's name, and sorts and filters by the same. Leading tags go only where a separator or brackets mark them (`TV 5 Monde`, `ABC News` keep their first word). **Resolution tags at the end become the badge** — plain, superscript (`ᴴᴰ`), bracketed (`(HD)`), `Full HD`, or as lines (`1080p` → FHD, `720p` → HD, `576i` → SD, `2160p` / UHD → 4K). **Departure:** codec, frame-rate and Backup/VIP tags stay in the name (`Sky Sports F1 HEVC`), so two feeds of one channel don't read the same. `+1`, numbers, the provider's capitals and a name's own punctuation (`Canal+`, `E!`) are kept; a name that is nothing but tags stays as the provider wrote it. Rename shows the provider's name under the field; "Use provider's name" goes back to the cleaned one. Movie and series names are left as the provider wrote them.
