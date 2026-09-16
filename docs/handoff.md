# Handoff — 2026-09-16 (session 10)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Nothing is blocked. Phase 1 steps 1–5 are done and committed locally;
**nothing is pushed yet** — four commits are waiting (step 3b, the session 9
handoff, step 4 and step 5). `origin/main` is still at step 3a (`e9efe17`).
Step 6 (the fake provider skeleton) needs no hardware and no TV.

Two things only you can check, and one run covers both:

1. **window_manager #585, the crash when the window is closed.** Still
   unverified. This laptop is on Wayland, and neither closing a window nor
   taking a screenshot works from a script here — `org.gnome.Shell.Screenshot`
   answers `Access denied` — so it needs one manual close.
2. **The window size is now remembered** (step 5). It writes on the first run
   and restores on the second, so the check needs two launches.

```
flutter run -d linux       # resize the window, then close it with the X
tail ~/.local/share/io.github.yasiralobaidi.iptvplayer/logs/app.log
flutter run -d linux       # it should open at the size you left it
```

The rail's expanded state is remembered the same way; expand it before the
first close and it should still be expanded on the second launch. The
database file is
`~/.local/share/io.github.yasiralobaidi.iptvplayer/iptv_player.sqlite`;
deleting it is safe and gives a clean first run.

An instance from session 9 (PID 42684) may still be open. It is the *old*
build with the in-memory store, so close it before the run above rather than
reading anything into its behaviour.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 1 steps 1-5 are done. Do step 6 (tools/fake_provider skeleton) as written in
docs/plans/phase-1-foundation.md, and stop for my review when it's finished.
```

## Where things stand
- **Phase 0 done, GO for Linux accepted** (ADR-007). Windows playback is still
  unverified — no PC yet.
- **Phase 1 step 1:** app scaffold, every ADR-002 package, lints, `build.yaml`.
- **Phase 1 step 2:** `Result`/`AppFailure`, `redact()`, logging with our own
  rotation, global error handlers, background isolates, `bootstrap()`.
- **Phase 1 step 3a:** bundled variable fonts, `AppTokens` as a
  `ThemeExtension`, the dark theme, the focus system, the basic components,
  and the Component Gallery.
- **Phase 1 step 3b:** the canvas icon set and the media, overlay, casting and
  download components.
- **Phase 1 step 4:** the router, the desktop shell, the global shortcuts, the
  placeholder screens and the window plumbing.
- **Phase 1 step 5:** the drift database, the DAOs, `SettingsRepository`, and
  the migration flow.
- 246 tests pass; `flutter analyze`, the format check and
  `flutter build linux --debug` are clean.

## Done this session (2026-09-16)
- `lib/data/db/tables.dart`: `sources` and `settings`, schema v1. `sources`
  has **no password column** — only `credential_ref`, the
  flutter_secure_storage key — and a test asserts that.
- `lib/data/db/app_database.dart`: `AppDatabase`, `AppDatabase.memory()` for
  tests, and `openAppDatabase()` — a `LazyDatabase` over
  `NativeDatabase.createInBackground`, so the file is opened and queried off
  the UI isolate.
- `lib/data/db/daos/`: `SettingsDao` (read/write/remove/watch/readAll) and
  `SourcesDao` (all/watchAll/byId/count/upsert/patch/remove/markSynced).
- `lib/data/settings/settings_repository.dart`: `Result`-returning, with
  `SettingsKeys` in one place. Anything sqlite or drift throws becomes a
  `StorageFailure`; a value that isn't the JSON the caller expected reads as
  the fallback, so one corrupt row can't stop the app from starting.
- `lib/data/settings/db_window_bounds_store.dart` and `db_ui_preferences.dart`
  fill the two holes step 4 left: the window size and the rail's expanded
  state now survive a restart.
- `lib/core/settings/ui_preferences.dart`: the narrow interface the shell
  sees, next to `WindowBoundsStore`. The shell still imports no drift.
- `lib/app/bootstrap.dart` opens the database, overrides
  `appDatabaseProvider`, `windowBoundsStoreProvider` and
  `uiPreferencesProvider`, and falls back to an in-memory database with a
  logged error rather than failing to start.
- Migration flow: `drift_schemas/app/drift_schema_v1.json` is committed,
  `test/data/db/generated/` holds the verifier helpers, and
  `test/data/db/schema_v1_test.dart` checks the live schema against the dump.
- `test/data/db/fts5_test.dart` proves the `sqlite3` package's binaries have
  FTS5, which Phase 6 depends on and ADR-002 only assumed.
- `docs/progress.md`, `docs/02-providers-and-data.md` and the running ADR-008
  list updated.

## Instructions for the next session
1. Step 6 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. **Regenerating the schema:** after any table change, bump
   `schemaVersion`, then run `dart run build_runner build`,
   `dart run drift_dev make-migrations`, and
   `dart run drift_dev schema generate drift_schemas/app/ test/data/db/generated/`.
   Add a case to `test/data/db/schema_v1_test.dart` for the new version.
   `build.yaml` has to keep its `databases:` entry or `make-migrations`
   refuses to run.
3. `AppDatabase.memory()` is how a test gets a database; it needs no
   `TestWidgetsFlutterBinding`. Widget tests still need no database at all —
   `windowBoundsStoreProvider` and `uiPreferencesProvider` default to their
   in-memory versions, and `pumpApp` is unchanged.
4. A drift stream's first event arrives asynchronously, so a test that wants
   it has to subscribe and `await pumpEventQueue()` before writing;
   `emitsInOrder` on a fresh subscription misses the initial value.
5. The shell's other slots — `shellSourceProvider`, `shellSyncStatusProvider`,
   `shellDownloadsProvider`, `shellCastSessionProvider` — are still
   deliberately empty. Override the provider in the phase that owns the data
   rather than changing the shell.
6. `test/app/app_harness.dart` pumps the real app with a silent log and an
   uninstalled `ErrorReporter`; `pumpApp(tester, overrides: [...])` is how a
   test fills a shell slot, and `findByLabel('…')` finds an icon-only
   control. Don't call `pumpApp` twice in one test — Riverpod refuses a
   change in the number of overrides.
7. The placeholder screens are meant to be replaced, not extended. When a
   phase builds its real screen, delete the `PlaceholderScreen` call and keep
   the file and route.
8. Commit messages carry no trailers. Commit locally; the user pushes.
9. At the end: analyze, format check, `flutter test`, update
   `docs/progress.md`, overwrite this file, and commit.

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
- The focus ring is stroked outside the control, not a box shadow, and it
  inverts to the primary text colour on accent-filled surfaces.
- `FocusPane` is a traversal group, not a `FocusScope`.
- Global shortcuts wrap the router's navigator, not the shell: the shell's
  own `Shortcuts` would never fire over the search overlay.
- Search is a route, not a dialog, so Ctrl+K, Esc and back agree with each
  other.
- The canvas beats docs/05 on token values; docs/05 gets corrected at the end
  of the phase along with ADR-008.

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
