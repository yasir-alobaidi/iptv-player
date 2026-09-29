# Handoff — 2026-09-29 (Phase 6: steps 1–6 built, step 7 half built)

For the next Claude Code session on this project, and for the user starting
it. Read this file whole, then CLAUDE.md, docs/progress.md, ADR-013 in
docs/decisions.md, and docs/plans/phase-6-search-and-polish.md.

## Before you start the next session (user)
1. **Review and push** the local commits, oldest first: "Phase 6 step 1:
   channel names cleaned and stored, schema v7", steps 2–6, "CI: run
   every integration test and name each one that fails", "Phase 6 step
   7a: …" and this handoff. The plan commit (eff4053) is pushed.
2. **CI after the push:** the plan push's run failed one Linux integration
   test that the public annotations don't name. With the CI change, every
   integration file runs and each failure is an annotation, so the next
   run says which. Windows fails its 4 known tests.
3. **Schema v7 upgrades your database** the first time the new build runs;
   channel names are then cleaned in the background (about a second per
   50,000) and your next guide import stores programmes in the order
   search needs.
4. **Try it:** Ctrl+K or `/` and type — ↑/↓, Tab between groups, Enter
   plays a channel or opens a title, the Menu key has the channel menu;
   Favorites (Ctrl+6): New group, Alt+↑/↓ to move, F to remove (Undo);
   Live TV: a group under Favorites, Show hidden channels in a channel's
   menu, the categories pane's menu and Alt+↑/↓; Settings → Categories →
   Hidden channels.
5. **Decide when you can:** "Remind me" on upcoming programmes — Phase 9,
   or after v1 (decision 5)?

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, docs/progress.md,
ADR-013 in docs/decisions.md and docs/plans/phase-6-search-and-polish.md first.
Phase 6 steps 1–7a are reviewed and pushed; CI is <green | red: …>.
Finish step 7 (its tests and walk), then step 8, the phase exit.
```

## Where things stand
- **Phase 6 steps 1–6 are built and committed; step 7 is half built**
  (part a committed, all green). ADR-013 has each step as built.
- **Checks, all green at the step 7a commit:** analyze, format,
  `build_runner` leaves no diff; **2,057 app tests** (10 skipped) under
  `TZ=UTC`; under xvfb: `search_keyboard` (new, the `large` catalogue),
  `live_tv_keyboard`, `guide_keyboard`, `guide_settings_keyboard`,
  `guide_watch`, `vod_walk`, `app_launch`.
- **Measured:** search on the `large` catalogue with a 611,328-programme
  guide: median 6.6 ms, p95 24 ms, worst 31 ms (proposed budget 50 ms);
  the channel-name fill 1.2 s for 50,000.

## Done this session (2026-09-29)
- **The plan approved** ("continue the work"); your panel's "1 of 1
  connections" was another of your devices (noted in ADR-012).
- **Step 1:** `cleanChannelName` with a 111-name corpus and a fuzz; the
  matcher's tag tables shared; schema v7 (`clean_name`, `quality`,
  `favorite_groups`, `favorites.group_id`, the search index on the name
  shown); sync writes both columns; the guarded fill for older catalogues.
  **Departure:** codec, frame-rate and Backup/VIP tags stay in the name —
  only resolution tags become the badge — so two feeds of one channel
  don't read the same.
- **Step 2:** `ChannelBadge` after the name on Live TV's and the player
  panel's rows; Rename shows the provider's name and returns to the
  cleaned one.
- **Step 3:** the search repository. Found by the benchmark: short words
  took 0.7–5.2 s on the programme index. Fixed by storing the guide in
  start order and reading matches in that order from the first programme
  on now (31 ms worst).
- **Step 4:** the overlay, every state, the keyboard in the field, the
  hand-offs (Guide on a programme, Show all into filters), goldens, the
  integration walk.
- **Step 5:** favorites' order and groups; Live TV's groups under
  Favorites; Home in your order; exit criterion 2 proved against the fake
  panel.
- **Step 6:** the Favorites screen (canvas), its model, drag and keyboard
  moves, Undo, goldens.
- **Step 7a:** one channel menu (Live TV, Guide, Home, Favorites, Search),
  hide with Undo, the categories pane's menu and moves, Show hidden
  channels, the Hidden channels tab, Live TV's list keeping the keyboard
  under the wheel.
- **CI:** every integration file runs, each failure named.

## What's next
1. **Step 7, the rest:** widget tests for the Hidden channels tab (list,
   filter, Show and the focus moving on, Show all, the tab appearing),
   the categories pane's menu (Hide with Undo, Rename, Move) and Alt+↑/↓,
   the Guide's menu key, Search's channel menu; the **exit-criterion-4
   walk** (an integration test: hide a channel and a hidden category's
   non-favorite → gone from Live TV, the Guide, Search and Home → Settings
   → Hidden channels → Show → back); the Categories manager's list as one
   Tab stop (Known issues). Record in ADR-013 step 7.
2. **Step 8 — the exit** (plan): the keyboard walk against the fake panel;
   frames while typing into search in profile mode on the real display;
   with your go-ahead (a pop-up first: catalogue calls only, no stream)
   one sync of your panel into a throwaway database to review the cleanup
   on its 12,610 channel names and look at its movie names; docs/05 "As
   built" (Search, Favorites, names), docs/02's schema v7, docs/06's
   search budget (50 ms); ADR-013 Accepted; progress; handoff.
3. **Alongside:** the Linux integration test CI names; the Windows
   failures, one commit each.

**Loose ends, small:**
- Favorites' drag draws Flutter's gap, not the canvas's accent line.
- A guide imported before this build keeps channel order until its next
  import, so programme search hits may not be the soonest for up to a day.
- `GuideGridController.showProgramme` is lost if the Guide's view is
  rebuilt for another source before the grid has rows.

## The road to v1 (what is still needed to go live)
Desktop v1 is Linux and Windows. The Google TV app follows it (docs/07).
- **CI green on both systems.** Linux: one integration test to identify
  (see above); Windows fails 4 named tests (progress.md Known issues).
- **Phase 6 — Search and polish:** steps 7 (rest) and 8 left.
- **Phase 7 — Casting**, the largest and riskiest phase: our own Cast v2
  client, the ffprobe-based planner, the FFmpeg relay with its supervisor,
  the UI, and the casting matrix on the user's TV. Ask before every cast
  (memory). The relay must own its sockets (ADR-010).
- **Phase 8 — Downloads and the local library:** resumable downloads
  (`.part` + verify + rename; they yield to playback), the library
  scanner, offline playback, library casting, the SIGKILL-safety tests.
- **Phase 9 — Settings, diagnostics, polish:** every Settings section, the
  log viewer and Copy diagnostics (redacted); the keyboard audit at
  100/115/130 % text scale and with reduce motion; every docs/06 budget in
  profile mode, and **the 8-hour soak with faults** (memory growth ≤ 50
  MB).
- **Phase 10 — Packaging:** a Windows installer bundling libmpv and FFmpeg
  (MSIX vs Inno Setup: recommend, then build); a Linux AppImage tested on
  clean Ubuntu 22.04 and 24.04 VMs; semantic versioning, CHANGELOG.md,
  docs/release.md, a final regression, and the tag v1.0.0.
- **Only the user can unblock:** the Windows PC (playback and hardware
  decoding have never run on real Windows; ADR-007's GO covers Linux
  only); the app's name and icon; the window_manager #585 check; access
  to their TV for the casting matrices; permission for each real-provider
  stream.

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
- **Run widget tests with a timeout** (`flutter test … --timeout 40s`,
  and `--plain-name` to run one): a widget test that fails part-way can
  otherwise hang until the 10-minute default, which happened several
  times this session.
- **The session's end:** analyze, `dart format --set-exit-if-changed lib
  test integration_test tools`, `TZ=UTC flutter test`, the fake provider's
  `dart test` (in `tools/fake_provider`), and the integration tests that
  touch what changed, each under `xvfb-run -a … -d linux`, one file per
  run. Then add to ADR-013, update docs/progress.md, rewrite this file,
  and commit.

## Codebase notes by area
New this session (Phase 6 steps 1–7a):
- **Channel names** (`lib/features/live_tv/domain/channel_names.dart`: `cleanChannelName`, `ChannelQuality` stored by name; `channel_name_tags.dart`: the tag tables and scanners the guide's matcher shares — keep them in one place). `ChannelItem.name` is rename ?? `clean_name` ?? provider name (`channelShownName`, `channelColumns`, `channelFromRow` in `db_channel_repository.dart` — reuse them in any query that lists channels); `providerName` is the raw name whenever it differs; `isRenamed`; `quality`; `favoriteGroupId`.
- **Every channel row sync writes goes through `withCleanName`** (`lib/data/sync/channel_rows.dart`); `clean_name`/`quality` are in the channels DAO's `DoUpdate` list. Tests that insert channels and expect search or the cleaned name must use it too. `ChannelNameFill` (+ `runChannelNameWork`) fills rows with no cleaned name after launch, guarded, before the launch syncs.
- **`channels_fts` indexes `(clean_name, display_name)`**, not the provider's name (v7).
- **The guide swap inserts programmes by start time** (`EpgDao.swapIn`): search relies on programme row ids following the schedule. Don't insert `epg_programs` another way without keeping that order (tests insert sorted: `putGuide()` in the search repository test).
- **Search** (`lib/features/search/`): `DbSearchRepository` (one query per group; programmes per source from `_firstLive`, cached 5 min — a stale value is still a valid lower bound), `searchWords` (the only way text reaches FTS), `SearchSession` (the overlay's state, 150 ms), `search_text.dart` (every phrase, `highlightRanges`), `SearchActions` (what opening does; uses the container and router, since the overlay closes first), `search_overlay.dart`. Benchmark: `search_benchmark_test.dart` (`SEARCH_BENCH_DIR=<dir>` keeps its 500 MB database to study queries with Python's sqlite3).
- **Cross-screen requests:** `GuideProgrammeRequest` (the Guide opens on a programme with its sheet: `GuideGridController.showProgramme`, applied once the grid has rows; the sheet opens a frame after the grid moves), `LiveTvController.showSearch` / `CatalogueController.showSearch` (filter fields follow their query now), `HiddenChannelsRequest` / `openHiddenChannels`.
- **Favorites** (`lib/features/favorites/`): `FavoritesDao` (order: `sort_order` per group; a move renumbers the target list; groups' own order), `FavoritesRepository`, `favoriteGroupsProvider`; `FavoriteChannels`' and `FavoriteGroupChannels`' "number" sort is the user's order. The screen's list is one flat list (`favorite_layout.dart`: `favoriteEntries`, `keyboardMove`, `dropPlace` — the drop index is `onReorderItem`'s, already adjusted). `showGroupNameDialog`.
- **One channel menu:** `showChannelMenu` / `hideChannel` / `showGroupMenu` (`lib/features/live_tv/presentation/channel_menu.dart`); `renameChannel` (`channel_rename_dialog.dart`); `askCategoryName` (in `categories_manager.dart`). `AppNotice` carries an action (Undo).
- **Hidden channels:** `HiddenChannels` filter (drops the `is_hidden = 0` clause); `HiddenChannelsView` in Settings → Categories, a tab in the manager's `SegmentedControl<CatalogueKind?>` (null is that tab).
- **Design:** `ChannelBadge`; `ChannelRow` gained `quality`, `hidden`, `leading`, `timeLeft`; `AppSearchTokens` and `text.searchQuery`/`searchHeading`; `PosterArtwork(showTitle:)`; `CatalogueGrid` (the grid body the Movies/Series screens and Favorites share).
- **Live TV's list keeps the keyboard under the wheel:** a row that goes with the focus calls `onFocusGone` from `deactivate`; `_holder` (never a Tab stop) holds it while the view moves; it answers only its own keys (`node.hasPrimaryFocus`), or it swallows the rows' arrows.
- **Traps met this session:** the file tool turned `\u` escapes into literal invisible characters again (grep before committing); `pkill -f` inside a command killed the command; `late final … = ref.read(…)` was first read in `dispose`; a provider's `build` that sets its own state synchronously (defer with a microtask); binding more SQL variables than a statement uses fails (`_Query.variables` takes exactly ?1–?4); an inner CTE's ORDER BY can't use the outer alias.

New this session (Phase 5 step 8):
- **Where the focus goes after a destination jump** (`DesktopShell.
  _followTheJump`): after the frame, then a microtask (the focus manager's
  own update, queued while the screen was built, runs first). If the
  focus is already on a control of the content (the screen's autofocus),
  it stays; otherwise `FocusPaneController.focusFirst()`: the first
  control in reading order (`_readingOrder`, shared with `_leave`),
  never a `FocusScopeNode`, never a node not laid out (`_rectOf`). A
  screen that wants a particular first control uses `autofocus` — and
  should not offer other controls before it is ready (the details
  frame's chip is `ExcludeFocus` while loading).
- **The focus tree's order is attach order**, not the order drawn. Never
  take `traversalDescendants.first` as "the first control".
- **`TitleGrid` and the mouse:** a card notices it goes with the focus in
  `deactivate` (a `Focus` widget unfocuses its node before the owner's
  `dispose`); `_onFocusedCardGone` then, after the frame, gives the focus
  to a card on screen, or to `_holder` while the view still moves
  (`ScrollEndNotification` finishes it). `_moving` marks a key's own move
  in flight; `_pendingFocus` a card not built yet.
- **`LaunchMark`** (`lib/core/logging/launch_mark.dart`,
  `launchMarkProvider`): `bootstrap()` starts its stopwatch first thing;
  Home calls `homeShown()` after its first frame with rows. Tests get
  `LaunchMark.none()`.
- **Integration test support:** `support/panel_app.dart` (`PanelApp`: the
  real player, a throwaway database, the fake panel synced), `support/
  frames.dart` (`measureFrames`, `FrameStats`, `waitReal`), `support/
  real_provider.dart` (`readPlayLogin`, `LogFileOutput`); `Keys.typeIn`
  types into a field with no label (a `SearchField`'s).
- **Launching the real app from a test** (the cold start): redirect
  `XDG_DATA_HOME` and `XDG_CACHE_HOME`, and point
  `DBUS_SESSION_BUS_ADDRESS` nowhere, or it reaches the real keyring (and a
  sync would prune the real app's secrets). A log line's timestamp is on
  the same clock as the test's, so the log's 500 ms flush doesn't matter.
- **`pkill -f <pattern>` inside a Bash command kills that command too**
  when its own text matches (it did, once).

New this session (Phase 5 steps 6–7):
- **Playback of files:** `Playable` (`lib/features/playback/domain/
  playable.dart`: `PlayableChannel`, `PlayableMovie`, `PlayableEpisode`)
  is on every `PlaybackState` as `item`; `state.channel` is the live
  channel or null — **Live TV and the Guide stop only a channel**, and the
  player stops a file when it is disposed (any way out of `/player`).
  `coordinator.timelines` / `timeline` (`VodTimeline`), `startedFrom`,
  `seek`, `setPaused`, `PlaybackEnded`. The coordinator's `progress:`
  (`WatchProgress`) is optional; tests that only play live leave it out.
- **The coordinator's state stream is synchronous:** a listener must not
  call back into the coordinator while it is being told something
  (`VodPlayerController` acts on the end in a microtask).
- **The player's VOD face:** `PlayerScreen` decides by `state.item`
  (`_isVod`); `VodPlayerController` (presentation) holds the pending seek,
  "Resumed from", "Preparing…", the next episode and the card;
  `vod_osd.dart` draws it. Keys with Ctrl/Alt/Meta always go to the app's
  shortcuts. The seek bar is `ExcludeFocus` (←/→ seek from anywhere).
- **`vodLauncherProvider` lives in `lib/features/playback/presentation/
  vod_launch.dart`** (moved from `details_state.dart`); tests override it
  with a recording launcher (`test/features/home/home_fakes.dart`,
  `details_screen_test.dart`).
- **The fake engine:** `FakePlayerEngine.sequence` is opens and calls in
  order; `duration(d)`; `setPaused` reports `PlayerPaused` back; `seek`
  records `seek:<ms>`. `Rig(watchProgress:)` takes a real `WatchProgress`
  for screens that read it back; `FakeWatchProgress.marks` answers
  `watch`.
- **Widget tests of the player** (`vod_player_screen_test.dart`): wrap
  each in its `_vodTest`, which always stops the coordinator — a failed
  expectation otherwise leaves the watchdog's timers running and the file
  hangs. Stop with `unawaited(coordinator.stop())` then `settle`: the save
  goes to drift, which only moves while the test pumps.
- **Home** (`lib/features/home/`): `HomeRepository` / `DbHomeRepository`
  (rows re-read on table changes), `home_state.dart` (providers),
  `home_rows.dart` (`HomeRowController`, `homeArrowKey`, `HomeRow`,
  `MinuteTicker`), `home_screen.dart`. The grid's cards are
  `MovieCard` / `SeriesCard` / `FavoriteMark` in
  `lib/features/vod/presentation/title_cards.dart`. `ChannelTile` is a
  design component; `SectionHeader` follows the canvas; token
  `text.sectionTitle`.
- **Riverpod 3 pauses a hidden branch's providers:** a screen coming back
  into view builds once with what it had. Key sections whose presence
  changes, and don't leave the focus in something the fresh data removes.
- **Integration tests on files:** `support/fake_panel.dart` has
  `vodAvailable`, `firstMovieId` (100000, the MP4 sample) and
  `panel.movie(id)`; `Keys.shift(key)` is new. mpv and FFmpeg absorb the
  fake panel's `drop_after_bytes` on a file by themselves (probed).
  Movie 100000's metadata runtime is made up; only the player's length is
  real.

From the session before (Phase 5 steps 1–5):
- **The fake panel** (`tools/fake_provider`): `lib/vod.dart` (VOD files),
  `lib/artwork.dart` (artwork; the generator still writes
  `artworkRoot`, which the serializers rewrite to the request's origin
  with `artworkFor`), `server.dart` routes each path prefix to its own
  handler (no `Cascade`: it replaced 404 reasons), `state.apiCalls` counts
  `player_api.php` actions for "a second open makes no request" tests.
  VOD faults act only on `/movie/` and `/series/`; `drop_after_bytes` is a
  byte of the file, not of the body.
- **The VOD feature** (`lib/features/vod/`): `domain/` — `catalogue.dart`
  (`TitleQuery`, filters, `TitleSort`, `Details<T>`), `titles.dart`
  (items, details, the two repositories), `watch_progress.dart`
  (`WatchMark`, `VodRef`, `ContinueItem`, `WatchProgress`, `resumeAfter`,
  `completeAt`, `isComplete`), `next_up.dart`, `vod_launcher.dart`;
  `data/` — `db_movie_repository.dart`, `db_series_repository.dart`,
  `db_watch_progress.dart`, `title_details_source.dart` (one
  `XtreamClient` per source, rebuilt when the sign-in changes),
  `vod_rows.dart` (shared SQL: `titleWindow` picks a page's ids on the
  filtered table, then joins only those rows — keep that shape, the
  indexes depend on it), `vod_providers.dart`; `presentation/` — the
  grid, the screens, `details_state.dart`, `title_routes.dart`,
  `vod_text.dart`. Movies and Series screens are thin wrappers.
- **Schema v6:** `movies_added`, `movies_name`, `movies_rating` indexes
  (`@TableIndex.sql`), series genre/cast/director/backdrop (sync writes
  them with `COALESCE(new, old)`), `movie_details.video_height` /
  `audio_channels`, `watch_history.series_key` / `dismissed`.
  "Undated last" / "unrated last" use SQLite's NULLs-last-when-descending
  — no `IS NULL` term, or the index stops being used.
- **Never write `.whenComplete(() => map.remove(key))`** to coalesce
  futures: `remove` returns the future itself, and it waits for itself
  forever. Use `removeWhere((k, _) => k == key)`.
- **Riverpod passes no equal value on.** A list that must re-read when a
  favorite or a mark changes can't listen to a count; use a revision
  (`channelRevisionProvider`, `TitleCount.revision`). And a refresh must
  re-read pages in place, never clear them: clearing disposes the focused
  row and the keyboard's focus with it.
- **A focus request "after the next frame" needs a frame:** call
  `scheduleFrame()` with `addPostFrameCallback` when nothing else will
  (`TitleGrid._move`).
- **Images:** screens call `artworkFor(context, url, width:)` (never
  `NetworkImage`); `ArtworkScope` is filled at the app root from
  `artworkImagesProvider` (`bootstrap()` overrides it with the disk cache;
  tests get plain network images). `ArtworkImage` is the component;
  `PosterArtwork` a poster without a card. The cache is
  `lib/data/images/artwork_cache.dart` (`ArtworkUnavailable` never names
  the URL).
- **Silent Flutter errors are logged, not toasted** (`ErrorReporter`).
- **Details pages** hide the shell's top bar (`DesktopShell.immersive`,
  from `isTitleDetailsPath`); `AppDetailsTokens` holds the canvas's
  measures; `tokens.text.movieTitle` / `seriesTitle`; `AppButtonSize.xl`.
- **Tests:** `test/features/vod/vod_fakes.dart` (`VodFakes`, `settle`),
  `vod_test_support.dart` (`ScriptedDetails` — scripted answers, a `gate`
  to hold them, call counts; seed helpers). **Don't write to the database
  from `runAsync` while a page watches a drift stream:** the write waits
  on the page's stream, which only moves when the test pumps — write
  before the page opens, or from the test's own zone
  (`unawaited(db…)` then `settle`).

From Phase 4 step 7:
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
    linux` (one file per run), add to ADR-013, update `docs/progress.md`,
    overwrite this file, and commit.

## Don't reopen without new evidence
- Phase 6 (ADR-013): cleaned names stored (`clean_name`, `quality`), technical tags kept in the name, only resolution tags as the badge; the search index on the name shown; search's ranking (source, favorites, prefix, rank) and the programme query by row-id order from the first programme on now (measured: 0.7–5.2 s → 31 ms worst); one-letter words only narrow programmes; no "Show all" for programmes; favorites' order per group with renumbering moves; groups under Favorites in Live TV; "Order" on favorites' sort; the flat header/row list for the Favorites screen; one channel menu everywhere; "Hidden" as a tag.
- Phase 5 step 8 (ADR-012): the first control after a jump in reading
  order, with the screen's own autofocus winning; the details chip out of
  focus while loading; the grid keeping the keyboard when the mouse
  scrolls (hold, then the card on screen in the same column); the picture
  sweep on the known size; the cold start timed from `Process.start` to
  Home's log line on the profile build; the poster test's top-to-bottom
  part in profile mode only (CI time).
- Phase 5 steps 6–7 (ADR-012): the sealed `Playable` on the one
  coordinator; the player (not Live TV) stopping a file; the end rule by
  the player's length only; 30 s for a file's first frame; saving on
  pause/seek/leave/failure/end and every 10 s of playing; the seek bar out
  of the Tab order; −10/+10 as text buttons; the countdown's bar under the
  button; Home's poster opening in its own branch (Esc to the grid); the
  hero on the app's gradient; ↑/↓ on Home to the nearest card by position.
- Phase 5 (ADR-012): the seven plan decisions; one `vod` feature for the
  shared domain; our own image cache instead of extended_image (its cache
  is fixed to `/tmp`); PNG artwork in the fake panel; the take-over of a
  VOD slot by a request for the same file; `drop_after_bytes` counted in
  the file; the window query picking ids first and the three sort
  indexes; lists refreshing on a revision and in place; no typing into
  the grid's filter from the grid (F and D are its keys); Download and
  Cast left off the details pages until their phases; `AppButtonSize.xl`
  for both details pages.
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
- Remind me on upcoming programmes: Phase 9, or after v1? (Phase 6
  decision 5; the plan suggested Phase 9.)
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
- Windows installer type (MSIX or Inno Setup) is Phase 10's to recommend,
  but the user decides.
