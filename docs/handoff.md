# Handoff — 2026-09-23 (Phase 4 steps 3 and 4 built)

For the next Claude Code session on this project, and for the user starting
it. Read this file whole, then CLAUDE.md, docs/progress.md,
docs/plans/phase-4-epg-and-guide.md and ADR-011 in docs/decisions.md.

## Before you start the next session (user)
1. **Review steps 3 and 4, then push.** Both are committed locally and
   nothing is pushed:
   - `75172ea` "Phase 4 step 3: the XMLTV parser and the import isolate"
   - `e9a9f76` "Phase 4 step 4: matching, and now/next everywhere"
2. **CI was red on your last push (step 2, run 35494753305).**
   - **Linux (4 failures): fixed in step 3.** Phase 3's goldens printed
     clock times in the machine's zone; CI runs in UTC. No image was
     re-recorded.
   - **Windows (3 failures): I can't read them.** They were already failing
     at the Phase 2 exit, when the job also ran past its 45-minute limit.
     Job logs need admin rights on the repo. Open run 35494753305 → Windows
     → "Test (Windows, goldens excluded)" and paste the three test names
     into the next session.
3. **Optional, with your go-ahead:** one guide import from your real panel.
   It downloads the guide only, plays no stream, so it uses none of your
   one connection. It shows your provider's real XMLTV shape before
   Settings → Guide is built.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, docs/progress.md,
docs/plans/phase-4-epg-and-guide.md and ADR-011 in docs/decisions.md first.
Steps 3 and 4 are reviewed and pushed; CI is <green | red: …>.
Windows failing tests: <names, or "not checked">. Real guide import: <yes | not yet>.
Do Phase 4 step 5 (Settings → Guide) and stop for my review. Use multiple agents where it helps.
```

## Where things stand
- **Phases 1–3 are built** (foundation, sources and sync, Live TV and the
  player). Phase 3's exit is met: the fault suite, the zap budget (p50
  961 ms / p95 972 ms), and the 1-hour soak.
- **Phase 4 (EPG and the guide) has steps 1–4 of 7:**
  1. The fake panel serves XMLTV with every quirk.
  2. Schema v5 stores the guide, with staging and an atomic swap.
  3. The XMLTV parser and the import isolate.
  4. Channel matching, and now/next on every Live TV row, in the preview
     and in the player.
- **What a real run shows today:** nothing starts a guide import outside
  tests (`epgImporterProvider` exists; the scheduler is step 7). So until a
  guide is imported, rows show the short EPG as before, and the Guide
  screen is still a placeholder (step 6).
- **Checks, all green:** analyze and format clean; **1,409 app tests**
  (4 skipped benchmarks) under `TZ=UTC`; the fake provider's 114; under
  xvfb, app launch, the sources and Live TV keyboard walks, and the fault
  suite.
- **Measured:** the XMLTV parser reads 300 MB in 4.3 s with +23 MB RSS. The
  full 300 MB import (batch writes and the swap) is still to measure, in
  step 7. Matching: 50,000 channels against 5,000 guide channels in
  ~175 ms.

## Done this session (2026-09-23)
- **Step 3: the XMLTV parser and the import.** Built by three parallel
  agents from one written spec: the parser, the import pipeline, and
  fixture tests written from the spec rather than from the parser's
  output.
  - Entities are decoded twice (as XML, then by `cleanText`), so a guide's
    channel names match the panel's.
  - A programme that goes back in time is skipped as `out_of_order`: the
    first schedule for a channel wins. The fake panel gives HD/SD pairs one
    guide id with two schedules, which would have shown two programmes on
    at once.
- **A database deadlock, found by a flaky test and fixed at the root.** It
  hit the Phase 2 sync as well as the import. drift's `batch()` is a
  transaction the client opens and commits, and drift never rolls back a
  dead client's transaction. So cancelling a job mid-batch froze every
  query in the app. Writing isolates now start with `startGuardedJob`,
  connect with `openJobDatabase`, and are only killed between
  transactions. A regression test deadlocks under the old kill.
- **CI:** the Linux golden time-zone fix (`goldenNow()` in the golden
  harness).
- **Step 4: matching, and now/next everywhere.** Three agents again: the
  matcher, the match job and its hooks, and the guide the screens see.
  - My one design change after review: a name tie goes to the channel's
    own country (`UK:` → the `.uk` feed). Without it, a UK channel with no
    guide id took the French schedule.
  - The now/next agent's UI choices are recorded in ADR-011 step 4:
    "No guide information", "Next 9:00 PM · Title", and nothing is looked
    up while Live TV is covered.

## What's next: the rest of Phase 4
Work one step at a time. After each step: analyze, format, `TZ=UTC flutter
test`, a local commit, and a stop for review. The user may answer
"continue", which means do the next step.

### Step 5 — Settings → Guide (the sketch in the plan, approved)
- **The page.** A new Settings section, built like Settings → Playback:
  `lib/features/playback/presentation/playback_settings.dart`, with its
  store in `db_playback_settings_store.dart`. Settings live in
  `lib/features/settings/presentation/` (`settings_section.dart` lists the
  sections).
- **What it shows:**
  - The source picker.
  - "Guide data": where the guide came from and when, and "N of M channels
    matched". Read these from `guideCoverageProvider` / `watchCoverage`.
  - **Refresh guide**: `epgImporterProvider.importGuide(sourceId)`, with its
    `progress` stream for a thin progress line.
  - **Keep N days**: a global setting (default 7). Store it the way
    playback settings are stored, and pass it to `EpgImporter.keepAhead`
    (today a constructor value).
  - **Time offset**: per source. It's `sources.epg_offset_minutes`, already
    in `SourceForm` and the table.
  - **Decision 4:** changing the days or the offset re-imports.
- **The unmatched list.** Channels of the source with no row in
  `epg_matches`: a new `EpgRepository` read (a `LEFT JOIN`, paged: it can
  be thousands). It is one Tab stop with the arrows inside
  (`FocusPane(tabStop: true)`); Enter opens the picker.
- **The Match… picker.** Type to filter; the guide's channels are ranked by
  the matcher's own `normalizeChannelName` against the channel's name.
  - `EpgRepository.guideChannels(query:)` exists but uses `LIKE`. Rank in a
    background isolate if the guide is big (hard rule 2).
  - Enter maps (`setMapping`), then `EpgMatchService.rematch(sourceId)`,
    so the row and the rest of the app update. Esc cancels.
  - "Change" and remove (`removeMapping` + rematch) for mapped channels.
- **States (hard rule 4):** loading, no source, no guide URL for the source
  (`resolveGuideLocation` says why: no `url-tvg` and no override), no guide
  imported yet, importing, a failed import (with the old guide kept), all
  matched.
- **Keyboard first:** a keyboard walk in the style of
  `integration_test/sources_keyboard_test.dart`.
- **Tests:** widget tests per state and for the picker.
- **Needs a user decision? No:** the sketch is approved. Decide small UX
  points yourself and record them in ADR-011.

### Step 6 — The Guide grid (canvas artboard `Guide`)
- **Read the canvas first:** https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99
  (with the Artifact tool, action `read`), and `design/Guide.dc.html`. The
  plan's step 6 lists every measure: 240 px per hour, a 220 px channel
  column, 72 px rows, cells inset 6 px with an 8 px radius, the now line
  and its pill, and the dashed "No guide information · Match to a guide
  channel" row. **Every value goes into `lib/design/tokens` (hard rule 9).**
- **Scrolling (decision 6):** a vertical list of rows sharing one
  horizontal `ScrollController`, and a second list for the pinned channel
  column. Not `TwoDimensionalScrollView`.
- **Data (decision 7):** `EpgRepository.windowForChannels(ids, from, to)`
  for the visible channels plus one screen and one hour of margin. Cache it
  by (channel, hour bucket), and cancel in-flight queries on fast scrolls.
  Channel pages come from the same `ChannelRepository` Live TV uses.
- **Keyboard:** ←/→ between programmes, ↑/↓ between channels,
  PageUp/PageDown, Home = now, Enter opens the detail sheet (sketch in the
  plan), Esc goes back. G opens the Guide from anywhere; Ctrl+3 as today.
- **States:** loading skeletons, no source, no guide yet, nothing today,
  importing (a thin progress line, the old guide still shown), offline.
- **Tests:** goldens at 1280×800 and 1920×1080, drawn at `goldenNow()` (a
  local time, never an instant).

### Step 7 — Scheduler, toast, exit
- **The scheduler (decision 5):**
  - Refresh a guide older than 24 h: checked at launch (after
    `startUp()`) and hourly.
  - After a sync, never beside it, and one source at a time.
  - A manual refresh from Settings.
  - `SyncEngine.onSynced` already calls the matcher; the scheduler decides
    when to import.
- **The toast:** "Guide updated · N channels matched", via
  `lib/app/shell/toast_host.dart`; N comes from `EpgMatchSummary`.
- **Exit measurements**, in `benchmark`-tagged tests:
  - **The 300 MB import:** ≤ 4 min, peak RSS +300 MB, no UI frame over
    32 ms. Run the fake provider in its own process: `dart run
    tools/fake_provider/bin/server.dart --profile large --port 8899`, guide
    `?channels=2150&days=7`, about 300 MB. If the swap's copy is the
    bottleneck, the fallback in ADR-011 is a generation column.
  - **The grid's scroll:** no frame over 16 ms, with `flutter drive
    --profile` (see `integration_test/large_sync_test.dart`).
- **An integration test:** import → Live TV shows now/next → open the Guide
  → arrow to a programme → Enter → Watch → the player opens that channel.
- **The phase exit:** numbers into docs/progress.md, ADR-011 closed out,
  this file rewritten.

## The road to v1 (what is still needed to go live)
Desktop v1 is Linux and Windows. The Google TV app follows it (docs/07).
- **Phase 4 steps 5–7** (above). Until step 7, the app never imports a
  guide by itself.
- **CI green on both systems.** Linux should go green with the step 3
  commit; Windows needs its 3 failing tests named (see "Before you start").
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
  `TZ=UTC flutter test` before every commit. Check the last CI run at the
  start of a session:
  `curl -s "https://api.github.com/repos/yasir-alobaidi/iptv-player/actions/runs?per_page=3"`.
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
New this session:
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
- The three failing Windows CI tests: their names, from the job log (needs
  the user's admin access).
- A real guide import from the user's panel: yes or not yet.
- Windows installer type (MSIX or Inno Setup) is Phase 10's to recommend,
  but the user decides.
