# 00 — Overview

## What we're building
A personal IPTV player that connects to IPTV providers (Xtream Codes API and M3U playlists with XMLTV guides), plays live TV, movies, and series smoothly on a laptop, and casts to Chromecast / Google TV at original quality whenever the receiver supports the stream. It also downloads movies and episodes for offline viewing and manages the user's own video files, which play and cast the same way. A Google TV app follows the desktop release.

## Priorities (in order)
1. **Stable** — never crashes; recovers from bad streams and bad data on its own.
2. **Fast** — instant UI, quick channel starts, low CPU through hardware decoding.
3. **Beautiful** — polished dark media UI with excellent keyboard (and later remote) navigation.
4. **Feature-rich** — only once 1–3 hold.

## Platforms
| Platform | Release | Player engine | Casting |
|---|---|---|---|
| Linux x64 | v1 | media_kit (libmpv) | Yes (sender + FFmpeg relay) |
| Windows 10/11 x64 | v1 | media_kit (libmpv) | Yes (sender + FFmpeg relay) |
| Google TV / Android TV | v2 | Chosen in TV-0 spike (media_kit vs Media3) | No (the TV is the player) |
| macOS | not planned | — | — |

## v1 scope (desktop)
- Sources: Xtream Codes login, M3U URL, M3U file; multiple sources with a switcher
- Onboarding with live validation (account status, expiry, max connections)
- Background sync: categories, live channels, movies, series
- Category manager: hide, reorder, rename (onboarding lets the user pick categories up front)
- Live TV: 3-pane browser with preview player, now/next, favorites, fast zapping, number entry, last channel
- Full-screen player: auto-hiding OSD, channel overlay, audio/subtitle tracks, aspect modes, stream info
- EPG: XMLTV + Xtream short EPG, channel matching, guide grid, program search
- Movies & series: poster grids, details, resume, next episode, continue watching
- Home screen, unified search (FTS5), favorites, watch history
- Casting: discovery, device picker, direct fast path, FFmpeg relay (copy video, fix audio), transcode fallback, casting bar
- Downloads & library: download movies and episodes (queue, resume, connection-limit aware), folders of the user's own videos, offline playback, casting library items with seeking and subtitles
- Settings, diagnostics (redacted log export), appearance options
- Installers: Windows (MSIX or Inno Setup), Linux (AppImage)

## Non-goals for v1
DRM-protected services · Stalker/MAG portals · recording/DVR of live channels · online metadata lookups for local files · multi-view · cloud accounts/sync · phones · macOS · auto-update

## v1 success criteria
- 8-hour live playback soak with injected faults: no crash, memory growth within budget, automatic recovery
- Zap time p50 ≤ 1.5 s on the fake provider; ≤ 2.5 s on a real provider over Wi-Fi
- Sync 50k channels + 30k movies with no UI frame over 32 ms
- Casting: supported H.264/HEVC sources play with video untouched (`-c:v copy`); unsupported sources fall back automatically
- Downloads survive network drops and app kills without damaged files; downloaded and local files play with the network off
- Every screen fully usable with the keyboard alone

## Development hardware
Ubuntu 22.04 (fish shell), Intel UHD 630 (VA-API) + NVIDIA GTX 1650 Ti Mobile (NVDEC/NVENC), 12 threads, 16 GB RAM.
Windows testing must use real Windows hardware (VM GPU decoding isn't representative).
Cast target: the user's Google TV (exact model **TBD — record in docs/decisions.md during Phase 0**).
