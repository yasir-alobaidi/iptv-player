# 06 — Quality, stability & testing

## Stability rules (checked in every review)
- No uncaught exceptions: `FlutterError.onError` and `PlatformDispatcher.instance.onError` log and show a non-fatal toast; errors inside isolates are caught and reported
- Parsers never throw on bad input: they return partial results plus skipped-row reasons (logged and counted in diagnostics)
- Every async operation has a timeout; every retry has a budget and backoff
- Every stream, subscription, timer, and process is disposed by its owner (`ref.onDispose`)
- Bounded resources: image cache (memory 150 MB, disk 500 MB), EPG retention window, rotating logs (5 × 5 MB)
- Every DB migration step has a test
- A file under its final name is always complete: downloads write to `.part` and rename only after verification; the library never modifies files in folders the user added

## Test layers
| Layer | Tooling | Covers |
|---|---|---|
| Unit | flutter_test + mocktail | Xtream DTOs, M3U, XMLTV, name cleanup, EPG matcher, URL builder, CastPlanner, watchdog state machine, backoff, redact(), sync mark-and-sweep, download queue and resume rules, filename sanitizer, NameParser |
| Fixtures | test_fixtures/ | real-world-shaped JSON/M3U/XMLTV with every quirk in docs/02, plus malformed files (truncated, wrong encoding, huge); filename corpus for NameParser (docs/09) |
| Database | drift in-memory + schema verifier | DAOs, FTS queries, migrations |
| Widget | flutter_test | every screen in loading/empty/error/content states; focus traversal order; shortcuts |
| Golden | matchesGoldenFile (bundled fonts loaded by `test/flutter_test_config.dart`) | core components and key screens at 1280×800 and 1920×1080. **Linux only** — text rasterizes differently on Windows, so the same widget is a different image: they carry `@Tags(['golden'])` (declared in the root `dart_test.yaml`), skip off-Linux with a reason, and the Windows CI job runs `flutter test --exclude-tags golden` (ADR-008). Images live in `test/golden/images/`; after re-recording with `--update-goldens`, look at the PNG — a green golden only means nothing changed |
| Integration | integration_test + fake provider | onboarding → sync → play → zap → fault recovery; VOD resume; search; guide; download → kill app → relaunch → resume → play offline; library scan → play → resume |
| Phase exit | integration_test + the fake provider in its own process | `integration_test/large_sync_test.dart`: Welcome → Connect → a `large`-profile sync (50,000 / 30,000 / 3,000), **asserted under docs/06's 60 s** → Pick categories → Home → Settings shows the counts. It starts the fake provider with `dart run` (an empty `--samples` folder, since the API needs none) and kills it after; it measures frame times and the UI isolate's longest pause without asserting them. For the profile-mode numbers: `flutter drive --profile -d linux --driver=test_driver/integration_test.dart --target=integration_test/large_sync_test.dart` (writes `build/integration_response_data.json`). The Linux embedder reports raster time as 0, so only build times and the pause mean anything |
| Real provider | integration_test, opt-in, local only | `integration_test/real_provider_test.dart` walks sources_keyboard_test's flow (wrong password, Cancel, sync, Pick categories, Settings → Refresh, Account details, Edit, Categories, Remove) against a real Xtream panel. Skipped unless `~/.config/iptv-player-dev/real_provider.json` (or `$IPTV_REAL_PROVIDER`) holds `server`, `username`, `password`, so CI skips it; `"wrong_password": false` in it skips the wrong sign-in, since a panel may lock an account out after a few. Throwaway database and in-memory keyring; findings masked into `build/real_provider_run/report.md` and `app.log`. Run with `xvfb-run -a flutter test integration_test/real_provider_test.dart -d linux` |
| Playback | integration_test, the real player and the fake provider (its own process, the samples) | `player_engine_test` (first frame, zap, the connection let go, a missing channel, HLS), `playback_faults_test` (drop, stall, slow start, 401, 404, connection limit, 500, expiring redirect, codec switch), `live_tv_keyboard_test` (Live TV and the player, keyboard only). Skipped without the samples; CI generates the three it needs with Ubuntu's ffmpeg and plays with `IPTV_PLAYER_VIDEO=0` (no picture); the laptop runs them with video. `real_provider_play_test` plays from the user's provider only with `"play": true` in the login file and only after the user freed the connection |
| Crash | a real process killed with SIGKILL | a sync killed part-way leaves the database file intact, the previous catalogue whole and the user's choices kept, and the next launch fails the dead run as interrupted (`test/data/sync/sync_kill_test.dart`: `dart run`s `support/sync_victim.dart` and kills it after 5,000 rows). POSIX only, so skipped on Windows; skipped with a reason when there is no `dart` on PATH |
| Cast protocol | fake receiver (Dart TLS server speaking Cast v2) | connect, launch, load, status, errors, heartbeat loss |
| Soak | tools/soak | 8 h live playback with random faults; memory/CPU logged every minute (1 h at a phase exit) |
| Manual | checklists | casting matrix and library casting matrix (docs/04); Linux Intel + NVIDIA; Windows |

## Fake provider (tools/fake_provider)
`dart run tools/fake_provider/bin/server.dart --port 8899 --profile default`
- Xtream endpoints from docs/02 backed by generated data with configurable counts (e.g., 50,000 channels, 30,000 movies, 3,000 series) and quirk toggles (numbers as strings, `info: []`, map vs list episodes, invalid UTF-8)
- `get.php` M3U output and `xmltv.php` (optional gzip, scalable to 300 MB)
- Streams: loops generated samples (`ffmpeg -re -stream_loop -1 -i <sample>.mkv -c copy -f mpegts pipe:1`) or serves pre-segmented HLS. Loop an MKV remux of each sample, never the `.ts` itself: looping a TS file with B-frames breaks video timestamps at every wrap (on HEVC 4K about 100 decode errors per wrap and a few-second freeze on the TV; ADR-004 Finding 8). Even from MKV a wrap leaves one short gap (under 0.1 s) and a few decode errors, so tests don't assert on frames around a wrap
- VOD files: movie and episode URLs serve the VOD samples with Range, ETag, and Last-Modified; `vod_as_hls` serves them as HLS playlists; `size_mb` pads a sample to any size for download benchmarks
- Fault injection per profile or query: `drop_after_s`, `stall_after_s`, `slow_start_ms`, `http_status` (401/403/404/429/500), `max_connections`, `redirect_with_expiring_token`, `codec_switch_after_s`; for VOD files `ignore_range`, `drop_after_bytes`, `throttle_kbps`, `change_etag`, `wrong_content_length`
- Admin endpoint to change faults at runtime during integration tests (`POST /admin/faults`); **any fault can also be set per request as a query parameter** (`/live/test/test/7.ts?drop_after_s=5`), so one test can fault one stream. Live-stream faults as built (Phase 3): `drop_after_s` ends the body; `stall_after_s` stops the media but sends a 188-byte MPEG-TS null packet each second, so a client that gives up is noticed and its slot freed; `slow_start_ms` delays the answer; `http_status` answers 401/403/404/429 (`Retry-After: 1`)/5xx; `max_connections` refuses with 403 `MAX_CONNECTIONS_REACHED`; `redirect_with_expiring_token` 302s to a `?token=` that gets 403 `TOKEN_EXPIRED` after 10 s; `codec_switch_after_s` swaps to an HEVC (or H.264) loop inside the same body
- Live HLS: `/live/u/p/<id>.m3u8` starts one ffmpeg per channel writing 2 s segments (6 in the playlist) served from `/hls/<id>/`, shared by every viewer, holding one connection slot, stopped 20 s after the last playlist request
- **Tests start it in-process.** It is a path dev-dependency of the app (`fake_provider: {path: tools/fake_provider}`), so a test calls `FakeProviderServer.start(state: …, port: 0)` and gets a free port. Two traps: flutter_test's binding answers every `HttpClient` request with a 400, so a test that talks to a real server sets `HttpOverrides.global = null` in `setUpAll`; and an in-process server shares the test's isolate, so **a timing or UI-jank measurement must run the server as a separate process** (`dart run tools/fake_provider/bin/server.dart --profile large`), or the server's own JSON encoding shows up as the client's jank

## Media samples (tools/media_samples/generate.sh)
Synthetic sources only (`testsrc2`, `smptehdbars`, `sine`):
h264_1080p50_aac.ts · h264_1080p25_ac3.ts · h264_1080i50_mp2.ts (interlaced) · hevc_2160p25_eac3.ts · hevc_1080p50_aac.ts · mpeg2_576i25_mp2.ts · codec_switch_h264_720p_to_1080p.ts · vod_h264_aac_10min.mp4 · vod_hevc_eac3_subs.mkv · vod_h264_ac3_10min.mkv + vod_h264_ac3_10min.en.srt
Live samples are 30–120 s long and the fake provider loops them; VOD samples are 10 minutes.
`tools/media_samples/library_tree.sh <dir> <count>` builds a fake library (movies, episodes, junk release names, subtitles, nested seasons) from short low-resolution clips, each with a unique title tag so quick hashes differ; fictional names only. Tests lower the scanner's 20 MB minimum file size.

## Performance budgets (profile mode, dev laptop)
Measured by tests tagged `benchmark`, which are skipped unless run with `flutter test --tags benchmark --run-skipped` (timings on shared CI runners are noise); the numbers go in docs/progress.md. The sync budget: `test/data/sync/sync_benchmark_test.dart`, with the fake provider in its own process.

| Metric | Budget |
|---|---|
| Cold start to interactive Home (cached data) | ≤ 2.0 s |
| Channel list scroll, 50k rows | no frame > 16 ms at 60 Hz |
| Sync 50k channels + 30k movies (fake provider) | ≤ 60 s; no UI frame > 32 ms |
| XMLTV 300 MB import | ≤ 4 min; UI unaffected; peak RAM +300 MB max |
| Zap p50 / p95 (fake provider) | ≤ 1.5 s / ≤ 3 s |
| Idle memory after sync with guide | ≤ 450 MB |
| H.264 1080p50 playback CPU (hwdec) | ≤ 15 % total CPU |
| 8 h soak memory growth | ≤ 50 MB (median of the last five minutes over the median of minutes 21–25: the player settles for ~40 min, and a reconnect spikes RSS for a sample or two — ADR-010 "The soak run") |
| Library scan, 5,000 new files (library_tree.sh) | ≤ 5 min; browsable while scanning; no UI frame > 32 ms |
| Library rescan, 5,000 unchanged files | ≤ 5 s |
| Download speed vs `curl` on the same URL (fake provider) | ≥ 90 % |
| Memory growth during a 4 GB download | ≤ 30 MB |

## CI (GitHub Actions)
Matrix ubuntu-22.04 + windows-latest (`.github/workflows/ci.yml`): `flutter pub get` **and `dart pub get --directory=tools/fake_provider`, without which the root `flutter analyze` cannot resolve that package's imports** → build_runner (fail on diff; `core.autocrlf false` is set before checkout so Windows does not fail on line endings) → `flutter analyze` (`analysis_options.yaml` excludes `third_party/**` and `spike/**`) → `dart format --set-exit-if-changed lib test integration_test tools` (not `.`: vendored upstream code isn't formatted to our settings) → `flutter test` → `flutter build linux|windows --release`. Linux job also runs integration tests against the fake provider under xvfb, one file per run, after generating the three media samples the player tests need with Ubuntu's ffmpeg, and with `IPTV_PLAYER_VIDEO=0` (no GPU: mpv plays with no picture). Upload release builds as CI artifacts.

## Definition of done (every feature)
1. Spec behavior implemented, including loading/empty/error/offline states
2. Fully usable by keyboard with visible focus
3. Tests at the right layers, all green
4. No analyzer warnings; formatted
5. Logs redacted; no secrets anywhere
6. docs/progress.md updated
