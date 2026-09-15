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

## ADR-003 · pending (Phase 0) — Desktop playback spike results

## ADR-004 · pending (Phase 0) — Casting spike results, device model(s), verified LOAD fields

## ADR-005 · 2026-09-15 · Accepted — Downloads and local library in v1
**Decision:** v1 downloads provider movies and episodes and manages a library of the user's own video files; both play offline and cast to Chromecast / Google TV. New Phase 8; settings/polish and packaging move to Phases 9 and 10. Spec: docs/09.
**Context:** The user wants to download movies and episodes (from IPTV or elsewhere), manage them in the player, and watch them on their Google TV.
**Alternatives rejected:**
- A separate media server (Plex, Jellyfin) — another app to install and run, with no link to IPTV watch progress
- Downloads inside the Google TV app — Chromecast with Google TV has 8 GB of storage; casting from the laptop covers the need
**Consequences:** Downloads share provider connection limits and pause for playback; casting gains a direct-file path with Range requests plus a relay path with seeking and WebVTT subtitles; four new tables via a migration; no online metadata lookups in v1; recording live channels stays a non-goal.
