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

## ADR-002 · 2026-09-15 · Accepted (media_kit provisional until ADR-003) — Package selection and versions
**Decision:** Toolchain Flutter 3.47.4 stable (Dart 3.13.3). Packages below, checked on pub.dev and GitHub on 2026-09-15 (latest version, release date, platform tags, open issues). Constraints use `^` on these versions; `pubspec.lock` is committed.

| Need | Package (version) | Released | Notes |
|---|---|---|---|
| State | flutter_riverpod 3.4.3 · riverpod_annotation 4.0.7 · riverpod_generator 4.0.9 (dev) · riverpod_lint 3.1.9 (dev) | 2026-09-03 | Riverpod 3 code-gen |
| Routing | go_router 18.0.1 | 2026-09-02 | Flutter favorite; needs Flutter ≥ 3.44 |
| Database | drift 2.35.0 · drift_dev 2.35.0 (dev) · sqlite3 3.6.0 | 2026-09-09 / 09-13 | **sqlite3_flutter_libs dropped:** it is end-of-life (0.6.0+eol, does nothing). sqlite3 3.x bundles SQLite through build hooks; the default binaries are compiled with `SQLITE_ENABLE_FTS5`. Linux binaries need glibc ≥ 2.24 |
| HTTP | dio 5.11.1 | 2026-09-04 | |
| Models | freezed 4.0.1 (dev) · freezed_annotation 3.1.0 · json_serializable 6.14.1 (dev) · json_annotation 4.12.0 · build_runner 2.16.1 (dev) | 2026-08/09 | |
| Desktop video | media_kit 1.2.6 · media_kit_video 2.0.1 · media_kit_libs_video 1.0.7 | 2025-12-13 | **Provisional.** Last pub release is 9 months old; main (c533e44, 2026-08-30) has unreleased Linux fixes (#1440 raster-thread block, #1446 memory leaks). Open Linux issue #1404: on Flutter ≥ 3.38 the H/W render path can fall back to S/W rendering (EGL context not current on the platform thread), confirmed by several users on Intel, AMD, NVIDIA. Also #1345 tearing on 3.38+. Spike A tests pub 1.2.6 and main@c533e44 and checks the `VideoOutput` log line; if H/W rendering or hwdec fails, compare **fvp 0.38.1** (2026-08-17). On Linux media_kit uses the system libmpv (Ubuntu 22.04: 0.34.1), which the AppImage must bundle (Phase 10) |
| mDNS | bonsoir 7.1.5 | 2026-08-11 | Linux uses Avahi over D-Bus. Watch Windows #156 (possible deadlock in `BonsoirDiscovery.stop()`). Fallback multicast_dns 0.3.3+1 + manual IP |
| Local HTTP | shelf 1.4.2 · shelf_router 1.1.4 | 2024-06 / 2023-05 | Old releases, but dart-lang maintained and stable; no open blockers |
| Cast protobuf | protobuf 6.1.0 · protoc_plugin 25.1.0 (dev tool, generated code committed) | 2026-09-11 | Needs `protoc` once (apt `protobuf-compiler`). If that's a hassle, the fallback hand-written encoder is small: CastMessage has 7 fields |
| Window | window_manager 0.5.2 | 2026-07-04 | Linux issues to check in Phase 1: #585 crash on exit (Fedora KDE X11), #561 title bar on KDE Wayland |
| Secrets | flutter_secure_storage 11.1.1 | 2026-09-11 | libsecret on Linux; no open Linux issues |
| Images | **extended_image 10.1.0** | 2026-07-12 | Chosen over cached_network_image 4.0.0, which depends on flutter_cache_manager → sqflite (no native desktop backend) and limits its disk cache by object count, not bytes. docs/06 needs a 500 MB disk cap: we add a small size-based cache sweeper |
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

## ADR-003 · 2026-09-15 · In progress (Intel done; NVIDIA done on X11, Wayland pending; Windows deferred) — Desktop playback spike results
**Setup:** HP laptop, Ubuntu 22.04.5, kernel 6.8, GNOME on Wayland for the first Intel runs (X11 runs there use XWayland via `GDK_BACKEND=x11`); after the NVIDIA driver install and reboot the session was "Ubuntu on Xorg", used for the real-Xorg and NVIDIA runs, Intel UHD CometLake-H (iHD 22.3.1), GTX 1650 Ti. Flutter 3.47.4 release build (Impeller, OpenGL ES). media_kit uses the system libmpv 0.34.1 with FFmpeg 4.4.2. Spike: `spike/playback_spike` plays each sample as an endless MPEG-TS stream (`-re -stream_loop -1 -c copy`) over loopback, with the Balanced preset and `hwdec=auto-safe`. Per sample: 5 s warm-up, then a 12 s measuring window (45 s for the codec switch). Results in `spike/playback_spike/results/`; `summarize.py` prints the tables.

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

**Visual check on NVIDIA:** not confirmed by a frame grab. `x11grab -window_id` failed with BadMatch and wrote nothing, most likely because `grab_frame.sh` took the first window named playback_spike, and GTK also creates an unmapped one with that name (a later run's first match was `IsUnMapped`). A root-region grab of that geometry captured whatever covered the screen instead, so it proves nothing (those images were deleted). `grab_frame.sh` now picks a viewable window and fails when no image is written. Evidence so far: mpv reports `nvdec` with 0 dropped frames, and nvidia-smi lists the process on the GPU. The user confirms the picture by eye during the NVIDIA Wayland runs.

**GPU choice for the app:** without the offload variables the app renders and decodes on Intel, which already meets every budget. NVIDIA is not required; whether to offer "use discrete GPU" (for example `PrefersNonDefaultGPU=true` in the .desktop file) is decided in packaging (Phase 10).

**Decision (user, 2026-09-15): ship the fix as a pinned patched fork of media_kit_video.** The app depends on our fork with `spike/vendor/media_kit_video_egl_display.patch` applied, pinned to a commit, until upstream fixes #1404. We don't post the patch upstream (it would go out under the user's account) unless the user asks. fvp stays the fallback only if Windows fails.

**Windows (user, 2026-09-15):** a real Windows PC exists but isn't available yet. The Windows run is deferred and doesn't block step 4 on Linux.

**Pending:** NVIDIA on native Wayland (needs a Wayland login). fvp isn't needed: Intel and NVIDIA both work with the patch.

## ADR-004 · pending (Phase 0) — Casting spike results, device model(s), verified LOAD fields

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
