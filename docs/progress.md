# Progress

_Update at the end of every session._

## Current phase
Phase 0 — Environment & spikes. Steps 1–3 done. **Step 4 (Spike A, playback) nearly done:** Intel (Wayland and real Xorg) and NVIDIA (Xorg) all work well with the ~60-line media_kit patch, shipped as a pinned patched fork (ADR-003). Left: NVIDIA on native Wayland (needs a Wayland login). The Windows run is deferred until your PC is available.

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
- 2026-09-15: You rebooted and pushed step 4 (Intel). Decided: ship the fix as a pinned patched fork of media_kit_video; Windows run deferred (PC not available yet)
- 2026-09-15: Phase 0 step 4, Xorg session (the login after the reboot was "Ubuntu on Xorg"): **NVIDIA GTX 1650 Ti** (driver 595.91.07, PRIME offload) hits #1404 unpatched (`nvdec-copy`, up to 112 % of one core on HEVC 4K, zap 525/812 ms); **patched: zero-copy `nvdec`, 0 drops, ≤ 1.2 % CPU, zap 328/614 ms**, three runs agree. **Intel on real Xorg, patched: zero-copy `vaapi`, 0 drops, ≤ 2.3 % CPU, zap 378/624 ms**, video confirmed on screen, so only XWayland loses zero-copy. NVIDIA frame grabs failed (the script picked GTK's unmapped window of the same name), so NVIDIA's picture is checked by eye in the Wayland runs; `grab_frame.sh` now picks a viewable window and fails when no image is written

## In progress
- Phase 0 step 4: NVIDIA on native Wayland (`run_matrix.sh patched nvidia wayland` and `pub nvidia wayland`) after you log in with the "Ubuntu" session. fvp isn't needed

## Next
1. You: log out, choose "Ubuntu" (not "Ubuntu on Xorg") under the gear on the login screen, log in, start a new session
2. Spike A on NVIDIA, native Wayland: `spike/playback_spike/run_matrix.sh patched nvidia wayland`, then `pub nvidia wayland` (the script sets the PRIME offload variables)
3. Windows spike run when your Windows PC is available (pub media_kit; the patch is Linux-only)
4. Phase 0 step 5 — Spike B casting; needs the home network and your Google TV model
5. Phase 0 step 6 — finish ADR-003, write ADR-004, GO / NO-GO (set up the pinned patched media_kit_video fork)

## Open questions
- Exact Google TV model (Chromecast with Google TV 4K or HD, Google TV Streamer, or a TV with Google TV built in)
- Windows test machine: a real PC exists but isn't available yet (2026-09-15). The Windows spike run is deferred until it is; the step 6 GO/NO-GO covers Linux only and lists this as open
- App name and icon (placeholder: "IPTV Player", Dart package `iptv_player`)

## Known issues
- media_kit #1404: every unpatched build falls back to S/W rendering on this laptop (Wayland and X11). Our patch fixes it; upstream has no fix yet (NVIDIA too: unpatched falls back to `nvdec-copy` and heavy CPU)
- Zero-copy VA-API fails under XWayland (`GDK_BACKEND=x11` inside a Wayland session): Ubuntu 22.04's libva-x11 only supports DRI2 and XWayland only DRI3, so mpv uses `vaapi-copy`: dropped frames at 50 fps, audio underruns, VOD first frame about 5.5 s, zap p95 3.3 s. Native Wayland and a real Xorg session are both fine
- NVIDIA startup logs one `libmpv_render: after creating texture: OpenGL error INVALID_OPERATION` (no visible effect so far)
- Spike tooling: `run_matrix.sh` exits 0 even when the app can't open a display (seen once after the reboot, when the Wayland run started on an Xorg session); check the log has a `done` event
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
| H.264 1080p50 CPU (hwdec) | ≤ 15 % | Intel Wayland 1.5 % · Intel Xorg 2.3 % · NVIDIA Xorg 1.1 %, 0 drops — patched media_kit (unpatched Intel: 11.6 %, 207 drops; unpatched NVIDIA: 6.6 %) | 2026-09-15 |
| 8 h soak memory growth | ≤ 50 MB | — | — |
| Library scan, 5,000 new files | ≤ 5 min | — | — |
| Download speed vs curl | ≥ 90 % | — | — |
