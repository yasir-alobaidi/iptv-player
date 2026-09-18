# Handoff — 2026-09-18 (session 15, after step 4)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
**Review Phase 2 step 4 (M3U playlists, and `get.php` on the fake
provider).** Four local commits are waiting on top of what you pushed:
steps 1–3 (reviewed) and step 4. Still nothing visible in the app. Worth
your eyes: "M3U and get.php (step 4)" in ADR-009, and the list under
docs/02's M3U section. Two things there are choices you might want to
weigh in on: a playlist line ending in `.mp4`/`.mkv` counts as a movie
even without `/movie/` in its path, and a per-line CDN token that the
playlist URL doesn't carry can't be recognized, so it's stored as sent.
Push when you're happy with it.

If you have an M3U playlist of your own, give me its path (or URL) next
session and I'll run it through the parser: nothing is stored, and a real
playlist will find quirks the fixtures don't have.

The window checks from Phase 1 are still yours to do when convenient; they
don't block Phase 2:

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
Step 4 is reviewed <or: here is what to change>. Do Phase 2 step 5 and stop for my review.
```

## Where things stand
- **Phase 1 is complete** (ADR-008), and CI is green on both OSes.
- **Phase 2 plan approved 2026-09-18** — the recommendation on all four
  questions and the three layout sketches (recorded at the top of the plan
  and in ADR-009).
- **Phase 2 step 1 done:** schema v2 — the catalogue tables, FTS5 search
  kept current by triggers, the v1 → v2 migration, and the catalogue DAOs.
- **Phase 2 step 2 done:** `CredentialStore` (`lib/core/secure/`), the
  keyring implementation (`lib/data/secure/`), and `SourceRepository`
  (`lib/features/sources/{domain,data}`), with `credentialStoreProvider`
  overridden in `bootstrap()`.
- **Phase 2 step 3 done:** `XtreamClient` and its tolerant parsers
  (`lib/data/providers/xtream/`), shared text cleanup
  (`lib/data/providers/provider_text.dart`), fixtures in
  `test_fixtures/xtream/`, and the fake provider as a path dev-dependency.
- **Phase 2 step 4 done:** the streaming M3U parser and reader
  (`lib/data/providers/m3u/`), `IdleTimeout` (`lib/core/streams/`),
  fixtures in `test_fixtures/m3u/`, `get.php` and the `messyM3u` quirk on
  the fake provider, and a skipped-by-default `benchmark` test tag.
- 426 app tests (plus one skipped benchmark) and 87 fake-provider tests
  pass; `flutter analyze`, the format check and `flutter build linux
  --debug` are clean.

## Done this session (2026-09-18)
- Read the first CI run: green on both OSes; Windows built for the first
  time. Marked the plan approved.
- Steps 1–4: schema v2, credentials and sources, the Xtream client, M3U.
  The decisions and measurements are in ADR-009; the short version is
  below.
- Checked the real keyring by hand: GNOME Keyring round-trips through the
  real plugin (recorded in ADR-009).

## Instructions for the next session
1. **Step 5 is next: the sync engine** (see the plan and progress.md
   "Next"). **Spike drift in a background isolate with its own connection
   first** — the phase's one real unknown. Inside the sync isolate: Xtream
   through `XtreamClient`, M3U through `readM3u` (not
   `readM3uInBackground`: the sync isolate *is* the background). Upserts
   through the DAOs' `upsertAll` in 5,000-row batches, then `sweep` items
   before categories, only after a succeeded run. A dangling or missing
   category → a synthetic "Uncategorized" category or a null
   `category_id` (decide, and record in ADR-009). M3U: `remote_key` is
   `M3uEntry.identity`; `stream_url` is `M3uEntry.streamUrl` (already
   templated); the per-entry `#EXTVLCOPT` and catch-up fields go in
   `extras_json`; episodes are grouped into series by `seriesName`, and
   those without one need a rule (by group?). The account goes into
   `account_json` as `XtreamAccount.toStoredJson()`; `exp_date` into
   `expires_at`. M3U header EPG URLs carry credentials: they go to the
   secure store with the source's other secrets, never the database.
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
1b. **`pruneOrphanedSecrets()` must run after a successful keyring use**
   (step 5: at the start of a sync, once a session), never at launch on its
   own: listing a locked keyring prompts for its password.
2. **Sync writes go through the DAOs' `upsertAll` and `sweep`.** Upserts
   rewrite only provider-owned columns — never `display_name`, `is_hidden`,
   a category's `sort_order`, or `episodes_fetched_at`. If a new column is
   provider-owned, add it to that DAO's `DoUpdate` list, or re-syncs will
   silently keep the stale value.
3. **Mark-and-sweep uses the run id:** `SyncRunsDao.start()` returns the id,
   every upserted row carries it in `seen_run`, and only a *succeeded* run
   sweeps. Sweep the items before the categories. Call
   `SyncRunsDao.failInterrupted()` once on launch (step 5 wires it in).
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
    the phase that owns the data overrides them (step 7 for the first two).
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

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
