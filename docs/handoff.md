# Handoff — 2026-09-16 (session 13)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
**Phase 1 steps 1–8 are all done and committed locally. Eight commits are
waiting to be pushed, and pushing is now the one thing that moves the phase
forward:** step 8 added the CI workflow, and CI cannot be green — or red —
until GitHub sees it. `origin/main` is still at step 3a (`e9efe17`).

```
git push
# then read the run (public repo, no gh CLI needed):
curl -s 'https://api.github.com/repos/yasir-alobaidi/iptv-player/actions/runs?per_page=1' \
  | grep -E '"name"|"status"|"conclusion"|"html_url"'
```

Everything the workflow does was verified locally on Linux, step by step, so
the Linux job should pass. **The Windows job has never run anywhere** — no
Windows machine has touched this project yet. If it fails, the two likely
places are `media_kit_libs_video` (it downloads libmpv at build time) and the
vendored `third_party/media_kit_video`; the patch itself only touches
`linux/video_output.cc`, so it cannot be the cause.

Two things still only you can do, and one run covers both:

1. **window_manager #585, the crash when the window is closed.** Still
   unverified: this laptop is on Wayland, and neither closing a window nor
   taking a screenshot works from a script here.
2. **The window size and the rail's expanded state are remembered** — they
   are written on the first run and restored on the second.

```
flutter run -d linux       # resize, expand the rail, close with the X
tail ~/.local/share/io.github.yasiralobaidi.iptvplayer/logs/app.log
flutter run -d linux       # same size, rail still expanded
```

While that window is open, the new keyboard rules are worth ten seconds of
your own hands, because tests cannot tell you how they feel: **Ctrl+3** (focus
should land in the guide, ring visible), **Tab** from there, **Esc** (focus
should step back from the chrome into the screen), and arrowing the rail with
**↑ ↓** then **Enter** (focus should stay on the rail).

**PID 42684 is still open** — the session 9 build with the in-memory store.
Close it first rather than reading anything into its behaviour.

The fake provider runs if you want to see real data move:

```
dart run tools/fake_provider/bin/server.dart --port 8899
mpv 'http://127.0.0.1:8899/live/test/test/1.ts'
```

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 1 steps 1-8 are done and I have pushed. Check the CI run, fix anything red,
then write the Phase 1 exit docs (ADR-008 from the running list in progress.md, and the
docs/05 corrections). Stop for my review when it's finished.
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
- **Phase 1 step 8:** `.github/workflows/ci.yml` — Linux + Windows, every
  step verified locally except the Windows job, which needs a push.
- 259 app tests and 81 fake-provider tests pass; `flutter analyze`, the format
  check over `lib test integration_test tools` and `flutter build linux
  --debug` are clean.

## Done this session (2026-09-16)
Step 8, the CI workflow, plus the keyboard/focus decisions from the session
before it.

`.github/workflows/ci.yml`: one matrix job over ubuntu-22.04 and
windows-latest, Flutter pinned to 3.47.4, on push to main, on pull requests
and on demand, with in-progress runs superseded per ref. In order: apt
dependencies → `flutter pub get` and `dart pub get
--directory=tools/fake_provider` → `build_runner` then `git diff
--exit-code` → `flutter analyze` → the format check → `flutter test` (Linux)
or `flutter test --exclude-tags golden` (Windows) → the fake provider's
`dart test` → the integration test under xvfb → release bundles, uploaded as
artifacts.

Each step was run here before being written down: `dart pub get --directory=`
works, `build_runner` leaves the tree clean, analyze and format are clean,
259 + 81 tests pass, the integration test passes under xvfb, and `flutter
build linux --release` produces exactly the `build/linux/x64/release/bundle`
path the workflow uploads.

## Instructions for the next session
1. Step 8 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. CI is written; if a job is red, these are the three things that were
   easy to get wrong and are already handled — don't "fix" them away: `dart pub get` in
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
