# Progress

_Update at the end of every session._

## Current phase
Phase 0 — Environment & spikes. Steps 1–3 done. **Step 4 (Spike A, playback) in progress:** Intel is done and works well with a ~60-line media_kit patch (ADR-003). NVIDIA waits for a reboot (driver installed, not loaded). The Windows PC question is still open.

## Done
- 2026-09-14: Planning docs and CLAUDE.md created
- 2026-09-14: Design canvas (Cinematic Dark, 9 screens): https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99
- 2026-09-15: Checked the laptop: nothing from docs/setup.md is installed yet (state table updated; Flutter install switched to the manual method)
- 2026-09-15: Plan fixes: exit criteria for every phase; Phase 0 asks about a Windows PC and tests casting a plain file
- 2026-09-15: Added downloads and a local library, both castable to Google TV (docs/09, ADR-005). New Phase 8; settings/polish is now Phase 9, packaging Phase 10
- 2026-09-15: Design canvas now has 18 screens (same link): Home, Movies grid, Search, Library, Downloads, Settings · Downloads and library, Favorites, onboarding Sync and Pick categories; Library nav item and download controls on the details screens
- 2026-09-15: Phase 0 step 1: `.gitignore` (generated design bundle untracked, kept on disk); `tools/fetch_ffmpeg.sh` run → FFmpeg 8.1.2 in `third_party/ffmpeg/linux-x64/`; Flutter 3.47.4 extracted to `~/develop/flutter`
- 2026-09-15: Phase 0 step 2: ADR-002 written (package versions). Key findings: sqlite3_flutter_libs is end-of-life (use sqlite3 3.x, FTS5 included); extended_image instead of cached_network_image; media_kit provisional (last pub release Dec 2025, open Linux H/W-rendering issue #1404 on Flutter ≥ 3.38)
- 2026-09-15: Phase 0 step 3: `tools/media_samples/generate.sh` generates all 11 samples in docs/06 (checked with ffprobe)
- 2026-09-15: Setup verified after your sudo install: Flutter 3.47.4 on PATH, Linux toolchain ✓, VA-API (iHD) lists H.264, HEVC, and HEVC 10-bit, libmpv 0.34.1. The NVIDIA driver 595-open is installed but not loaded (no reboot since the install). You pushed steps 1–3 to GitHub
- 2026-09-15: ADR-006: Spike B discovers Cast devices with multicast_dns + manual IP (bonsoir needs Flutter; it's tested in the app in Phase 7). Step 5 prompt updated
- 2026-09-15: Phase 0 step 4, Intel: `spike/playback_spike` (media_kit player, loopback MPEG-TS server, stats overlay, automatic runs; `run_matrix.sh`, `summarize.py`, `grab_frame.sh`). **media_kit #1404 reproduced** on pub 1.2.6 and main@c533e44, Wayland and X11: S/W rendering, `vaapi-copy`, up to 530 dropped frames per 12 s. **`spike/vendor/media_kit_video_egl_display.patch` fixes it:** H/W rendering, zero-copy `vaapi` for H.264, HEVC, and HEVC 4K, 0 drops, ≤ 1.7 % CPU, zap p50/p95 320/597 ms; video confirmed on screen. All docs/03 libmpv names verified. Details in ADR-003

## In progress
- Phase 0 step 4: NVIDIA runs (after the reboot) and the Windows question; fvp comparison only if NVIDIA needs it

## Next
1. You: reboot (NVIDIA driver installed but not loaded), then check that `nvidia-smi` lists the GTX 1650 Ti
2. Spike A on NVIDIA: `spike/playback_spike/run_matrix.sh patched nvidia wayland`, plus `pub nvidia wayland` for comparison (the script sets the PRIME offload variables)
3. You: is a real Windows PC (not a VM) available?
4. Phase 0 step 5 — Spike B casting; needs the home network and your Google TV model
5. Phase 0 step 6 — finish ADR-003, write ADR-004, GO / NO-GO (including how we ship the media_kit patch)

## Open questions
- Exact Google TV model (Chromecast with Google TV 4K or HD, Google TV Streamer, or a TV with Google TV built in)
- Windows test machine availability
- App name and icon (placeholder: "IPTV Player", Dart package `iptv_player`)
- How to ship the media_kit fix (decided in step 6): a pinned fork of media_kit_video with our patch (recommended while upstream is silent), offering the patch upstream on #1404 (outward-facing, so only with your OK), or switching to fvp

## Known issues
- media_kit #1404: every unpatched build falls back to S/W rendering on this laptop (Wayland and X11). Our patch fixes it; upstream has no fix yet
- Zero-copy VA-API fails under XWayland (`GDK_BACKEND=x11`): Ubuntu 22.04's libva-x11 only supports DRI2 and XWayland only DRI3, so mpv uses `vaapi-copy`: dropped frames at 50 fps, audio underruns, VOD first frame about 5.5 s, zap p95 3.3 s. Native Wayland (the GTK default) is fine; a real Xorg session is untested
- libmpv 0.34.1: `deinterlace` is yes/no only (the app implements Auto from `video-frame-info/interlaced`); media_kit sets `subs-fallback`, which doesn't exist in 0.34.1 (one harmless error); every open logs `Failed to create file cache` (Phase 3: set `cache-on-disk=no`)
- `hwdec=auto-safe` doesn't GPU-decode MPEG-2 (SD MPEG-2 costs about 1 % CPU)
- BtbN's `latest` FFmpeg release is rebuilt daily; set `FFMPEG_TAG` to a dated autobuild tag to pin a build before packaging
- Cast docs show the HLS segment enums only as JS constants (`HlsSegmentFormat.FMP4`); the exact string sent on the wire (`"fmp4"` vs `"FMP4"`) must be confirmed on the device in step 5

## Measurements
| Metric | Budget | Latest | Date |
|---|---|---|---|
| Zap p50 / p95 (fake provider) | ≤ 1.5 s / ≤ 3 s | 320 / 597 ms — spike over loopback, Intel, patched media_kit (fake provider not built yet) | 2026-09-15 |
| Sync 50k channels + 30k movies | ≤ 60 s | — | — |
| XMLTV 300 MB import | ≤ 4 min | — | — |
| Idle memory with guide | ≤ 450 MB | — | — |
| H.264 1080p50 CPU (hwdec) | ≤ 15 % | 1.5 %, 0 drops — Intel, patched media_kit (unpatched: 11.6 %, 207 drops) | 2026-09-15 |
| 8 h soak memory growth | ≤ 50 MB | — | — |
| Library scan, 5,000 new files | ≤ 5 min | — | — |
| Download speed vs curl | ≥ 90 % | — | — |
