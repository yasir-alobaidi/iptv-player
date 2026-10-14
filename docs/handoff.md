# Handoff — 2026-10-14, fifth session (TV-0 begun without a TV: the Android build, the app on a Google TV emulator; Start over)

For the next Claude Code session on this project, and for the user starting
it. Read this file whole, then CLAUDE.md, docs/progress.md, **ADR-020 and
ADR-021 in docs/decisions.md** (ADR-020: the Android toolchain, the Google
TV project, what the emulator showed, what TV-0 still needs; ADR-021:
Start over), **docs/setup.md §7** (the Android commands) and **docs/07**.
ADR-018/019 and ADR-016 "The exit" are still the state of the name, the
TV's bar and Phase 9.

## Before you start the next session (user)
**Your list** — what this session left for you:
1. **Push** this session's commits (`git log origin/main..HEAD`), now or
   after the next session fixes the one CI failure on your last push
   (788e0f1, Linux only: a test that assumed the 10-minute sample where CI
   makes 2-minute ones; the app itself is fine). Then CI runs the new
   Android job for the first time.
2. **Your question about AirPlay and TVs that aren't Google** — answered
   below ("Casting to TVs that aren't Google"). Say whether you want DLNA
   casting and when.
3. **For TV-0's rest, when a TV is free:** turn on Developer options and
   USB debugging on it (Settings → System → About → press "Android TV OS
   build" seven times; Settings → System → Developer options → USB
   debugging). I ask before every TV session; the Living Room TV stays
   off limits until you say so.
4. Still from before: **Bijou and its jewel** (keep, or say otherwise);
   **the progress-bar fix on the Bedroom TV** (after my pop-up, about 10
   minutes); **the one real reminder** at the laptop
   (`flutter test integration_test/manual/real_reminder.dart -d linux`);
   if you want them, **the night's soak** and **the full casting matrix**;
   **Phase 9's close** is yours to say; **the dock icon**
   (`flutter build linux --release`, then `tools/install_desktop_entry.sh`).
5. Optional: `fish_add_path ~/Android/Sdk/platform-tools` to have `adb`
   in your own terminal.

**What this session did on your machine (outside the repository):**
installed Temurin JDK 21 in `~/develop/jdk-21.0.12.1+1` (linked as
`~/develop/jdk`) and the Android SDK in `~/Android/Sdk` (about 5 GB with
the emulator image), accepted the SDK's licences, pointed Flutter at both
(`flutter config`), and created the emulator `bijou_google_tv`
(`~/.android/avd/`). **And it ran your laptop out of memory once** (04:02):
a Gradle build beside the emulator; systemd-oomd killed your GNOME session
and the kernel your editor. Gradle is now capped at 3 GB, and the rule
(build, stop Gradle, then the emulator) is in docs/setup.md and in memory.

**What this session decided for you** (say if you want any otherwise):
- **The TV app's id is `io.github.yasiralobaidi.bijou`** — no "iptv" in
  it; an id is forever once installed, and nothing is saved under an old
  one on Android (ADR-020).
- **JDK 21** rather than 17 (what Android Studio bundles; AGP 9 needs 17+).
- **Start over is a button, always there,** after Back/Forward 10 s in a
  film's or an episode's player and in the casting view, not beside Play
  (a stray press there would lose your place) (ADR-021).

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the Bijou project (the repo is still iptv-player). Read docs/handoff.md,
CLAUDE.md, docs/progress.md, ADR-020 and ADR-021 in docs/decisions.md first.
Fix the CI failure the handoff names (cast_e2e_library_test.dart:495), then check
CI on the last push (the new Android job too).
<The Bedroom TV is free: you may use it for TV-0 after asking | Don't use any TV>
<I want DLNA casting: plan it | Not now>
Then: <TV-0's engine comparison on the TV | TV-1 on the emulator (plan first) | Phase 10 | what is left of Phase 9>
```

## Where things stand
- **TV-0: begun (ADR-020).** Done: the toolchain, `android/`, start-up by
  form factor, the CI job, the emulator run. Left: the app on a real TV,
  and the engine comparison (media_kit vs a Media3 plugin) there.
- **Phase 9: all nine steps built and run;** ADR-016's "The exit" lists
  what is not met. Its close is the user's call.
- **Phases 7 and 8: accepted without the TV sitting** (ADR-014/015).
- **Schema is v10**; no new dependency in pubspec, no new settings key.
- **The test suite is about 4,880 tests** (20 skipped); see "The session's
  end" for this session's count.

## Casting to TVs that aren't Google (the user's question, answered)
The user asked: "since most of the smart tvs they have air play or
streaming from android, is there anyway we can support that in the app,
and let the users of the app, stream on the tv directly even if they are
not google?" Answer given, nothing built:
- **DLNA / UPnP — yes, and the one to do first.** Most smart TVs (Samsung,
  LG, Sony and Panasonic for certain; many Hisense, TCL, Philips and Android
  TVs; consoles) are DLNA "media renderers": the app finds them on the
  network (SSDP) and tells them to play an address on the laptop. It fits
  what is built: the same local server and FFmpeg relay, a second kind of
  device behind `CastService`, the same Cast button and picker. Plain Dart,
  no licence. The catch: every TV plays a different set of formats and
  says little about it, seeking and subtitles vary, positions are polled,
  and there is no receiver screen of ours. Roughly 1.5–2 weeks with a fake
  renderer for the tests and a format ladder like the Chromecast's.
- **AirPlay — not now.** Samsung, LG, Sony, Vizio and Roku TVs since about
  2019 receive AirPlay 2, but AirPlay is Apple's closed protocol: a sender
  that isn't an Apple device uses a reverse-engineered one (pyatv), which
  needs pairing and encryption, plays URLs reliably only on Apple TVs
  (reports of third-party AirPlay TVs refusing them), and Apple can change
  it. The same TVs also speak DLNA. Revisit only for a TV that does AirPlay
  and nothing else.
- **Fire TV, Shield, Sony/TCL/Hisense Android TVs: the TV app covers them.**
  Fire OS runs Android apps, so the Google TV APK installs there too (no
  DLNA on Fire TV without an app). **Roku TVs:** Roku's own control
  protocol can open its media player with an address — possible later.
- **Screen mirroring (Miracast):** a feature of the system (Windows' Win+K),
  not of an app.
- **Proposal:** DLNA casting as its own phase after Phase 10 (or beside
  TV-2), planned first, with an ADR. Waiting for the user's word.

## Done this session (2026-10-14, the fifth)
- **The Android toolchain** (ADR-020, docs/setup.md §7): JDK 21, the SDK,
  NDK 28.2, the emulator and the Google TV image, `flutter doctor` clean.
- **`android/`** from Flutter 3.47.4's template, in a scratch copy:
  `io.github.yasiralobaidi.bijou`, Bijou, leanback launcher, banner and
  launcher icons (`tools/brand/make_icons.py`; the desktop icons are byte
  for byte as they were), internet, plain http, a dark launch window,
  desugaring, Gradle at 3 GB.
- **Start-up by form factor** (`lib/app/bootstrap.dart`): on the TV, no
  `AppWindow`, no FFmpeg or relay sweeps, no cast notices, no downloads or
  library; `FocusHighlightStrategy.alwaysTraditional`.
- **The `sub-files` fix** (`media_kit_player_engine.dart`): never `""`;
  `change-list sub-files clr` when there are none. Android's (and
  Windows') libmpv failed every play on it.
- **Start over** (ADR-021): `AppIcons.startOver` (hand-drawn in
  `tools/extract_icons.dart`), an `OsdButton` in `VodOsdBottom`
  (`onStartOver`), an `AppIconButton` and Home in `casting_view.dart`, the
  shortcut tables (code and docs/05).
- **CI's Android job** (`.github/workflows/ci.yml`): Temurin 21, `flutter
  build apk --release`, the APK as the artifact `bijou-android-apk`.
- **The emulator run**, by remote keys: ADR-020 "What the emulator showed".

## The session's end, as run
- **CI on the user's last push (788e0f1): failed, one test** (Linux; Windows
  green): `test/features/casting/cast_e2e_library_test.dart`, "a subtitle
  file beside a Matroska film, through the relay …" — Expected 600000–600200,
  Actual 120005. **A test assumption, not the app:** `_tenMinutes`
  (line 495) expects the 10-minute VOD sample, but CI generates its samples
  at `VOD_SECONDS=120` (2 minutes), and the relay reports that file's real
  length. Fix first next session: compare with the sample's own length
  (ffprobe it, as the test already does for other facts, or read
  `VOD_SECONDS`), then run the file with `RELAY_FFMPEG_DIR=/usr/bin` and
  with samples made at 120 s. Not fixed this session: the user asked to
  stop at a clean point.
- **Checks:** analyze and format clean; **4,902 app tests under `TZ=UTC`**
  (20 skipped), all passing after the last golden (the shortcuts panel) was
  re-recorded; six goldens re-recorded in all, each looked at. Not re-run:
  `build_runner` (no annotated code changed), the fake provider's and the
  fake TV's suites (unchanged), the FFmpeg 4.4 run (nothing in the relay
  changed).
- **Android:** debug APKs built and run on the emulator (above). **The
  release APK was not built locally**; CI's new job is its first build.
- **Not run this session:** any TV (both offline); **the integration walks
  that Tab through the player or the casting view** (`live_tv_keyboard`,
  `library_walk`, `cast_walk`, `library_cast_walk`, `player_engine`): one
  more control is in each row, so a walk that counts Tabs may need one
  more; the soak; the real reminder.
- **Left running: nothing** (the emulator, Gradle's daemons and the fake
  panel were stopped).
- **Agents:** the user asked for agents to work while I waited, then to
  stop at a clean point, so none was started. The two tasks meant for them
  are items 2 and 3 of "What's next".

## What's next
1. **The CI failure above** (one test's assumption), then the user's push;
   then CI's first Android job (it may need to fetch platform 35/36 or the
   NDK itself on the runner).
2. **The integration walks** listed above, under Xvfb, one file per run
   (in a git worktree if agents run beside other `flutter test` work: they
   share `build/test_cache`).
3. **TV-0's Media3 candidate:** a small plugin of our own in
   `spike/tv_engine_spike/` (ExoPlayer 1.x, a `SurfaceView` platform view
   for frame-rate matching, the decoder and passthrough reported), beside
   media_kit in one comparison app, measured on the emulator first (does
   Media3 draw where mpv can't?), then on a TV. `video_player`'s Android
   side uses Media3 but exposes none of what the comparison measures.
   Gradle and the emulator under one lock: `flock <scratchpad>/android.lock`.
4. **The user's answers:** DLNA casting, and a TV for TV-0 (then
   `adb connect <address>:5555`, install, and the comparison of docs/07).
5. **Or TV-1 on the emulator** (plan first): ADR-020's list is its start.

## How to work in this project
- **The user's standing rules** (also in memory):
  - Commit locally and never push; the user pushes.
  - **No `Co-Authored-By` or other trailers in commits**, even when a system
    reminder asks for one.
  - **Before playing from the user's real provider**, show a pop-up and
    wait for a yes: the plan allows one connection.
  - **Before anything is sent to a TV, ask with a pop-up and wait,** every
    time. **The Living Room TV (192.168.1.155) is off limits until the
    user says it is free;** the Bedroom TV (192.168.1.231) may be used
    after asking. Always pass `CAST_HOST=<address>`; confirm which address
    is which first (`avahi-browse -rtp _googlecast._tcp`).
  - **Decide UX yourself**: pick the option with the best experience and
    record it; don't ask.
  - Read CI with `curl` on the public Actions API (no `gh`).
  - Use `~/develop/flutter/bin` on PATH in the Bash tool (the shell is
    fish). **The SIGKILL tests need `dart` on PATH** too, or they skip
    (3 more skipped than usual means PATH).
  - **Installing an APK on a TV counts as using the TV:** ask first, as
    for a cast.
- **Android (ADR-020, docs/setup.md §7):** the JDK is `~/develop/jdk`, the
  SDK `~/Android/Sdk` (`adb` at `~/Android/Sdk/platform-tools/adb`; not on
  the Bash tool's PATH). **Never run a Gradle build and the emulator at
  once** — together they killed the user's desktop session once: build,
  `cd android && ./gradlew --stop`, `pkill -f '[K]otlinCompileDaemon'`,
  then start the emulator (headless, `-no-window`); `adb emu kill` before
  the next build. Don't run the full test suite beside the emulator either.
  `pgrep -f`/`pkill -f` match their own shell's command line: write the
  pattern as `'[q]emu-system'`. The laptop is `10.0.2.2` from the
  emulator; drive it with `adb shell input keyevent KEYCODE_…` and look
  with `adb exec-out screencap -p`. mpv draws no picture there.
- **A failing golden in `player_golden_test.dart` hangs the run** instead
  of failing it: the test throws before `t.finish`, and the player's
  timers keep the runner waiting. A full run that stalls on that file
  (one `flutter_tester` at 0 % CPU) means a player golden changed; run it
  alone with output to a file to read the diff.
- **CI runs in UTC; this laptop is New York time.** Run the full suite as
  `TZ=UTC flutter test` before every commit (about 2 min 40 s now). Check
  the last CI run at the start of a session:
  `curl -s "https://api.github.com/repos/yasir-alobaidi/iptv-player/actions/runs?per_page=3"`,
  then each job from its `jobs_url`. **Failed tests by name** (public, no
  admin rights): `curl -s
  https://api.github.com/repos/yasir-alobaidi/iptv-player/check-runs/<job id>/annotations`
  — the message now carries the whole first paragraph (Expected, Actual,
  Which).
- **CI's FFmpeg is the system's 4.4; this laptop's tests use the bundled
  8.1.** Before a push, run every test that runs FFmpeg as CI does:
  `RELAY_FFMPEG_DIR=/usr/bin flutter test test/data/cast test/features/casting
  test/data/downloads` (and a walk under Xvfb with it). Seen: a clip 4.4
  makes starts 6 ms off 0, so cue times compared as text failed; it
  converts sound three times slower.
- **Windows-only test traps** (seen on CI): paths joined with `\`; a closed
  loopback port refused only after ~2 s (a test's short connect wait reads
  it as a timeout).
- **Run the app or integration tests under Xvfb with `unset
  WAYLAND_DISPLAY; export GDK_BACKEND=x11`** (in fish: `env -u
  WAYLAND_DISPLAY GDK_BACKEND=x11 xvfb-run -a flutter test
  integration_test/<file> -d linux`): otherwise GTK opens the window on
  the user's real Wayland desktop, whatever `xvfb-run` does. Close a window from a script under Xvfb
  with a `WM_DELETE_WINDOW` client message (a ctypes libX11 script; there
  is no xdotool); give every ctypes call its `argtypes`, or a 64-bit
  display pointer is truncated and it segfaults.
- **Don't run several `flutter test` processes in one checkout when you
  can avoid it:** they share `build/test_cache/build/*.dill`, and after
  this session's parallel stress runs that cached kernel made every
  compile balloon to 13 GB until the kernel OOM-killed it ("The Dart
  compiler exited unexpectedly", then the tool hangs). Fix: move that
  `.dill` aside. Stress-run in parallel only when needed, then check
  memory.
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
    reports its client gone; ports taken by another test file; step 6: a
    direct play refused within 50 ms, before a test sampled the plan —
    record states from the stream instead): read the error before
    touching the product code.
  - Look at every re-recorded golden PNG.
  - Grep new files for literal invisible characters (BOM, zero-width space,
    U+FFFD, NBSP) and write them as escapes.
  - Confirm `build_runner` leaves no diff.
- **A fake that is kinder than the real thing hides bugs:** the fake TV
  read a relayed stream as fast as it came, so nothing ever tested a TV
  that holds back, and the relay took that for a stall. When a fake
  stands in for hardware, model its pace too (it buffers, it pauses).
- **Run widget tests with a timeout** (`flutter test … --timeout 40s`,
  and `--plain-name` to run one): a widget test that fails part-way can
  otherwise hang until the 10-minute default.
- **The session's end:** analyze, `dart format --set-exit-if-changed lib
  test integration_test tools`, `TZ=UTC flutter test`, the fake provider's
  and the fake receiver's `dart test`, and the integration tests that
  touch what changed, each under `xvfb-run -a … -d linux` (X11, above),
  one file per run. Then add to ADR-016, update docs/progress.md, rewrite
  this file, and commit.
- **Lessons of this session (the name, the TV's bar):**
  - **A receiver's behaviour can be seen without the TV:** the Default
    Media Receiver is Chrome's media stack, so headless Chrome playing
    what the relay serves shows what the TV will. A small server in the
    scratchpad (FFmpeg with the relay's arguments, chunked, as the TV
    reads it) and a page logging `video.duration`, `currentTime`,
    `buffered` and `seekable` reproduced the Bedroom TV's growing length
    in a minute, and tried each fix before any code:
    `google-chrome --headless=new --autoplay-policy=no-user-gesture-required
    --user-data-dir=<scratchpad>/prof <page>`. What it can't show: the
    receiver's own UI and its handling of a LOAD's `currentTime`.
  - **The LOAD's `media.duration` is not what a TV shows:** the receiver
    shows its media element's length, which comes from the stream.
  - **FFmpeg's fragmented MP4 always counts from 0** (8.1:
    `-output_ts_offset`, `-copyts`, `-use_editlist 0`, `frag_discont`
    all leave `tfdt` at 0), and `empty_moov` writes the length as 0.
  - **The relay's isolate is plain Dart, and so is everything it imports:**
    `relay_job.dart` importing `lib/core/cast/cast_relay.dart` pulled in
    Flutter (through `cast_encoders.dart`), and the SIGKILL tests failed
    with "Bad state: No element" (their victim never said "ready"). `dart
    run test/data/cast/relay/support/relay_victim.dart` prints the import
    chain. Hence `RelayTimeline` beside `CastTimeline`.
  - **A provider's generated file copies its doc comment:** edit the
    comment, run `build_runner`.
  - **A length ffprobe reads from part of a fragmented MP4 can include
    the first picture's display offset** (80 ms here), depending on how
    much was read: compare a stream's length with a tolerance.
  - **`pkill -f` killed the shell again** while stopping a scratch server
    (exit 144): keep the server's PID and kill that.
  - **On Windows, `flutter_secure_storage` and `path_provider` both name
    their folders from the exe's version information** (CompanyName +
    ProductName), read natively: changing the product name loses the
    passwords and the data. The name people read is `FileDescription`.
- **Lessons of the session before (the player, the windows, step 7's rest, the
  first real TV):**
  - **A fake on this computer's own address can't show which address is
    whose.** The Cast client took `Socket.address` for the local address;
    in dart:io it is the address the socket was connected **to**. The fake
    TV is on 127.0.0.1, so every cast test passed for three phases, and
    the first real TV showed that none could have played. When a fake
    stands in for another machine, list what only another machine can
    show, and say so in the phase's exit.
  - **A tool that touches a shared device must not have that device as
    its default,** and must undo what it did whatever fails: `cast_tv_test`
    threw before its `try` and left the receiver open on the TV.
  - **`pkill -f <pattern>` kills the shell that runs it** when the pattern
    is in its own command line. Kill by PID.
  - **A measurement of nothing passes.** The player's processor use first
    read 6.5 % of a core: nothing was being drawn. The channel list's
    End and Home read 0.3 ms: the list has neither key. The Guide's
    PageDown number had the Home press in it. **Every measurement checks
    that the thing measured happened** (the picture at the stream's size,
    the list moved), and one number is one action.
  - **A test window with a fixed size never draws the player's picture**
    (`tester.view.physicalSize`, as every whole-app walk sets it). The
    texture stays 1 × 1 and mpv drops every frame. The app is fine
    (`integration_test/manual/picture_probe.dart` shows both). So the
    walks prove Playing, not a picture; the soak and `playback_cpu_test`
    use the window as it is. Why the fixed size does it: not looked into.
  - **A state stream forwarded as it is replays its past** to the next
    screen that watches (Riverpod pauses a provider nobody watches).
    That was the cast bug the soak found; `currentThenChanges` is the
    rule now (CLAUDE.md, docs/01). **Still forwarded as they are, and
    harmless only because the last value is all that matters:** the
    download queue's list, the player's size and tracks, drift's watch
    streams. A long pause with many changes replays them all in one go.
  - **A regression test must fail without the fix.** The first test for
    the cast bug passed on the old code: its fake cast changed state
    once, the real one keeps changing. Stash the fix and run the test
    before believing it.
  - **Run the thing the way a person meets it, for long enough.** Three
    phases of cast tests never played anything after a cast. The soak's
    second act did, in its first eight minutes.
  - **Riverpod's listeners are told on the provider's word:** before
    acting on a state that starts something (a hand-over, a navigation),
    ask the object that owns the state as well.
  - **The audit's checks pass on screens that look wrong.** A row that
    stretches, a name cut with "…", a word broken in two: none is an
    overflow. `AUDIT_SHOTS=<folder>` draws every scene in every look; make
    contact sheets (PIL) and look. This session's real findings all came
    from looking: Live TV's names, Home's cards, the Guide's column, the
    Series page's titles.
  - **A new scene or a walk at 130 % finds what the old ones couldn't:**
    the Series page's overflow (no scene had it), the casting view's row
    with subtitles (no scene had a film with subtitles).
  - **A timed step that needs the user must wait for the user, not for a
    clock:** the first reminder run counted from the launch and both
    reminders came due while the window was in front.
  - **A golden with `sceneTest(large:)` is a second picture at 130 %;**
    `AuditLook` windows are in `test/audit/audit_look.dart`.
  - **A `PageMeasure` must stay in the tree on every tab** (pass
    `double.infinity` for a grid): wrapping one tab's body in it rebuilds
    the page and drops the focus.
  - **Tab in a one-stop list:** `FocusPane._leave` puts the focus on the
    pane's edge item for a moment so that Flutter's own `next` / `previous`
    walk on from there; the scope's focused child moves at once, the
    primary focus only once. An item removed in the same frame still has
    its focus node: ask nothing of its element (`_rectOf`).
  - **Don't run `flutter analyze` or anything heavy while a profile-mode
    measurement runs on the display:** it is the thing being measured.
- **Lessons of the session before (Phase 9 steps 6–7):**
  - **A failing widget test whose screens still watch the database waits
    out its whole timeout** on the fixture's close. The audit pumps an
    empty widget before it fails (`auditRun`); a failing golden comparison
    still hangs its file. Run the audit with `AUDIT_REPORT=1` while
    sweeping: it prints and fails nothing, 45 s for everything.
  - **Never pipe a long `flutter test` into `tail`** while it may hang:
    nothing shows until it ends. Write to a log in the scratchpad, with
    `timeout`, and read the log.
  - **A `Skeleton` with no width inside a `Column` is 0 px wide.** Use
    `SkeletonColumn`.
  - **A `Column` of fixed rows in a bounded pane overflows the day the
    pane is short** (a small window, a larger text size, one more setting
    above it). Lists scroll; placeholders are cut.
  - **Scaled text is laid out a fraction taller than its font size says:**
    a row sized to the sum of its lines' heights overflowed by 0.2 px at
    130 %. Round a computed row height up (`guideRowHeight`).
  - **A focus node that only holds the focus for its keys must be
    `skipTraversal`,** or Tab lands on a stop that shows nothing; Tab from
    it still goes on to the first control.
  - **Tab passes some controls that the arrows reach** (the catalogue's
    "More" chip, beside a one-stop row of chips): the audit follows the
    arrows from every stop before it says a control is unreachable.
  - **A golden's choreography is written for its own window:** a tap or a
    focus on something by name may be below the fold in 1024 × 640 at
    130 %. Use `tapShown` (it scrolls to it first), or do the step only
    when its target is there.
  - **Named arguments can go before the closure:**
    `sceneTest('x', audit: size.width == 1280, (tester) async {…})`.
  - **A provider that only listens must subscribe to the stream itself**
    (`reminderWatchesProvider`), and `bootstrap()` reads it once; a test
    of it reads it the same way.
  - **In the search overlay Ctrl+Z belongs to the text field:** a toast's
    Undo there is the mouse's; give the keyboard its own way back (Ctrl+R
    toggles).
- **Lessons of the session before (Phase 9 steps 1–5):**
  - **Check a "nothing of X leaves the app" rule against the real
    thing.** The made-up sources had names of their own; the real one
    was named after its server, and that name was in the export. A copy
    of `~/.local/share/io.github.yasiralobaidi.iptvplayer/` and the login
    file in `~/.config/iptv-player-dev/` make that check without any
    network: never print their values.
  - **`Isolate.run` inside a method sends `this` with the closure,** and
    a class holding the database can't be sent ("object is unsendable …
    FfiDatabase"). Call it from a top-level function that takes only
    what it needs (`_writeInIsolate`, `_readInIsolate`).
  - **riverpod_generator drops a trailing "Notifier" from a provider's
    name:** `systemNotifier` became `systemProvider`. Hence
    `systemNotifications`.
  - **A list with `itemExtent` doesn't lay itself out again when rows are
    added in place:** its scroll extent stays stale until the next
    scroll. The log view marks its viewport (`_layOutList`).
  - **A focus ring is drawn the frame after the focus lands:** a golden
    of something that takes the focus as it opens needs a second
    `settleApp`.
  - **A control that is disabled while it works drops the focus,** and
    Flutter puts it somewhere the user didn't choose.
  - **`find.descendant(of: x, matching: find.byType(Scrollable))` also
    finds a text field's.**
  - **A sliver's children are built a little past each edge:** a test
    that reads "what is shown" must keep to what is inside the viewport.
  - **The shortcut tables in docs/05 are written by a test:**
    `UPDATE_SHORTCUT_DOCS=1 flutter test test/app/shortcut_table_test.dart`.
  - **To look only at where a re-recorded golden changed,** diff it
    against `git show HEAD:<file>` with PIL's `ImageChops.difference(…)
    .getbbox()`; then look at the new ones whole.


## Codebase notes by area
New this session (the fourth):
- **The name:** `lib/core/app_identity.dart` (`appName`, `appFileSlug`,
  `appDescription`), read by every place a person sees the name; never
  a literal. `AppMark.appName` points at it.
- **The mark:** `AppMark` paints `JewelPainter` on the accent's tile (the
  icon's 1024-unit coordinates; under 64 px the small variant).
  `tools/brand/make_icons.py` writes the SVG master, the Windows `.ico`,
  the Linux hicolor icons and the previews from the same coordinates.
- **The relay's clock:** `Fmp4Timeline` (`lib/data/cast/relay/
  fmp4_timeline.dart`) sits between FFmpeg's stdout and the TV's socket
  in `_ContinuousSession._serve` when the job has a `RelayTimeline`
  (`castRelayJob` makes one from `CastTimeline` for a file's continuous
  stream only). The coordinator awaits `_startOf` before the relay
  starts or renews, passes `_clockOf(cast, begins)`, LOADs at
  `cast.starts`, and turns the TV's time into the file's with
  `_fileTime` (the floor, the from-0 fallback); `_checkLength` logs a
  wrong length the TV reports.
- **The fake TV** reads each continuous stream's `start` and `length`
  (`FakeMediaCheck`) with ffprobe, as a TV's demuxer would; its own
  `MEDIA_STATUS` still reports the LOAD's duration and counts from the
  LOAD's `currentTime`.

New the session before (steps 8 and 9):
- **State providers:** `lib/core/streams/current_state_stream.dart`
  (`currentThenChanges(() => x.state, x.states)`) under
  `playbackStateProvider`, `castingStateProvider`, `castTimelineProvider`
  and `libraryScanStateProvider`. A new coordinator's provider is built
  the same way. `PlayerScreen` hands over to the casting view only when
  `_coordinator.casting` agrees with the provider.
- **The measurements on the display** (profile mode, one at a time, the
  window in front, nothing else running — not even the analyzer):
  `flutter drive --profile -d linux --driver=test_driver/integration_test.dart
  --target=integration_test/<name>_test.dart` for `guide_scroll` (flings,
  wheel down, wheel sideways, →, PageDown, Home, each its own number),
  `poster_grid_scroll`, `channel_list_scroll` (a stand-in player that
  "plays" at once; its first frame goes out in a microtask, because the
  fake engine's events don't nest), `search_typing`, `playback_cpu`
  (no fixed window size; `PLAYBACK_CPU_SECONDS`). The numbers print and
  go to `build/integration_response_data.json`. **`flutter drive
  --profile` leaves the test's app in `build/linux/x64/profile/bundle`:**
  run `flutter build linux --profile` again before
  `cold_start_benchmark_test` or `idle_memory_benchmark_test`
  (`IDLE_MINUTES`, default 10).
- **The soak** (`integration_test/soak_test.dart`, `tools/soak/run.sh
  [minutes]`): `PanelApp.open(panel, video:, maxConnections: 1,
  overrides: [...castOverrides, ...downloadShellOverrides, …])`, then
  what `bootstrap()` does after launch (the download folder registered,
  the queue started, the cast's toasts). `tick()` is a quarter second of
  the app plus the minute's row; `until(done, limit)` and `hold(time)`
  wait through it, so a round's waits are sampled too. `castRound()`,
  `downloadAndWalk()`, `pictureDrawn()`, `trouble(what)`.
  `IPTV_SOAK_ROUND_MINUTES=3` with `IPTV_SOAK_MINUTES=8` is the
  rehearsal (two rounds; memory not judged under 26 minutes). On the
  display run it under `gnome-session-inhibit --inhibit idle`.
  `build/soak/soak.csv` has a row a minute, `summary.txt` the line.
- **Probes kept as tools** (`integration_test/manual/`, run by hand, not
  by CI): `picture_probe.dart` (`PROBE_LATE`, `PROBE_SIZE`: is the
  picture drawn), `picture_probe_app.dart` (`PROBE=stop|leave|cast`: is
  it drawn again, and what the player is told as it opens),
  `real_reminder.dart`.
- **The Guide's page** (`_page` in `guide_grid.dart`): `_pageTarget` is
  where a glide is going, so a second page starts from there; cleared
  when the glide ends or something else scrolls.

Earlier this session (the player, the windows, step 7's rest):
- **The player's OSD:** `lib/design/components/osd_controls.dart`
  (`OsdButton`, `OsdVolume`, `OsdControlRow` — which decides when Audio and
  Subtitles carry words — `OsdCenterPlay`, `OsdScale`), `tokens.player`
  (`AppPlayerTokens`: sizes, `scaleFor(window)`), `AppSlider(overVideo:)`.
  `lib/features/playback/presentation/player_overlays.dart` (`OsdShade`,
  `OsdBack`, `OsdTop`, `OsdBottom(leading:, trailing:)`), `vod_osd.dart`,
  `player_screen.dart` (`_controls`, `_channelControls`, `_volume`, the
  menus), `player_sound.dart` (`playerSoundControllerProvider`; the level
  is kept in `UiPreferences.playerSound`, key `player.sound`).
  `PlayerSurface(onPictureTap:, onPictureDoubleTap:)` hears the picture's
  clicks under whatever is laid over it. `PlayerEngine.setSpeed`.
- **Window sizes:** `tokens.layout` (`AppLayoutTokens`: `pageMeasure`,
  Home's card widths and `across` / `cardWidth`, Live TV's panes),
  `PageMeasure` (`lib/design/components/page_measure.dart`),
  `live_tv_screen.dart`'s `_panes`, `tokens.details.seriesColumnFor`,
  `guideChannelColumnWidth(context)`.
- **Offline:** `appOfflineProvider` (`lib/core/platform/
  network_status.dart`); the shell's `_OfflineBar`; `guideStaleLine(…,
  offline:)`.
- **Tab:** `lib/design/focus/focus_pane.dart` (`_leave`, `_remembered`,
  `_onFocusChanged`'s redirect while Tab is held).
- **Cast:** `pickLocalAddress` in `lib/data/cast/cast_transport.dart`;
  `CastSubtitleRefused` (a notice).
- **The audit:** `test/audit/states_audit_test.dart` (scenes with no
  picture), `AUDIT_SHOTS`, `sceneTest(large:)`, twelve looks.
- **Tests' support:** `test/features/playback/support/vod_player_rig.dart`
  (`VodPlayerRig`: a movie or an episode in the player), `WALK_TEXT=130`
  in `integration_test/support/panel_app.dart`,
  `integration_test/manual/` (by-hand runs, not CI's).
- **Measurements:** `integration_test/channel_list_scroll_test.dart`
  (new), beside `guide_scroll_test`, `poster_grid_scroll_test`,
  `search_typing_test` (all `flutter drive --profile` on the real
  display).

From the session before (Phase 9 steps 6–7):
- **Reminders on screen:** `lib/features/reminders/presentation/` —
  `reminder_actions.dart` (`toggleReminder`, `removeReminder`,
  `reminderFor`, `showReminderInGuide`, `reminderChannel`; all take the
  app's `ProviderContainer`), `reminders_dialog.dart`
  (`showRemindersDialog`; `reminderChannelItemProvider` for a row's logo),
  `reminder_watch.dart` (`reminderWatchesProvider`, `watchReminder`),
  `reminder_text.dart` (every sentence and label).
- **Where a reminder is set:** `search_overlay.dart` (`_RemindMe`,
  `_remind`, `_remindHint`, the footer's `remind`), `guide_grid.dart`
  (`_remind` on R, `_noteReminders`, the `reminders` set a row's strip
  gets, `_MadeCell.reminded`), `guide_programme_sheet.dart`,
  `guide_screen.dart` (`_RemindersButton`), `guide_settings.dart` (the
  row).
- **Icons the canvas doesn't draw** go in `tools/extract_icons.dart`'s
  `_handDrawn` and in `assets/icons/` (`bell`, `bell-filled`).
- **The audit:** `test/audit/audit_look.dart` (`AuditLook`, `auditLooks`,
  `currentAuditLook`), `test/audit/audit_harness.dart` (`auditRun`,
  `auditReport`, `auditScreen`, `AuditScene`, `auditSettle`),
  `test/golden/golden_harness.dart` (`sceneTest`, `golden`, `tapShown`).
  `pumpApp` and `appearanceOverrides` read `currentAuditLook`. A scene's
  `allow` is a map of a piece of a finding's text to why it is no fault.
- **The text-size helpers the screens use:** `context.scaled`,
  `scaledAround`; `guideRowHeight(context)`, `searchRowHeight(context)`,
  `cardCaptionHeight(context)`; `SkeletonColumn`.
- **Test fakes:** `FakeReminders` has `setFailure` and `watchFailure`;
  `test/features/reminders/reminder_screens_test.dart` is the model for a
  widget test that drives a toast's action, the desktop's notice
  (`FakeNotifier.answer`) and a cast (`CastUi`) in one file.
- **`integration_test/reminder_walk_test.dart`:** the app's clock is a
  closure the test moves (`appClockProvider`), the desktop is a recording
  `SystemNotifier`, the window a recording `WindowControls`; after
  `PanelApp.restart()` it starts the reminders as `bootstrap()` does.


From the session before (Phase 9 steps 1–5):
- **The look:** `lib/design/appearance.dart` (`AppearanceSettings` →
  `resolve(SystemAppearance)` → `Appearance`), `lib/design/text_scale.dart`
  (`context.scaled`, `scaledAround`, `textScale`, `AppTextScale`),
  `AppDensity.row()`, `tokens.timeStyle`. `IptvPlayerApp` builds the
  theme from `appearanceProvider`. The store and providers are in
  `lib/features/settings/{domain,data}/` (`appearanceStoreProvider` is
  given by `bootstrap()`, already read; `desktopAppearanceProvider`,
  `appearanceControllerProvider`, `timeStyleProvider` for text made away
  from a screen).
- **Settings pages** are in `lib/features/settings/presentation/`:
  `appearance_section.dart`, `shortcuts_section.dart`, `data_section.dart`
  (+ `data_text.dart`), `about_section.dart`, `licenses_dialog.dart`,
  `setting_row.dart` (`SettingRow`: the control goes under the words
  when they don't fit side by side). `SettingsSection` has no "phase"
  any more: every section is built.
- **Shortcuts:** `lib/app/shortcut_table.dart` (the one list),
  `lib/app/shell/shortcut_list.dart` (`ShortcutList`,
  `showShortcutsPanel`), F1 in `lib/app/shortcuts.dart`.
- **`ScrollPane`** (`lib/design/components/scroll_pane.dart`): one Tab
  stop, keyboard scrolling, `reverse` for a list drawn from the bottom.
  **`AppDialog`** has `focusSecondary` and keeps 24 px from the window's
  edges. **`SegmentedControl`** wraps, and an option can have a `swatch`.
- **Export and import:** the file and its reader in
  `lib/features/settings/domain/settings_export.dart`; the port, the plan
  and the summaries in `settings_transfer.dart`; `DbSettingsTransfer`
  (`data/`), whose `exportedName` keeps a server or a username out of a
  source's name. Fixtures: `test_fixtures/settings/`. docs/02 has the
  format.
- **Pictures:** `ArtworkStore` (`lib/core/images/artwork_store.dart`),
  `ArtworkCache.size()` / `clear()`.
- **Diagnostics:** `lib/features/diagnostics/` — `domain/
  diagnostics_report.dart` (`buildDiagnosticsReport`, `withoutAddresses`),
  `data/db_diagnostics.dart` (gathers the facts), `data/
  file_log_reader.dart` (`readLogPage`, `readLogSince`), `domain/
  log_lines.dart`, `presentation/report_view.dart` and `log_view.dart`.
  `DecoderNotes` (`lib/core/player/decoder_notes.dart`) is written by the
  playback coordinator at the first frame. `SystemFactsReader`
  (`lib/core/platform/system_facts.dart`; Linux and Windows readers in
  `lib/data/platform/`). `PlayerVersion` is a capability only the real
  engine has. `FfmpegEncoderDetector.remembered(folder)` reads the last
  detection without running one.
- **Hardware decoding:** `PlaybackSettings.hardwareDecoding` →
  `PlayRequest.hardwareDecoding` → `mpvOptionsFor(request, picture:)`;
  `MediaKitPlayerEngine.create(hardwareDecoding:)` for the stored choice
  at launch; `mpvProperty()` for tests.
- **Reminders:** `lib/features/reminders/` — `domain/reminder.dart`
  (`Reminder`, `ReminderDraft`, `ReminderRepository`, `ReminderGuide`,
  `followReminder`), `domain/reminder_scheduler.dart`
  (`ReminderScheduler`, `ReminderFollower`), `data/
  db_reminder_repository.dart` (also `DbReminderGuide`,
  `DbReminderTransfer`), `data/reminder_providers.dart`
  (`ReminderService`), `presentation/reminder_alerts.dart` and
  `reminder_text.dart`. The table is `lib/data/db/reminder_tables.dart`,
  the DAO `remindersDao`.
- **Notifications and the window:** `SystemNotifier`
  (`lib/core/platform/system_notifier.dart`, provider
  `systemNotificationsProvider`), `DbusNotifier` and `WindowsNotifier`
  (`lib/data/platform/`); `WindowControls.isFocused()` /
  `bringToFront(activationToken:)`; the runner's channel
  `iptv_player/window` in `linux/runner/my_application.cc`.
- **`EpgImporter.wentLive`** is a stream of the sources whose guide was
  just swapped in.
- **Settings controllers have `reload()`** (playback, guide, cast,
  downloads); Appearance's is `retry()`.
- **Test fakes and harness:** `pumpApp(withAppearance:, settle:)`;
  `test/features/settings/appearance_fakes.dart` (`appearanceOverrides`,
  `ScriptedAppearanceStore`), `data_fakes.dart` (`FakeArtworkStore`,
  `FakeTransfer`, `sketchPlan`); `test/features/diagnostics/
  diagnostics_fakes.dart` (`FakeDiagnostics`, `FakeLogReader`, `logRow`,
  `FakeFileReveal`, `diagnosticsOverrides`); `test/features/reminders/
  reminder_fakes.dart` (`FakeReminders`, `FakeReminderGuide`,
  `FakeNotifier`); `FakeWindow` has `focused` and `raised`;
  `FakeEpgRepository.cleared`; `pumpDesign(textScale:)`; the playback
  `Rig(decoders:)`. A fake notification service on a private bus:
  `test/data/platform/dbus_notifier_test.dart`.

From the session before (Phase 8 step 7, parts 2b–4: subtitles, the MP4,
the matrix rows, the walk):
- **A cast's place has two numbers now.** `_Cast.from` is the place asked
  for (a resume, a seek); `_Cast.offset` is where the TV's time 0 is in
  the file: 0 whenever the TV reads a file by itself, and for a relayed
  file on this computer the key frame `CastSubtitles.startOf` found.
  `_reload` restarts at `from`, never at `offset` (asking FFmpeg for a key
  frame's own time lands on the key frame before it).
- **`_tvReads(cast)`, not `plan.delivery.direct`,** says "the TV fetches
  it itself and seeks in it": it is also true on the MP4 (`cast.onMp4`),
  while the cast's plan stays the relay's.
- **Subtitles are made once, moved many times.** `CastSubtitleSet.files(by:)`
  rewrites cue times in Dart; `by` is 0 when the TV reads the file itself.
  The set's `subtitles` can grow (a file's own tracks come after the
  files beside it); `tracksLoaded` on the cast is how many the last LOAD
  named, and a choice past it means a new LOAD (`_loadAgainHere`).
- **A subtitle's id is its place in the list, from 1,** in the state, in
  the LOAD and in `setSubtitle`; `cast.textTrack` is what the user wants,
  `cast.shownTrack` what the TV was last told. The TV's own status isn't
  read for it.
- **Everything the cast writes is under `<relayFolder>/<pid>/`**
  (`subtitles-<n>`, `mp4-<n>`, the relay's sessions): the relay deletes
  the lot at quit and `sweepRelayFolders` after a crash. The relay never
  clears that folder while the app runs.
- **`castRelayJob(...).outputArgs`** is the one place that says which
  streams a plan sends and how; the MP4 uses it, so it can't drift from
  the relay.
- **FFmpeg's `-frames:v 1 -frames:a 1` in one output prints only one
  stream's packet**; two outputs (`pipe:1`, `pipe:2`) print both, which is
  how `startOf` reads the picture's and the sound's first packets. An
  unmapped picture changes where FFmpeg seeks (it seeks by the sound
  then), so the picture is always mapped.
- **A `dart run` victim can't import the cast's makers** (the plan's
  types bring Flutter in): what it must run lives in
  `cast_file_jobs.dart`, plain Dart, which the makers use too.
- **`integration_test/library_scan_test.dart` is the model for a test
  that uses the real scanner:** override `folderPickerProvider` with the
  folder, and call `libraryScansProvider.startUp()` after the app is
  pumped, as `bootstrap()` does. Files under 20 MB are not videos to the
  scanner: use the samples.
- **Test fakes:** `FakeSubtitles` (`ready`, `late` + `last.finish()`,
  `keyFrameBefore`, each set's `moves`) and `FakeMp4Copies`
  (`last.whole()` / `failed()`) in `cast_fakes.dart`; `FakeTv.onTextTrack`
  and its `textTrack:<id>` calls; `FakeResolver.downloadSubtitles`;
  `PanelResolver.beside`; `CastE2E.subtitleLanguages`, `relaying`,
  `mp4Ready`. `FakeRelay.serveFile` names the URL by the file's extension.
- **Widget tests of the casting view with subtitles:** set
  `ui.cast.subtitles.ready` and a download's path before `cast(...)`.

From the session before (the download fixes, MP4, Phase 8 step 7 part 1):
- **A library folder's `is_available` is only as fresh as the last scan.**
  Screens dim by it; nothing that opens a file may trust it
  (`DbStreamResolver._file` goes by the disk). The download folder isn't
  made until its first download: `LibraryScan._folder` leaves it alone
  while it has no items.
- **A provider's episode title is read like a file's name:**
  `providerEpisodeTitle` gives '' for `S01E01`, `The.Show.S02E12.1080p…`
  and "Episode 4"; the library shows "Episode N" for an empty title
  (`libraryEpisodeTitle`, `libraryItemNames`).
- **The download's finish, in order** (`FileDownloadFinisher.finish`):
  size, ffprobe, the MP4 copy to `<name>.mp4.part`, the copy checked, the
  download's `.part` deleted, the rename, the poster, the library row.
  `whole(task)` reads the disk for a finish that was cut: no `.part` and
  one of the file, `<name>.mp4.part`, `<name>.mp4`. The queue finishes
  those at launch without connecting.
- **`mp4Obstacle` works on `LibraryMedia`** (the library's ffprobe
  reader, `readLibraryProbe`), whose `container` is the first word of
  ffprobe's `format_name` (`matroska`, `mov`, `mpegts`, `avi`, `flv`).
  Dolby Vision is found in ffprobe's raw text ("DOVI configuration
  record"): `LibraryMedia` doesn't carry it.
- **Tests of the download step:** `download_remux_test.dart` makes clips
  with lavfi and uses shell scripts as a misbehaving FFmpeg;
  `download_data_test.dart`'s `_Remux` is the fake; the queue's
  `ScriptedFinisher.working` holds a finish open; `DownloadE2E` runs the
  real remux (movie 100002 made a real Matroska by the test).
- **A file on this computer in a cast:** `CastItemStream.upstream.file` is
  its path; `info.sourceId` is `file:<path>` (what a refusal teaches) and
  `key` is the path (its facts). The coordinator never calls `_room` or
  `_countCast` for it. A direct play's URL is `cast.served`, closed by
  `_stopRelay`.
- **`FakeRelay.serveFile`** logs `file` and lists `files`;
  `canServeFiles = false` makes it fail. `PanelResolver.files` (the cast
  e2e rig) maps a movie's key or a library item's quick hash to a path.
- **The fake TV and a file with a length** (`FakeWatch._watchFile`): any
  `video/mp4` answer with `Content-Range`, or `Content-Length` and
  `Accept-Ranges`, is played in real time. A test that only wants "it
  plays" should wait for `tv.playerState == 'PLAYING'` and a check, not
  for FINISHED: a 10-minute sample now takes 10 minutes to end.
- **The fake TV's text tracks are fetched beside the media, not before
  it:** a test waits for `tv.textTracks.length` (or a track's id) rather
  than reading it at PLAYING. They are cleared at every LOAD.
- **`library_actions.dart` imports the casting presentation**
  (`cast_actions.dart`): widget tests that choose Cast need the cast's
  providers; the menu test only covers the drive-away case, and the
  cast itself is tested on the coordinator and end to end.

From the session before (Phase 8 step 6, parts 9–11):
- **Search's library group:** `DbSearchRepository._library` is one
  statement over `library_fts` — `by_show` (the rows whose show's name
  matches), `found` (each match, an episode found by its show standing for
  the show's key), `hit` (one row per show or item, ranked, six read) —
  then the shows by key (`LibraryDao.showsKeyed`) and the folders for
  their labels. `LibraryDao.showKeySql('i.')` is the show key with a table
  alias: `library_fts` has `title` and `show_title` columns too, so a join
  with it must qualify them.
- **What Enter does from anywhere:** `libraryMovieLocation`,
  `libraryShowLocation` and `playLibraryItem` in `library_actions.dart`
  take the `ProviderContainer` (search's overlay is gone by then, the
  Library screen passes its own).
- **`showLibraryItemMenu(beforePlay:, onChanged:, onGone:)`:** a caller
  that isn't a library page says what follows a Play, an edit, a leave.
- **The Downloaded mark:** `downloadedKeysProvider(type, sourceId)` (one
  watched set per source) and `isDownloaded(ref, type, sourceId, key)` in
  `download_actions.dart`; `DownloadedMark` / `DownloadedPill` in
  `lib/design/components/downloaded_mark.dart`; `PosterMarks` in
  `title_cards.dart`. `MovieCard` is a `ConsumerWidget` now. Tests mark a
  movie downloaded with `VodFakes.downloadMovie(key, title)`.
- **Home's cards take their keys from `_cardKeys(card, favorite:,
  download:)`:** F and D in one place; a card with nothing to download
  passes no request.
- **In the search overlay the keyboard stays in the field:** a plain
  letter can't be a shortcut there. Ctrl+D is handled in `_onKey`, beside
  the arrows.
- **The walk** (`integration_test/library_walk_test.dart`): `PanelApp`
  with `downloadShellOverrides`, `systemVideosProvider` pointed into a
  temp folder (the download folder is its `IPTV Player`), FFmpeg from
  `castBinaries()`; after the app is pumped it does what `bootstrap()`
  does after launch (`registerDownloadFolder`, `downloadToastsProvider`,
  `downloadQueueProvider.startUp()`). A Downloads row's label carries its
  progress ("<title>, 6%"): find it by what it starts with. The tabs'
  labels carry their counts ("Downloads, 1", "Movies, 2").
- **Windows trap, again:** a test that expects a path the app shows or
  hands on must build it with `p.join` / `p.joinAll` — also the `~` form
  (`p.join('~', 'Videos', 'IPTV Player')`).

From the session before (Phase 8 step 6, parts 3–8):
- **Where the Library's UI is:** `lib/features/library/presentation/` —
  `library_screen.dart` (the tabs; `_items` and `_shows` are the grids),
  `library_movie_page.dart`, `library_show_page.dart`,
  `library_actions.dart` (`showLibraryItemMenu`, `confirmDeleteFile`),
  `library_edit_dialog.dart` (`showEditDetails`, `libraryEditFrom`),
  `library_text.dart` (every sentence), `library_state.dart` (`LibraryTab`
  has `downloads`; `libraryShowMarks` is null until the marks are read).
  `lib/features/downloads/presentation/` — `downloads_panel.dart` (the
  tab), `download_text.dart` (words, `downloadSectionOf`,
  `downloadSections`), `download_actions.dart` (`titleDownloadProvider`,
  `startDownloads`, `downloadPressed`, `downloadButtonFace`,
  `pickDownloadFolder`, `downloadToastsProvider`,
  `downloadShellOverrides`), `download_settings_section.dart`.
- **The details pages share pieces** (`title_details_screen.dart`):
  `DetailsFrame`, `DetailsBackdrop`, `DetailsPoster`, `DetailsMetaLine`
  (`more:` for a file's quality), `DetailsTimeLeft`, `DetailsSeasonTabs`
  (owns ←/→; `trailing:` for Download season), `DetailsEpisodeList` (←
  goes to the page's main action). `nextUpAmong` is the Continue rule over
  any list of episodes.
- **The shell takes ← in a screen as "back to the nav rail"**
  (`_ContentPane` in `desktop_shell.dart`) unless the screen binds it. A
  row of controls that should move with ←/→ must bind both itself.
- **Riverpod pauses a provider nothing watches:** one that only
  `ref.listen`s would miss events after a `container.read`. Subscribe to
  the stream itself (`downloadToasts` and `downloadNoticeStreamProvider`,
  a `Raw<Stream>`), or keep a `container.listen`.
- **A provider may be overridden once per container:** `VodFakes` holds
  the fake download queue (`vod.queue`), `LibraryUi` adds the rest; a test
  needing another answer changes the fake (`queue.failure`), it doesn't
  override again.
- **`AppTextField` keeps the controller it was first built with:** give
  each field a key when a dialog's fields change places.
- **Toasts take turns** (`ToastHostController`): a test that expects a
  second toast pumps `AppToast.defaultDuration` once; a longer jump lets
  both come and go.
- **A menu item runs after the menu has faded out** — after
  `showAppMenu`'s future completes. Pass a callback for what follows
  (`showLibraryItemMenu(onGone:)`); don't await the menu for it.
- **A lazy `ListView` builds only what shows:** Settings' sections are
  long; a widget test makes the window taller (`openLibrary(size:)`).
- **Widget tests of these screens:**
  `test/features/library/presentation/library_ui_support.dart` —
  `openLibrary(tester, location:, before:, overrides:, watcher:, size:,
  now:)` gives `LibraryUi` (a real `DbLibraryRepository` on a memory
  database over `VodFakes`; `add()` writes a file's row, `leftAt()` its
  mark; scripted scans; `queue` the fake downloads; `revealed`, `picked`,
  `disk`, `downloadFolders`). `test/features/downloads/support/
  fake_downloads.dart` has `FakeDownloads` and `download(...)`.
  `emptyLibraryOverrides` (`test/app/app_harness.dart`) is for shell tests
  that pass through the Library with no database.
- **Goldens:** `test/golden/library_golden_test.dart` (Movies at both
  sizes, Series, Videos, Downloads, Folders, the first run, a movie, a
  show, Settings → Downloads & library). Look at every image re-recorded.
- **CI:** integration files run under `timeout 600` each and print their
  time; the job's limit is 75 minutes. To reproduce CI's integration step
  here: generate CI's samples into the scratchpad (`FFMPEG=/usr/bin/ffmpeg
  LIVE_SECONDS=30 VOD_SECONDS=120 OUT_DIR=… tools/media_samples/generate.sh
  …`), move `tools/media_samples/out` aside, link the scratchpad folder in
  its place, run with `IPTV_PLAYER_VIDEO=0`, **leave the real-provider
  files out** (the login file exists on this laptop), and put the samples
  back (7 more tests skip while CI's are in).
- **Don't edit `lib/` while integration tests run in the background:**
  each file builds the app from the working tree and fails on a half-made
  change.

From two sessions before (Phase 8 step 6, parts 1–2):
- **The Library's data:** `LibraryRepository.watchCount/range/watchShows/
  watchShowEpisodes/watchFolderTotals` (`DbLibraryRepository`; the DAO's
  `itemWindow`, `watchTotals`, `watchShows`, `watchShowEpisodes` share one
  filter, `_whereSql`/`_items`). A show's key: `l:<title lower case>` for
  the user's own, `p:<source>:<series key>` for downloads (`_showKey`).
- **Pictures on disk:** pass `localArtworkUrl(path)` to `artworkFor`; both
  `ArtworkImages` implementations answer `file:` URLs with a `FileImage`.
- **Presentation may not import `dart:io` or `lib/data/`** (the layering
  test): the home folder comes from `homeFolderProvider`, the folder dialog
  from `folderPickerProvider` (file_selector).
- **`libraryVodRef(item)`** is where any library item's place is kept;
  `PlayableLibraryItem.vodRef` uses it (a download → its title's ref).
- **Trap:** a public widget named like an imported type shadows it in that
  file without a warning (`DetailsLoading` broke a pattern match).

From earlier this session (Phase 8 step 5, part 2):
- **Show in folder:** `fileRevealProvider` (`lib/core/platform/file_reveal.dart`,
  default `NoFileReveal`; `bootstrap()` gives it `platformFileReveal(log)`
  from `lib/data/platform/file_reveals.dart`). Linux calls
  `org.freedesktop.FileManager1` (`ShowItems` / `ShowFolders`, file URIs),
  then `xdg-open`; Windows `explorer.exe /select,<path>`. Tests stand a fake
  file manager on an in-process `DBusServer` (`file_reveals_test.dart`).
- **The failure card's file actions:** `PlayerSurface` watches
  `failedFileProvider(item)` (`lib/features/playback/presentation/failed_file.dart`)
  when the problem is `fileUnreadable`; `beforeShowInFolder` (the player
  leaves full screen) and `onFileRemoved` (the player leaves) come from
  `PlayerScreen`. `LibraryRepository.item(id)` / `downloadOf(type, source,
  key)` give the item with its `path`.
- **Offline:** `networkStatusProvider` / `systemNetworkProvider`
  (`lib/core/platform/network_status.dart`; the system's from
  `lib/data/platform/system_networks.dart` via `bootstrap()`), fed by
  `playbackReachabilityProvider` (read in `bootstrap()`; `sourceAnswered`
  is the rule) and read by `homeOfflineProvider` (Home's banner, step 6).
  `PlaybackCoordinator.local` says whether what plays is a file.
- **Presentation may not import `lib/data/`** (`test/app/layering_test.dart`):
  a provider screens need goes in `lib/core/` (with a default `bootstrap()`
  overrides) or in a feature's `data/*_providers.dart`.
- **Widget tests that write library rows:** write them in `_Vod.open`'s
  `before:` (after the seed, before the app is pumped). A write from
  `runAsync` once a page watches drift waits for good (the first draft hung
  for minutes); a library row with a provider link needs its source row
  first (`provider_source_id` is a foreign key).
- **`integration_test/library_playback_test.dart`** copies the MP4 sample
  into a temporary download folder and a library folder and writes their
  rows itself; Esc from the player goes back to the page it was opened from
  (the Library only when there is nothing to go back to).

From earlier this session (Phase 8 steps 1–5):
- **Where things are:** `lib/core/library/` (`LibraryItem`, `LibraryFolder`,
  `LibraryMedia`, `LibraryRepository`), `lib/core/downloads/` (`DownloadTask`,
  `DownloadRequest`, `DownloadService`, `DownloadSettings`, `download_paths.dart`,
  `download_runner.dart` — the runner's interface and sendable messages);
  `lib/data/downloads/` (`HttpDownload`, `HlsDownload`, `download_isolate.dart`,
  `IsolateDownloadRunner`, `DbDownloadStore`, `FileDownloadFinisher`);
  `lib/data/library/` (`name_parser.dart`, `library_scan.dart`,
  `library_probe.dart`, `library_thumbnails.dart`, `system_trash.dart`,
  `quick_hash.dart`, `download_folder.dart`); `lib/features/downloads/`
  (`DownloadQueue` in domain, `download_ports.dart`, `CatalogueDownloadTitles`,
  providers); `lib/features/library/data/` (`DbLibraryRepository`,
  `LibraryScans`, `LibraryFavorites`, providers). `bootstrap()` registers the
  download folder, starts the queue, then the scans, after the first frame;
  the quit tasks shut the queue down.
- **Downloads give way** through `SourceConnections.giveWay`: `room()` asks
  the download holder to let go before it waits. The queue comes back 10 s
  after other holders leave a source. **Don't await a `StreamSubscription
  .cancel()` in code tests drive with fake time** — its future is the root
  zone's and the rest escapes fake time (the first queue tests hung on it).
- **The downloads isolate's code is plain Dart** (the SIGKILL victim runs
  under `dart run`): never import Flutter there; `stream_facts.dart` and
  anything importing it (the finisher's probe) bring Flutter in, so the
  victim uses a stand-in finisher.
- **The library's shown columns hold the user's edit** (`title`, `kind`, …);
  `user_edits_json` says what was set; a rescan writes only the rest. Remove
  from library is a settings list (`library.removed`), read by the scanner.
- **A file on this computer:** `ResolvedStream.local`; the coordinator skips
  the connection rules, holds none, and fails at once as `fileUnreadable`.
  `PlayableLibraryItem` (sourceId '', `LocalRef(quickHash)`); local history
  and favorites have their own DAO methods (no source: `source_id IS NULL`,
  one row each by the `*_local` indexes). Since step 7 part 1 the cast uses
  a download's file too (`CastItems._resolve`).
- **Tests and tools:** `test/features/downloads/support/download_e2e_rig.dart`
  (`DownloadE2E`: the fake panel, the isolate, ffprobe, a database);
  `download_kill_test.dart` (the `dart run` victim); `library_tree.sh <dir>
  <count>` (+ `.manifest.tsv`; tests lower the 20 MB minimum); the benchmarks
  `test/tools/download_measure_test.dart` and
  `test/tools/library_scan_measure_test.dart` (`--tags benchmark
  --run-skipped`). **A measurement must not count the test's own work**: the
  scan's "35 ms" pause was the test reading 5,000 rows on its isolate.
- **For step 6:** mapping 5,000 library rows on the UI isolate takes about
  30 ms — the Library's grids need windowed queries like the Movies grid's.
  Local pictures (thumbnails, posters on disk) need a file image path through
  the design system (`artworkFor` takes URLs). The canvas has Library,
  Library · Downloads and Settings · Downloads and library; read it with the
  Artifact tool first. `NextEpisode.stillUrl` is null for local files for now.
- **Traps met:** `Result.guard` used to wrap a thrown `AppFailure` as
  "unexpected" (fixed in `AppFailure.fromError`); a guarded job's result is a
  `Result` inside a `Result`; Dart's `RandomAccessFile.flush()` is an `fsync`
  (why downloads sync every 64 MB); `xdg_directories.getUserDirectory` runs a
  process synchronously (read `user-dirs.dirs` instead).

From the session before (Phase 7 step 8, before the TV):
- **`test/tools/cast_matrix_tv_test.dart`** (`real_cast`): `_rows()` holds
  the matrix (number, name, what to watch, `asks` for a row that needs the
  user, `fakeDevice` for the fake run); `_Matrix` is the stack (built like
  `CastE2E`, plus the panel on the TV-facing address, real encoder
  detection, `_ReadingEngine` — a player that really reads the stream, so
  the one-connection row means something). `castChannel`, `castFile`,
  `zap`, `seekTo`, `playingAgain`, `hold`, `remote`, `relayPid`. Each row
  starts with a clean device profile and panel query; failures are
  recorded and the run goes on. `CAST_HOST=fake` is its self-check.
- **Waiting on the cast in such a runner:** "Playing on" is logged once a
  play (not after a re-LOAD: wait for "loading it again"); a wait's message
  must be read when it gives up (`what: () => …`), or it shows the state
  from when it began; set `HttpOverrides.global = null` in any test that
  makes real HTTP requests.

From the session before (Phase 7 step 7):
- **The casting screens import only `casting_providers.dart`,
  `lib/core/cast/` and domain types** (hard rule 6). What the screens read:
  `castingStateProvider`, `castTimelineProvider`,
  `castingViewOpenProvider` (open / close), `knownCastDevicesProvider`,
  `castDevicesProvider` (discovery runs while the picker shows it).
- **What a Cast does is in `cast_actions.dart`:** `castFrom(context, item:,
  from:)` (a session on and an item: the TV at once; else the picker),
  `castTo(container, device, …)` (connect = the hand-over, then the item
  if it isn't what moved; the view opens when something plays),
  `playOnTv(container, item)`.
- **The shell's slots** (`lib/app/shell/shell_state.dart`) are overridden
  by `castShellOverrides`: the session for the bar, the top bar's button,
  and `shellContentOverlayProvider` (any widget over the content pane —
  the casting view). The shell keeps the screen under an overlay off stage
  (`Offstage` + `ExcludeFocus` + `TickerMode(false)`) and gives the focus
  back to the content pane when the overlay goes.
- **Every sentence is in `cast_text.dart`** (and the plan's in
  `cast_plan_text.dart`); the toasts' in `cast_shell_slots.dart`.
- **Widget tests:** `test/features/casting/support/cast_ui_harness.dart`
  — `CastUi` (Live TV's fakes + a `CastRig` sharing its playback rig,
  devices, readiness, network, `FakeAddressCheck`, all overrides including
  `castShellOverrides`); `settleCast(tester, rounds:)`; `focusedLabelOf`.
  **A test that starts a session must end it while it still pumps**
  (`castTest` wrappers stop the cast and the playback in `finally`): a
  session left on keeps timers going and teardown waits for good. Run the
  coordinator's calls unawaited in the test's zone, never in `runAsync`.
  `CastPicker._shown` counts open pickers (static state: a test's leak
  would block the next test's picker — keep it a counter).
- **Integration:** `PanelApp.open(…, overrides:)`; `PanelApp` quits a cast
  as `bootstrap()` does; `WALK_LOG=1` prints a walk's app log;
  `support/cast_tv.dart` — `castBinaries()` (bundled, else
  `RELAY_FFMPEG_DIR`, else `/usr/bin`), `castOverrides(binaries, folder)`
  (no network browsers: a walk must never find a real TV),
  `runningProcesses(folder)`. **`Keys.focusIsOn` is true when the focus is
  on an ancestor of the target** — the casting view's own focus node
  holds every control — so Tab until `focusedLabel()` names the control.
- **Relay rules (fixed this session):** the continuous stream's quiet
  timer and the proxy's idle timer run only while their reader reads
  (cancelled in `onPause`, re-armed in `onResume`); a continuous session's
  `dropStream()` ends the TV's connection before its FFmpeg is stopped
  (teardown, renew, a second request). Keep both for any new stream path.
- **The fake receiver buffers like a TV** (`FakePlayback.bufferAhead` 30 s
  / `bufferRefill` 10 s; null reads as fast as it comes) for fragmented
  MP4 only; HLS and plain files are read as before. `FakeWatchListener`
  gained `played`. A test waiting for a new LOAD must allow
  `tv.loaded == null` (between FINISHED and the LOAD).
- **Traps met this session:** a static on a widget class leaks between
  tests; `ExcludeFocus` drops the focus inside it; `find.byTooltip` misses
  `AppTooltip` (use `findByLabel`); an `AppSlider` in a row needs
  `compact` or its bubble row overflows; a Flutter import reaching
  `cast_relay.dart` breaks `relay_kill_test`'s plain-Dart victim (hence
  `cast_relay_ports.dart`); closing a subscription in `dispose` after a
  stop that notifies it ("modify a provider during build"): cancel first;
  a socket's `close()` and `addStream` wait for an unread peer — destroy
  it when the end needn't be clean.

From the session before (Phase 7 step 6):
- **The cast coordinator** (`lib/features/casting/domain/cast_coordinator.dart`)
  is domain code: it talks to `CastReceivers`, `CastRelay`,
  `StreamFactsLookup`, `CastEncoderDetection`, `CastDeviceStore`,
  `CastItems` and the `PlaybackCoordinator`; `classifyStreamFailure` comes
  in as a function (`StreamFailureClassifier`), since domain code never
  imports `lib/data/`.
- **Each play is a private `_Cast`;** every new attempt at it (a re-LOAD, a
  new plan, a seek, a codec switch, the next encoder) calls `_restart`,
  which bumps its `generation` and forgets the loaded URL; every await in
  `_deliver`/`_load`/… checks `_fresh(cast, generation)`, and a relay
  session started for a stale attempt is stopped. Keep that shape for any
  new recovery path.
- **The TV's statuses count only for the media this cast loaded:** its
  media session id (from the LOAD's answer), else its URL (`contentId`).
  PLAYING cancels the 10 s reach rule as a fetch does.
- **Relay failures are handled from the `CastRelayFailed` event only**
  (`ready` completes with the same failure; acting on both would do it
  twice). A session the coordinator stops completes `ready` with
  "stopped", which identity checks (`_current`) ignore.
- **The playback coordinator while casting:** `_remote` set by
  `castStarted`; `stop()` is a no-op (screens call it when left);
  `castShows(item)` keeps `PlaybackCasting` in step with the cast;
  `castEnded()` → idle. Its `connections` (`SourceConnections`) is shared:
  the player sets its holder on open/stop and waits for room before
  opening; the cast sets its own from `castRelay.connections` plus the TV's
  direct play.
- **Tests on fakes:** `test/features/casting/support/cast_fakes.dart` —
  `CastRig` (a cast coordinator beside the playback `Rig`), `FakeTv`
  (`media`, `playing`, `idle`, `onLoad` returning null for the default),
  `FakeReceivers` (`launching` holds a join after its connection is up),
  `FakeRelay`/`FakeRelaySession` (`log` of input/start/stop/renew, `fail`,
  `emit`), `FakeProbe`, `FakeEncoderDetection`, `MemoryCastDevices`,
  `FakeSleep`, `fastTimings`, facts fixtures (`h264Facts`, `hevc4kFacts`,
  `mkvFacts`, `mp4Facts`). `FakeResolver` gained `hls` and
  `customUserAgent`.
- **End to end:** `test/features/casting/support/cast_e2e_rig.dart` —
  `CastE2E.start(device:, maxConnections:, giveUp:)` (the fake panel, the
  relay in its isolate, ffprobe, our Cast client, the coordinators on a
  `FakePlayerEngine`, x264-only encoders, the artwork cache for pictures),
  `PanelResolver` (`query` for faults, `hls`, `remap` to serve a channel
  from another — the panel's own codec switch restarts with every
  connection), `tvPlaying(after:, checks:)` (**a continuous stream gets one
  check**, HLS one per segment), `plans` (every plan, from the stream),
  `running`/`sessionFolders`, `panelChannel(id, logoUrl:)`; logos are
  `<panel>/art/live/<file>`. Files aren't paced like live channels: a movie
  plays within a second. `RELAY_LOG=1` prints the cast's log.
- **The codec switch** is the fake panel's `codec_switch_after_s` fault on
  any channel; the sample named `codec_switch_h264_720p_to_1080p` changes
  resolution only, which the program watch doesn't report.
- **Sleep inhibition tests** stand a fake portal and a fake logind on an
  in-process `DBusServer` (descriptor passing works). On the real session
  `gnome-session-inhibit --list` shows a hold.
- **Quitting:** `AppWindow.beforeClose` (set in `bootstrap()` to `_quit`)
  runs on the window's close; `_quit` only touches providers that exist
  (`container.exists`).

From the session before (Phase 7 step 5):
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
- ADR-018/019 (2026-10-14): the name Bijou and its jewel until the user says otherwise; "Server login / Playlist link / Playlist file"; identifiers that name saved things keep `iptv`; the TV's bar on the film's time (not only its length); the length written only from the stream's own facts; the from-0 fallback decided at the first report past a second, for streams that began 10 s in or more; `mfra` dropped rather than rewritten.
- Phase 9 steps 1–5 (ADR-016): text size held to 100–130 %, and heights that hold text scaled through `context.scaled` (the argument untouched at 100 %, so the goldens stay as they were); Live TV's category rows at 40 px in Compact; the clock's style a required argument of every formatter; the shortcuts as one table with docs/05 written from it; hardware decoding as Automatic (`auto-safe`) or Off (`no`), no list of decoders; the report and the log as two views; a source in an export known by a SHA-256 of type, server and username, never by the server, and named "Xtream source N" when its name says the server or the username; an import as one transaction, a guide-days change taking hold at the next refresh; the report's masking (`<address>`, `<server>`, `Source N`, `~`) before `redact()`; a reminder taken out of the store before it is shown (never twice, at the price of one lost if the app dies in that moment); a reminder following its programme by title and guide channel within 12 hours, a move of 5 minutes or more said; a system notification only while the window is covered; no default action on GNOME Shell's notices (measured on 42.9: it raises the window itself and sends no token); flutter_local_notifications pinned at 22.3.1.
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
- The Google TV version: the user asked when to start. Recommended:
  TV-0 (the player spike) right after Phase 9, before Phase 10's
  installers. It needs the Android SDK, JDK 17 and `adb` installed, and
  the TV in Developer mode on the laptop's network: has the user done
  those?
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- Bijou and its jewel (ADR-018): kept, or another name? And the Google
  TV app's `applicationId` (it can drop "iptv" from the start: nothing is
  saved under it yet).
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
- Windows installer type (MSIX or Inno Setup) is Phase 10's to recommend,
  but the user decides.
