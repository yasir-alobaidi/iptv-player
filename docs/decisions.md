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

## ADR-002 · 2026-09-15 · Accepted (media_kit settled by ADR-003) — Package selection and versions
**Decision:** Toolchain Flutter 3.47.4 stable (Dart 3.13.3). Packages below, checked on pub.dev and GitHub on 2026-09-15 (latest version, release date, platform tags, open issues). Constraints use `^` on these versions; `pubspec.lock` is committed.

| Need | Package (version) | Released | Notes |
|---|---|---|---|
| State | flutter_riverpod 3.4.3 · riverpod_annotation 4.0.7 · riverpod_generator 4.0.9 (dev) · riverpod_lint 3.1.9 (dev) | 2026-09-03 | Riverpod 3 code-gen |
| Routing | go_router 18.0.1 | 2026-09-02 | Flutter favorite; needs Flutter ≥ 3.44 |
| Database | drift 2.35.0 · drift_dev 2.35.0 (dev) · sqlite3 3.6.0 | 2026-09-09 / 09-13 | **sqlite3_flutter_libs dropped:** it is end-of-life (0.6.0+eol, does nothing). sqlite3 3.x bundles SQLite through build hooks; the default binaries are compiled with `SQLITE_ENABLE_FTS5`. Linux binaries need glibc ≥ 2.24 |
| HTTP | dio 5.11.1 | 2026-09-04 | |
| Models | freezed 4.0.1 (dev) · freezed_annotation 3.1.0 · json_serializable 6.14.1 (dev) · json_annotation 4.12.0 · build_runner 2.16.1 (dev) | 2026-08/09 | |
| Desktop video | media_kit 1.2.6 · media_kit_video 2.0.1 · media_kit_libs_video 1.0.7 | 2025-12-13 | **Settled by ADR-003:** pub 1.2.6 with our patched media_kit_video from `third_party/`. Checked 2026-09-15: the last pub release is 9 months old; main (c533e44, 2026-08-30) has unreleased Linux fixes (#1440 raster-thread block, #1446 memory leaks). Open Linux issue #1404: on Flutter ≥ 3.38 the H/W render path can fall back to S/W rendering (EGL context not current on the platform thread), confirmed by several users on Intel, AMD, NVIDIA. Also #1345 tearing on 3.38+. Spike A tests pub 1.2.6 and main@c533e44 and checks the `VideoOutput` log line; if H/W rendering or hwdec fails, compare **fvp 0.38.1** (2026-08-17). On Linux media_kit uses the system libmpv (Ubuntu 22.04: 0.34.1), which the AppImage must bundle (Phase 10) |
| mDNS | bonsoir 7.1.5 | 2026-08-11 | Linux uses Avahi over D-Bus. Watch Windows #156 (possible deadlock in `BonsoirDiscovery.stop()`). Fallback multicast_dns 0.3.3+1 + manual IP |
| Local HTTP | shelf 1.4.2 · shelf_router 1.1.4 | 2024-06 / 2023-05 | Old releases, but dart-lang maintained and stable; no open blockers |
| Cast protobuf | protobuf 6.1.0 · protoc_plugin 25.1.0 (dev tool, generated code committed) | 2026-09-11 | Needs `protoc` once (apt `protobuf-compiler`). If that's a hassle, the fallback hand-written encoder is small: CastMessage has 7 fields |
| Window | window_manager 0.5.2 | 2026-07-04 | Linux issues to check in Phase 1: #585 crash on exit (Fedora KDE X11), #561 title bar on KDE Wayland |
| Secrets | flutter_secure_storage 11.1.1 | 2026-09-11 | libsecret on Linux; no open Linux issues |
| Images | **extended_image 10.1.0** | 2026-07-12 | Chosen over cached_network_image 4.0.0, which depends on flutter_cache_manager → sqflite (no native desktop backend) and limits its disk cache by object count, not bytes. docs/06 needs a 500 MB disk cap: we add a small size-based cache sweeper |
| Vector icons | **flutter_svg 2.3.0** | 2026-09-15 | Added in Phase 1 (ADR-008): the icon set is the design canvas's own SVGs, extracted by `tools/extract_icons.dart` and addressed through the `AppIcons` enum. `crypto` joins the dev dependencies for the extractor's markup hashes |
| XML | xml 7.0.1 | 2026-04-25 | Event/streaming API for XMLTV |
| Pickers | file_selector 1.1.0 | 2025-11-21 | flutter.dev package; fallback file_picker 13.0.0 |
| Drag and drop | desktop_drop 0.8.4 | 2026-09-01 | |
| Folder watching | watcher 1.2.1 | 2026-01-08 | inotify on Linux (watch limit: fall back to rescans) |
| Standard folders | path_provider 2.1.6 · xdg_directories 1.1.0 | | |
| Native calls | ffi 2.2.0 · win32 6.4.0 | | statvfs, GetDiskFreeSpaceExW, IFileOperation |
| Logging | logger 2.8.0 | 2026-09-05 | |
| Lints | very_good_analysis 11.0.0 | 2026-09-03 | |
| Tests | mocktail 1.0.5 (+ SDK flutter_test, integration_test) | 2026-04-10 | |

**Bundled FFmpeg:** BtbN/FFmpeg-Builds, GPL variant, branch 8.1 (tested: n8.1.2-52, 2026-09-14), fetched by `tools/fetch_ffmpeg.sh` with SHA-256 checks. Linux build depends only on glibc ≥ 2.28. Includes libx264, libx265, h264/hevc NVENC, VA-API, QSV, AC-3/E-AC-3/MP2, WebVTT. GPL is fine for a personal app; revisit if the app is ever distributed.
**Context:** Phase 0 step 2. Priorities stable → fast; prefer maintained packages with desktop support.
**Alternatives rejected:** sqlite3_flutter_libs (EOL); cached_network_image (sqflite dependency on desktop); johnvansickle static FFmpeg (no NVENC/VA-API/QSV).
**Resolution check (2026-09-15, Flutter 3.47.4):** every package above resolves together with `flutter pub get` at its latest version (`pub outdated`: direct dependencies all up to date). media_kit from git main `c533e446755f51cf53c7e57aea873f2aa5355f81` also resolves, but only when **all eight** media_kit packages come from git at that SHA via `dependency_overrides`: media_kit, media_kit_video, media_kit_libs_video, media_kit_libs_linux, media_kit_libs_windows_video, media_kit_libs_android_video, media_kit_libs_ios_video, media_kit_libs_macos_video (paths `media_kit`, `media_kit_video`, `libs/universal/…`, `libs/<platform>/…`). Main needs media_kit_libs_windows_video 1.0.12, which isn't on pub.
**Consequences:** media_kit stays provisional until Spike A (ADR-003). If we must use media_kit from git, pin that SHA for all eight packages in `pubspec.yaml` and recheck pub releases every phase.

## ADR-003 · 2026-09-15 · Done for Linux (Windows deferred) — Desktop playback spike results
**Setup:** HP laptop, Ubuntu 22.04.5, kernel 6.8, GNOME on Wayland for the first Intel runs (X11 runs there use XWayland via `GDK_BACKEND=x11`); after the NVIDIA driver install and reboot the session was "Ubuntu on Xorg", used for the real-Xorg and NVIDIA Xorg runs; the NVIDIA Wayland runs used a later "Ubuntu" (Wayland) login; Intel UHD CometLake-H (iHD 22.3.1), GTX 1650 Ti. Flutter 3.47.4 release build (Impeller, OpenGL ES). media_kit uses the system libmpv 0.34.1 with FFmpeg 4.4.2. Spike: `spike/playback_spike` plays each sample as an endless MPEG-TS stream (`-re -stream_loop -1 -c copy`) over loopback, with the Balanced preset and `hwdec=auto-safe`. Per sample: 5 s warm-up, then a 12 s measuring window (45 s for the codec switch). Results in `spike/playback_spike/results/`; `summarize.py` prints the tables.

**Finding 1: media_kit #1404 reproduces on every unpatched build.** Both pub 1.2.6 and main@c533e44, on both Wayland and X11, log `VideoOutput: EGL display or context is invalid` and then `S/W rendering`. On Flutter ≥ 3.38 no EGL context is current on the platform thread where the plugin looks for one. Decoding stays on the GPU but only in copy-back mode (`vaapi-copy`), and the CPU draws every frame: 1.1–1.6 cores busy at 50 fps, and 140–530 dropped frames per 12 s on HEVC 1080p50 and HEVC 4K. main's Linux render code is identical to 1.2.6; it only removes the drops on H.264 1080p50.

**Finding 2: a ~60-line patch fixes it.** `spike/vendor/media_kit_video_egl_display.patch` (applied by `run_matrix.sh patched`): when no EGL context is current, get the EGLDisplay from GDK (`eglGetPlatformDisplayEXT` with the Wayland or X11 native display) and choose an ES2 RGBA8 config. The log confirms the raster thread and mpv use the same EGLDisplay, so the EGLImage handoff works: H/W rendering with zero-copy `vaapi` (`hwdec-interop` `vaapi-egl`). This is the fix proposed in #1404; nothing is merged upstream yet.

Intel, native Wayland. Cells: hwdec-current · first frame (ms) · process CPU % of all 12 cores · dropped frames in the window.

| Sample | pub 1.2.6 (S/W render) | main@c533e44 (S/W render) | **pub + patch (H/W render)** |
|---|---|---|---|
| h264_1080p50_aac | vaapi-copy · 1448 · 11.6 · 207 | vaapi-copy · 1886 · 12.9 · 0 | **vaapi · 531 · 1.5 · 0** |
| h264_1080p25_ac3 | vaapi-copy · 1917 · 6.5 · 0 | vaapi-copy · 1933 · 6.6 · 0 | **vaapi · 796 · 0.9 · 0** |
| h264_1080i50_mp2 | vaapi-copy · 1520 · 6.8 · 0 | vaapi-copy · 1712 · 7.6 · 0 | **vaapi · 417 · 0.9 · 0** |
| hevc_1080p50_aac | vaapi-copy · 1433 · 9.9 · 482 | vaapi-copy · 1669 · 9.6 · 510 | **vaapi · 299 · 1.5 · 0** |
| hevc_2160p25_eac3 | vaapi-copy · 1562 · 10.5 · 164 | vaapi-copy · 1554 · 9.5 · 138 | **vaapi · 397 · 1.7 · 0** |
| mpeg2_576i25_mp2 | no · 638 · 2.8 · 0 | no · 641 · 2.8 · 0 | **no · 642 · 1.0 · 0** |
| codec_switch 720p→1080p | vaapi-copy · 1636 · 8.8 · 765 | vaapi-copy · 1624 · 8.1 · 839 | **vaapi · 295 · 1.3 · 6** (both sizes seen, no failure) |
| vod_h264_aac_10min.mp4 | vaapi-copy · 1741 · 6.5 · 0 | vaapi-copy · 1715 · 6.5 · 0 | **vaapi · 601 · 0.9 · 0** |
| vod_h264_ac3_10min.mkv | vaapi-copy · 1926 · 6.5 · 0 | vaapi-copy · 1711 · 6.6 · 0 | **vaapi · 596 · 0.9 · 0** |
| vod_hevc_eac3_subs.mkv | vaapi-copy · 1722 · 6.5 · 0 | vaapi-copy · 1702 · 6.5 · 0 | **vaapi · 592 · 1.0 · 0** |

X11 (unpatched) matches Wayland within noise.

**Visual check:** frames grabbed from the patched X11 window (`grab_frame.sh`; GNOME doesn't allow screenshots of native Wayland windows from scripts) show real moving video for h264_1080p50_aac and hevc_2160p25_eac3, not a black or frozen texture.

**Finding 3: zero-copy fails under XWayland.** With the patch and `GDK_BACKEND=x11`, rendering stays on the GPU (same EGLDisplay on both threads), but mpv's `vaapi-egl` interop can't open a VA display from the X11 connection (`libva: vaGetDriverNameByIndex() failed`). Confirmed cause: Ubuntu 22.04's libva-x11 (2.14.0) only has DRI2 code, and XWayland offers only DRI3. It falls back to `vaapi-copy`, which brings back the drops (321 on H.264 1080p50, 511 on HEVC 1080p50, 116 on HEVC 4K per 12 s). The whole patched X11 run was worse than native Wayland:
- VOD first frames took 5.3–5.8 s (Wayland 0.6 s)
- 14 audio underruns and 4 A/V desync warnings
- zap p50/p95 425/3261 ms with plain `-re` (349/382 ms with a burst); the first 3 zaps took 3.1–3.5 s
- the codec switch restarts mpv's video output, which resets `frame-drop-count`; the watchdog must not treat a lower count as an error

Only XWayland is affected: a real Xorg session gets zero-copy (Finding 4), and GTK picks native Wayland inside a Wayland session. Possible fix if we ever need it: on X11, have the patch give mpv a DRM render node instead of the X11 display. (These XWayland results are kept as `results/patched_intel_xwayland.*`.)

**Zap time** (20 alternating opens of h264_1080p50_aac ↔ h264_1080p25_ac3, 0 failures in every run). Measured from `open()` until mpv's `path` is the new URL, `playback-time` is available, and video params are known. Loopback server; excludes the 350 ms banner debounce and real network latency.

| Build (Intel, Wayland) | Plain `-re` p50 / p95 (ms) | 2 s initial burst p50 / p95 (ms) |
|---|---|---|
| pub 1.2.6 | 402 / 666 | 162 / 386 |
| main@c533e44 | 385 / 669 | 162 / 388 |
| **pub + patch** | **320 / 597** | **302 / 310** |

Budget ≤ 1.5 s / ≤ 3 s: met with a wide margin. The fake-provider measurement in Phase 3 replaces this figure.

**libmpv 0.34.1 names:** all 14 option names in docs/03 exist in libmpv's `options` list, and all accept the Balanced preset values (read back: `cache-secs` 8, `demuxer-max-bytes` 67108864, `demuxer-lavf-probesize` 1000000, `demuxer-lavf-analyzeduration` 1, `stream-lavf-o` as set, and so on). All 27 properties the player and overlay need are in `property-list`, including `hwdec-current`, `hwdec-interop`, `video-params`, `estimated-vf-fps`, `frame-drop-count`, `decoder-frame-drop-count`, `video-frame-info`, `demuxer-cache-duration`, `paused-for-cache`, and `current-tracks`. Differences from docs/03:
- `deinterlace` is only a yes/no flag in 0.34.1 (no `auto`). The app implements Auto by reading `video-frame-info/interlaced`, which reports `yes` for 1080i50 and 576i25.
- `hwdec=auto-safe` doesn't GPU-decode MPEG-2. SD MPEG-2 costs 1 % CPU, so this is acceptable.
- media_kit sets `subs-fallback`, which 0.34.1 doesn't have; it logs one harmless error.
- Every open logs `Failed to create file cache`. Phase 3 sets `cache-on-disk=no` explicitly, or a `demuxer-cache-dir`.

**Finding 4: a real Xorg session is fine on Intel.** On "Ubuntu on Xorg", libva-x11's DRI2 path works, so the patched build keeps zero-copy `vaapi` (`hwdec-interop` `vaapi-egl`): 0 drops, ≤ 2.3 % CPU, first frames 0.3–0.8 s, zap p50/p95 378/624 ms (336/383 with a burst), no underruns or desync. CPU is a little above native Wayland (2.3 vs 1.5 % on H.264 1080p50). Frames grabbed from the window show real moving video for h264_1080p50_aac and hevc_2160p25_eac3.

**Finding 5: NVIDIA needs the same patch, and works well with it.** GTX 1650 Ti, driver 595.91.07 (open kernel modules), PRIME render offload (`__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`, set by `run_matrix.sh`), Xorg session. nvidia-smi 25 s into each run lists the spike process on the GPU (C+G, 180–255 MiB).
- Unpatched pub 1.2.6 hits #1404 exactly as on Intel (`EGL display or context is invalid` → S/W rendering) and decodes with `nvdec-copy`. The copy-back is fast enough that nothing drops, but CPU is 3.4–9.4 % of all cores (up to 112 % of one core on HEVC 4K) and zap p50/p95 is 525/812 ms.
- Patched: same EGLDisplay on both threads, H/W rendering, zero-copy `nvdec` (`hwdec-interop` `vaapi-egl,cuda-nvdec`; `hwdec=auto-safe` picks nvdec). Three runs agree within noise (run 3: zap 334/615 ms, per-sample CPU and drops as in runs 1–2).
- One-off startup messages on NVIDIA with no visible effect: `libmpv_render: after creating texture: OpenGL error INVALID_OPERATION`, and the VA-API probe failing (`Failed to query surface attributes`). GTK also warns `Failed to create OpenGL context: No available configurations for the given RGBA pixel format` at startup on both builds.

NVIDIA, Xorg. Cells: hwdec-current · first frame (ms) · process CPU % of all 12 cores · dropped frames in the window.

| Sample | pub 1.2.6 (S/W render) | **pub + patch, run 1** | **pub + patch, run 2** |
|---|---|---|---|
| h264_1080p50_aac | nvdec-copy · 454 · 6.6 · 0 | **nvdec · 632 · 1.1 · 0** | **nvdec · 304 · 1.1 · 0** |
| h264_1080p25_ac3 | nvdec-copy · 824 · 3.5 · 0 | **nvdec · 808 · 0.7 · 0** | **nvdec · 613 · 0.7 · 0** |
| h264_1080i50_mp2 | nvdec-copy · 639 · 3.4 · 0 | **nvdec · 498 · 0.7 · 0** | **nvdec · 422 · 0.7 · 0** |
| hevc_1080p50_aac | nvdec-copy · 506 · 6.9 · 0 | **nvdec · 333 · 1.1 · 0** | **nvdec · 305 · 1.1 · 0** |
| hevc_2160p25_eac3 | nvdec-copy · 593 · 9.4 · 0 | **nvdec · 412 · 0.7 · 0** | **nvdec · 411 · 0.8 · 0** |
| mpeg2_576i25_mp2 | no · 737 · 2.7 · 0 | **no · 641 · 0.9 · 0** | **no · 638 · 0.9 · 0** |
| codec_switch 720p→1080p | nvdec-copy · 433 · 5.4 · 0 | **nvdec · 322 · 1.2 · 4** | **nvdec · 318 · 1.1 · 0** |
| vod_h264_aac_10min.mp4 | nvdec-copy · 789 · 3.4 · 0 | **nvdec · 404 · 0.7 · 0** | **nvdec · 796 · 0.7 · 0** |
| vod_h264_ac3_10min.mkv | nvdec-copy · 814 · 3.6 · 0 | **nvdec · 612 · 0.7 · 0** | **nvdec · 603 · 0.7 · 0** |
| vod_hevc_eac3_subs.mkv | nvdec-copy · 796 · 3.8 · 0 | **nvdec · 661 · 0.7 · 0** | **nvdec · 592 · 0.7 · 0** |

Zap p50/p95 on NVIDIA (plain `-re` / 2 s burst): pub 525/812 · 486/528 ms; patched run 1 336/616 · 326/508 ms; patched run 2 328/614 · 320/334 ms. 0 failures.

**NVIDIA on native Wayland** ("Ubuntu" session, same offload variables, `GDK_BACKEND=wayland`), one run each:
- Unpatched pub 1.2.6: the same #1404 failure (`EGL display or context is invalid` → S/W rendering), `nvdec-copy`, 0 drops, CPU 3.0–9.7 % of all cores (117 % of one core on HEVC 4K), zap p50/p95 541/823 ms (511/546 with a burst). Within noise of Xorg.
- Patched: same EGLDisplay on both threads, H/W rendering, zero-copy `nvdec` (`vaapi-egl,cuda-nvdec`) on every H.264 and HEVC sample. 0 drops, except 8 during the codec switch, when mpv restarts its video output (Intel on Wayland had 6). First frames 0.3–0.6 s; zap 342/624 ms (327/338 with a burst), 0 failures. nvidia-smi lists the process on the GPU (C+G, 279 MiB on H.264, 709 MiB on HEVC 4K).
- CPU is 1.4–2.7 % of all cores, about twice the Xorg figure (0.7–1.1 %). Intel went the other way (H.264 1080p50: Wayland 1.5 %, Xorg 2.3 %). Both are far under the 15 % budget, so this wasn't investigated.
- Wayland-only startup message on the patched build: `VideoOutput: Failed to query Flutter's EGL config ID`, just before `H/W rendering`, with no visible effect. The GTK `Failed to create OpenGL context` warning seen on Xorg doesn't appear.

NVIDIA, native Wayland. Cells: hwdec-current · first frame (ms) · process CPU % of all 12 cores · dropped frames in the window.

| Sample | pub 1.2.6 (S/W render) | **pub + patch (H/W render)** |
|---|---|---|
| h264_1080p50_aac | nvdec-copy · 327 · 7.3 · 0 | **nvdec · 528 · 2.7 · 0** |
| h264_1080p25_ac3 | nvdec-copy · 817 · 3.9 · 0 | **nvdec · 636 · 1.5 · 0** |
| h264_1080i50_mp2 | nvdec-copy · 646 · 3.9 · 0 | **nvdec · 431 · 1.5 · 0** |
| hevc_1080p50_aac | nvdec-copy · 513 · 7.4 · 0 | **nvdec · 323 · 2.7 · 0** |
| hevc_2160p25_eac3 | nvdec-copy · 609 · 9.7 · 0 | **nvdec · 420 · 1.6 · 0** |
| mpeg2_576i25_mp2 | no · 746 · 3.0 · 0 | **no · 644 · 1.8 · 0** |
| codec_switch 720p→1080p | nvdec-copy · 235 · 6.0 · 0 | **nvdec · 349 · 2.6 · 8** |
| vod_h264_aac_10min.mp4 | nvdec-copy · 805 · 4.0 · 0 | **nvdec · 421 · 1.4 · 0** |
| vod_h264_ac3_10min.mkv | nvdec-copy · 615 · 4.0 · 0 | **nvdec · 615 · 1.4 · 0** |
| vod_hevc_eac3_subs.mkv | nvdec-copy · 800 · 3.9 · 0 | **nvdec · 626 · 1.5 · 0** |

**Visual check on NVIDIA:** not confirmed by a frame grab. `x11grab -window_id` failed with BadMatch and wrote nothing, most likely because `grab_frame.sh` took the first window named playback_spike, and GTK also creates an unmapped one with that name (a later run's first match was `IsUnMapped`). A root-region grab of that geometry captured whatever covered the screen instead, so it proves nothing (those images were deleted). `grab_frame.sh` now picks a viewable window and fails when no image is written. **Confirmed by eye on Wayland (user, 2026-09-15):** the user watched a short patched run of h264_1080p50_aac and hevc_2160p25_eac3 (`--auto samples --only …`; results `patched_nvidia_wayland_visual.*`: `nvdec`, 0 drops) and saw moving video on both.

**GPU choice for the app:** without the offload variables the app renders and decodes on Intel, which already meets every budget. NVIDIA is not required; whether to offer "use discrete GPU" (for example `PrefersNonDefaultGPU=true` in the .desktop file) is decided in packaging (Phase 10).

**Decision (user, 2026-09-15): ship the fix as a pinned patched fork of media_kit_video.** The app depends on our fork with `spike/vendor/media_kit_video_egl_display.patch` applied, pinned to a commit, until upstream fixes #1404. We don't post the patch upstream (it would go out under the user's account) unless the user asks. fvp stays the fallback only if Windows fails.

**Where the fork lives (user, 2026-09-15, step 6):** in this repo, not on GitHub. `third_party/media_kit_video` is media_kit_video 2.0.1 from pub.dev (without `example/`) plus `third_party/patches/media_kit_video-2.0.1-egl-display.patch`, rebuilt reproducibly by `tools/vendor_media_kit_video.sh`; the repo's commits pin it, and the app points `dependency_overrides` at it (Phase 1). The production patch is the spike patch without its diagnostics: no `SPIKE PATCH` prints, one neutral log line (`No current EGL context; using GDK's EGLDisplay …`), and no misleading `Failed to query Flutter's EGL config ID` error when there's no context to query. Checked with `run_matrix.sh vendored intel wayland`: H/W rendering and zero-copy `vaapi`; H.264 1080p50 first frame 534 ms, 1.5 % CPU, 0 drops; HEVC 4K 392 ms, 1.9 % CPU, 0 drops. Upstream media_kit_video isn't formatted to our settings (`dart format` would change 20 of its files), so the app's format and analyze steps leave `third_party/` out.

**Windows (user, 2026-09-15):** a real Windows PC exists but isn't available yet. The Windows run is deferred and doesn't block step 4 on Linux.

**Status:** done for Linux. Intel and NVIDIA play zero-copy with the patch on native Wayland and Xorg; the one exception is XWayland (Finding 3). fvp isn't needed. Still open: the Windows run, when the PC is available. The GO/NO-GO is ADR-007.

## ADR-004 · 2026-09-15 · Done (one device) — Casting spike results, device model(s), verified LOAD fields
**Setup:** "Living Room TV", a Chromecast with Google TV (4K) (model from the user; mDNS only says `md=Chromecast`) on a Samsung 4K TV: Android 14 build UTTC.250917.004, cast build 3.72.446070, receiver user agent `Chrome/92.0.4515.0 … CrKey/1.56.500000 DeviceType/AndroidTV`. The laptop is on 5 GHz Wi-Fi (540 Mbit/s, 192.168.1.254/24), the device at 192.168.1.155. The user's second Google TV doesn't answer on the network; they chose to test one device. `spike/cast_spike` is a Dart CLI: multicast_dns discovery, our own Cast v2 client (protobuf `CastMessage`, TLS to port 8009), a shelf relay server on the LAN address (port 38400), and the docs/04 FFmpeg relay (bundled 8.1.2) reading a loopback provider that plays each sample as an endless real-time MPEG-TS stream (`-re -stream_loop -1`). Results in `spike/cast_spike/results/` (gitignored). The user watched the TV and reported picture and sound for the key runs. Testing stopped at the user's request; any further TV test needs their OK first.

**Finding 1: discovery works next to avahi-daemon.** multicast_dns found both Cast devices on the LAN in 5.0 s (the TV and a Nest Mini speaker) with avahi-daemon running, so the two coexist (ADR-006). `md` is just `Chromecast` on this 4K Google TV model, the same string older 1080p Chromecasts use, so docs/04 can't seed HEVC or 4K support from the model name. The `ca` bitmask does separate video devices: bit 0 (video out) is set on the TV (465413) and not on the Nest Mini (198660).

**Finding 2: the Cast v2 sequence works, with two surprises.** CONNECT → GET_STATUS → LAUNCH CC1AD845 → CONNECT transportId → LOAD works against the device's self-signed TLS 1.3 certificate. LAUNCH takes 3.0–5.6 s when the receiver app isn't running (53 ms when it is). The device also sends `LAUNCH_STATUS` (its `status` is a string, `USER_ALLOWED`) and `MULTIZONE_STATUS` on another namespace, and keeps sending after our CLOSE; the spike crashed on each until its parsing was tolerant. After LOAD_FAILED the media session is gone: STOP returns `INVALID_REQUEST` / `INVALID_MEDIA_SESSION_ID`.

**Finding 3: relay-copy results on the device.** Cells: relay output · LOAD → PLAYING · result, with what the user saw and heard where they watched.

| Sample | Relay | Result |
|---|---|---|
| h264_1080p50_aac | TS · 3.3–4.0 s | **plays**: smooth moving pattern, steady tone (4 min, 200 MB) |
| h264_1080p25_ac3 | TS, AC-3 5.1 → AAC stereo · 2.2 s | **plays**: bars and tone steady |
| h264_1080p25_ac3 | fMP4 · 2.0 s | **plays** (not watched; receiver reports 1920×1080) |
| hevc_1080p50_aac | fMP4, `-tag:v hvc1` · 1.8–2.3 s | **plays**: bars and tone steady (2 min); also plays with `hlsSegmentFormat` `"FMP4"`, `"bogus"`, or no field (not watched) |
| hevc_2160p25_eac3 | fMP4 · 3.9 s | before the TV fix: LOAD_FAILED about 1 s after the first segment (also with `"FMP4"`, no field, or `hev1`); after: **plays** at 3840×2160 but **stutters**, tone steady (Finding 7) |
| h264_2160p25_aac (extra 30 s sample) | TS · 4.0–4.9 s | before the TV fix: LOAD_FAILED the same way; after: **plays** at 3840×2160, smooth except a few-second freeze at the sample's loop point, tone steady (Finding 8) |

The relay lists its first 2 segments 3.6–4.9 s after it starts. Receiver requests carry `Origin: https://www.gstatic.com`, so the CORS headers are needed (not tested without them).

**Finding 4: 4K needs the TV's full-bandwidth HDMI mode.** With Samsung's Input Signal Plus off for the Chromecast's HDMI port, the Chromecast never offered 4K and refused every 4K stream, H.264 and HEVC, with a bare LOAD_FAILED about 1 s after the first segment, while 1080p played. After the user turned it on, both 4K samples play. The app can't see the HDMI mode, so it must learn a device's maximum resolution from this failure (docs/04 learning), fall back to a 1080p transcode, and tell the user that a TV setting may unlock 4K.

**Finding 5: BUFFERING in MEDIA_STATUS isn't a stall.** In the live run the user watched (h264_1080p25_ac3), the receiver reported BUFFERING 31 % of the time and flipped state 12 times a minute, yet bars and tone never stalled and `currentTime` kept pace with the clock; an unwatched run showed 46 % and 22 a minute. It was worst when LOAD went out with 2–3 segments listed and nearly gone (5 %) with about 4 (one run each). The app must not treat BUFFERING as a stall; the relay's segment age and IDLE/ERROR are the signals.

**Finding 6: a plain MP4 with Range (BUFFERED) plays and seeks.** `vod_h264_aac_10min.mp4` served from `/f/<token>/media.mp4`: PLAYING 1.1 s after LOAD. The TV opened `Range: bytes=0-`, then a new request from byte 98,304,000 for SEEK 300 s and from 19,464,192 for SEEK 60 s. Each SEEK was answered in 150–185 ms with PLAYING at the target; PAUSE and PLAY worked; the user saw both jumps and the pause.

**Finding 7: open-GOP HEVC breaks FFmpeg's HLS fMP4 segments.** The 4K HEVC stutter most likely comes from the relay output, not the network or the device: the laptop's link was 540 Mbit/s, the tone never dropped, and playback time kept pace. Joining the relay's fMP4 segments shows a duplicated frame time and a two-frame gap at every segment cut. Checked on the laptop with the same relay command each time:

| Source | Relay output | Frame timing |
|---|---|---|
| x265 clip, open GOP (CRA keyframes with leading RASL frames) | HLS fMP4 | 3 duplicates and 3 gaps in 4 segments |
| the same clip, closed GOP (IDR keyframes only) | HLS fMP4 | clean |
| hevc_2160p25_eac3, hevc_1080p50_aac (both open GOP) | HLS fMP4 | the same kind of fault |
| hevc_2160p25_eac3 | HLS TS | clean |
| hevc_2160p25_eac3 | one continuous fragmented MP4 (docs/04 low-latency mode) | clean |
| h264_1080p50_aac (with B-frames) | HLS fMP4 | clean |

x265 defaults to open GOP and real HEVC channels may use it too, so docs/04's "HEVC → HLS with fMP4 segments" can't be the only HEVC path. **Confirmed on the TV in step 6**, with the clean-looping source from Finding 8: HLS fMP4 segments still stutter (user), while the same source as one continuous fragmented MP4 response (`/p/<token>/stream.mp4`, `video/mp4`, `LIVE`) plays smoothly (user): PLAYING 3.3 s after LOAD, one HTTP request for the whole 90 s, 3840×2160. MEDIA_STATUS looked alike for both (BUFFERING 2–4 % of the time), so only watching told them apart. The app sends HEVC as one continuous fragmented MP4 (docs/04). The Cast docs say HEVC isn't supported in TS (not tested).

**Finding 8: the spike's looping test source breaks at each loop.** `-stream_loop -1` on a TS sample with B-frames corrupts video timestamps where the file wraps: on the 30 s H.264 4K sample, a 0.76 s jump, 16 lost frames, and 2 decode errors per wrap, while audio stays continuous. The TV's segment requests stalled for 3–4 s at the wraps (around 30 s and 60 s into the run), matching the freeze the user saw. The relay copies the fault unchanged, so it's a test-source problem. Looping an MKV remux instead removes almost all of it (laptop: all 1500 packets, one gap under 0.1 s, and 4 instead of 102 decode errors per wrap on HEVC 4K), and in step 6 the same H.264 4K cast ran 110 s on the TV with no freeze (user). The spike and docs/06 now loop MKV remuxes.

**Finding 9: a continuous stream's end is final.** Step 6 killed the relay FFmpeg 25 s into a continuous fMP4 cast. The HTTP response ended; the TV didn't reconnect, played out about 4 s of buffer, and reported IDLE/FINISHED (the user reported that it kept playing, most likely before the buffer ran out). So on this path a relay restart or provider drop needs a new LOAD from the coordinator, while HLS lets the receiver keep polling a restarted relay (docs/04 Supervisor).

**Verified LOAD fields** (Google Cast docs, checked 2026-09-15; device results above): LOAD carries `media`, `autoplay`, `currentTime`; `media` has `contentId` (the URL; an optional `contentUrl` overrides it), `contentType` (`application/x-mpegurl` for HLS and `video/mp4` for files both played), `streamType` `LIVE` / `BUFFERED`, `metadata` (`metadataType` 0, `title`, `subtitle`), and `hlsSegmentFormat` / `hlsVideoSegmentFormat`, documented as "only required for HLS content playback using MPL". SEEK takes `currentTime` and `resumeState` `PLAYBACK_START`. Shaka Player replaced MPL as the Web Receiver's default HLS player in 2026 (release notes: SDK 3.0.0150, April), and this receiver ignores the segment-format fields: HEVC fMP4 plays with `"fmp4"`, `"FMP4"`, `"bogus"`, or no field. The `"fmp4"` vs `"FMP4"` question doesn't matter on current receivers, and the app doesn't send the fields (docs/04).

**Status:** done on one device. Step 6 confirmed Findings 7 and 8 on the TV and added Finding 9. Still open: the second Google TV, and a path for HEVC library files (Phase 8). GO / NO-GO: ADR-007.

## ADR-005 · 2026-09-15 · Accepted — Downloads and local library in v1
**Decision:** v1 downloads provider movies and episodes and manages a library of the user's own video files; both play offline and cast to Chromecast / Google TV. New Phase 8; settings/polish and packaging move to Phases 9 and 10. Spec: docs/09.
**Context:** The user wants to download movies and episodes (from IPTV or elsewhere), manage them in the player, and watch them on their Google TV.
**Alternatives rejected:**
- A separate media server (Plex, Jellyfin) — another app to install and run, with no link to IPTV watch progress
- Downloads inside the Google TV app — Chromecast with Google TV has 8 GB of storage; casting from the laptop covers the need
**Consequences:** Downloads share provider connection limits and pause for playback; casting gains a direct-file path with Range requests plus a relay path with seeking and WebVTT subtitles; four new tables via a migration; no online metadata lookups in v1; recording live channels stays a non-goal.

## ADR-006 · 2026-09-15 · Accepted — Spike B discovers Cast devices with multicast_dns + manual IP
**Decision:** `spike/cast_spike` is a plain Dart CLI. It finds devices with multicast_dns 0.3.3+1 (PTR `_googlecast._tcp.local` → SRV → A/AAAA + TXT `fn`, `md`, `id`) and also takes `--ip`. The app still uses bonsoir (ADR-002); Phase 7 tests bonsoir inside the Flutter app on Linux and Windows, and if it fails there the app falls back to the multicast_dns code proven here.
**Context:** The Phase 0 step 5 prompt asks for a Dart CLI using bonsoir, but bonsoir is a Flutter plugin (native code behind platform channels; Avahi over D-Bus on Linux) and can't run under `dart run`. The user approved this on 2026-09-15.
**Alternatives rejected:**
- Make the cast spike a Flutter app just to use bonsoir — slower to iterate, and discovery isn't the risky part of Spike B
- Manual IP only — leaves discovery untested
**Consequences:** Spike B proves the mDNS query and TXT fields; bonsoir itself (Avahi on Linux, Windows issue #156) is verified in Phase 7. multicast_dns binds UDP 5353 next to avahi-daemon; Spike B records whether both work together.

## ADR-007 · 2026-09-15 · Accepted (user OK 2026-09-15) — Phase 0 GO / NO-GO: GO for Linux
**Decision:** GO. Build the app on the stack in ADR-001 and ADR-002, on Linux first; Windows follows once a real Windows PC confirms hardware decoding.

**Exit criteria** (docs/08, Phase 0):

| Criterion | Result |
|---|---|
| Hardware decoding for H.264 and HEVC on Linux | met: zero-copy on Intel (`vaapi`) and NVIDIA (`nvdec`), Wayland and Xorg, with our patched media_kit_video (ADR-003); rechecked from `third_party/media_kit_video` |
| Hardware decoding on Windows | open: no Windows PC yet; not a Linux blocker |
| Zap time measured | met: p50 / p95 320 / 597 ms over loopback (budget 1.5 / 3 s) |
| An H.264 sample casts with `-c:v copy`, plus HEVC if the device supports it | met: H.264 1080p50, 1080p25 (AC-3 → AAC), and 4K over HLS/TS; HEVC 1080p and 4K (ADR-004) |
| A local MP4 casts as a plain file with working seeking | met: Range requests, each seek playing from the target within 200 ms |
| ADR-002, ADR-003, ADR-004 written | met |

**Choices the app builds on:**
- media_kit 1.2.6 from pub with our patched media_kit_video 2.0.1 in `third_party/media_kit_video`, rebuilt by `tools/vendor_media_kit_video.sh` (ADR-003)
- Casting through our own Cast v2 client, the Default Media Receiver, and the bundled FFmpeg relay: H.264 relay-copy as HLS/TS; HEVC relay-copy as one continuous fragmented MP4, because open-GOP HEVC stutters in HLS fMP4 segments; IDLE/FINISHED on a live continuous stream means a new LOAD (docs/04, ADR-004)
- Device capabilities are learned from failures, not trusted from `md`; a bare LOAD_FAILED on a 4K stream can mean a 1080p HDMI link
- The fake provider loops MKV remuxes of the samples (docs/06)

**Risks carried forward:**
- media_kit upstream is quiet (last pub release December 2025) and #1404 is unfixed, so we carry a patch; recheck pub each phase
- Windows hardware decoding is unverified (Phase 10 at the latest)
- A relay restart or provider drop restarts a continuous-fMP4 cast visibly, while HLS/TS rides through; Phase 7's matrix measures both
- HEVC library files need a path other than HLS fMP4 segments (Phase 8)
- Casting was tested on one device (Chromecast with Google TV 4K); the user's second Google TV and other models weren't

**Alternatives rejected:**
- NO-GO or switching to fvp: the patch fixes media_kit on Linux; fvp stays the fallback only if Windows fails
- Transcoding all HEVC to H.264 for casting: GPU cost and quality loss when a copy path plays smoothly

**Consequences:** The user gave the OK on 2026-09-15; Phase 1 starts. Its root `analysis_options.yaml` excludes `third_party/**` and `spike/**`, `pubspec.yaml` points `dependency_overrides` at `third_party/media_kit_video`, and formatting covers first-party folders only (`dart format --set-exit-if-changed lib test integration_test tools`), because upstream media_kit_video isn't formatted to our settings.

## ADR-008 · 2026-09-16 · Accepted — Phase 1 foundation choices
**Decision:** the app is built on the structure, tokens, focus model, data layer, test tooling and CI below. Everything here was decided while building Phase 1 steps 1–8; where a choice contradicts an earlier plan or doc, this ADR wins and the doc has been corrected.

**Identity:** application ID `io.github.yasiralobaidi.iptvplayer`, Dart package `iptv_player`, window title "IPTV Player" (a placeholder — the real name and icon are still open).

### The canvas beats docs/05
docs/05 was written before the design canvas existed. Where they disagree, the canvas is what the app implements and docs/05 has been corrected: the top bar is **64 px** (docs/05 said 56), the nav rail has **no Search item** (search is the top bar field plus Ctrl+K and `/`), the focus ring is a **2 px ring with a 4 px glow at 25 %**, and h2 / bodyStrong are **700**, not 600. Canvas values that docs/05 had no token for became tokens: **radius `control` = 10** for buttons, inputs and rows, and the **17 / 14 / 12 px** text styles (`titleSmall`, `label`/`buttonSmall`, `labelSmall`), plus `button` 15/800.

Two additions the canvas does not draw: the rail's **collapse toggle** (docs/05 asks for one; it sits above Settings, where it disturbs the drawn layout least) and, in the design system, everything docs/05 specifies that the canvas has no artboard for.

### Design system
- **Variable fonts, bundled:** `Manrope[wght]` and `JetBrainsMono[wght]`, registered with `LicenseRegistry`. Variable weights render correctly on Linux, so no static instances are shipped. A variable font takes its weight from `fontVariations`, so `copyWith(fontWeight:)` alone does nothing — the nav rail marks the selected item by colour, not by weight, for that reason.
- **Icons are the canvas's own SVGs**, extracted by `tools/extract_icons.dart` into `assets/icons/` and addressed through the `AppIcons` enum, rendered with **flutter_svg 2.3.0** (added to the ADR-002 package table; `crypto` is a new dev dependency for the extractor's hashes). Each icon is identified by a hash of its markup, so redrawing one fails loudly instead of silently dropping it, and a missing icon is a compile error rather than an empty box.
- **`AppTokens` is a `ThemeExtension`** with accent, density and reduce-motion switchable at runtime. Design tokens only outside `lib/design/` (hard rule 9).
- **The focus ring is stroked outside the control** (`FocusRing` + a `CustomPainter`), not a box shadow: a shadow is a filled rectangle behind the box, so on a transparent ghost button it fills the control instead of outlining it. On accent-filled surfaces the ring inverts to `textPrimary` with a 5 px glow at 35 %, since accent-on-accent is invisible.
- **`ChannelRow` draws the programme's progress on the title line** — a 72 px bar after the ellipsized title, as the canvas does. Riding the row's bottom edge (the step 3b choice) strikes through the title in both densities; the step 7 golden is what showed it.
- `EmptyState` and `ErrorState` scroll rather than overflow a short pane; `SurfaceStateOverride` forces hover/focus/pressed for the gallery and goldens.

### Focus and keyboard (also the Google TV foundation)
- **`FocusPane` is a `FocusTraversalGroup`, not a `FocusScope`.** A scope remembers its focused child for free, but it traps Tab — focus could never leave the nav rail. The memory is explicit instead (`FocusPaneController`, with `focusLast`/`focusFirst`/`focusPane`/`items`/`hasFocus`), and both behaviours are tested.
- The shell has **three panes** — rail, top bar, screen. Left/Right between them go through `FocusPaneController.focusPane()` (the remembered item, else the pane's first). The rail binds Right and the screen pane binds Left; a screen with its own horizontal movement binds Left first and wins, because `Shortcuts` resolves from the focused node outwards.
- **Global shortcuts wrap the router's navigator, not the shell**, so they also fire over the search overlay. `/` is an `Action` that disables itself while a text field has focus, which makes `Shortcuts` pass the key through instead of eating it. **Search is a non-opaque route, not a dialog**, so Ctrl+K, Esc and Back agree with each other.
- **A destination shortcut takes focus with it; Enter on a rail item does not.** Ctrl+1 … Ctrl+7 and Ctrl+, mean "take me there", so focus lands on the first control of the screen that opens; Enter or Space on a rail item means "I am browsing the rail", so the item keeps focus and ↑ ↓ keep working. Switching a branch pulls focus into the new route's own scope, so both cases place focus deliberately, in a post-frame callback — the new branch is only traversable once laid out, which costs one frame (~16 ms) before the ring appears.
- **Esc means "leave what you stepped into"**, in order: close what is open → return focus from the chrome to where the user was in the screen → with focus already in the screen, do nothing. It never navigates to another destination. The shell's `CloseTopIntent` action shadows the global one while focus is inside the shell, so it pops as well: `Actions` resolves outwards from the focused node and does **not** fall through to an outer action when the nearest one is disabled.
- **Never write a conditional sibling next to a focusable subtree in a `Stack`.** The rail's active indicator was `if (selected) Positioned(…)`, so every selection change altered the child count, moved the item's subtree by one index, rebuilt its element and destroyed the `FocusNode` holding the keyboard focus. Indicators stay in the tree and go transparent instead.

### Core
- **Our own log rotation** (`RotatingFileOutput`, 5 × 5 MB, exact): logger's `AdvancedFileOutput` only checks size once a minute.
- **No `runZonedGuarded`** — Flutter warns when it wraps `runApp`, and `FlutterError.onError` plus `PlatformDispatcher.onError` cover the same errors. This supersedes the step 2 plan.
- `Result<T>` and `AppFailure` are sealed; details are redacted when a failure is created. `redact()` covers Xtream stream paths, credential query parameters, URL user-info, auth headers, JSON and printed-map credential fields, and exact secrets from a `SecretRegistry`, URL-encoded forms included.
- `meta` is a direct dependency (`@immutable`). Dart 3.13's `unnecessary_type_name_in_constructor` means the unnamed constructor is written `new(...)` / `const new(...)`; a **named generative const constructor cannot be written that way at all**, so those become `static const` fields.

### Data
- **`DateTime` columns are ISO-8601 UTC text** (`store_date_time_values_as_text: true`). drift's other option is unix seconds, which it reads back as *local* time, so `DateTime.utc(...)` does not survive the round trip — a DAO test caught it. EPG times stay integer epoch ms in their own columns (docs/02).
- The `settings` table holds **one JSON document per key**, and readers fall back instead of throwing, so one corrupt row cannot stop the app from starting.
- **`sources` has no password column** — only `credential_ref`, the flutter_secure_storage key — and a test asserts it.
- The database is opened through a `LazyDatabase` over `NativeDatabase.createInBackground`, so neither opening the file nor any query touches the UI isolate. `bootstrap()` falls back to an in-memory database with a logged error rather than refusing to start.
- **Narrow interfaces keep drift out of the UI** (hard rule 6): `WindowBoundsStore` and `UiPreferences` live in `lib/core/`, their settings-table implementations in `lib/data/`. `railExpanded` is a plain getter read once in `bootstrap()`, so the first frame draws the remembered rail instead of flipping a frame later.
- `build.yaml` needs its `databases:` entry before `drift_dev make-migrations` will run at all. `sqlite3_flutter_libs` stays dropped: an FTS5 smoke test proves the `sqlite3` package's binaries are enough, which ADR-002 had only assumed.

### Window
Size and position are saved debounced and restored on the next launch, through the settings table. Minimum window 1024 × 640. **Two things are still unverified on this machine:** window_manager #585 (a crash when the window is closed) and whether the compositor honours a restored position on Wayland — neither can be tested from a script here, because closing a window and taking a screenshot both fail on this Wayland session.

### Testing
- **Goldens are recorded on Linux only** — text rasterizes differently on Windows, so the same widget is a different image. The mechanism is `@Tags(['golden'])` at library level (`group()` takes no `tags` parameter), the tag declared in a root `dart_test.yaml`, and `skip:` with a reason off-Linux; Windows CI runs `flutter test --exclude-tags golden`. Images live in `test/golden/images/`. A green golden only means nothing changed — read the PNG after re-recording.
- `test/flutter_test_config.dart` loads the bundled variable fonts with `FontLoader` for every test under `test/`, from disk rather than `rootBundle`, so no asset manifest is needed. The debug banner is suppressed for goldens with Flutter's own `debugAllowBannerOverride`, leaving `lib/` alone.
- **`tools/fake_provider` is its own package** with its own `pubspec.yaml` and an `analysis_options.yaml` that includes very_good_analysis, so it carries the app's lints. The root `flutter analyze` **does** reach into it, which is why CI must `pub get` it first. Its data is deterministic and lazily generated from **index-addressable** draws (splitmix64 over seed, a per-kind salt and the index), not a sequential `Random(seed)`: item N must not depend on N−1 having been built. Value quirks are baked in by the generator, representation quirks applied at serialization by `JsonShape`, so one generated row can be served either way. Streams loop an **MKV remux**, never the `.ts`, and every ffmpeg process has a PID file, a kill on disconnect and a startup sweep that only signals a pid whose `/proc/<pid>/cmdline` still matches (hard rule 8).
- `integration_test/app_launch_test.dart` pumps the real `IptvPlayerApp` with `bootstrap()`'s non-disk overrides. `bootstrap()` itself takes no overrides and resolves `AppPaths` on its own, so driving it from a test would write a log and a database into the user's real app-support directory and take over `FlutterError.onError`; a deeper launch test needs an injectable seam first.

### CI
One matrix job over **ubuntu-22.04** and windows-latest, with Flutter pinned to **3.47.4** (the version the goldens were recorded on). 22.04 rather than `ubuntu-latest`: it matches the development laptop and the AppImage target (libmpv 0.34.1), and 24.04 would silently change the mpv the app is tested against (ADR-003). `git config --global core.autocrlf false` runs **before** checkout, or Windows checks out CRLF and `git diff --exit-code` after `build_runner` reports every generated file as modified. CI installs no VA-API driver, no avahi and no protoc — it builds and tests, it never plays or casts — and the fake provider's ffmpeg tests skip themselves because neither the binaries nor the generated samples are committed.

**Alternatives rejected:**
- Following docs/05 where the canvas disagrees: the canvas is the drawn design and the thing the user approved; docs/05 was written first and has been corrected instead.
- `FocusScope` for panes (traps Tab), a box-shadow focus ring (fills transparent controls), unix-seconds `DateTime` columns (loses UTC), a sequential `Random(seed)` in the generator (breaks lazy per-id generation), one component sheet golden (one 1280 × 800 viewport would only ever show the buttons), and two separate CI jobs (each step would be written twice).
- Leaving focus where it was on a destination shortcut: it costs a keyboard user a Tab walk back into the content every single time.

**Consequences:** Phase 1 is complete in code — 259 app tests, 81 fake-provider tests, analyze and the format check clean, release bundles building on Linux. **Still open:** CI green on both OSes (needs a push; the Windows job has never run anywhere), the window_manager #585 check, Windows playback (ADR-007), and the app's real name and icon. The rules above are the ones later phases must not relitigate without new evidence; docs/05, docs/01 and docs/06 have been corrected to match.

**2026-09-18:** CI green on both OSes on its first run (run 35312720884, commit 2e1affd) — the Windows job built and tested the project for the first time, including `flutter build windows --release`. That closes the CI item; the window_manager #585 check, Windows playback and the name and icon remain open.

## ADR-009 · 2026-09-18 · In progress (written step by step through Phase 2) — Phase 2 sources, sync and data choices
**Decision:** the Phase 2 choices below. Like ADR-008, it is organized by theme and wins over any earlier doc; docs are corrected as each step lands. It moves to Accepted at the phase exit.

**Plan approved 2026-09-18** (docs/plans/phase-2-providers-and-data.md), with the recommendation taken on all four questions: you run onboarding against your real provider at the end of step 6; `favorites` and `watch_history` wait for the phases that write them; M3U file and URL ship together; sync *duration* is asserted in CI, and frame times are measured by a separate manual benchmark rather than gated.

### Schema v2 (step 1)
- **Tables:** `sync_runs`, `categories`, `channels`, `movies`, `movie_details`, `series`, `episodes`, plus the external-content FTS5 tables `channels_fts`, `movies_fts`, `series_fts` (docs/02 lists the columns). Every child table cascades from `sources`, so removing a source removes its whole catalogue; a swept category sets its items' `category_id` to null ("Uncategorized") rather than deleting them.
- **Mark-and-sweep uses a run id, not a timestamp.** `sync_runs.id` is the marker: each upsert writes `seen_run = <run id>`, and only a succeeded run sweeps `seen_run IS NULL OR seen_run != <run id>` in its own source. The same table records each run's outcome, failure kind and counts for Settings → Sources, and a run still `running` on launch is failed as `interrupted`.
- **Categories are unique per `(source_id, kind, remote_key)`**, not `(source_id, remote_key)`: Xtream numbers live, VOD and series categories independently, so `category_id = 1` exists once per kind.
- **The user's category order and the provider's are separate columns.** `position` is rewritten by every sync; `sort_order` is null until the user reorders, and display order is `sort_order IS NULL, sort_order, position` — a category that appears later lands at the end instead of shuffling the user's list.
- **Upserts rewrite only provider-owned columns** (`INSERT … ON CONFLICT DO UPDATE SET col = excluded.col` for an explicit list), so renames, hidden flags, user order, movie details and fetched episodes survive a re-sync, and row ids are stable. drift cannot infer the types of `DoUpdate.withExcluded` through `Batch.insertAll`; the type arguments are written out.
- **M3U items carry `stream_url` (credentials replaced by placeholders) and `extras_json`**; Xtream items leave both null because their URLs are built from the source. `movie_details.cast` is `cast_names` because `CAST` is SQL.
- **FTS is maintained by triggers**, with `WHEN old.name IS NOT new.name …` on the update triggers. Measured on 50k channels in 5,000-row batches (in-memory, this laptop): a first insert takes 2.0 s with triggers against 1.0 s without; a re-sync with unchanged names costs **nothing extra** (0.97 s both ways); dropping the triggers and running FTS5 `rebuild` afterwards costs 0.1 s. Triggers cost ~1 s per 50k new or renamed rows and cannot be forgotten by any writer, so they stay; step 5 revisits only if the 60 s budget is tight. Tokenizer `unicode61 remove_diacritics 2` with `prefix='2 3'` for type-ahead; changing either is a drop-and-rebuild, not a data migration.
- **Triggers are recreated after every upgrade, not inside a step.** drift's step-by-step `SchemaN` classes do not include triggers, and **its schema verifier does not compare them** — with the trigger step removed, every verifier test still passed and only the search test on a migrated database failed. That test is the guard. FTS consistency in tests uses FTS5's own `integrity-check`, which was confirmed to throw on a stale index.
- **The migration tests moved to drift's own layout**, `test/drift/app/` (`migration_test.dart` and `generated/`), because `make-migrations` regenerates there on every run; Phase 1's hand-made copy in `test/data/db/generated/` would have silently gone stale. The tests: every version to every later one, the live schema against the latest dump, a populated v1 database keeping every source and setting, and a migrated source taking a catalogue that search finds.
