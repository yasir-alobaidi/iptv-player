# Decisions (ADR log)

Format: ID · date · status — decision, context, alternatives, consequences.

## ADR-001 · 2026-09-14 · Accepted — Flutter for desktop and Google TV
**Decision:** One Flutter app: desktop (Linux, Windows) first, Google TV second.
**Context:** Needs a polished UI, keyboard and remote navigation, Linux + Windows now and Android TV later. Video must run in native engines.
**Alternatives rejected:**
- Python + PySide6 + libmpv — excellent desktop fit, but no realistic Google TV path
- Electron / web player — Chromium can't decode AC-3/E-AC-3 (silent channels), MPEG-TS needs JS demuxing, no Cast support in Electron
- Kotlin Multiplatform + Compose — good TV story, weak desktop video embedding
- Separate native apps — duplicate work
**Consequences:** Dart across the codebase; libmpv via media_kit on desktop (fvp fallback); TV engine chosen in TV-0; casting uses our own Dart Cast v2 client and a bundled FFmpeg relay.

## ADR-002 · pending (Phase 0) — Package selection and versions

## ADR-003 · pending (Phase 0) — Desktop playback spike results

## ADR-004 · pending (Phase 0) — Casting spike results, device model(s), verified LOAD fields

## ADR-005 · 2026-09-15 · Accepted — Downloads and local library in v1
**Decision:** v1 downloads provider movies and episodes and manages a library of the user's own video files; both play offline and cast to Chromecast / Google TV. New Phase 8; settings/polish and packaging move to Phases 9 and 10. Spec: docs/09.
**Context:** The user wants to download movies and episodes (from IPTV or elsewhere), manage them in the player, and watch them on their Google TV.
**Alternatives rejected:**
- A separate media server (Plex, Jellyfin) — another app to install and run, with no link to IPTV watch progress
- Downloads inside the Google TV app — Chromecast with Google TV has 8 GB of storage; casting from the laptop covers the need
**Consequences:** Downloads share provider connection limits and pause for playback; casting gains a direct-file path with Range requests plus a relay path with seeking and WebVTT subtitles; four new tables via a migration; no online metadata lookups in v1; recording live channels stays a non-goal.
