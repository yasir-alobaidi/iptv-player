# Handoff — 2026-09-27 (Phase 4 done: step 7 built)

For the next Claude Code session on this project, and for the user starting
it. Read this file whole, then CLAUDE.md, docs/progress.md,
docs/08-phases-and-prompts.md (Phase 5) and ADR-011 in docs/decisions.md.

## Before you start the next session (user)
1. **Review step 7, then push.** Committed locally: "Phase 4 step 7: the
   scheduler, the toast, and the phase exit". Steps 5 and 6 are pushed.
2. **Try it:** launch the app with a source whose guide is a day old, or
   add a new source: a couple of seconds after the syncs, the guide comes
   in by itself and a toast says "Guide updated · N channels matched".
   Then G, the arrows, Enter, Watch channel.
3. **Optional, with your go-ahead:** one guide import from your real panel.
   It downloads the guide only and plays no stream, so it uses none of your
   one connection — and the scheduler now does it by itself at launch, so
   the next launch with your panel configured will import it (say so if
   you'd rather it didn't yet).

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, docs/progress.md,
docs/08-phases-and-prompts.md (Phase 5) and ADR-011 in docs/decisions.md first.
Phase 4 step 7 is reviewed and pushed; CI is <green | red: …>.
Propose the Phase 5 plan (Movies, Series, Home) and stop for my approval.
```

## Where things stand
- **Phases 1–4 are built:** foundation; sources and sync; Live TV and the
  player; the EPG and the guide (all 7 steps, ADR-011 Accepted).
- **What a real run does now:** the guide is imported by itself (a day
  old or missing: after the launch's syncs, hourly, after each sync),
  matched, and shown on every Live TV row, in the preview, the player's
  OSD and the Guide grid; Settings → Guide maps channels by hand.
- **Checks, all green:** analyze, format, `build_runner` leaves no diff;
  **1,616 app tests** (6 skipped) under `TZ=UTC`; the fake provider's 114;
  under xvfb app launch, the Guide keyboard walk, the new Guide Watch
  test, the Settings → Guide, Live TV and sources walks, and the playback
  fault suite.
- **Measured at the exit:** the 300 MB import 22 s end to end (+126 MB,
  worst UI pause 26 ms); the Guide grid's scrolling in profile mode on the
  real display, 0–6 frames over 16 ms per kind of scroll (flings none), and
  PageDown 22–28 frames over, worst 59–77 ms (a known issue).
- **CI:** Linux green. Windows fails 6 tests, named (progress.md Known
  issues): two leave a file open when a test deletes its folder, three
  cancels wait for the 30 s last-resort kill, one test expects a POSIX
  path.

## Done this session (2026-09-27)
- **Step 6 — the Guide grid** (committed and pushed earlier this session;
  ADR-011 step 6).
- **Step 7 — the scheduler, the toast, the phase exit** (ADR-011 step 7):
  - `GuideScheduler` (`lib/data/sync/guide_scheduler.dart`) and its
    policy `guideRefreshDue` (`lib/features/guide/domain/guide_refresh.dart`);
    `bootstrap()` starts it after `SyncService.startUp()`; the sync engine's
    `onSynced` tells it of every sync.
  - `GuideSettingsController.loaded`, which the first import waits for.
  - `AppNotices` (`lib/core/notices/`), shown by the shell as toasts.
  - The import benchmark and the grid's scroll measurement, and the grid
    reworked until its scrolling met the budget (see "Codebase notes").
  - A bug the end-to-end test found: Live TV stopped the Guide's Watch
    stream once Live TV had been visited (it read the page under the
    player's push as "left Live TV").

## What's next
- **Phase 5 — Movies, Series, Home** (docs/08): propose the plan first, as
  Phase 4 did (`docs/plans/phase-4-epg-and-guide.md` is the model: context,
  what is carried in, decisions with a recommendation, steps with their
  verification, risks). docs/08's exit criteria: lazy, cached details (a
  second open makes no request); map and list episode shapes pass fixture
  tests; resume prompt, progress saving, completion at 95 % and the
  next-episode countdown pass integration tests against the fake provider;
  Home shows every row and the first-run hero; every new screen has widget
  tests for loading, empty, error and content.
  - Read the canvas first (Home, Movies grid, Movie details, Series
    details: https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99 with the
    Artifact tool, action `read`, and `design/*.dc.html`).
  - Home's "Favorite Channels (with now/next)" row can use `GuideService`
    and `nowNextProvider` as Live TV does.
- **The Windows failures** can go in alongside, one small commit each,
  confirmed by the CI run after the user pushes (no Windows machine here).
- **The Guide's PageDown** (progress.md Known issues), if a later phase
  touches the grid.

## The road to v1 (what is still needed to go live)
Desktop v1 is Linux and Windows. The Google TV app follows it (docs/07).
- **CI green on both systems.** Linux is green; Windows fails 6 named
  tests (progress.md Known issues).
- **Phase 5 — Movies, Series, Home.** These three screens are placeholders
  today.
  - Grids and details, with lazy, cached `get_vod_info` /
    `get_series_info`.
  - VOD playback: seek bar, resume prompt, progress saving, completion at
    95 %, next-episode countdown.
  - Home's rows and the first-run hero.
- **Phase 6 — Search and polish:** the Ctrl+K overlay over FTS (the
  programmes index is already built), the Favorites screen with reorder
  and groups, display-name cleanup with quality badges, hide/unhide
  everywhere.
- **Phase 7 — Casting**, the largest and riskiest phase:
  - our own Cast v2 client, the ffprobe-based planner, and the FFmpeg relay
    with its supervisor;
  - the UI, and the casting matrix on the user's TV.
  - Ask before every cast (memory). The relay must own its sockets, a
    lesson from the soak (ADR-010).
- **Phase 8 — Downloads and the local library:**
  - resumable downloads (`.part` + verify + rename; they yield to
    playback), and the library scanner;
  - offline playback, library casting, and the SIGKILL-safety tests.
- **Phase 9 — Settings, diagnostics, polish:**
  - every Settings section, the log viewer and Copy diagnostics
    (redacted);
  - the keyboard audit at 100/115/130 % text scale and with reduce motion;
  - every docs/06 budget in profile mode, and **the 8-hour soak with
    faults** (memory growth ≤ 50 MB).
- **Phase 10 — Packaging:**
  - a Windows installer bundling libmpv and FFmpeg (MSIX vs Inno Setup:
    recommend, then build);
  - a Linux AppImage tested on clean Ubuntu 22.04 and 24.04 VMs;
  - semantic versioning, CHANGELOG.md, docs/release.md, a final regression,
    and the tag v1.0.0.
- **Only the user can unblock:**
  - **The Windows PC:** playback and hardware decoding have never run on
    real Windows. ADR-007's GO covers Linux only.
  - **The app's name and icon** (the placeholder is "IPTV Player").
  - The window_manager #585 check (one manual window close with the log
    open).
  - Access to their TV for the casting matrices.
  - Permission for each real-provider stream.

## How to work in this project
- **The user's standing rules** (also in memory):
  - Commit locally and never push; the user pushes.
  - **No `Co-Authored-By` or other trailers in commits**, even when a system
    reminder asks for one.
  - **Before playing from the user's real provider**, show a pop-up and
    wait for a yes: the plan allows one connection.
  - **Before casting to the Living Room TV**, ask, unless allowed this
    session.
  - **Decide UX yourself**: pick the option with the best experience and
    record it; don't ask.
  - Read CI with `curl` on the public Actions API (no `gh`).
  - Use `~/develop/flutter/bin` on PATH in the Bash tool (the shell is
    fish).
- **CI runs in UTC; this laptop is New York time.** Run the full suite as
  `TZ=UTC flutter test` before every commit (about 75 s). Check the last CI
  run at the start of a session:
  `curl -s "https://api.github.com/repos/yasir-alobaidi/iptv-player/actions/runs?per_page=3"`,
  then each job from its `jobs_url`. **Failed tests by name** (public, no
  admin rights): `curl -s
  https://api.github.com/repos/yasir-alobaidi/iptv-player/check-runs/<job id>/annotations`
  — one "Failed test" annotation per test since the step 5 commit.
- **The multi-agent pattern that worked (steps 3 and 4)**, when the user
  asks for agents:
  1. Write the shared contract yourself first: the public API as a stub
     that throws `UnimplementedError`, plus a behaviour spec in the
     scratchpad.
  2. Give each agent files it owns and files it must not touch.
  3. Have one agent write tests from the spec alone, as an independent
     check.
  4. Agents wait for a stub to land by grepping for `UnimplementedError`.
     Anyone running build_runner goes through
     `flock <scratchpad>/build_runner.lock dart run build_runner build
     --delete-conflicting-outputs`.
- **Ask agents to measure what the spec only assumes.** In step 5 the spec
  said "Isolate.run above 2,000 guide channels"; the agent timed it, found
  it blocked the UI longer than no isolate at all, and reported rather than
  shipped it.
- **Verify agents' claims before committing; the reviews found real
  bugs:**
  - Run the full suite under `TZ=UTC`, and stress-run anything flaky
    (`xargs -P 8`).
  - Look at every re-recorded golden PNG.
  - Grep new files for literal invisible characters (BOM, zero-width space,
    U+FFFD, NBSP) and write them as escapes.
  - Confirm `build_runner` leaves no diff.
- **The session's end:** analyze, `dart format --set-exit-if-changed lib
  test integration_test tools`, `TZ=UTC flutter test`, the fake provider's
  `dart test` (in `tools/fake_provider`), and the integration tests that
  touch what changed, each under `xvfb-run -a … -d linux`, one file per
  run. Then add to ADR-011, update docs/progress.md, rewrite this file,
  and commit.

## Codebase notes by area
New this session (step 7):
- **The scheduler** (`GuideScheduler`, provider `guideSchedulerProvider`)
  reads the sync engine and the settings controller lazily (closures), and
  the sync engine reads it lazily in `onSynced`: watching either way would
  make a provider cycle. Nothing runs before `startUp()`; `synced()`
  before it only queues. Tests drive it with `fakeAsync` — **make every
  future a fake hands out inside the fake zone** (a `Completer` made in
  `setUp` never completes there).
- **Toasts from anywhere:** `ref.read(appNoticesProvider).show(AppNotice(…))`.
  `AppNotice` has no `const` and no `==` on purpose.
- **The Guide grid's structure after the rework** (`guide_grid.dart`):
  - `_Strip` builds a row's cells for a stretch (±2 h, ±45 min when just
    scrolled in) in a `RepaintBoundary`, slid by a `Transform` from the
    shared offset `_x`; rebuilt every half hour the view moves (`_holds`,
    `slack`), reusing unchanged cells' widgets (`_MadeCell`).
  - `_edge` draws, per frame, the cell the view's edge cuts (its words laid
    out once at the programme's width, `_CellView.layoutWidth`) and the
    focus ring; `_PastTheCut` clips the sliding layer past it.
  - `_BuildBudget` lets four rows a frame build their cells, and stretch
    rebuilds take turns while the view is still inside.
  - Rows redraw for the cache only on their channel's
    `GuideWindowCache.revisionOf`.
  - The grid's `windowForChannels` has no descriptions; the sheet reads
    `EpgRepository.programme(id)` through `guideProgrammeProvider`.
  - Measure with `integration_test/guide_scroll_test.dart` on the real
    display (`--dart-define=GUIDE_TIMELINE=true` traces the keys instead,
    `GUIDE_TIMELINE_WIDGETS=true` adds per-widget events). **In profile
    builds `FocusNode.debugLabel` is empty**: find nodes by their place.
- **`router.state.uri.path` is the top route**; the delegate's
  `currentConfiguration` stays on the page under a push. Both Live TV and
  the Guide read `router.state` now.
- `testWidgets` builds the semantics tree unless `semanticsEnabled: false`;
  a frame-time test should say which it measures.

From the session before (step 6):
- **The Guide** is `lib/features/guide/presentation/`: `guide_screen.dart`
  (the states, the toolbar, Watch), `guide_grid.dart` (`GuideGrid`,
  `GuideGridController` for the toolbar, `guideCells` / `cellAt`),
  `guide_programme_sheet.dart`, `guide_view_state.dart`
  (`guideChannelsProvider`, the Guide's own filter). The time axis is
  `GuideTimeline` (`lib/features/guide/domain/guide_timeline.dart`: local
  half hours, `viewStartFor(now)` = the half hour before now's), the data
  `GuideWindowCache` (same folder).
- **The grid's cursor** is `_row` + `_anchor` (a moment) in
  `_GuideGridState`; the ring is drawn by the cell that contains the
  anchor. `_placeCursor` pulls both back on screen before any key.
- **Tests:** `test/features/guide/guide_grid_fakes.dart` has
  `GuideFixture`: the canvas's channels and programmes at Tue 15 Sep
  9:22 PM *local*, on a real in-memory database, with the real guide and
  fakes for the importer and the matcher. The Guide's widget tests need
  `_settle` (runAsync + pumps), never `pumpAndSettle` (skeletons shimmer).
  A test that fails partway can hang the file until the 10-minute timeout
  (seen once: the Watch test); run it alone with `--timeout 40s`.
- **Router paths:** `router.state.uri.path` is the top route (the player
  after a push); `routerDelegate.currentConfiguration.uri` stays on the
  page under a push. Live TV's `_onLocation` reads the second, so its
  `startsWith(playerRoutePath)` never matches — harmless (the base path is
  `/live` while the player is up), but don't copy it.
- `integration_test/support/keyboard.dart` now maps G, Home, PageUp and
  PageDown to physical keys too.

From the session before (step 5):
- **Settings → Guide** is `lib/features/guide/presentation/`:
  `guide_settings.dart` (the page), `guide_match_picker.dart`
  (`showGuideMatchPicker` → `MatchToGuideChannel` / `UseAutomaticMatch`),
  `guide_text.dart` (every phrase), `guide_match_request.dart`
  (`openGuideMatch` from anywhere). `SettingsLocation` now holds
  `guideSourceId` (`showGuide`).
- **The page talks to domain interfaces** in
  `lib/features/guide/domain/guide_matching.dart`: `GuideImportService`
  (the importer; `guideOrigin` says where a guide would come from without
  fetching) and `GuideMatching` (`rematch`). After `setMapping` /
  `removeMapping`, always `rematch`: the rest of the app reads
  `epg_matches`, not the mappings.
- **Visible channels** (not hidden, not in a hidden category) are what
  `channelMatches` and `ChannelMatchCounts` count — Live TV's
  `AllChannels` rule.
- **The Match… picker's ranking** is `rankGuideChannels` (pure,
  `guide_channel_ranking.dart`); above 2,000 guide channels it runs in
  `GuideRankingWorker` (`lib/features/guide/data/guide_ranking_worker.dart`),
  one isolate per (source, live import) that reads the guide itself. Never
  send a whole guide through `Isolate.run`: the copy happens on the
  sending isolate (measured 305–407 ms at 50,000).
- `DbEpgRepository.dispose()` stops the workers (`epgRepositoryProvider`
  calls it); tests must dispose the repository before closing the
  database.
- **Tests:** `test/features/guide/presentation/guide_settings_fakes.dart`
  has in-memory fakes of the guide store, importer, matcher and settings
  store (`GuideFakes(OnboardingFakes())`). The page needs two
  `settleApp` calls: the list arrives a frame after the coverage.
- `tools/ci/failed_tests.dart` reads `flutter test --file-reporter
  json:test-results.json` and prints the annotations.

From the session before (steps 3 and 4):
- **Any isolate that writes to the database** starts with
  `startGuardedJob` and connects with `openJobDatabase`
  (`lib/data/db/job_database.dart`). Never `startBackgroundJob` +
  `connection.connect()`: a kill inside a drift batch leaves its
  transaction open and blocks the whole database.
  `test/data/db/job_database_test.dart` is the regression test.
- **The EPG import (step 3):**
  - `parseXmltv` (`lib/data/providers/xmltv/`) is the parser's only API.
    Its rules are in ADR-011 step 3. The skip codes in `XmltvSkip` are
    stored, so never rename them.
  - `EpgImporter.importGuide(sourceId)` resolves the guide (override →
    `xmltv.php` → the playlist's `url-tvg`) and runs `runEpgImportWork`
    guarded.
  - It then swaps the rows in on the app's side, or abandons them and
    sweeps.
  - Anything that can print a guide URL must go through `hideUrl` /
    `failureWithoutUrl`.
- **Matching (step 4):**
  - `EpgMatcher` / `normalizeChannelName`
    (`lib/features/guide/domain/epg_matcher.dart`) is pure.
  - `EpgMatchService.rematch(sourceId)` runs the guarded match job and
    coalesces calls. It runs after every import and every sync
    (`SyncEngine.onSynced`, wired in `syncServiceProvider`).
  - Matches are derived state; the user's mappings are the separate
    `epg_mappings` table.
- **The guide the screens see (step 4):**
  - `guideServiceProvider` is a `CompositeGuide(DbGuide, ShortEpgGuide)`.
    `GuideService.warm` looks a page up in one query, and `changes` fires
    on new imports or matches.
  - Lists redraw on `guideRevisionProvider`.
  - `nowNextProvider` watches `guideChangesProvider`, never
    `guideRevisionProvider`, which it bumps itself.
  - Live TV warms its pages (`channel_list_pane.dart`) and skips it while
    covered (`TickerMode`).
- **Goldens are drawn at `goldenNow()`**, a local time. Screens format
  times in the viewer's zone, so an instant draws differently on CI.
- **A widget test in the step 4 style that fails partway through hangs
  until the 10-minute timeout.** Suspect that first when a run stalls.

From earlier sessions (still true):
- **Phase 3 (playback):** `PlayerEngine` (`lib/core/player/`) is the seam;
   `MediaKitPlayerEngine` (`lib/data/player_mediakit/`) passes
   `waitForInitialization: false` on its own property calls (media_kit
   otherwise waits for the video controller's first texture, which needs
   frames drawn) and sets `vid=auto` when headless. `PlaybackCoordinator`
   (`lib/features/playback/domain/`) owns playback, the connection policy
   and the watchdog; `HttpStreamProber` classifies failures;
   `playbackCoordinatorProvider`, `playbackStateProvider`,
   `playbackSettingsControllerProvider`. Live TV in
   `lib/features/live_tv/`; the player at `/player`
   (`PlayerScreen`, root navigator). Integration tests that play need
   `binding.framePolicy = fullyLive` and the samples
   (`streamsAvailable`); `IPTV_PLAYER_VIDEO=0` plays with no picture.
   **Never play from the user's provider without asking first** (a pop-up;
   they free their one connection and say yes).
- **Step 8:** keyboard helpers for integration tests live in
   `integration_test/support/keyboard.dart` (`Keys`, finders). They send
   explicit physical keys (profile builds have no key debug names) and
   `resume()` clears held keys (the real desktop reports its modifiers).
   A long list is one Tab stop with `FocusPane(tabStop: true)`. Frame
   times: `flutter drive --profile -d linux
   --driver=test_driver/integration_test.dart
   --target=integration_test/large_sync_test.dart`; the Linux embedder
   reports raster time as 0. An empty 404 from the panel is an
   `AuthFailure`; a scripted test server that means "not found" must
   send a body.
- **Step 7 (Settings):** `SettingsScreen` + `settingsLocationProvider`
   (section, and the source the Categories section manages); open it from
   anywhere with `openSettings()`. Pages in
   `lib/features/sources/presentation/`: `SourcesSettings`,
   `CategoriesManager`, `source_text.dart` (every phrase about a source's
   state), `current_source.dart` (`chosenSourceIdProvider`,
   `currentSourceProvider` — what the catalogue screens of Phase 3+
   should browse), `source_shell_slots.dart` (`sourceShellOverrides`,
   applied in `bootstrap()`; an integration test must apply them too).
   Edit is `ConnectScreen(editSourceId:)` at `editSourcePath(id)`.
   `onboardingReturnPathProvider` makes adding from Settings end there.
   Remove a source only through `SyncService.removeSource()`, then
   `chosenSourceIdProvider.notifier.forget(id)`.
   **Show menus and dialogs with `showAppMenu` / `showAppDialog`**; Esc
   closes them through the global Esc action. A callback a provider builds
   must not use its `ref` later: read the notifiers first (see
   `source_shell_slots.dart`).
   **Integration tests under xvfb:** register `tester.testTextInput`,
   ignore the engine's lifecycle and view-focus events (there is no window
   manager, so the window flips between focused and not and Flutter parks
   keyboard focus), and send Enter in a text field as
   `receiveAction(TextInputAction.done)`, as the platform's text input
   does. **One file per `flutter test` run** on Linux desktop.
- **Onboarding (step 6):** screens in `lib/features/onboarding/presentation/`;
   the domain they use in `lib/features/sources/domain/` (`SourceChecker`,
   `CategoryRepository`, `validateDraft`, `groupCategories`). The app opens on
   Welcome when the sources table is empty (`startLocationProvider`, set in
   `bootstrap()`). Widget tests run against the fakes in
   `test/features/onboarding/onboarding_fakes.dart`; **a future a fake hands
   out must be made inside the test body**, not in `setUp`, or the fake clock
   never delivers it. `focusIsOn(tester, finder)` there checks keyboard focus.
   Set text weights with `TextStyle.withWeight()`, never
   `copyWith(fontWeight:)` alone (it doesn't change a variable font's weight;
   older components still do it, see Known issues). `layering_test.dart`
   fails when presentation or design code imports drift, dio, media_kit,
   sqlite3, `dart:io`, `dart:isolate` or `lib/data/`.
- **The sync engine (step 5):** the sync isolate writes **only single
   batches, never a longer transaction** — a killed isolate's open
   transaction blocks the database for everyone (spiked), and since
   Phase 4 step 3 it is stopped with `startGuardedJob`, so it is never
   killed inside a batch either. Start and finish happen on
   the UI isolate; the finish is one transaction. `openAppDatabase` must
   stay a `createBackgroundConnection` (not a `LazyDatabase`), or sync
   writes go through a proxy on the UI isolate; `app_database_open_test`
   guards it. A closure sent to an isolate must be built in a top-level
   function (`startSyncJob`), or it drags its enclosing scope along.
   `removeSource()` stops a sync before removing its source; an empty Xtream
   list is swept only when the previous successful run had it empty too
   (`counts_json` `"empty"`). The kill test needs `dart` on PATH and is skipped on Windows.
- **M3U (step 4):** credentials in stream URLs are `{username}`,
   `{password}`, `{token}` placeholders; `fillUrl(template,
   playlistSecrets(realPlaylistUrl))` rebuilds the real URL at play time
   (Phase 3). The identity hash is pinned in tests: never change
   `entryIdentity`. Test fixtures are byte-exact (`.gitattributes`).
   Timing checks go in a test tagged `benchmark`, which is skipped unless
   run with `--tags benchmark --run-skipped`.
- **The Xtream client (step 3):** get credentials only through
   `SourceRepository.credentialsFor()`, and never keep `SourceCredentials`
   in a long-lived object. `XtreamAccount.toStoredJson()` is an allow-list
   and already free of the echoed username and password, so store exactly
   that in `account_json`. In step 5 the client runs **inside** the sync
   isolate. **Don't set dio's `receiveTimeout`** anywhere: it replaces a
   Timer per chunk and froze the UI isolate for ~1 s on 50k rows; the
   client's own idle watchdog (`idleTimeout`) replaces it.
- **Tests that talk to a real server** (the fake provider in-process, or
   a scripted `HttpServer`) need `setUpAll(() => HttpOverrides.global =
   null)`: flutter_test's binding otherwise answers every request with a
   400. **Timing and jank measurements need the fake provider in its own
   process** (`dart run tools/fake_provider/bin/server.dart --profile large
   --port …`): in-process, its JSON encoding shows up as the client's jank.
   To test a connection dropped mid-body, use a raw `ServerSocket`;
   `HttpServer.detachSocket()` leaves it open.
- **Write invisible characters as escapes** (`'\ufeff'`, `'\ufffd'`,
   `\u00a0`). The file-writing tool turned escapes into the literal
   characters more than once this session; grep for them before
   committing.
- **Secrets (step 2):** the keyring holds one JSON document per source
   under `source.<id>`; the database never holds a password, and holds
   playlist and EPG URLs as their origin only (`displayOrigin()`), because
   `redact()` can't see a token in a path. `InMemoryCredentialStore` (with
   `locked = true` to simulate a locked keyring) is the store for every
   test and CI; there is no keyring there. The hard-rule-3 test in
   `test/features/sources/data/db_source_repository_test.dart` scans the
   real database file — extend it rather than writing a second one.
- **`pruneOrphanedSecrets()` runs after a successful keyring use** — the
   engine does it once a session after the first credentials read — never
   at launch on its own: listing a locked keyring prompts for its password.
- **Sync writes go through the DAOs' `upsertAll` and `sweep`.** Upserts
   rewrite only provider-owned columns — never `display_name`, `is_hidden`,
   a category's `sort_order`, or `episodes_fetched_at`. If a new column is
   provider-owned, add it to that DAO's `DoUpdate` list, or re-syncs will
   silently keep the stale value.
- **Mark-and-sweep uses the run id:** `SyncRunsDao.start()` returns the id,
   every upserted row carries it in `seen_run`, and only a *succeeded* run
   sweeps. Sweep the items before the categories. Call
   `SyncRunsDao.failInterrupted()` once on launch (`SyncService.startUp()`
   does, from `bootstrap()`).
- Categories are unique per `(source_id, kind, remote_key)`; items per
   `(source_id, remote_key)`. `idsByRemoteKey(source, kind)` maps a
   provider's category id to the row id items need.
- **Schema changes:** bump `schemaVersion`, `dart run build_runner build`,
   then `dart run drift_dev make-migrations` — one command writes the dump
   (`drift_schemas/app/`), `lib/data/db/app_database.steps.dart`, and
   `test/drift/app/generated/`. Write the `fromNToM` step in
   `AppDatabase`, and add a case to `test/drift/app/migration_test.dart`
   (ours; the tool leaves it alone once it exists). **Don't create triggers
   inside a step:** `_recreateTriggers` rebuilds them all after every
   upgrade, because drift's versioned schemas omit them and its verifier
   doesn't compare them.
- FTS consistency in tests: `INSERT INTO <t>(<t>, rank) VALUES
   ('integrity-check', 1)` throws on a stale index (verified).
- **`DoUpdate.withExcluded` inside `Batch.insertAll` needs explicit type
   arguments** (`DoUpdate<$ChannelsTable, ChannelRow>.withExcluded`), or the
   analyzer reports every `excluded.x` as a nullable access.
- Root `flutter analyze` reaches into `tools/fake_provider`; `dart pub get`
   there first. Work in it with `dart test` from `tools/fake_provider`, and
   `dart run tools/fake_provider/bin/server.dart` from the repo root.
- The ffmpeg tests need `third_party/ffmpeg/linux-x64/ffmpeg` and
   `tools/media_samples/out`, and skip with a reason without them. Keep it
   that way: CI on Windows has neither.
- `/proc/<pid>` is a **directory**; liveness checks read
    `/proc/<pid>/cmdline`.
- The shell's slots are filled by overriding their providers from the
    feature that owns the data: source, switcher, sync line and notice come
    from `sourceShellOverrides` (step 7); `shellDownloadsProvider` (Phase 8)
    and `shellCastSessionProvider` (Phase 7) are still empty.
- `test/app/app_harness.dart`: `pumpApp(tester, overrides: [...])`,
    `findByLabel('…')`; don't call `pumpApp` twice in one test.
- Re-recording a golden: `flutter test --tags golden --update-goldens`,
    then look at the PNG before trusting it.
- Commit messages carry no trailers. Commit locally; the user pushes.
- At the end: analyze, format check, `TZ=UTC flutter test`, the fake
    provider's `dart test`, each integration test under `xvfb-run -a … -d
    linux` (one file per run), add to ADR-011, update `docs/progress.md`,
    overwrite this file, and commit.

## Don't reopen without new evidence
- Phase 4 step 7: the scheduler's policy (a day old; failures wait 6 h; no
  guide address or a locked keyring left alone until a sync); the toast's
  N counts visible channels; only the scheduler's imports toast; the grid's
  sliding stretches and edge layer (measured: per-frame rebuilds of every
  cell cost 12–13 ms a frame).
- Phase 4 step 6: the channel column inside each row (one list, one shared
  horizontal offset); the cache's one query at a time with the newest
  request waiting; gap cells from 5 minutes; one Tab stop with a cursor
  whose ↑/↓ keep the moment; Esc in the grid does nothing with nothing
  open (ADR-008); the toolbar under the shared top bar; the picker in
  place over the grid; Watch zaps through the Guide's list and stops on
  the way back.
- Phase 4 step 5: counts cover visible channels; three lists; the picker
  keeps the focus in its field; the offset stepper saved once it settles;
  Keep global; the ranking worker instead of `Isolate.run` per keystroke
  (measured).
- Phase 4 step 4: the matcher's rule order behind the manual mapping, and
  a name tie going to the channel's own country; the imported guide in
  front of the short EPG; every row warmed from the database.
- Writing isolates are guarded (`startGuardedJob`); a batch is not atomic
  under a kill.
- Phase 4 (ADR-011): the seven plan decisions; the swap on the app's side;
  seven v5 tables; the XMLTV parser as our own byte scanner (the `xml`
  package is dropped); entities decoded twice; `out_of_order` — the first
  schedule read wins; an import with nothing to keep fails and the old
  guide stays.
- Goldens are drawn at `goldenNow()`, a local time, never an instant: a
  screen formats times in the viewer's zone.
- Flutter + media_kit for desktop with the patched `media_kit_video` in
  `third_party/` (ADR-001, ADR-003). fvp only if Windows fails.
- Casting through our own Cast v2 client, the Default Media Receiver and a
  bundled FFmpeg relay (ADR-004). H.264 → HLS/TS; HEVC → one continuous
  fragmented MP4.
- Package choices in ADR-002; downloads and the local library are in v1
  (ADR-005); discovery is bonsoir with multicast_dns as the proven fallback
  (ADR-006). sqlite3_flutter_libs stays dropped — the FTS5 test proves the
  `sqlite3` package's binaries are enough.
- `DateTime` columns are ISO-8601 UTC **text**. drift's other option is unix
  seconds, which it reads back as local time, so a UTC value doesn't survive
  the round trip. EPG times stay integer epoch ms in their own columns.
- Goldens are recorded on Linux only (text rasterization differs on Windows),
  tagged `golden` at library level and declared in `dart_test.yaml`.
- `ChannelRow` draws the programme's progress as a 72 px bar **on the title
  line**, after an ellipsized title, as the canvas does. The bottom-edge
  version from step 3b struck through the title; don't put it back.
- The fake provider's quirks are split on purpose: value quirks are baked in
  by the generator (it knows the item's index), representation quirks by
  `JsonShape` at serialization.
- The fake provider's draws are index-addressable rather than a sequential
  `Random(seed)`: lazy generation means item N must not depend on N−1.
- Bad credentials: 200 with `{"user_info":{"auth":0}}` on `player_api.php`
  (what real panels send), 401 on a stream.
- The focus ring is stroked outside the control, not a box shadow, and it
  inverts to the primary text colour on accent-filled surfaces.
- `FocusPane` is a traversal group, not a `FocusScope`.
- Global shortcuts wrap the router's navigator, not the shell.
- Search is a route, not a dialog, so Ctrl+K, Esc and back agree.
- The canvas beats docs/05 on token values; docs/05 gets corrected at the end
  of the phase along with ADR-008.
- Categories are unique per kind; mark-and-sweep compares a run id, not a
  timestamp; FTS is maintained by triggers with a `WHEN` guard (ADR-009, with
  the measurements).
- Hand-written tolerant readers rather than json_serializable for provider
  data; no dio `receiveTimeout`; one request at a time per source; URLs
  always rebuilt from the source's server (ADR-009).
- Secrets only in the keyring, no file fallback; playlist and EPG URLs in
  the database as their origin only, not masked; orphan pruning after a
  sync, never at launch (ADR-009).
- The sync isolate connects straight to the database isolate
  (`serializableConnection()` over `createBackgroundConnection`), writes
  only in batches, and is killed on cancel; FTS triggers stay (sync costs
  ~75 µs a row with them, far inside the budget); dangling categories are
  a null `category_id`; an empty Xtream list keeps the last one (ADR-009).

- Onboarding (ADR-009 step 6): the sync page is reached with `go`, so Esc
  can't abandon a first sync; a source is added at Start sync, not at the
  test; the typed draft is kept in memory only; categories cluster over
  the whole list and the filter only hides entries.
- Settings (ADR-009 step 7): the overview query watches `sources` and
  `sync_runs` only; the current source is remembered, with the first as
  the fallback; Edit reuses Connect; the manager is a flat list; a
  destructive dialog focuses its safe button; in-field Clear is not a Tab
  stop.

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
- A real guide import from the user's panel: the scheduler will do it at
  the next launch with the panel configured, unless told not to yet.
- Windows installer type (MSIX or Inno Setup) is Phase 10's to recommend,
  but the user decides.
