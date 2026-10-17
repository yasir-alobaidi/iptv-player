# 07 — Google TV version (v2)

Starts after desktop v1 ships. Same repository and Flutter app, new **TV shell**.

## Carries over unchanged
Data layer (Xtream/M3U/XMLTV, sync, drift DB) · domain interfaces · Riverpod providers · watchdog logic · name cleanup · EPG matcher · design tokens · most components (the focus system was built for this).

## New for TV
| Area | Approach |
|---|---|
| Shell | 10-foot UI; large targets; overscan-safe margins (48 dp horizontal, 27 dp vertical) |
| Input | D-pad only: arrows, Center/OK, Back, Home; plus Channel Up/Down, Guide, Info, Menu, number and media keys when present. No hover, no pointer; minimal typing |
| Player | Chosen in TV-0 (below) |
| Casting | Excluded via conditional imports / feature flag — the TV is the player |
| Downloads & library | Not on the TV in v2 (Chromecast with Google TV has 8 GB of storage). Downloads and local files reach the TV by casting from the desktop app |
| Performance | Low-end target: Chromecast with Google TV (2 GB RAM). Smaller image caches, shorter EPG retention (−2 h to +3 days), gradients instead of blurs, cheap list items |
| Lifecycle | Stop playback when the app goes to background (Home); restore state on return; handle audio focus |
| Manifest | LEANBACK_LAUNCHER intent category, an adaptive icon (Google TV's "Your apps" row shows it in a circle; the version code is the commit count, so an update's icon shows, ADR-028), 320×180 banner, `android.software.leanback` and `android.hardware.touchscreen` declared `required="false"` |
| Distribution | Sideloaded APK via adb for personal use |

## TV-0 — player engine spike (before any TV screens)
**Status (2026-10-15, ADR-025): done on the Bedroom TV** (a Chromecast with Google TV 4K, 2 GB, a 32-bit system). **media_kit stays**, drawing straight into the surface (`vo=mediacodec_embed`, `hwdec=mediacodec`): 720p50 went from 904 dropped frames in 28 s (mpv's `gpu` output copying every frame back) to none, at a third less CPU. Media3 isn't built: on this TV it would win only on AC-3/E-AC-3 passthrough (media_kit's libmpv opens no audio output for it on Android), HDR and native 4K (a texture goes through Flutter's 1080p layer); frame-rate matching can't help, the TV takes no 50 Hz mode. Revisit with Media3 for those. (Before: ADR-020, the toolchain, the project and the emulator, where mpv draws no picture.)

Compare on a real Google TV device:
| Criterion | (a) media_kit on Android (libmpv + mediacodec) | (b) native Media3/ExoPlayer plugin |
|---|---|---|
| Channel start and zap time | measure | measure |
| 4K HEVC HDR | measure | measure |
| AC-3 / E-AC-3 passthrough | test | test |
| Frame-rate matching (50 Hz content on 60 Hz TV) | likely unavailable | test Media3 frame-rate strategy with SurfaceView |
| MPEG-TS robustness, interlaced content | test | test |
| Memory on 2 GB device | measure | measure |
| Flutter OSD over video | texture — simple | platform view z-order — verify |
Decision rule: choose (b) if it wins on frame-rate matching or passthrough and overlays work cleanly; otherwise (a). Both implement `PlayerEngine`. Record the ADR.

## Already the TV's (ADR-025, before TV-1)
On a TV, gated on `FormFactor`; the desktop is unchanged: no Cast anywhere (the TV is the player); no keycaps, and hints in the remote's terms ("Hold OK"); no Library, downloads, keyboard page or playlist files; no volume or full-screen button in the player; the remote's Back, Channel Up/Down, Info, Guide and media keys; OK activates on release and held opens the item's menu; the first control focused at launch (as soon as the screen has one, until the first press: ADR-030); playback stops when the app leaves the screen and plays again on return; "Still watching?" after 4 hours with no key; a 64 MB image cache, a 150 MB picture folder and smaller player buffers (ADR-031), and no blur. **Settings → Data** (ADR-031) keeps Pictures, Guide, **Watch history** (Clear…) and **Database** (Compact), said of "this TV", by remote: Right from Data lands on the row level with it, OK opens Clear…'s choices with Keep focused (Up reaches them, OK picks one; a kind with nothing in it is passed by), Back keeps everything. The launch's tidy-up (docs/02, History upkeep) runs as on the desktop, with no downloads to wait for; a compaction holds a copy of the live data in memory while it runs (about its size), and is rare: once after the guide is cleared, and while a guide is in place only with half the file free.

**Leaving with Back ends the process (ADR-032):** Back on Home finishes the activity and its Flutter engine; `MainActivity` then ends the process, so the next launch starts clean (libmpv outlived the engine, and the next engine's first play crashed). A launch after Back is a cold start (Home in ~1 s).

**And since ADR-026 (the user's TV bug list, fixed on the Bedroom TV):** text typed on Bijou's own keyboard (`RemoteKeyboard`: OK on a field; Search opens with it beside its results, Right from the keys to the results and Left back, OK on a recent search runs it: ADR-029's addendum), Google TV's keyboard never opening; Left and Up move within a screen first and only at its edge reach the rail or the top bar (Search and the source switcher), Down returns; the focus never lost; no rail toggle; Home's rows end in See all; the player's OK shows a channel's controls and pauses a film, ↑/↓ in a film reach the controls, the arrows and OK belong to a focused control, Back returns to the picture; a film's seek bar is a stop above Play whose ←/→ seek, a hold in growing steps, and OK after seeking goes there and plays (ADR-030); full volume, never muted by the app; no Download anywhere, no Export/Import, no Hardware decoding, "this TV"; a round adaptive icon.

## TV screens (shared logic, new layouts)
1. Onboarding: large fields, on-screen keyboard, Test connection
2. Home: focus-driven rows with large cards; focused row scrolls into view
3. Live TV: category rail + channel list over a background preview; OK = fullscreen
4. Player: OK/Info shows OSD; Up/Down zap; Left = channel panel; channel and number keys; Back closes OSD, then exits
5. Guide: D-pad-optimized grid (larger rows, 1 hour = 360 dp)
6. Movies / Series grids and details
7. Search: on-screen keyboard with live results rows
8. Settings: TV lists and toggles

## TV phases
| Phase | Scope | Estimate |
|---|---|---|
| TV-0 | Engine spike + ADR; Android project setup; running on device | 3–5 days |
| TV-1 | TV shell, navigation, focus audit of shared components, remote key mapping | 1 week |
| TV-2 | Player, OSD, zapping, lifecycle on the chosen engine | 1 week |
| TV-3 | Live TV, Guide, Home layouts | 1 week |
| TV-4 | Movies, Series, Search, Settings layouts | 1 week |
| TV-5 | Low-end performance pass, on-device soak, packaging | 3–5 days |
