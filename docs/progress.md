# Progress

_Update at the end of every session._

## Current phase
Phase 0 — Environment & spikes (not started; system setup not done yet)

## Done
- 2026-09-14: Planning docs and CLAUDE.md created
- 2026-09-14: Design canvas (Cinematic Dark, 9 screens): https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99
- 2026-09-15: Checked the laptop: nothing from docs/setup.md is installed yet (state table updated; Flutter install switched to the manual method)
- 2026-09-15: Plan fixes: exit criteria for every phase; Phase 0 asks about a Windows PC and tests casting a plain file
- 2026-09-15: Added downloads and a local library, both castable to Google TV (docs/09, ADR-005). New Phase 8; settings/polish is now Phase 9, packaging Phase 10
- 2026-09-15: Design canvas now has 18 screens (same link): Home, Movies grid, Search, Library, Downloads, Settings · Downloads and library, Favorites, onboarding Sync and Pick categories; Library nav item and download controls on the details screens
- 2026-09-15: Handoff for the next session written to docs/handoff.md

## In progress
—

## Next
1. System setup from docs/setup.md (sudo steps by hand), then reboot
2. Phase 0 steps 1–4 — work on any network
3. Phase 0 step 5 (casting) — needs the home network with the Google TV; hotel and guest Wi-Fi usually block it

## Open questions
- Exact Google TV model (Chromecast with Google TV 4K or HD, Google TV Streamer, or a TV with Google TV built in)
- Windows test machine availability
- App name and icon (placeholder: "IPTV Player", Dart package `iptv_player`)

## Measurements
| Metric | Budget | Latest | Date |
|---|---|---|---|
| Zap p50 / p95 (fake provider) | ≤ 1.5 s / ≤ 3 s | — | — |
| Sync 50k channels + 30k movies | ≤ 60 s | — | — |
| XMLTV 300 MB import | ≤ 4 min | — | — |
| Idle memory with guide | ≤ 450 MB | — | — |
| H.264 1080p50 CPU (hwdec) | ≤ 15 % | — | — |
| 8 h soak memory growth | ≤ 50 MB | — | — |
| Library scan, 5,000 new files | ≤ 5 min | — | — |
| Download speed vs curl | ≥ 90 % | — | — |
