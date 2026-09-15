# Phase 1 — Foundation: plan

## Context
Phase 0 ended with GO for Linux (ADR-007, accepted 2026-09-15). Phase 1 creates the production Flutter app that every later phase builds on: packages and lints, core plumbing (Result, logging with `redact()`, error handlers, isolates), the design system and a Component Gallery that matches the Claude Design canvas, the keyboard-first desktop shell, the drift database skeleton, the fake provider skeleton, tests, and CI.
Exit criteria (docs/08): the gallery matches the canvas · the shell is fully keyboard navigable · redaction tests pass · CI is green on Linux and Windows.

Inputs already checked this session: the published canvas equals `design/*.dc.html` (19 files, no comments), so the local files are the visual reference. Phase 0 carry-overs: `dependency_overrides` → `third_party/media_kit_video`; analyzer excludes `third_party/**` and `spike/**`; format only `lib test integration_test tools`; fake provider loops MKV remuxes.

**Decided with you (2026-09-15), recorded in ADR-008 and docs/05 during the phase:**
- The canvas wins over docs/05 for the shell: a 64 px top bar, no Search item in the nav rail (search lives in the top bar and Ctrl+K), and the canvas focus style (2 px accent ring + 4 px glow at 25 %).
- Canvas values that docs/05 lacks become named tokens: radius 10, and text sizes 12, 14, and 17 px.
- Icons are the canvas's own SVGs, rendered with flutter_svg (a new package; version checked on pub.dev in step 1).
- Application ID: `io.github.yasiralobaidi.iptvplayer`.

Working rhythm: one numbered step at a time. After each step run analyze, format, and tests, commit locally (no trailers, not pushed), and stop for your review.

## Step 1 — Project scaffold
- Run `flutter create --platforms=linux,windows --org io.github.yasiralobaidi --project-name iptv_player` in the scratchpad. Copy `linux/`, `windows/`, `pubspec.yaml`, and `lib/main.dart` into the repo, so README.md, .gitignore, and docs aren't overwritten. Set the Linux `APPLICATION_ID` to `io.github.yasiralobaidi.iptvplayer` and the Windows product name to "IPTV Player".
- `pubspec.yaml`: every ADR-002 package at its ADR version (`^`), plus flutter_svg (latest stable, checked on pub.dev), plus `dependency_overrides: media_kit_video: path: third_party/media_kit_video`. Commit `pubspec.lock`. Declare font assets (step 3a).
- `analysis_options.yaml`: very_good_analysis 11, riverpod_lint plugin, exclude `third_party/**`, `spike/**`, `**/*.g.dart`, `**/*.freezed.dart`. `build.yaml` for drift/riverpod/freezed options.
- Verify: `flutter pub get`, `build_runner build`, `flutter analyze`, `flutter build linux --debug`, and the app opens an empty window.

## Step 2 — core/
- `lib/core/result.dart`: sealed `Result<T>` (`Ok`/`Err`), sealed `AppFailure` (network, auth, notFound, parse, storage, timeout, cancelled, unexpected), each with a user-facing message key and a redacted detail.
- `lib/core/logging/`:
  - `redact.dart`: Xtream path credentials (`/live|movie|series|timeshift/{u}/{p}/`), query-string `password`/`username`/`token`, basic-auth `user:pass@host`, `Authorization` headers, and runtime-registered secrets.
  - `app_logger.dart` (logger package; every message passes through redact).
  - `rotating_file_sink.dart`: 5 × 5 MB, buffered async writes, in the app support `logs/` folder.
- `lib/app/bootstrap.dart`: `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError` → log, plus a non-fatal toast stream the shell shows (step 4).
- `lib/core/isolates/background.dart`: `runInBackground<T>` (`Isolate.run` + timeout → `Result<T>`) and `BackgroundWorker` (spawned isolate with a progress stream, cancel, and error reporting) for sync/parsers later.
- `lib/core/platform/form_factor.dart`: `FormFactor.desktop`, with a debug override for `tv` later.
- Tests: redact (the three required cases plus encoded and edge cases, and no false positives on normal URLs), rotation (temp dir), Result/AppFailure, isolate timeout/error/cancel.

## Step 3a — design/ foundations
- Fonts: `assets/fonts/Manrope[wght].ttf` and `JetBrainsMono[wght].ttf` with their OFL.txt from google/fonts, added to `LicenseRegistry`. Weights come from `FontWeight` + `FontVariation('wght')`. If a variable weight renders wrong on Linux, generate static instances with fontTools (noted in ADR-008).
- `lib/design/tokens.dart`: colors (dark) and the five accents; spacing; radius xs 6 · sm 8 · **10** · md 12 · lg 16 · pill; elevation/shadow; focus (2 px ring + 4 px glow at 25 %); density (row 56/44); typography (docs/05 scale plus **12, 14, and 17 px** styles taken from the canvas, tabular figures); motion with reduce-motion variants. `AppTokens` is a `ThemeExtension`, so accent, density, and reduce motion change at runtime.
- `lib/design/theme.dart`: dark `ThemeData` built only from tokens.
- `lib/design/focus/`:
  - `FocusableSurface`: Focus + Actions for Enter/Space, hover separate from focus, 2 px ring + glow, 1.03 scale for tiles, one-step lighter surface.
  - `FocusPane`: a `FocusTraversalGroup` that remembers its last focused child; Left/Right moves between panes.
  - Directional intents and the Menu / Shift+F10 intent.
- Basic components (`lib/design/components/`): AppButton, AppIconButton (tooltip with shortcut), AppTextField (clear, validation, reveal), SearchField, Chip/FilterChip, Badge, Kbd, Tooltip, ProgressBar, Skeletons, EmptyState, ErrorState (Retry + Details), SegmentedControl.
- Component Gallery at `/dev/gallery`, only in debug builds or with `--dart-define=GALLERY=true`. It has sections per component, each shown in default, hover, focused, pressed, disabled, loading, and error states, plus toggles for accent, density, and reduce motion. Fully keyboard navigable.
- Widget tests: activation by Enter/Space, focus ring visible, disabled state not focusable.

## Step 3b — design/ media and overlay components
ChannelLogo (monogram color from the name hash) · ChannelRow · PosterCard · LandscapeCard · SectionHeader · HorizontalRail (virtualized, edge arrows on hover) · Slider (volume, seek with time bubble) · Banner · Toast · Dialog/Sheet · Menu/ContextMenu · CastingBar · QualityBadge · ReconnectingPill · DownloadButton (all states) · DownloadRow · StorageMeter. These are presentational only: plain parameters, no domain imports. Each goes in the gallery with widget tests.
Icons: the canvas SVGs, extracted from `design/*.dc.html` into `assets/icons/*.svg` (deduplicated, `currentColor` stroke). `AppIcon` renders them with flutter_svg, tinted with token colors. The icon set goes in the gallery (step 3a gets the icons the basic components need).

## Step 4 — app/: router, shell, window, shortcuts
- `lib/app/router.dart`: go_router `StatefulShellRoute.indexedStack` with Home, Live TV, Guide, Movies, Series, Favorites, Library, Settings; a Search overlay route (Ctrl+K or `/`); and `/dev/gallery`. Placeholder screens use EmptyState ("Coming in Phase N").
- `lib/app/desktop_shell.dart`:
  - Nav rail, 72 px collapsed / 240 px expanded (toggle): app mark, Home, Live TV, Guide, Movies, Series, Favorites, Library, spacer, Settings (no Search item, as on the canvas); active indicator bar as on the canvas. It collapses automatically below 1280 px.
  - Top bar (64 px): title, source chip ("No source"), search field with Ctrl K keycap, a sync status slot, a download indicator slot, and the cast button (disabled).
  - A hidden CastingBar slot, and a toast host fed by the error handlers from step 2.
- `lib/app/shortcuts.dart`: Ctrl+1…7, Ctrl+, , Ctrl+K and `/` (ignored while a text field has focus), Esc back/close. Player keys come in Phase 3.
- window_manager: minimum 1024 × 640 and a title. Size and position are remembered through a `WindowBoundsStore` interface; step 5 backs it with the settings table. On Wayland only the size can be restored, because apps can't position their own windows. Also check window_manager #585 (crash on exit) on this laptop.

## Step 5 — data/db
- `lib/data/db/app_database.dart`:
  - drift, schema v1.
  - `sources` table: id, type, name, server/playlist URL or file path, EPG URL, user agent, live format, EPG offset, refresh interval, connection limit override, timestamps. It has no credential columns; credentials live in flutter_secure_storage, keyed by source id.
  - `settings` table: a key and a JSON value.
  - Opened with `NativeDatabase.createInBackground` (off the UI isolate).
- `SettingsRepository` returns `Result`, and backs window bounds and the rail's expanded state.
- Migration setup: the `drift_dev make-migrations` flow, with `drift_schemas/` committed and generated schema tests under `test/data/db/`. Also a smoke test that FTS5 is compiled in (needed in Phase 6).
- Tests: DAOs on in-memory drift, SettingsRepository, the schema v1 verifier.

## Step 6 — tools/fake_provider (skeleton)
- A separate Dart package: shelf, shelf_router, args. Same lints; covered by `dart format tools`.
- `bin/server.dart --port 8899 --profile default --samples <dir> --ffmpeg <path>`.
- `lib/`:
  - `profile.dart`: counts, seed, quirk toggles.
  - `generator.dart`: deterministic seeded channels, movies, and series, generated lazily so 50k rows stay cheap.
  - `player_api.php`: account info (user_info/server_info with `max_connections`); live/VOD/series categories and lists from the generator; other actions return a documented 501.
  - Streams at `/live/{u}/{p}/{id}.ts`: `ffmpeg -re -stream_loop -1 -i <sample>.mkv -c copy -f mpegts pipe:1`. Remuxes are cached with a `.part` + rename, ported from `spike/cast_spike/lib/relay.dart:128-141`. The process is killed on client disconnect and has a PID file and startup cleanup (hard rule 8). `max_connections` is enforced, with 401 on bad credentials.
  - `/admin/faults` stub: GET/POST of the fault set; injection itself comes in later phases.
- A README with usage, profiles, and the MKV-not-TS note.
- Tests: generator determinism and JSON shape; the account and list handlers in process; the stream test is skipped when ffmpeg or samples are missing.

## Step 7 — goldens and shell keyboard test
- `test/flutter_test_config.dart` loads the bundled fonts. Component-sheet goldens at 1280×800, and the shell at 1280×800 and 1920×1080. Tagged `golden`; they run on Linux only (text rasterization differs on Windows; recorded in ADR-008).
- `test/app/shell_keyboard_test.dart`: Tab and arrows through the rail and top bar, Enter opens a destination, Ctrl+1…7 and Ctrl+, , Ctrl+K opens and Esc closes search, and the focus ring is visible at each stop.
- `integration_test/app_launch_test.dart`: a smoke test (launch, shell renders, navigate) so the CI xvfb path exists from day one.
- Compare the gallery with the canvas side by side: screenshots with the `run` skill against the `.dc.html` artboards; differences listed in the step report.

## Step 8 — CI (GitHub Actions)
`.github/workflows/ci.yml`, a matrix of ubuntu-22.04 and windows-latest, with Flutter 3.47.4 pinned:
1. apt dependencies (GTK, libmpv, libsecret, jsoncpp, mimalloc, ninja, clang)
2. `pub get` for the app and the fake provider
3. build_runner, then `git diff --exit-code`
4. `flutter analyze`
5. `dart format --set-exit-if-changed lib test integration_test tools`
6. `flutter test` (goldens excluded on Windows), then the fake provider tests
7. `flutter build linux|windows --release`, uploaded as artifacts
8. Linux only: the integration test under xvfb

`gh` isn't installed, so I can't watch runs. You push, and "CI green" is confirmed from the Actions page (or after you install `gh`).

## Docs at the end of the phase
- ADR-008: Phase 1 foundation choices: app ID `io.github.yasiralobaidi.iptvplayer`; the canvas wins on shell sizes and focus style; extra tokens; canvas SVG icons with flutter_svg (added to the ADR-002 table); variable fonts; Linux-only goldens; window bounds on Wayland.
- docs/05 updated: 64 px top bar, rail without Search, the focus glow, radius 10, and the 12/14/17 px styles. docs/01 package table gets flutter_svg; docs/06 notes Linux-only goldens.
- progress.md and handoff.md.

## Verification (per step and at exit)
- Every step: `flutter analyze` clean, format check clean, `flutter test` green, `flutter build linux --debug` succeeds.
- Step 4 and later: `flutter run -d linux`. Navigate the whole shell with the keyboard only; resize below 1280 px and to 1024×640; restart to confirm the window size is remembered.
- Step 6: `dart run tools/fake_provider/bin/server.dart --port 8899`, then `curl` the account endpoint, and play `/live/test/test/1.ts` with mpv to confirm the MKV loop and that the process is cleaned up on disconnect.
- Exit: the gallery screenshots against the canvas, the keyboard test, the redaction tests, and CI green on both OSes after you push.

## Risks
- riverpod_lint plugin, drift_dev, and freezed analyzer version clashes (ADR-002 resolved them together; re-run if a patch release lands).
- Variable-font weight rendering in goldens.
- window_manager positioning on Wayland.
- media_kit_libs on the Windows CI runner (downloads libmpv at build time).
- very_good_analysis strictness slowing the first steps.
