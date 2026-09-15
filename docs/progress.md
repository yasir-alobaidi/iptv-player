# Progress

_Update at the end of every session._

## Current phase
Phase 0 — Environment & spikes. Steps 1–3 done; **step 4 is blocked on the sudo setup** (docs/setup.md sections 1–2) and a reboot.

## Done
- 2026-09-14: Planning docs and CLAUDE.md created
- 2026-09-14: Design canvas (Cinematic Dark, 9 screens): https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99
- 2026-09-15: Checked the laptop: nothing from docs/setup.md is installed yet (state table updated; Flutter install switched to the manual method)
- 2026-09-15: Plan fixes: exit criteria for every phase; Phase 0 asks about a Windows PC and tests casting a plain file
- 2026-09-15: Added downloads and a local library, both castable to Google TV (docs/09, ADR-005). New Phase 8; settings/polish is now Phase 9, packaging Phase 10
- 2026-09-15: Design canvas now has 18 screens (same link): Home, Movies grid, Search, Library, Downloads, Settings · Downloads and library, Favorites, onboarding Sync and Pick categories; Library nav item and download controls on the details screens
- 2026-09-15: Phase 0 step 1: `.gitignore` (generated design bundle untracked, kept on disk); `tools/fetch_ffmpeg.sh` run → FFmpeg 8.1.2 in `third_party/ffmpeg/linux-x64/`; Flutter 3.47.4 extracted to `~/develop/flutter` (not on PATH yet)
- 2026-09-15: Phase 0 step 2: ADR-002 written (package versions). Key findings: sqlite3_flutter_libs is end-of-life (use sqlite3 3.x, FTS5 included); extended_image instead of cached_network_image; media_kit provisional (last pub release Dec 2025, open Linux H/W-rendering issue #1404 on Flutter ≥ 3.38)
- 2026-09-15: Phase 0 step 3: `tools/media_samples/generate.sh` generates all 11 samples in docs/06 (checked with ffprobe)

## In progress
—

## Next
1. You: sudo setup (docs/setup.md sections 1–2), `fish_add_path ~/develop/flutter/bin`, reboot
2. Phase 0 step 4 — Spike A playback (Intel VA-API + NVIDIA NVDEC; media_kit pub 1.2.6 vs main@c533e44; fvp if needed); ask about a real Windows PC
3. Phase 0 step 5 — Spike B casting; needs the home network and the Google TV model
4. Phase 0 step 6 — ADR-003, ADR-004, GO / NO-GO

## Open questions
- Exact Google TV model (Chromecast with Google TV 4K or HD, Google TV Streamer, or a TV with Google TV built in)
- Windows test machine availability
- App name and icon (placeholder: "IPTV Player", Dart package `iptv_player`)
- Spike B says "Dart CLI … bonsoir", but bonsoir needs the Flutter SDK and can't run in a plain Dart CLI. Recommendation: the CLI uses multicast_dns (the documented fallback) plus manual IP; bonsoir is tested inside the Flutter app in Phase 7. Needs your OK (record in decisions.md)

## Known issues
- media_kit #1404: on Flutter ≥ 3.38 Linux video may fall back to software rendering ("VideoOutput: S/W rendering" in the log). Spike A must check this line on both GPUs
- BtbN's `latest` FFmpeg release is rebuilt daily; set `FFMPEG_TAG` to a dated autobuild tag to pin a build before packaging
- Cast docs show the HLS segment enums only as JS constants (`HlsSegmentFormat.FMP4`); the exact string sent on the wire (`"fmp4"` vs `"FMP4"`) must be confirmed on the device in step 5

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
