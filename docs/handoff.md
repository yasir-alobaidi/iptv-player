# Handoff — 2026-09-16 (session 11)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Nothing is blocked. Phase 1 steps 1–6 are done and committed locally;
**nothing is pushed yet** — five commits are waiting (step 3b, the session 9
handoff, step 4, step 5 and step 6). `origin/main` is still at step 3a
(`e9efe17`). Step 7 (goldens and the shell keyboard test) needs no hardware
and no TV.

Two things only you can check, and one run covers both. This is the same
check that was open last session; it is still open:

1. **window_manager #585, the crash when the window is closed.** This laptop
   is on Wayland, and neither closing a window nor taking a screenshot works
   from a script here — `org.gnome.Shell.Screenshot` answers `Access denied`
   — so it needs one manual close.
2. **The window size and the rail's expanded state are remembered**
   (step 5). They are written on the first run and restored on the second,
   so the check needs two launches.

```
flutter run -d linux       # resize the window, expand the rail, close with the X
tail ~/.local/share/io.github.yasiralobaidi.iptvplayer/logs/app.log
flutter run -d linux       # same size, rail still expanded
```

The database file is
`~/.local/share/io.github.yasiralobaidi.iptvplayer/iptv_player.sqlite`;
deleting it is safe and gives a clean first run.

**PID 42684 is still open** — the session 9 build with the in-memory store.
Close it before the run above rather than reading anything into its
behaviour.

Optional, and fun to look at rather than necessary: the fake provider now
runs, so you can point the app at a provider before any of the provider code
exists.

```
dart run tools/fake_provider/bin/server.dart --port 8899
curl -s 'http://127.0.0.1:8899/player_api.php?username=test&password=test'
mpv 'http://127.0.0.1:8899/live/test/test/1.ts'
```

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 1 steps 1-6 are done. Do step 7 (goldens and the shell keyboard test) as written in
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
- **Phase 1 step 6:** `tools/fake_provider` — the Xtream API, live streams and
  the fault stub.
- 246 app tests and 81 fake-provider tests pass; `flutter analyze`, the format
  check and `flutter build linux --debug` are clean.

## Done this session (2026-09-16)
`tools/fake_provider`, a separate Dart package (shelf, shelf_router, args,
path) carrying the app's lints through its own
`analysis_options.yaml`:

- `lib/profile.dart`: `FakeProfile` with the `default` (240/120/24), `large`
  (50k/30k/3k) and `quirky` profiles, `FakeQuirks` (every quirk docs/02 says
  the parser must tolerate) and `FakeFaults` (the docs/06 fault list, parsed
  tolerantly so a typo in a test can't take the server down).
- `lib/models.dart`: the docs/02 JSON shapes. `JsonShape` applies the
  *representation* quirks — numbers as strings, `""` for null, `info: []` —
  so one generated row can be served either way.
- `lib/generator.dart`: the catalogue. Deterministic and lazy; draws are
  index-addressable (splitmix64 over seed + a per-kind salt + the index), so
  `channelById(4211)` is identical whether or not its neighbours were built.
  Fictional names with quality tags and country prefixes, so the docs/02 EPG
  name normalization has something to chew on.
- `lib/player_api.dart`: the nine docs/02 actions. `server_info.url`/`port`
  follow the request's Host. Lists are written onto the response one item at
  a time; `get_live_streams` on `large` is 14.2 MB in 0.44 s with the
  server's memory flat.
- `lib/streams.dart`: `/live/{u}/{p}/{id}.ts` — `ffmpeg -re -stream_loop -1`
  over an MKV remux of the sample (never the `.ts`: ADR-004 Finding 8), the
  remux written `.part` and renamed, one in-flight future per sample so two
  requests never remux into the same file, a PID file per process, kill on
  disconnect and on shutdown, and a startup sweep.
- `lib/admin.dart`: `/admin/faults` GET/POST/DELETE. The set is stored and
  reported; **nothing injects it yet** — each fault starts being honoured in
  the phase whose tests need it.
- `lib/server.dart`, `bin/server.dart`: the pipeline, the flags,
  repo-relative defaults, SIGINT shutdown that takes the children with it,
  and a verbose request log that redacts the credentials in a stream path.
- `README.md`: usage, the profiles, the endpoints, why the loop is an MKV,
  and what is deliberately still missing.
- Tests: 81, in `test/generator_test.dart` (determinism, index-addressability,
  laziness budgets on the `large` profile, the quirks, the JSON shapes),
  `test/player_api_test.dart`, `test/streams_test.dart` (the ffmpeg ones skip
  themselves with a reason when the binary or the samples are missing) and
  `test/admin_test.dart`.

## Instructions for the next session
1. Step 7 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. `dart format --set-exit-if-changed lib test integration_test tools` from
   CLAUDE.md **fails today**: `integration_test/` does not exist yet. Step 7
   creates `integration_test/app_launch_test.dart`, which fixes it; until
   then, drop that one path when you run the check by hand.
3. Root `flutter analyze` reaches into `tools/fake_provider`, so **step 8's CI
   has to `dart pub get` that package before the analyze step** or every
   import in it is unresolved. The package's `pubspec.lock` is committed, as
   the spikes' are.
4. Working in the fake provider: `dart test` from `tools/fake_provider`, and
   `dart run tools/fake_provider/bin/server.dart` from the repo root (the
   nested package resolves correctly from there — verified).
5. The ffmpeg tests need `third_party/ffmpeg/linux-x64/ffmpeg` and
   `tools/media_samples/out`, and skip with a reason without them. Keep it
   that way: CI on Windows has neither.
6. `/proc/<pid>` is a **directory** — `File('/proc/$pid').existsSync()` is
   false for a live process. Liveness checks read
   `/proc/<pid>/cmdline`, which is also how the stale sweep tells our ffmpeg
   from a reused PID.
7. The shell's slots — `shellSourceProvider`, `shellSyncStatusProvider`,
   `shellDownloadsProvider`, `shellCastSessionProvider` — are still
   deliberately empty. Override the provider in the phase that owns the data
   rather than changing the shell.
8. `test/app/app_harness.dart` pumps the real app with a silent log and an
   uninstalled `ErrorReporter`; `pumpApp(tester, overrides: [...])` fills a
   shell slot, and `findByLabel('…')` finds an icon-only control. Don't call
   `pumpApp` twice in one test.
9. Regenerating the drift schema: bump `schemaVersion`, then
   `dart run build_runner build`, `dart run drift_dev make-migrations`, and
   `dart run drift_dev schema generate drift_schemas/app/ test/data/db/generated/`.
   Add a case to `test/data/db/schema_v1_test.dart`.
10. Commit messages carry no trailers. Commit locally; the user pushes.
11. At the end: analyze, format check, `flutter test`, the fake provider's
    `dart test`, update `docs/progress.md`, overwrite this file, and commit.

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

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
