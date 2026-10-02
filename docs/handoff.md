# Handoff — 2026-10-02 (Phase 7 step 5 done, stopped for review; the TV run waits)

For the next Claude Code session on this project, and for the user starting
it. Read this file whole, then CLAUDE.md, docs/progress.md,
docs/plans/phase-7-casting.md, ADR-014 in docs/decisions.md, the Phase 7
part of docs/08-phases-and-prompts.md and docs/04-casting.md.

## Before you start the next session (user)
1. **Review Phase 7 step 5** (ADR-014 "The relay, its proxy and its
   supervisor"). Its choices to look at:
   - **the departures from docs/04's FFmpeg options:** no `-user_agent`
     (the proxy sends the source's), `-reconnect_delay_max 1` (FFmpeg
     ends 3 s after the app is killed, not 16), FFmpeg reading 2 s of the
     stream before it starts (as the probe does), `aac_adtstoasc` for AAC
     copied into MP4;
   - **the program watch:** the proxy reads a live channel's PAT/PMT to
     catch a codec switch, which FFmpeg, copying, never reports;
   - **the continuous stream written on the TV's own connection**, so a
     TV that leaves is seen at once (ADR-010's lesson, met again);
   - **CI** now generates the media samples before the unit tests (two
     more, 1080i and 576i), so the relay's tests run there with FFmpeg
     4.4.
2. **Push** the local commit (step 5).
3. **The TV run waits** (the TV isn't on the network for now). When you
   want it, say so; the session asks before it casts. It can go with
   step 6's cast through the app, in one sitting.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, docs/progress.md,
docs/plans/phase-7-casting.md, ADR-014 in docs/decisions.md, docs/08-phases-and-prompts.md (Phase 7)
and docs/04-casting.md first. Step 5 is <approved | approved with these changes: …>.
<The TV run waits | The TV is on the network: the TV run can go ahead after you ask>. Then start step 6.
```

## Where things stand
- **Phase 7 (casting): steps 1–4 approved; step 5 done; step 2's TV run
  waits (2026-10-02: "consider the test on living room tv to do it
  later"; then "I dont have the living room tv on network so we gonna do
  it later").**
- **Checks at the step 5 commit:** analyze, format, `build_runner` leaves
  no diff; **2,791 app tests** (15 skipped) under `TZ=UTC`, about 2 min
  20 s now (the relay's end-to-end tests stream in real time); the
  relay's seven unit files 8 of 8 with eight copies at once, the
  real-FFmpeg ones 3 of 3 three at once, and all 30 also with the system
  FFmpeg 4.4 (`RELAY_FFMPEG_DIR=/usr/bin`); the fake receiver's 32, the
  fake provider's 141; `app_launch_test` under xvfb; the real app's
  launch deleted a planted stale relay folder.
- **CI:** green on both systems at a3a07bd (steps 2–4). Step 5 moves the
  sample generation before `flutter test`: check the first run after the
  push (the Linux job now runs the relay's end-to-end tests with 4.4).

## Done this session (2026-10-02, fourth session)
- **Step 4 approved; the TV run waits** (the TV isn't on the network).
- **Step 5** (details in ADR-014 "The relay, its proxy and its supervisor"):
  - the domain: `lib/core/cast/cast_relay.dart`;
  - `lib/data/cast/relay/`: `isolate_cast_relay.dart` (the app's side),
    `relay_isolate.dart` (the isolate and its messages),
    `relay_runtime.dart` (sessions and the supervisor), `relay_proxy.dart`,
    `relay_server.dart`, `relay_job.dart` (`relayArguments`),
    `relay_args.dart` (`castRelayJob`), `ffmpeg_log.dart`,
    `hls_playlists.dart`, `ts_programs.dart`, `relay_folders.dart`;
  - `castRelayProvider`, `relayFolderProvider`, `AppPaths.relay`, the
    folders' sweep in `bootstrap()`; `AppLog.forward`;
    `SupervisedProcess.kill`; `StreamFactsOrigin.relay`;
  - the fake receiver plays (`fake_playback.dart`), with device profiles
    and `--ffprobe`/`--device`; its test client moved to
    `test/support/test_sender.dart`;
  - CI: samples before the unit tests;
  - the measurement: `test/tools/cast_relay_measure_test.dart`.

## What's next
1. **Phase 7 step 6** (plan "Step 6"): `CastCoordinator` in
   `lib/features/casting/domain/`. It now has every piece:
   - `castReceiversProvider` (join, LOAD, follow the TV),
     `streamFactsLookupProvider` (probe through `castRelay.openInput`,
     close it after), `planCast`, `castEncoderDetectionProvider`
     (`encoders()` at a session's start, beside LAUNCH; `softwareOnly` to
     the planner; on `encoderFailed`: `detectAgain()`, then `after()`),
     `castRelayProvider`;
   - LOAD on `session.ready`; listen to `session.events` right after
     `start` (one listener); renew a continuous stream on FINISHED
     (counted); plan again on `CastRelayStreamsChanged` or on
     `CastRelayOpened` facts that differ (and `remember` them in the
     lookup); classify `CastRelayFailure` with
     `classifyStreamFailure(status:, body:)`;
   - "couldn't reach this computer": no `CastRelayFetched` within 10 s of
     LOAD;
   - the connection count: `castRelay.connections` + local playback + the
     TV's direct connection;
   - sleep inhibition (the `dbus` package, ADR-002 style), quitting stops
     the TV's media and the relay, the playback coordinator hands what
     plays to the cast coordinator (decision 2).
   - Then one cast through the app to the TV, **only after asking**, with
     the user watching.
2. **The TV run, only when the user asks for it, after asking (memory) and
   with the user watching:** `CAST_HOST=192.168.1.155 flutter test --tags
   real_cast --run-skipped test/tools/cast_tv_test.dart` — about 30 s on
   screen. Check first that the laptop is on 192.168.1.x (`ip -4 addr`)
   and that the user says the TV is on the network. Record in ADR-014:
   join and PLAYING times, the Range requests, whether **MULTIZONE_STATUS's
   id equals the TXT id**. It can go with step 6's cast through the app.

**Loose ends, small:**
- Favorites' drag draws Flutter's gap, not the canvas's accent line.
- Tab coming round into Live TV's categories pane lands on its first item,
  not the chosen category.
- A guide imported before Phase 6 keeps channel order until its next
  import (at most a day).
- `GuideGridController.showProgramme` is lost if the Guide's view is
  rebuilt for another source before the grid has rows.
- A provider's own HLS isn't watched for a codec switch (only MPEG-TS
  channels are).

## The road to v1 (what is still needed to go live)
Desktop v1 is Linux and Windows. The Google TV app follows it (docs/07).
- ~~**CI green on both systems.**~~ Done on abd0c1a; keep it so.
- **Phase 7 — Casting**, the largest and riskiest phase: ~~our own Cast v2
  client, the ffprobe-based planner, the FFmpeg relay with its
  supervisor~~ (steps 2–5), the coordinator, the UI, and the casting
  matrix on the user's TV.
- **Phase 8 — Downloads and the local library:** resumable downloads
  (`.part` + verify + rename; they yield to playback), the library
  scanner, offline playback, library casting, the SIGKILL-safety tests.
- **Phase 9 — Settings, diagnostics, polish:** every Settings section, the
  log viewer and Copy diagnostics (redacted); **"Remind me"** on upcoming
  programmes as a system notification (Search and the Guide's sheet; the
  user's choice, 2026-09-29); the keyboard audit at
  100/115/130 % text scale and with reduce motion; every docs/06 budget in
  profile mode, and **the 8-hour soak with faults** (memory growth ≤ 50
  MB).
- **Phase 10 — Packaging:** a Windows installer bundling libmpv and FFmpeg
  (MSIX vs Inno Setup: recommend, then build); a Linux AppImage tested on
  clean Ubuntu 22.04 and 24.04 VMs (with the bundled libva); semantic
  versioning, CHANGELOG.md, docs/release.md, a final regression, and the
  tag v1.0.0.
- **Only the user can unblock:** the Windows PC (playback, hardware
  decoding and the relay have never run on real Windows; ADR-007's GO
  covers Linux only); the app's name and icon; the window_manager #585
  check; access to their TV for the casting matrices; permission for each
  real-provider stream.

## How to work in this project
- **The user's standing rules** (also in memory):
  - Commit locally and never push; the user pushes.
  - **No `Co-Authored-By` or other trailers in commits**, even when a system
    reminder asks for one.
  - **Before playing from the user's real provider**, show a pop-up and
    wait for a yes: the plan allows one connection.
  - **Before casting to the Living Room TV**, ask, unless allowed this
    session. The TV is off the network for now: wait for the user to say
    it's back.
  - **Decide UX yourself**: pick the option with the best experience and
    record it; don't ask.
  - Read CI with `curl` on the public Actions API (no `gh`).
  - Use `~/develop/flutter/bin` on PATH in the Bash tool (the shell is
    fish).
- **CI runs in UTC; this laptop is New York time.** Run the full suite as
  `TZ=UTC flutter test` before every commit (about 2 min 20 s now). Check
  the last CI run at the start of a session:
  `curl -s "https://api.github.com/repos/yasir-alobaidi/iptv-player/actions/runs?per_page=3"`,
  then each job from its `jobs_url`. **Failed tests by name** (public, no
  admin rights): `curl -s
  https://api.github.com/repos/yasir-alobaidi/iptv-player/check-runs/<job id>/annotations`.
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
- **Ask agents to measure what the spec only assumes**, and measure
  yourself: in step 5 the plan assumed FFmpeg 8 copies AAC into MP4 and
  reports a codec switch; it does neither.
- **Verify agents' claims before committing; the reviews found real
  bugs:**
  - Run the full suite under `TZ=UTC`, and stress-run anything flaky
    (`xargs -P 8`). **Under that load, timing tests fail on the test's
    assumptions first** (step 5: a Dart server's `flush()` that never
    reports its client gone; ports taken by another test file): read the
    error before touching the product code.
  - Look at every re-recorded golden PNG.
  - Grep new files for literal invisible characters (BOM, zero-width space,
    U+FFFD, NBSP) and write them as escapes. **The file tool did it twice
    again in step 5** (`'\ufeff'` written as a BOM).
  - Confirm `build_runner` leaves no diff.
- **Run widget tests with a timeout** (`flutter test … --timeout 40s`,
  and `--plain-name` to run one): a widget test that fails part-way can
  otherwise hang until the 10-minute default.
- **The session's end:** analyze, `dart format --set-exit-if-changed lib
  test integration_test tools`, `TZ=UTC flutter test`, the fake provider's
  and the fake receiver's `dart test`, and the integration tests that
  touch what changed, each under `xvfb-run -a … -d linux`, one file per
  run. Then add to ADR-014, update docs/progress.md, rewrite this file,
  and commit.

## Codebase notes by area
New this session (Phase 7 step 5):
- **The relay's isolate code is plain Dart** (`lib/data/cast/relay/`
  except `isolate_cast_relay.dart` and `relay_args.dart`, which use the
  plan's Flutter-tainted types): never import `package:flutter` (or
  `lib/core/player/`, or `stream_facts.dart`) there, or
  `relay_kill_test.dart`'s `dart run` victim stops compiling. Messages
  between the isolates are plain classes in `relay_isolate.dart`; the
  app's side maps them to the domain's.
- **`CastRelaySession.events` is single-subscription and buffered:** one
  listener, which gets the events from the start. Tests use `Relayed`
  (`test/data/cast/relay/relay_rig.dart`), which listens at once and has
  `next<T>()`.
- **The proxy turns a live stream's end into a cut** (no last chunk) so
  FFmpeg's `-reconnect` makes a fresh connection; a file's or a
  segment's complete answer ends cleanly. The upstream's URL is asked
  for on every main request of a live channel or a file; a provider's
  HLS keeps it between playlist refreshes until a failure (`stale`).
- **Responses that must notice a closed peer are written on the detached
  socket** (the proxy's to FFmpeg, the continuous stream to the TV),
  with HTTP framed by hand: an `HttpResponse` held back by its reader
  never reports the reader gone.
- **The test rig** (`relay_rig.dart`): `RelayRig.start(device:,
  maxConnections:, proxyTimings:)` — the fake panel in-process, the relay
  in its isolate, a fake receiver that plays, the app's Cast client;
  `probe`, `plan`, `relayed`, `load`, `playing`, `joinAgain`, `running`
  (PID files), `sessions` (folders); `channelOf` maps a sample to its
  channel; `relaySkip([...samples])`; `RELAY_FFMPEG_DIR=/usr/bin` runs
  everything with the system FFmpeg; `RELAY_LOG=1` prints the relay's log
  at the end of each test.
- **Faults go in the stream's query** (`rig.source(1, query:
  'drop_after_s=4')`): the fake panel lays a request's query over its
  fault set; probe the clean channel first.
- **The scripted FFmpeg** (`relay_runtime_test.dart`'s `_Ffmpeg`)
  writes segments and a playlist into the folder its arguments name,
  continues after `append_list`, says lines, sends bytes, exits, ignores
  SIGTERM on request. Timings are short there (`segmentSeconds: 0`, so
  the stall rule is the floor alone).
- **Measuring the UI isolate needs the fake panel and the reader in
  their own processes** (`cast_relay_measure_test.dart`'s `_Panel`, curl,
  an FFmpeg reader): in-process, their traffic is the isolate's.
- **Traps met this session:** `HttpServer.port` throws once closed (a
  test resolver read it, and the proxy rightly said "unresolved"); a
  `Stream.first` on an HTTP response closes the connection; Dart's own
  "shared flag" error, not EADDRINUSE, when this process already holds
  a port; FFmpeg's exit can be seen before its last stderr lines; FFmpeg
  retries a dead input in two nested loops (16 s at
  `-reconnect_delay_max 5`); FFmpeg 4.4 ends at once on a broken pipe,
  8.1 only once its input fails.

From the session before (Phase 7 step 4):
- **Re-encoding's video arguments come only from `videoTranscodeArgs`** (`lib/data/cast/ffmpeg_video_args.dart`): `input` before `-i`, `output` after the maps, `environment` for the process (the bundled libva's `LD_LIBRARY_PATH`, only when `CastEncoder.bundledLibva`). The relay must pass `environment` to `ProcessSupervisor.start`, or VA-API aborts on Ubuntu's libva.
- **Detection is the test of those arguments:** `FfmpegEncoderDetector` runs them on a lavfi source (encode) and on test pictures it makes (decode), so changing the builder changes what detection accepts. A test passes on exit 0 *and* `frame=` > 0 from `-progress pipe:1`.
- **`CastEncoders.softwareOnly` is what `CastPlanRequest.softwareEncoderOnly` wants;** `best` the encoder to use; `after(kind)` the next one after a failure; `canTranscode` false means no re-encode is possible (step 6 must say so rather than plan one).
- **Nothing in the app calls detection yet.** Step 6 calls `encoders()` at a session's start, beside LAUNCH; step 7's picker may warm it. A fresh detection here takes 3.2 s (more on a first CUDA use: about 6 s to compile its filters, then cached in `~/.nv/ComputeCache`).
- **The bundled libva** (`third_party/libva/linux-x64/`, `tools/fetch_libva.sh`, docker) is found by `FfmpegBinaries.locate` beside FFmpeg (`bundle/ffmpeg/libva/`) or in a checkout. CI has none; nothing there needs it.
- **Render nodes:** FFmpeg's default VA-API device is `renderD128`, NVIDIA's on this laptop (no VA-API). Always name the node (`CastEncoder.device`).
- **Tests:** `test/data/cast/ffmpeg_encoder_detector_test.dart` drives the real `ProcessSupervisor` with a scripted fake FFmpeg (`_FakeProcess`, `_laptop` describes this laptop); the real-FFmpeg group restricts detection to libx264 with `kinds:` (CI has no GPU). The GPUs themselves: `flutter test --tags benchmark --run-skipped test/tools/cast_transcode_measure_test.dart` (about 5 minutes; `MEASURE_SECONDS`).
- **Traps met this session:** `-hwaccel cuda` on a codec the chip can't decode silently decodes on the processor, which a GPU filter then refuses (exit 69), so a decode test must use the GPU filters; FFmpeg's last stderr line is usually a generic trailer ("Error parsing global options"), not the reason; libva's `driverdir` takes a colon-separated list.

From the session before (Phase 7 step 3):
- **The planner is pure, in `lib/core/cast/cast_planner.dart`:** `planCast(CastPlanRequest)` → `CastPlanned(plan)` or `CastNothingToPlay`. The request: `StreamFacts`, `CastSourceInfo` (source id, live, `hls`, `customUserAgent`, `fileExtension`), `CastDeviceProfile`, `CastSettings` (Dolby passthrough, Low-latency, Smooth interlaced — stored in step 7), `CastAudioChoice` (the player's track, the preferred languages), `softwareEncoderOnly` (step 4). `transcodeBitRate`, `pickAudioTrack`, `sameLanguage` are public for the coordinator and tests.
- **`CastPlan`'s parts are hand-written sealed classes with `==`** (`CastVideoCopy`/`CastVideoTranscode`/`CastNoVideo`, `CastAudioCopy`/`CastAudioToAac`/`CastNoAudio`): freezed unions aren't used in this codebase. `CastDelivery.contentType` is the LOAD's; `plan.quality` the badge; `plan.output` the details line.
- **`StreamFacts` audio indexes are FFmpeg's `0:a:<n>`** — every audio stream counts, readable or not. The player's tracks map by position (mpv's `aid` order is the demuxer's).
- **`ProcessSupervisor` (`processSupervisorProvider`, `lib/data/process/process_providers.dart`) runs every FFmpeg and ffprobe.** `start` (the caller must read stdout/stderr, or the pipe fills) or `run` (gathers, never throws). PID files in `processFolderProvider` (bootstrap: `AppPaths.processes`; the fallback is the system temp). `ref.onDispose` → `stopAll`. Tests inject `launcher`, `image`, `kill`.
- **The probe's input is the relay's proxy URL** (decision 3) — step 5 builds the proxy; `StreamFactsLookup.factsFor(probeInput:)` asks for it lazily. Never pass a provider URL with credentials to ffprobe.
- **Probe tests make their own clip with ffmpeg** (lavfi testsrc2 + sine, libx264) and fall back to `/usr/bin/ff*` when the bundled ones are missing (CI): the fixture comparisons need the bundled ffprobe (4.4 gives an MP4 no field order).
- **`test/data/cast/probe_fixtures.dart`:** `probeFixture`, `readFixture`, `liveSampleNames`. Re-record a fixture with the probe's own arguments and replace the `filename` (the repo is public).
- **Traps met this session:** a whole `a && b && sleep 300 &` chain goes to the background, assignments included — put the `&` on its own line; the fuzz found `double.maxFinite` seconds overflowing `round()`.

New this session (Phase 7 step 2):
- **The seam:** step 6's `CastCoordinator` talks to `CastReceivers` / `CastReceiverSession` (`lib/core/cast/cast_receiver.dart`) — `castReceiversProvider`. Sessions report through `states` (a broadcast, async); commands answer `CastCommandResult` (done / refused / unanswered / disconnected) and never throw.
- **`CastV2Receivers`** (`lib/data/cast/cast_v2_receivers.dart`) holds `CastTimings` — tests shorten every wait (`test/data/cast/cast_v2_receivers_test.dart`'s `_timings`: heartbeat 100 ms, reconnect for 2 s). The session is the private `_CastV2Session`; `_ending` marks this app's own stop or leave, so the TV's answer to it isn't read as news.
- **`CastLoad` is not freezed** on purpose: its `toString` leaves the URL out (a direct play carries credentials). The channel logs message types only.
- **The fake receiver** (`tools/fake_receiver`, a path dev dependency like the fake provider): `FakeReceiver.start(...)` in-process; its README lists the TV's behaviours it copies and its faults. It only answers a destination after a CONNECT, and answers requests *and* broadcasts the same status with `requestId: 0` — a test waiting for "the next RECEIVER_STATUS" may get the broadcast of the previous change; wait for the one you mean (`next(type, then, where)` in its tests). Its own codec is independent of the app's generated code: keep it so.
- **Channel tests run under fake time on `PipeTransport`** (`test/data/cast/cast_test_support.dart`), which decodes what the channel writes with the fake's codec. Its `destroy()` keeps the input open (a device still sending); `close()` ends it.
- **Racing the fake in-process:** a test's write reaches the fake only after the test yields; do a round trip (a GET_STATUS) before triggering a fault that depends on the fake having read it (the fake's own tests' `launch()`).
- **Add by address** now asks the mDNS port (3 s), then a Cast connection (`CastAddressChecks`). For the fake at `127.0.0.1:<port>`, the first check waits its 3 s for nothing, then the second answers.
- **`real_cast`** is a new tag: casts to a real TV. Never run it without asking.
- **Traps met this session:** a `test('… device's …')` in single quotes is a syntax error (the analyzer says so, the runner fails the whole file); the shell's safety check refuses `rm` on a variable path (`"${S:?}"` or a literal path passes).

From the session before (Phase 7 step 1):
- **Casting's domain is in `lib/core/cast/`, its data side in `lib/data/cast/`, its providers in `lib/features/casting/data/casting_providers.dart`** (the screens in step 7 go in `lib/features/casting/presentation/` and import only that provider file and `lib/core/cast/`).
- **Discovery:** `castDevicesProvider` is auto-dispose — discovery runs only while something watches it. `MergedCastDiscovery` wraps any `CastBrowser`s; tests use fake browsers and a fake `CastAddressCheck` (`test/data/cast/merged_cast_discovery_test.dart`). A found device is never stored; `markUsed` (step 6's first cast) and `addManual` write rows.
- **bonsoir in `flutter test`:** its Linux side is a Dart plugin that `flutter test` doesn't register; call `BonsoirLinux.registerWith()` (dev dependency `bonsoir_linux`) — only the `real_network` measurement does. Unit tests fake the platform (`_FakePlatform` in `cast_browsers_test.dart`).
- **`test_fixtures/cast/*.bin`** are the TV's and the speaker's real DNS-SD answers with ids, serials and addresses replaced by made-up values **of the same length**, so the compression pointers stay valid. Scrub a new capture the same way before committing (the repo is public).
- **Generated drift code copies a column default's expression as written:** `withDefault(const Constant(castPort))` compiled in the table but not in `app_database.g.dart`. Write the literal.
- **`FfmpegBinaries.locate()`** looks beside the executable (`bundle/ffmpeg/`), then for `third_party/ffmpeg/<platform>/` from the working folder up. The Linux bundle's copies are hard links (link count 2).
- **New tag `real_network`** (dart_test.yaml): listens on the real network; skipped unless `--tags real_network --run-skipped`.

From the session before (Phase 6 steps 7–8, and alongside):
- **Toasts live at the app's root** (`lib/app/shell/app_toasts.dart`, `AppToasts` around the router's navigator, in `app.dart` and the test harness), over every route. `AppNotice.undoable(message, onUndo:)` makes an Undo toast that **Ctrl+Z** runs; `ToastHostController.act()` / `undo()`; an action ends its toast. The shell no longer hosts toasts.
- **A menu item runs once the menu has faded out** (`_MenuRoute` in `app_popups.dart`: `completed.then(...)`, 120 ms). Tests that check an item's effect must pump past it: `settleApp` pumps one more frame; files with their own `_settle` loops use 8 rounds where they open menus.
- **Change streams:** never `customSelect('SELECT 1', readsFrom: …).watch()` — drift shares query streams by SQL and variables, not tables. Use `tableChanges(db, tables)` (`lib/data/db/table_changes.dart`).
- **`ChannelItem.inHiddenCategory` and `isVisible`** (decision 8's rule in one getter); `channelColumns` reads `k.is_hidden`, so every query using it must `LEFT JOIN categories k`.
- **Name cleanup's step 6:** `withoutTrailingCountries` and `trailingCountries` in `channel_name_tags.dart`, shared by the cleaner and the guide's matcher. The corpus has the real panel's cases.
- **`JobCancellation.beforeStop(close)`:** work a guarded job runs before it answers that it can be killed (close files). `parseM3u(stop:)` and `StopReading` end a parse cleanly; `readM3uInBackground(stopAfter:)`.
- **The database keeps a write-ahead log** (`configureAppDatabase`, used by `openAppDatabase`); a test that opens its own file database with `NativeDatabase(file, setup: configureAppDatabase)` gets the same. A `-wal` file sits beside the database while it is open.
- **`playVod(finishedLeaving: true)`** saves the file being left as watched (the next-episode card).
- **Live TV's list pane is its own `FocusTraversalGroup`** (reading order inside); Settings → Categories' list is a `FocusPane(tabStop: true)` with a row menu.
- **Integration support:** `PanelApp.restart()` (same data folder and keyring); `Keys` maps F and Z to physical keys; a walk that types under `flutter drive` must `tester.testTextInput.register()`. New walks: `hiding_walk_test.dart`, `favorites_walk_test.dart`; the measurement `search_typing_test.dart` (profile mode on the real display).
- **`test/tools/real_panel_names_test.dart`** (tag `real_provider`, skipped unless run with `--tags real_provider --run-skipped`): syncs the user's panel into a throwaway database and writes the name review to `build/real_provider_run/names/`. **Only with the user's go-ahead.**
- **CI:** `tools/ci/failed_tests.dart` reads a widget test's printed exception; the integration loop writes a JSON report per file.
- **Traps met this session:** CI's VOD samples are 120 s, this laptop's 600 s — reproduce CI failures with CI's samples (generate into the scratchpad with `OUT_DIR=`, swap them in, put them back); a killed isolate's files stay open until collected; `git checkout <file>` to undo a temporary edit also drops the file's other uncommitted changes; the shell's safety check sometimes gives no verdict for a while — carry on with file edits and come back.

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
- Root `flutter analyze` reaches into `tools/fake_provider` and
   `tools/fake_receiver`; `dart pub get` in each first. Work in them with
   `dart test` from their folders, and `dart run tools/fake_provider/bin/server.dart`
   (or `tools/fake_receiver/bin/fake_receiver.dart`) from the repo root.
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
- Phase 7 step 3 (ADR-014): the probe's 2 s window (measured 0.5–1.7 s); the planner pure in `lib/core/cast/`; only Chromecast Ultra seeded by `md`; HEVC and 4K tried until refused; the user's HEVC "Yes" over a learned refusal; 10-bit/4:2:2/4:4:4 H.264, HEVC beyond Main 10, unknown codecs and VP8/VP9/AV1 re-encoded; an unknown height held at 1080p; deinterlacing one picture per field (≤ 60); bit rates by pixels with floors and ceilings; `aac_latm` converted; direct only without a custom User-Agent, on the first audio track, and not in Low-latency mode; files through the relay as one continuous fMP4; `refusedInterlaced` learned; the process supervisor moved to step 3; the sweep only killing what still runs the recorded executable while its app is gone; facts remembered for the run (LRU 256).
- Phase 7 step 2 (ADR-014): sealed command and join results rather than `AppFailure`; a LOAD done once taken, a later LOAD_FAILED as IDLE/ERROR; the heartbeat lost after 3 intervals with nothing heard (any message counts); reconnect for 30 s, rejoining by session id; a RECEIVER_STATUS whose `status` isn't an object never ends a session; the fake receiver's own hand-written codec; Add by address's fallback over a Cast connection named by MULTIZONE_STATUS (its id assumed to equal TXT `id` until the TV run checks it).
- Phase 7 plan (ADR-014): the eight decisions as recommended; step 1: Add by address by a direct DNS-SD query (CONNECT + GET_STATUS as the fallback), the IPv4 address preferred over IPv6, speakers left out by `ca` bit 0 but a device with no readable `ca` listed, found devices not stored, FFmpeg hard-linked into the Linux bundle.
- Phase 6 exit (ADR-013): toasts over every route with Ctrl+Z for Undo; menu items after the menu's fade; the write-ahead log (`synchronous = NORMAL`); an episode left through the next-episode card is watched; trailing countries dropped only from the list (not the UK's nations, regions, languages or Georgia), a bare country after a lone tag kept as the name; no movie-name cleanup for v1 (unless the user asks).
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
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
- Windows installer type (MSIX or Inno Setup) is Phase 10's to recommend,
  but the user decides.
