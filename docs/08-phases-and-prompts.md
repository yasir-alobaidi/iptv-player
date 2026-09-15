# 08 — Phases & session prompts

## How to work
- One phase (or one numbered step of a big phase) per Claude Code session, opened in the repo root.
- Paste the phase prompt. Claude reads CLAUDE.md, docs/progress.md, and the listed specs, then **proposes a plan (plan mode) before writing code**.
- Small commits; analyze + format + tests before each commit.
- End every session by updating docs/progress.md.
- Don't start a phase until the previous phase's exit criteria are met.

## Timeline (part-time estimates)
| Phase | Scope | Estimate |
|---|---|---|
| 0 | Environment + spikes (playback, casting, packages) → GO/NO-GO | 4–6 days |
| 1 | Foundation: app skeleton, design system, shell, fake provider, CI | 1 week |
| 2 | Sources, onboarding, sync | 1–1.5 weeks |
| 3 | Live TV, player, watchdog | 1.5–2 weeks |
| 4 | EPG and guide | 1–1.5 weeks |
| 5 | Movies, series, home | 1 week |
| 6 | Search, favorites, categories polish | 4–5 days |
| 7 | Casting | 2–3 weeks |
| 8 | Downloads and local library, including casting library items | 1.5–2 weeks |
| 9 | Settings, diagnostics, UX and performance polish | 1 week |
| 10 | Packaging and release | 1 week |
| TV-0…TV-5 | Google TV version (docs/07) | 4–6 weeks |

---

## Phase 0 — Environment & spikes (GO / NO-GO)
```
Read CLAUDE.md, docs/00-overview.md, docs/01-architecture.md, docs/03-playback.md, docs/04-casting.md, docs/06-quality.md, docs/setup.md, and docs/progress.md.

This phase proves the risky parts before we build the app. Spikes live in spike/ (throwaway). Record findings in docs/decisions.md.

1. Environment: check the setup in docs/setup.md on this machine (Ubuntu 22.04, fish shell). List exactly which commands I must run with sudo — don't run sudo yourself. Initialize git with a .gitignore suitable for Flutter plus third_party/ffmpeg binaries, spike outputs, and the generated design bundle design/iptv-player-ui.html. Write tools/fetch_ffmpeg.sh to download a recent static FFmpeg/ffprobe build (7.x or newer) into third_party/ffmpeg/linux-x64/ and run it.
2. Package health: for every candidate in docs/01-architecture.md, check latest version, release date, Linux/Windows/Android support, and critical open issues. Write ADR-002 in docs/decisions.md with the chosen package + version (or the fallback) and why.
3. Media samples: write tools/media_samples/generate.sh per docs/06-quality.md and generate them.
4. Spike A — playback (spike/playback_spike): minimal Flutter Linux app with media_kit that plays each sample from a local HTTP URL (tiny Dart server looping the file as MPEG-TS). On screen: hwdec-current, codec, resolution, fps, dropped frames, and process CPU %. Test on Intel (VA-API) and on NVIDIA (NVDEC; with PRIME render offload if needed). Measure zap time between two streams (20 runs, p50/p95). Confirm the libmpv property names used in docs/03-playback.md against the bundled libmpv. If hardware decoding of HEVC 4K fails or playback is unstable, repeat with fvp and compare. Then ask me whether I have a real Windows PC (not a VM): if yes, give me the steps to run the spike there and record hwdec-current for H.264 and HEVC; if not, record Windows hardware decoding as unverified in ADR-003.
5. Spike B — casting (spike/cast_spike): Dart CLI that discovers Cast devices (multicast_dns, with manual IP fallback; bonsoir needs Flutter and is tested in Phase 7, see ADR-006), connects with a minimal Cast v2 client, launches the Default Media Receiver, and loads a relay URL. Relay: bundled FFmpeg reading a looping sample with -c:v copy, audio to AAC, HLS output served by shelf with CORS headers. Test h264_1080p50_aac, h264_1080p25_ac3, and hevc_2160p25_eac3 (fMP4, only if my device supports HEVC). Also cast vod_h264_aac_10min.mp4 as a plain file served with HTTP Range requests (streamType BUFFERED) and check that seeking works — the path for downloads and local files (docs/09). Verify LOAD fields — including the HLS segment format fields — against current Google Cast documentation. Ask me for my Google TV / Chromecast model before this step; the laptop and the device must be on the same home network.
6. Write ADR-003 (playback results with measurements) and ADR-004 (casting results, device model, verified LOAD fields) and a clear GO / NO-GO for the stack. Update docs/03, docs/04, and docs/setup.md with anything that turned out different.

Stop after each numbered step, summarize, and wait for my OK before continuing.
```
**Exit criteria:** hardware decoding confirmed for H.264 and HEVC on Linux (and on Windows if a real Windows PC is available) · zap time measured · at least one H.264 sample casts with `-c:v copy` (plus HEVC if the device supports it) · a local MP4 casts as a plain file with working seeking · ADR-002/003/004 written · GO decision.

## Phase 1 — Foundation
```
Read CLAUDE.md, docs/01-architecture.md, docs/05-design-system.md (and the Claude Design canvas linked there, via the Artifact tool), docs/06-quality.md, docs/decisions.md, docs/progress.md.

Create the production Flutter app (Linux and Windows targets; Android comes in v2) using the folder layout in docs/01.
1. pubspec with packages from ADR-002; lints; build_runner.
2. core/: Result/AppFailure; logging with rotating file sink and redact() (unit tests: Xtream path credentials, query-string passwords, basic-auth URLs); global error handlers; background isolate helper; form-factor detection.
3. design/: tokens (colors, typography with bundled Manrope and JetBrains Mono, spacing, radius, motion, density), ThemeData, FocusableSurface focus system, and every core component in docs/05. Add a dev-only Component Gallery route that shows each component in each state and is fully keyboard navigable.
4. app/: go_router with the desktop shell (nav rail, top bar, placeholder screens for all destinations); window_manager (min size, remember size/position); global shortcut layer from docs/05.
5. data/db: drift database skeleton (sources, settings) with migration test setup.
6. tools/fake_provider: server skeleton (account endpoint, configurable data generation, streaming generated samples) with README.
7. Golden tests for core components; widget test for keyboard navigation through the shell.
8. GitHub Actions CI per docs/06 (Linux + Windows).
Match the Claude Design canvas visually. Propose the plan first.
```
**Exit criteria:** gallery matches the canvas · shell fully keyboard navigable · redaction tests pass · CI green on Linux and Windows.

## Phase 2 — Sources, onboarding, sync
```
Read CLAUDE.md, docs/02-providers-and-data.md, docs/05-design-system.md (Onboarding, Settings → Sources, Categories; check the canvas), docs/06-quality.md, docs/progress.md.

1. Full drift schema from docs/02 including FTS tables; DAOs; migration tests.
2. Xtream client (dio): account, categories, live, movies, series; tolerant DTO decoding covering every quirk in docs/02 with one fixture test per quirk; serialized requests with backoff; configurable User-Agent.
3. M3U streaming parser in an isolate (gzip, attributes, EXTVLCOPT, classification, stable identity) with fixtures including malformed and 50 MB files.
4. Credential store (flutter_secure_storage); passwords never stored in the DB.
5. Sync engine in a background isolate: stages, progress events, upsert + mark-and-sweep, user data preserved, one sync per source, failure keeps old data. Extend the fake provider with all Xtream/M3U endpoints and quirk toggles.
6. Onboarding flow, Settings → Sources, and the Categories manager per docs/05, with every state.
7. Source switcher in the top bar; account status and expiry banner.
8. Integration test: onboarding against the fake provider (50k channels) → sync → category picker → Home; assert no UI frame over 32 ms during sync.
Propose the plan first.
```
**Exit criteria:** sync budget met · all quirk fixtures pass · onboarding works against the fake provider and my real provider.

## Phase 3 — Live TV, player, watchdog
```
Read CLAUDE.md, docs/03-playback.md, docs/05-design-system.md (Live TV, Full-screen player, shortcuts; check the canvas), docs/06-quality.md, docs/decisions.md (ADR-003), docs/progress.md.

1. PlayerEngine in core/player and MediaKitPlayerEngine in data/player_mediakit with base options and buffer presets from docs/03 (property names as verified in ADR-003).
2. PlaybackCoordinator (connection policy, history) and PlaybackWatchdog (state machine, error classes, backoff, URL rebuild) with thorough unit tests using a fake engine.
3. StreamUrlBuilder for Xtream and M3U sources.
4. Live TV 3-pane screen: categories, virtualized channel list, debounced preview player, favorites, context menu, all states.
5. Full-screen player: OSD, channel banner, left channel panel, number entry, last channel, audio/subtitle/aspect menus, stream info overlay, ReconnectingPill, failure card.
6. Integration tests with fake-provider faults: drop, stall, slow start, 401, 404, connection limit, expiring redirect, codec switch — each recovers or shows the right message.
7. Zap-time benchmark (p50/p95) and tools/soak script (N hours, random faults, memory/CPU log).
Propose the plan first.
```
**Exit criteria:** all fault tests pass · zap budget met · 1-hour soak clean (8-hour soak before release).

## Phase 4 — EPG & guide
```
Read CLAUDE.md, docs/02-providers-and-data.md (XMLTV, matching), docs/05-design-system.md (Guide; check the canvas), docs/06-quality.md, docs/progress.md.

1. XMLTV streaming parser in an isolate (gzip, retention window, time offsets) with staging tables and atomic swap; fixtures including a generated 300 MB file.
2. Xtream short EPG (base64) for on-demand now/next when the full guide is missing or stale.
3. EPG matcher (exact id → case-insensitive → normalized name → manual mapping) with unit tests; Settings → Guide mapping UI.
4. Now/next everywhere: channel rows, preview, OSD, Home favorites.
5. Guide grid with 2D virtualization, now line, day selector, keyboard navigation, program detail sheet.
6. Daily refresh scheduling; "Guide updated" toast; programs FTS for search.
Propose the plan first.
```
**Exit criteria:** 300 MB import within budget without jank · guide scrolls smoothly with 50k channels × 7 days.

## Phase 5 — Movies, series, home
```
Read CLAUDE.md, docs/02-providers-and-data.md (movies/series), docs/03-playback.md (VOD & series), docs/05-design-system.md (Home, Movies, Series; check the canvas), docs/progress.md.

1. Movies grid (category chips, sort, filter, skeletons, image caching); movie details with lazy get_vod_info and caching.
2. Series grid; series details with lazy get_series_info (map and list episode shapes), season tabs, episode rows.
3. VOD playback in the full-screen player: seek bar, resume prompt, progress saving, completion, next-episode countdown.
4. Home rows: Continue Watching, Favorite Channels (with now/next), Recently Watched, Recently Added Movies/Series; first-run hero.
Propose the plan first.
```
**Exit criteria:** movie and series details load lazily and are cached (a second open makes no network request) · map and list episode shapes pass fixture tests · resume prompt, progress saving, completion at 95 %, and the next-episode countdown pass integration tests against the fake provider · Home shows every row and the first-run hero · every new screen has widget tests for its loading, empty, error, and content states.

## Phase 6 — Search, favorites, categories polish
```
Read CLAUDE.md, docs/05-design-system.md (Search, Favorites, Categories, name cleanup; check the canvas), docs/progress.md.

1. Global search overlay (Ctrl+K) over FTS: channels, programs now/upcoming, movies, series; grouped, keyboard navigable, recent searches.
2. Favorites screen: channels with drag reorder and groups; movies; series; empty states.
3. Channel name cleanup (display names + quality badges) with unit tests; rename support.
4. Hide/unhide/reorder polish across Live TV and Settings.
Propose the plan first.
```
**Exit criteria:** Ctrl+K search returns grouped results on the 50k-channel / 30k-movie fake dataset and works with the keyboard alone · favorites order and groups survive restart and re-sync · name cleanup tests cover every pattern in docs/05 · hidden items stay hidden in Live TV, Guide, Search, and Home and can be restored from Settings.

## Phase 7 — Casting
```
Read CLAUDE.md, docs/04-casting.md, docs/05-design-system.md (Casting; check the canvas), docs/06-quality.md (fake receiver), docs/decisions.md (ADR-004), docs/progress.md.

Build in this order and stop after each step for review:
1. CastDiscovery (bonsoir + manual IP) and cast_devices persistence.
2. CastV2Client + MediaChannel, tested against a fake Cast v2 receiver (TLS, framing, connect/launch/load/status/heartbeat/errors).
3. StreamProbe (bundled ffprobe) and CastPlanner (pure; exhaustive unit tests against the rules in docs/04).
4. Hardware encoder detection (test encodes, cached).
5. RelayServer, FfmpegRelay, RelaySupervisor (stall restart, restart budget, cleanup, PID files, startup sweep).
6. CastCoordinator: direct fast path with fallback, device capability learning, local playback suspension, zapping while casting, sleep inhibition, Windows firewall pre-prompt.
7. UI: device picker, casting view with QualityBadge, casting bar, toasts.
8. Walk me through the casting test matrix in docs/04 on my device(s); record results in docs/decisions.md.
Propose the plan first.
```
**Exit criteria:** casting matrix passes on owned devices · no orphan ffmpeg processes after killing the app with SIGKILL and relaunching.

## Phase 8 — Downloads & local library
```
Read CLAUDE.md, docs/09-downloads-and-library.md, docs/03-playback.md (connection policy, VOD, local files), docs/04-casting.md (Local files and downloads, library casting matrix), docs/05-design-system.md (Library, Movie and Series details, shortcuts; check the canvas), docs/06-quality.md, docs/decisions.md (ADR-004, ADR-005), docs/progress.md.

Build in this order and stop after each step for review:
1. Schema migration for library_folders, library_items, downloads, and library_fts, with migration tests; register the default download folder as a library folder.
2. Fake provider: VOD files with Range/ETag/Last-Modified, HLS VOD mode, and the download faults in docs/06; tools/media_samples/library_tree.sh.
3. DownloadQueue, HttpDownloader, HlsDownloader, DownloadFinalizer with unit tests for every rule in docs/09; connections through the PlaybackCoordinator (playback pauses downloads, which resume afterwards).
4. NameParser with the fixture corpus; LibraryScanner isolate, quick-hash identity, folder watching, external subtitles, thumbnails.
5. Offline playback of library items through PlayerEngine; progress shared with provider items; favorites and history for local files.
6. UI: Library screen (tabs, Downloads, Folders, item menu, Edit details), DownloadButton on movie and series details, top-bar download indicator, Library results in search, Settings → Downloads & library, offline banner — every state, matching the Library, Library · Downloads, and Settings · Downloads and library artboards.
7. Casting library items per docs/04: direct file with Range, relay with seeking for everything else, WebVTT subtitles; extend the fake receiver tests.
8. Integration tests (download → kill app → relaunch → resume → play offline; library scan → play → resume), then walk me through the library casting matrix in docs/04 on my device(s); record results in docs/decisions.md.
Propose the plan first.
```
**Exit criteria:** downloads resume after network drops and after SIGKILL + relaunch, with no damaged file under a final name · playback on a 1-connection source pauses downloads and they resume afterwards · a downloaded movie plays with the network off and shares progress with streaming · library budgets in docs/06 met · library casting matrix passes on owned devices · no orphan ffmpeg processes after SIGKILL + relaunch.

## Phase 9 — Settings, diagnostics, polish
```
Read CLAUDE.md, docs/05-design-system.md (check the canvas), docs/06-quality.md, docs/progress.md.

1. Complete every Settings section in docs/05.
2. Diagnostics: log viewer; Copy diagnostics (app/OS/GPU info, hwdec results, encoder detection, recent errors — redacted).
3. UX audit: every screen keyboard-only; loading/empty/error/offline states; focus traps; text scale 115/130 %; reduce motion. Fix everything found.
4. Performance pass in profile mode against docs/06 budgets; record numbers in docs/progress.md.
5. 8-hour soak with faults on Linux (and Windows if available); fix leaks.
Propose the plan first.
```
**Exit criteria:** every budget in docs/06 met in profile mode and recorded in docs/progress.md · 8-hour soak with faults on Linux: no crash, memory growth ≤ 50 MB · every screen passes the keyboard-only audit at 100/115/130 % text scale and with reduce motion · Copy diagnostics contains no credentials (checked with a real source configured).

## Phase 10 — Packaging & release
```
Read CLAUDE.md, docs/setup.md, docs/progress.md.

1. Windows: release build bundling libmpv (media_kit libs) and ffmpeg/ffprobe; installer (recommend MSIX or Inno Setup with reasons, then build it); icon; first-run firewall explanation.
2. Linux: AppImage bundling libmpv and ffmpeg/ffprobe; desktop entry and icons; test on clean Ubuntu 22.04 and 24.04 VMs.
3. Semantic versioning, CHANGELOG.md, docs/release.md checklist.
4. Final regression: integration tests, casting matrix, library casting matrix, soak summary. If ADR-003 still lists Windows hardware decoding as unverified and I have a real Windows PC by then, verify it now.
Propose the plan first.
```
**Exit criteria:** the AppImage runs on clean Ubuntu 22.04 and 24.04 VMs without system libmpv or FFmpeg · the Windows installer installs, runs, and uninstalls cleanly · packaged builds pass the final regression · CHANGELOG.md and docs/release.md are done and version 1.0.0 is tagged.

## Google TV
Follow docs/07-google-tv.md, starting with TV-0, using the same session pattern.
