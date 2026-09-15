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
| Manifest | LEANBACK_LAUNCHER intent category, 320×180 banner, `android.software.leanback` and `android.hardware.touchscreen` declared `required="false"` |
| Distribution | Sideloaded APK via adb for personal use |

## TV-0 — player engine spike (before any TV screens)
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
