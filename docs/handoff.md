# Handoff — 2026-09-16 (session 12)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Nothing is blocked. Phase 1 steps 1–7 are done and committed locally;
**nothing is pushed yet** — six commits are waiting (step 3b, the session 9
handoff, step 4, step 5, step 6 and step 7). `origin/main` is still at step 3a
(`e9efe17`). Step 8 (CI) needs no hardware and no TV, but CI only turns green
once you push.

**The two keyboard questions are decided and built** (you said to make the
best of it; the rules are in docs/05 and the reasoning is in the ADR-008 list
in docs/progress.md):
1. A destination **shortcut** takes focus with it — Ctrl+1…7 and Ctrl+, land
   on the first control of the screen they open. Enter or Space on a **rail
   item** keeps focus on the item, so ↑ ↓ keep walking the rail.
2. **Esc leaves what you stepped into**: close what is open, else return
   focus from the chrome to the screen, else do nothing. It never navigates.

Worth a minute of your own hands on the keyboard to confirm it feels right —
that is the one thing tests can't tell you.

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
Phase 1 steps 1-7 are done. Do step 8 (CI on GitHub Actions) as written in
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
- **Phase 1 step 7:** real fonts in tests, four goldens, the full keyboard
  matrix, and the integration smoke test.
- 259 app tests and 81 fake-provider tests pass; `flutter analyze`, the format
  check over `lib test integration_test tools` and `flutter build linux
  --debug` are clean.

## Done this session (2026-09-16)
Step 7, written by three agents in parallel and verified here:

- `test/flutter_test_config.dart` loads the bundled variable fonts with
  `FontLoader` for every test under `test/`, keyed off `AppFonts` so the
  family names can't drift. No existing test needed changing.
- `test/golden/`: two component sheets at 1280×800 and the shell at 1280×800
  and 1920×1080. `@Tags(['golden'])` at library level (`group()` has no
  `tags`), declared in a root `dart_test.yaml`, skipped off-Linux with a
  reason. Re-recording twice is byte-identical.
- `test/app/shell_keyboard_test.dart` is 13 tests now: the top bar walked
  with Tab and with arrows, a focus ring asserted at **every** stop from the
  rail through the top bar to the screen, Shift+Tab back out, Esc on a
  top-bar control, and focus after a destination change. One pre-existing
  test was vacuous — it tabbed against `Cast` while the disabled button's
  label is its tooltip — and now asserts the real thing.
- `integration_test/app_launch_test.dart` launches the real `IptvPlayerApp`
  with bootstrap's non-disk overrides, renders the shell and navigates.
  Verified under `xvfb-run -a flutter test integration_test -d linux`.
- **`ChannelRow` fixed** (`lib/design/`): the first golden showed the 2 px
  progress bar striking through the programme title in both densities. The
  canvas draws a 72 px bar *on the title line* after an ellipsized title, so
  that is what it does now. This supersedes the step 3b ADR-008 note.

Then the keyboard/focus rules above, and the two bugs that came out of
building them:

- `_RailSlot` drew the active-indicator bar as a **conditional `Stack`
  child**. Every selection change therefore changed the child count, moved
  the item's subtree by one index, rebuilt its element and destroyed the
  `FocusNode` that held the keyboard focus. The bar is always in the tree
  now, transparent when unselected, and animates in. **Never put a
  conditional sibling next to a focusable subtree in a `Stack`.**
- `late int _branch = widget.navigationShell.currentIndex` ran its
  initializer on first *read*, which was inside `didUpdateWidget`, after the
  index had already changed — so every branch change compared equal and the
  hook never fired. It is read in `initState` now.
- A branch switch pulls focus into the new route's own scope, so the rail
  case has to **restore** focus, not merely leave it alone.

## Instructions for the next session
1. Step 8 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. The CI matrix needs three things this repo now proves: `dart pub get` in
   `tools/fake_provider` **before** the root `flutter analyze`; `flutter test
   --exclude-tags golden` on the Windows job (goldens are Linux-only); and
   `xvfb-run -a flutter test integration_test -d linux` with `GDK_BACKEND=x11`
   and no `WAYLAND_DISPLAY` for the integration job. The smoke test needs no
   fake provider — docs/06 assumes one, but this test is deliberately
   network-free.
3. Root `flutter analyze` reaches into `tools/fake_provider` — that is why
   the `pub get` above matters. The package's `pubspec.lock` is committed, as
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
9. Re-recording a golden after a deliberate UI change:
   `flutter test --tags golden --update-goldens`, then look at the PNG before
   trusting it. Reading the image is how the `ChannelRow` bug was found —
   a green golden only means nothing changed, not that it looks right.
10. Regenerating the drift schema: bump `schemaVersion`, then
   `dart run build_runner build`, `dart run drift_dev make-migrations`, and
   `dart run drift_dev schema generate drift_schemas/app/ test/data/db/generated/`.
   Add a case to `test/data/db/schema_v1_test.dart`.
11. Commit messages carry no trailers. Commit locally; the user pushes.
12. At the end: analyze, format check, `flutter test`, the fake provider's
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

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
