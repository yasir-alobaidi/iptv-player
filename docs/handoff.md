# Handoff — 2026-09-18 (session 15, after step 5)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
**Review Phase 2 step 5 (the sync engine).** Five local commits are waiting
on top of what you pushed: steps 1–4 (reviewed) and step 5. Still nothing
visible in the app — the sync runs, but no screen shows it until step 6.
Worth your eyes: "The sync engine (step 5)" in ADR-009 and docs/02's "Sync
engine" section. Three choices there you might want to weigh in on:
- an Xtream list that comes back empty keeps the previous one rather than
  wiping it (a panel's hiccup is likelier than a provider dropping every
  movie; the cost is that a truly dropped kind lingers);
- an M3U episode with no numbering in its name joins a series named after
  its group; with no group either, it becomes a movie;
- on launch, stale sources sync 2 s after the first frame, which reads the
  keyring and so may ask you to unlock it.
Push when you're happy with it.

If you have an M3U playlist of your own, give me its path (or URL) next
session and I'll run it through the parser: nothing is stored.

The window checks from Phase 1 are still yours to do when convenient:

```
flutter run -d linux       # resize, expand the rail, close with the X
tail ~/.local/share/io.github.yasiralobaidi.iptvplayer/logs/app.log
flutter run -d linux       # same size, rail still expanded
```

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, docs/progress.md,
docs/plans/phase-2-providers-and-data.md and ADR-009 in docs/decisions.md first.
Step 5 is reviewed <or: here is what to change>. Do Phase 2 step 6 and stop for my review.
```

## Where things stand
- **Phase 1 is complete** (ADR-008), and CI is green on both OSes.
- **Phase 2 plan approved 2026-09-18.** Steps 1–4 done and reviewed:
  schema v2, `CredentialStore` and `SourceRepository`, `XtreamClient`,
  the streaming M3U parser and the fake provider's `get.php`.
- **Phase 2 step 5 done:** the sync engine (`lib/data/sync/`,
  `lib/features/sources/domain/sync.dart`), wired into `bootstrap()`
  (launch check) and `syncServiceProvider` / `syncStatusProvider`.
- 449 app tests (plus 3 skipped benchmarks) and 87 fake-provider tests
  pass; `flutter analyze`, the format check and `flutter build linux
  --debug` are clean; the built app starts cleanly on the real database.
- **Sync budget met:** `large` profile 6.5 s (re-sync 3.9 s) against 60 s;
  worst UI-isolate gap 31 ms (budget 32 ms, re-measure in profile mode in
  step 8).

## Done this session (2026-09-18)
- Steps 1–5 of Phase 2. The decisions and measurements are in ADR-009.
- Step 5's spike: drift works from a background isolate once the app opens
  its database with `createBackgroundConnection`; killing an isolate inside
  a transaction blocks the database, so the sync never opens one.

## Instructions for the next session
1. **Step 6 is next: onboarding** (plan step 6; the canvas's `Onboarding`,
   `OnboardingSync`, `OnboardingCategories`, and the approved Welcome
   sketch). Read the canvas with the Artifact tool first. The sync screen
   follows `syncStatusProvider(sourceId)`: `SyncRunning.progress` has the
   stage, a count per list, `stageTotal` once a list is in ("8,021 of
   about 13,800") and `account` (the Account line). Start the sync with
   `syncServiceProvider.sync(id)`; Cancel is `cancel(id)`; a failure is
   `SyncFailed.failure` for `failureMessage()`. "Test connection" is
   `XtreamClient.account(retry: false)` on the UI isolate (small body),
   mapped with `toProviderAccount()`. Pick-categories writes through
   `CategoriesDao.setHidden`/`setAllHidden`; counts from `itemCounts` (the
   null key is "Uncategorized"). **At the end of step 6 the user runs it
   against their real provider.**
1g. **The sync engine (step 5):** the sync isolate writes **only single
   batches, never a transaction** — a killed isolate's open transaction
   blocks the database for everyone (spiked). Start and finish happen on
   the UI isolate; the finish is one transaction. `openAppDatabase` must
   stay a `createBackgroundConnection` (not a `LazyDatabase`), or sync
   writes go through a proxy on the UI isolate; `app_database_open_test`
   guards it. A closure sent to an isolate must be built in a top-level
   function (`startSyncJob`), or it drags its enclosing scope along.
   Removing a source mid-sync isn't coordinated yet: step 7 should cancel
   first. The kill test needs `dart` on PATH and is skipped on Windows.
1f. **M3U (step 4):** credentials in stream URLs are `{username}`,
   `{password}`, `{token}` placeholders; `fillUrl(template,
   playlistSecrets(realPlaylistUrl))` rebuilds the real URL at play time
   (Phase 3). The identity hash is pinned in tests: never change
   `entryIdentity`. Test fixtures are byte-exact (`.gitattributes`).
   Timing checks go in a test tagged `benchmark`, which is skipped unless
   run with `--tags benchmark --run-skipped`.
1c. **The Xtream client (step 3):** get credentials only through
   `SourceRepository.credentialsFor()`, and never keep `SourceCredentials`
   in a long-lived object. `XtreamAccount.toStoredJson()` is an allow-list
   and already free of the echoed username and password, so store exactly
   that in `account_json`. In step 5 the client runs **inside** the sync
   isolate. **Don't set dio's `receiveTimeout`** anywhere: it replaces a
   Timer per chunk and froze the UI isolate for ~1 s on 50k rows; the
   client's own idle watchdog (`idleTimeout`) replaces it.
1d. **Tests that talk to a real server** (the fake provider in-process, or
   a scripted `HttpServer`) need `setUpAll(() => HttpOverrides.global =
   null)`: flutter_test's binding otherwise answers every request with a
   400. **Timing and jank measurements need the fake provider in its own
   process** (`dart run tools/fake_provider/bin/server.dart --profile large
   --port …`): in-process, its JSON encoding shows up as the client's jank.
   To test a connection dropped mid-body, use a raw `ServerSocket`;
   `HttpServer.detachSocket()` leaves it open.
1e. **Write invisible characters as escapes** (`'\ufeff'`, `'\ufffd'`,
   `\u00a0`). The file-writing tool turned escapes into the literal
   characters more than once this session; grep for them before
   committing.
1a. **Secrets (step 2):** the keyring holds one JSON document per source
   under `source.<id>`; the database never holds a password, and holds
   playlist and EPG URLs as their origin only (`displayOrigin()`), because
   `redact()` can't see a token in a path. `InMemoryCredentialStore` (with
   `locked = true` to simulate a locked keyring) is the store for every
   test and CI; there is no keyring there. The hard-rule-3 test in
   `test/features/sources/data/db_source_repository_test.dart` scans the
   real database file — extend it rather than writing a second one.
1b. **`pruneOrphanedSecrets()` runs after a successful keyring use** — the
   engine does it once a session after the first credentials read — never
   at launch on its own: listing a locked keyring prompts for its password.
2. **Sync writes go through the DAOs' `upsertAll` and `sweep`.** Upserts
   rewrite only provider-owned columns — never `display_name`, `is_hidden`,
   a category's `sort_order`, or `episodes_fetched_at`. If a new column is
   provider-owned, add it to that DAO's `DoUpdate` list, or re-syncs will
   silently keep the stale value.
3. **Mark-and-sweep uses the run id:** `SyncRunsDao.start()` returns the id,
   every upserted row carries it in `seen_run`, and only a *succeeded* run
   sweeps. Sweep the items before the categories. Call
   `SyncRunsDao.failInterrupted()` once on launch (`SyncService.startUp()`
   does, from `bootstrap()`).
4. Categories are unique per `(source_id, kind, remote_key)`; items per
   `(source_id, remote_key)`. `idsByRemoteKey(source, kind)` maps a
   provider's category id to the row id items need.
5. **Schema changes:** bump `schemaVersion`, `dart run build_runner build`,
   then `dart run drift_dev make-migrations` — one command writes the dump
   (`drift_schemas/app/`), `lib/data/db/app_database.steps.dart`, and
   `test/drift/app/generated/`. Write the `fromNToM` step in
   `AppDatabase`, and add a case to `test/drift/app/migration_test.dart`
   (ours; the tool leaves it alone once it exists). **Don't create triggers
   inside a step:** `_recreateTriggers` rebuilds them all after every
   upgrade, because drift's versioned schemas omit them and its verifier
   doesn't compare them.
6. FTS consistency in tests: `INSERT INTO <t>(<t>, rank) VALUES
   ('integrity-check', 1)` throws on a stale index (verified).
7. **`DoUpdate.withExcluded` inside `Batch.insertAll` needs explicit type
   arguments** (`DoUpdate<$ChannelsTable, ChannelRow>.withExcluded`), or the
   analyzer reports every `excluded.x` as a nullable access.
8. Root `flutter analyze` reaches into `tools/fake_provider`; `dart pub get`
   there first. Work in it with `dart test` from `tools/fake_provider`, and
   `dart run tools/fake_provider/bin/server.dart` from the repo root.
9. The ffmpeg tests need `third_party/ffmpeg/linux-x64/ffmpeg` and
   `tools/media_samples/out`, and skip with a reason without them. Keep it
   that way: CI on Windows has neither.
10. `/proc/<pid>` is a **directory**; liveness checks read
    `/proc/<pid>/cmdline`.
11. The shell's slots — `shellSourceProvider`, `shellSyncStatusProvider`,
    `shellDownloadsProvider`, `shellCastSessionProvider` — stay empty until
    the phase that owns the data overrides them (step 7 for the first two;
    `syncStatusProvider` is what the sync slot will read).
12. `test/app/app_harness.dart`: `pumpApp(tester, overrides: [...])`,
    `findByLabel('…')`; don't call `pumpApp` twice in one test.
13. Re-recording a golden: `flutter test --tags golden --update-goldens`,
    then look at the PNG before trusting it.
14. Commit messages carry no trailers. Commit locally; the user pushes.
15. At the end: analyze, format check, `flutter test`, the fake provider's
    `dart test`, add to ADR-009, update `docs/progress.md`, overwrite this
    file, and commit.

## Don't reopen without new evidence
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

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
