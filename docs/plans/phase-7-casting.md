# Phase 7 — Casting: plan

**Status: approved 2026-09-29, every recommendation and the five sketches (the user: "do the recommended").** What is built and every departure from this plan go into ADR-014 (docs/decisions.md) as the steps land.

## Context
Phases 1–6 built everything that plays on the laptop. Casting is the largest and riskiest phase left. Phase 0 proved each piece on your TV (ADR-004), but none of it is in the app yet.

Exit criteria (docs/08):
- The casting matrix (docs/04) passes on the devices you own.
- No FFmpeg process is left behind after the app is killed with SIGKILL and started again.

Already in place, so the phase starts further along than docs/08 suggests:
- **The spike's working code** (`spike/cast_spike`), proven on "Living Room TV":
  - a Cast v2 client with tolerant parsing and the heartbeat;
  - discovery with multicast_dns;
  - a shelf relay with FFmpeg and PID files;
  - the generated protobuf code.
  - It is spike code, without tests. The phase moves it into the app with tests, not as is.
- **Packages already in pubspec:** bonsoir, protobuf, shelf, shelf_router, ffi, win32.
- **FFmpeg 8.1.2** in `third_party/ffmpeg/linux-x64/` (ffmpeg and ffprobe). It is not copied into the app's build yet.
- **Design pieces from Phase 1:**
  - `CastingBar`, `QualityBadge` (Original / Converted audio / Transcoded, with the reason in a tooltip) and `ReconnectingPill`;
  - the cast icons;
  - the shell's casting-bar slot (`shellCastSessionProvider`, empty until now);
  - the top bar's Cast button, disabled with "Casting comes in Phase 7";
  - Settings' Casting section, marked "Phase 7".
- **Playback:**
  - `PlaybackCoordinator` already owns what plays and each source's connections (docs/03 says it owns the cast relay too);
  - `StreamResolver` rebuilds a stream's URL from its source every time;
  - `HttpStreamProber` classifies a provider's refusal (auth, offline, connection limit, server error);
  - `WatchProgress` saves where a movie was left.
- **Test material:**
  - every sample in docs/06's matrix, in `tools/media_samples/out`;
  - the fake panel's live faults (drop, stall, cut, slow start, statuses, connection limit, expiring redirect, codec switch) and its VOD files with Range.

What Phase 7 does **not** own:
- **Casting library files** and downloaded movies, subtitles on the TV, and seeking inside the part the relay has ready (Phase 8, docs/04 "Local files and downloads").
- **The Google TV app** (the TV is the player there, docs/07).
- **Speakers and other audio-only devices:** they are not listed (docs/04, the `ca` bit).
- **More than one cast at a time.**
- **Packaging FFmpeg into installers** (Phase 10). This phase only copies it into the Linux build, so a built app can cast.

Carried in, not to be relitigated without new evidence:
- **ADR-004:**
  - H.264 goes to the TV as HLS with TS segments, and HEVC as one continuous fragmented MP4, because open-GOP HEVC stutters in HLS fMP4 segments;
  - no segment-format fields in LOAD;
  - BUFFERING in the TV's status is not a stall;
  - a continuous stream that ends means a new LOAD;
  - 4K needs your TV's Input Signal Plus, so a bare LOAD_FAILED on a 4K stream may only mean the HDMI link is 1080p.
- **ADR-006:** multicast_dns works next to Avahi on this laptop.
- **ADR-007:** video is copied, never re-encoded, whenever the TV can play it.
- **ADR-010:** the relay must own its sockets, or a TV that leaves goes unnoticed.
- **Hard rules 3, 7 and 8:**
  - no credentials in logs;
  - one stream per source unless `max_connections` allows more;
  - every FFmpeg process has an owner, a watchdog, a PID file, and cleanup on exit and at the next launch.
- **Your standing rules:**
  - ask before every cast to the Living Room TV;
  - ask before any stream from your real provider.

Working rhythm, as before: one numbered step at a time, as docs/08 asks for this phase. After each: analyze, format, `TZ=UTC flutter test`, a local commit without trailers, and a stop for your review.

**When the TV is used,** each time asked for first, with you watching:
- step 2: the client's first LAUNCH and LOAD of a sample;
- step 6: one cast through the app, end to end;
- step 8: the matrix.

Everything else runs against a fake receiver (decision 8). Every cast in this phase plays the fake panel's samples, never your provider. The only exception would be one cast at the very end, if you want it, with its own pop-up.

## Decisions (my recommendation first in each)

1. **Movies and episodes cast in this phase too, not only channels.**
   - **Recommendation:**
     - **A file the TV can play as it is** (MP4, M4V or MOV; video the TV supports; AAC or MP3 audio) goes to the TV directly. The TV reads it with Range requests and seeks natively, as Phase 0 proved with a sample on your TV.
     - **Anything else** goes through the relay as one continuous stream, like HEVC live. Your panel's movies are MKV, so they go this way.
     - **Seeking a relayed file** starts the relay again at the new point, with a new LOAD. The app keeps the timeline and the saved position continuous, and "Preparing…" shows for the few seconds it takes (docs/05 already describes this).
     - **Resume works both ways:** a movie started on the laptop continues on the TV from the same point, and where the TV stopped is saved like local playback.
     - Phase 8 adds library files, subtitles, and seeks inside the ready part without a restart.
   - **Rejected alternative: channels only, movies in Phase 8.** The Cast button on the details pages would wait another phase, and the only extra work here is a seek that restarts the relay.

2. **While casting, everything you play goes to the TV.**
   - **Recommendation** (the Chromecast model most apps use):
     - Once a cast session is on, Enter on a channel, Watch, Play or Resume on a details page, a Home tile and a search result all play on the TV.
     - The casting view takes the full-screen player's place (the canvas's CastingView).
     - The Live TV preview opens no stream of its own. It shows what is on the TV, and moving through the list changes nothing until Enter.
     - Channel ↑/↓ in the casting view zaps the TV (docs/04).
     - **Cast (or C) while watching on the laptop moves what is playing to the TV.** A movie keeps its position.
     - **Stop casting** ends the session. Nothing starts playing on the laptop by itself.
   - **Rejected alternative: casting only what plays when you press Cast, while later plays go to the laptop.** On a one-connection source, the next play would take the connection away from the TV.

3. **FFmpeg and ffprobe read the provider through a small proxy inside the relay, not from the provider's URL.**
   - **Recommendation:** FFmpeg opens `http://127.0.0.1:<port>/in/<token>`. The relay's proxy opens the provider:
     - **No credentials in a process's command line or in FFmpeg's error lines.** Any local user can read a process's arguments (`/proc/<pid>/cmdline`).
     - **Every reconnect rebuilds the URL from the source,** with its User-Agent, as local playback does (ADR-009). An expiring redirect token is fetched fresh.
     - **The app sees exactly when the provider connection opens and closes.** The one-connection policy needs that, and so will Phase 8's downloads (ADR-010's lesson). The proxy also reads the provider's answer (401, 404, 5xx, a full account), so a failure gets the same words as on the laptop.
     - **A killed app takes FFmpeg's input with it,** so a leftover FFmpeg ends by itself within seconds. The launch sweep still runs.
     - For an HLS source, the proxy rewrites the playlist so its segments come through the proxy too.
   - **Cost:** the stream passes through a Dart isolate once more. Step 5 measures it.
   - **Rejected alternative: FFmpeg reads the provider URL itself (the spike's way).** The credentials would sit in its arguments, and the app could not see the connection.

4. **Where the relay's plan gets its facts** (codecs, resolution, interlacing, audio).
   - **Recommendation, in this order:**
     1. The laptop's player, when the channel or movie was playing here. It already knows, and asking costs no connection.
     2. A probe remembered from earlier in this run of the app. Zapping back and forth while casting costs nothing.
     3. ffprobe through the proxy, with an 8 s timeout.
   - FFmpeg reports the streams it actually opened. If they differ from the plan, the relay plans again (a new FFmpeg and a new LOAD).
   - **Rejected alternative: ffprobe before every cast** (docs/04 as written). It costs 1–3 s per cast. On a one-connection panel it also opens a connection just before the relay's own, and panels can be slow to free one (ADR-010).

5. **The relay runs in its own long-lived isolate.** That includes its HTTP server, the proxy, the FFmpeg processes and the supervisor.
   - **Recommendation:** start it with the first cast and keep it until the app quits. A 4K stream is tens of megabits a second through the proxy and through the continuous-stream path (hard rule 2). Step 5 measures the UI isolate while casting 4K HEVC.
   - **Rejected alternative: the UI isolate (the spike's way).** Simpler, but every chunk of video would pass through the UI's event loop.

6. **Discovery: bonsoir and multicast_dns side by side, merged by device id, plus Add by IP address.**
   - **Recommendation:**
     - bonsoir uses the system's own resolver (Avahi here, DNS-SD on Windows).
     - multicast_dns is proven on this laptop next to Avahi (ADR-006).
     - Either may fail quietly (logged) while the other finds the TV. There is no Windows PC here to try either on, and two independent ways make it likelier that one works there.
     - Step 1 measures each on this laptop, with Avahi running and stopped.
   - **Rejected alternatives:**
     - **bonsoir with multicast_dns only on error.** A resolver that runs but finds nothing (Avahi stopped) raises no error.
     - **multicast_dns alone.** On Windows it shares UDP port 5353 with the system's own responder, which nobody has tried.

7. **Keeping the laptop awake while casting.**
   - **Recommendation:**
     - **Linux:** the desktop portal's Inhibit (GNOME and KDE honour it), with logind's inhibitor as the fallback. Both go over D-Bus with the `dbus` package: pure Dart, a new dependency, checked ADR-002 style in step 6.
     - **Windows:** `SetThreadExecutionState` through win32, already a dependency.
     - Phase 8's downloads reuse the same inhibitor.
   - **Rejected alternative: a `systemd-inhibit` child process.** It is one more process to supervise, and a logind sleep lock is the blunter tool: it can refuse a suspend you ask for yourself.

8. **A fake receiver that plays what it is told to play.**
   - **Recommendation:** `tools/fake_receiver`, a package like the fake panel:
     - **Cast v2 over TLS** with a test-only certificate. It supports CONNECT, LAUNCH (optionally 3–6 s slow, like your TV), LOAD, the media commands, status and the heartbeat.
     - **Device profiles:**
       - a 4K HEVC TV;
       - a 1080p H.264-only Chromecast;
       - a 4K TV on a 1080p HDMI link, which refuses anything above 1080p with a bare LOAD_FAILED, like yours without Input Signal Plus.
     - **Faults:**
       - LOAD_FAILED on a codec;
       - the heartbeat stopping;
       - the socket dropping;
       - another app taking the TV;
       - the TV's remote pausing or stopping.
     - **It fetches the stream like a TV:**
       - It polls the HLS playlist and reads each segment, or reads the continuous body.
       - It checks with ffprobe that video and audio are really there.
       - It reports PLAYING, IDLE/FINISHED or IDLE/ERROR from what it actually got.
     - Tests add it by address (`127.0.0.1:<port>`). It never advertises itself on your network.
   - That makes almost all of the casting matrix runnable without the TV, and in CI's Linux job with its samples. The TV walk in step 8 then confirms rather than discovers.
   - **Rejected alternative: a protocol-only fake** (docs/06's minimum). It would pass while the relay sent nothing a TV could play.

## Step 1 — Discovery and known devices
- **Domain** (`lib/core/cast/`, as docs/01 lays out): `CastDevice` (id, name, model, host, port, capability bits, what the TV says it is doing, manual or found), `CastDiscovery`, `CastDeviceStore`.
- **Discovery** (`lib/data/cast/`), decision 6:
  - bonsoir and multicast_dns browse `_googlecast._tcp`, merged by the TXT `id`;
  - TXT `fn` (name), `md` (model), `ca` (devices without bit 0, video out, are left out), `rs` (what it is playing, for the canvas's "Busy · playing music");
  - a device is gone after it misses two rounds;
  - a manual address (host, or host:port for tests) is checked with a CONNECT and GET_STATUS (nothing shows on a TV), then kept.
- **Schema v8:** `cast_devices` as docs/02 lists it (device id, name, model, last host, manual, HEVC setting, what was learned, last used). The migration comes with its test.
- **FFmpeg in the build:** the Linux build copies `third_party/ffmpeg/linux-x64/{ffmpeg,ffprobe}` into its bundle; `FfmpegBinaries` finds them there or in `third_party/` during development. Missing binaries are a clear state ("This build can't cast: FFmpeg is missing"), never a crash. The Windows build does the same from `windows-x64` when it is present.
- **Verify:**
  - parsing tests with recorded TXT records, including odd ones (no `fn`, a bad `ca`, duplicates on two interfaces);
  - the merge and expiry rules with fake browsers;
  - the store on a real database;
  - **on this laptop (listening only, nothing shown on the TV):** both ways find Living Room TV and leave out the Nest Mini. Time to first sight is recorded with Avahi running and stopped.

## Step 2 — The Cast v2 client and the fake receiver
- **`CastChannel`:**
  - TLS to host:8009, accepting the device's self-signed certificate;
  - 4-byte length + protobuf `CastMessage` framing (the generated code is committed, as docs/04 says);
  - request ids with timeouts;
  - PING every 5 s, PONG answered, 3 missed → the channel is lost;
  - tolerant parsing: unknown namespaces and types, a `status` that is a string, messages after CLOSE, a frame split across reads, an oversized frame refused.
- **`ReceiverChannel`** (LAUNCH, GET_STATUS, STOP, SET_VOLUME) and **`MediaChannel`** (LOAD, PLAY, PAUSE, SEEK, STOP, GET_STATUS, MEDIA_STATUS parsing).
- **Reconnecting:** after a Wi-Fi blip, the client reconnects and joins the receiver app it left, by its transport id. The media session keeps playing on the TV meanwhile.
- **`tools/fake_receiver`** (decision 8): the protocol side now; fetching and ffprobe checks come in step 5.
- **Verify:**
  - the client against the fake receiver: connect, launch (and reuse a running app), load, status, every command, errors (LOAD_FAILED, INVALID_MEDIA_SESSION_ID), heartbeat loss, a socket drop and the rejoin;
  - framing fuzz tests;
  - **with your go-ahead, on the TV:** one LAUNCH and LOAD of the MP4 sample, served from the laptop with Range, then STOP. The TV returns to its home screen.

## Step 3 — The probe and the planner
- **`StreamProbe`** (bundled ffprobe through the proxy, 8 s timeout, supervised like every process) and the probe sources of decision 4.
- **`CastPlanner`**, pure: (probe, device profile, what was learned, settings) → `CastPlan`:
  - direct, relay-copy or relay-transcode;
  - HLS/TS or continuous fMP4;
  - copy the audio, or convert it to AAC;
  - which audio track;
  - the stream type (live, or a file);
  - the badge and its reason ("Your TV said no to HEVC, so the video is re-encoded to H.264").
  - It follows docs/04's rules, with decision 1's file rule.
- **Device profiles:** seeded from `md` only where it is unambiguous (docs/04's table), overridable per device.
- **Verify:** exhaustive planner tests — every docs/04 rule, every sample's probe, every device profile, each learned limit and setting, and probes with missing fields (no audio, unknown codec, no frame rate). These are unit tests, so they run in CI.

## Step 4 — Hardware encoder detection
- **A one-second test encode per candidate,** in docs/04's order:
  - Linux: NVENC → VA-API → QSV;
  - Windows: NVENC → QSV → AMF;
  - libx264 as the last resort, for 1080p and below only.
- A test decode of the matching hardware decoder, so transcoding HEVC 4K doesn't decode it on the CPU.
- The result is cached per FFmpeg version, and detected again after a transcode fails.
- **Transcode arguments** for each encoder: scaling down to the device's largest picture, deinterlacing, and bitrate 1.3 × the source with at least 6 Mbps at 1080p.
- **Verify:**
  - the argument builder in unit tests;
  - **on this laptop:** NVENC and VA-API both detected. The CPU cost of HEVC 4K → H.264 1080p and MPEG-2 576i → H.264 is measured with each and recorded.

## Step 5 — The relay, its proxy and its supervisor
- **The relay isolate** (decision 5): started on the first cast, spoken to with messages (start a session, stop, seek, events).
- **`RelayServer`:**
  - bound to the laptop's address on the TV's network — the local address of the Cast connection's own socket, which is the route the system uses to reach the TV;
  - a port in 38400–38499;
  - a random 128-bit token per session;
  - docs/04's routes, CORS headers, MIME types and `no-cache`;
  - everything else gets a 404.
  - **The continuous stream owns its socket** (ADR-010): a TV that leaves stops its FFmpeg.
- **The proxy** (decision 3): the provider connection, rebuilt through `StreamResolver` on every connect, counted against the source's connections, its refusals classified.
- **`FfmpegRelay`:**
  - docs/04's arguments for each plan;
  - stderr read at warning level, through `redact()`;
  - the streams FFmpeg opened, reported back (decision 4).
- **`SupervisedProcess`,** shared by ffprobe and FFmpeg (hard rule 8):
  - a PID file under the relay's folder, a timeout or watchdog, SIGTERM then SIGKILL after 3 s (TerminateProcess on Windows);
  - **the launch sweep** kills a leftover only if its command line shows it is our FFmpeg, since a process id can be reused. Then it deletes stale session folders.
- **`RelaySupervisor`:**
  - HLS: the newest segment older than max(3 × segment length, 10 s) → FFmpeg restarts from the source, keeping the token, so the TV keeps polling;
  - continuous: FFmpeg ends or goes quiet for 10 s → the coordinator loads again;
  - 5 restarts within 2 minutes → the session fails with Details.
- **The fake receiver learns to fetch and check** (decision 8).
- **Verify:**
  - every live fault of the fake panel, relayed to the fake receiver: drop, stall, cut, slow start, 401/404/500, the connection limit, the expiring redirect, the codec switch. Each recovers, or fails with the right words;
  - the proxy's connection accounting on a one-connection source;
  - **exit criterion 2, as a test:** a separate process runs a relay and is killed with SIGKILL. Its FFmpeg ends by itself, and the next launch's sweep leaves no process, PID file or folder (the pattern of `sync_kill_test`);
  - **measured:** the UI isolate's longest pause while casting HEVC 4K through the relay; the relay's CPU for H.264 1080p50 copy.

## Step 6 — The cast coordinator
- **`CastCoordinator`** (`lib/features/casting/domain/`, beside the playback coordinator; the data side in `lib/data/cast/`):
  - **The session:**
    - connect, then reuse the receiver app if it is running, else LAUNCH;
    - LAUNCH runs while the relay prepares its first segments, so the TV's 3–6 s overlaps the relay's;
    - LOAD once the playlist lists 2 segments (tuned in step 8), or at once for a continuous stream;
    - the metadata: name, programme, and the picture served from the app's own cache through the relay.
  - **The direct fast path** (docs/04 rule 1) and the direct file (decision 1). An error within 10 s falls back to the relay and is remembered per source and device.
  - **Learning** (docs/04): a failure within 15 s of a copy → above 1080p: remember 1080p and transcode, with the TV-setting hint; otherwise remember the codec and transcode.
  - **Live continuous streams:** FINISHED means a drop → a new FFmpeg, a new token, a new LOAD, counted against the budget (ADR-004).
  - **Files:** position = the TV's time + the relay's start point; seeks restart the relay (decision 1); progress saved like local playback; 95 % is watched.
  - **Following the TV:**
    - paused or stopped with its remote;
    - another app took it ("Living Room TV started something else");
    - it went quiet (the heartbeat) → reconnect, then end the session with a message.
  - **The TV never fetched the stream** within 10 s of LOAD → "Living Room TV couldn't reach this computer", with the firewall help (Linux's ufw, Windows' firewall, a VPN).
  - **Sleep inhibition** while a session plays (decision 7).
  - **Windows firewall:** before the first relay start on Windows, a dialog explains the prompt that follows. It can't be tried here.
  - **Quitting the app** stops the media on the TV and the relay.
- **The playback coordinator stays the single owner** (docs/03):
  - while a session is on, what it plays goes to the cast coordinator instead of the laptop's player (decision 2), so the screens' calls don't change;
  - its state says Casting;
  - the laptop's stream on the same source is closed before the relay opens its own;
  - the connection count covers local playback, the relay's proxy and the TV's direct connection, with room for Phase 8's downloads.
- **Verify:**
  - unit tests with fakes for every path above;
  - integration tests: the real relay against the fake panel and the fake receiver, for the docs/04 matrix except what needs eyes (fallbacks, learning, re-LOAD, zapping, files with seeks, a one-connection source while local playback runs);
  - **with your go-ahead:** one cast through the app to the TV — a channel of the fake panel, a zap, Stop.

## Step 7 — The casting UI
- **The Cast button:** enabled in the top bar; added to the player's OSD (after Stream info) and to the movie and episode pages; **C** from anywhere (docs/05's shortcut table). While casting, the button shows the connected icon and opens the picker with Stop casting.
- **The device picker** (canvas `CastPicker`):
  - the title with what will be cast;
  - "Looking for devices on your network…";
  - rows with icon, name, model line (what is known or learned: "Chromecast · 4K · HEVC") and status (Available, Busy · what it plays);
  - Add device by IP address (sketch E);
  - "Device not showing?" with Troubleshoot (same Wi-Fi, not a guest network, the firewall ports, VPNs).
  - States: searching, nothing found after 10 s (the help comes forward), not on a network, FFmpeg missing.
  - The list is one Tab stop with arrows inside. Enter casts, Esc closes.
- **The casting view** (canvas `CastingView`):
  - PLAYING ON LIVING ROOM TV, the logo, the number and name, the programme with its times and bar;
  - the quality badge with the plan's details line ("1080p · 50 fps · H.264 · AAC 2.0") and its sentence;
  - live: previous and next channel, volume, Stop casting (the canvas has no pause for live, and a paused live relay would run out of segments);
  - movies and episodes: play/pause, the seek bar, −10/+10 and "Preparing…" (sketch A);
  - its states: connecting, preparing, reconnecting (the pill), failed with Try again, Play here and Details (sketch D).
- **The casting bar** in the shell (the canvas's bottom bar): the title, "Casting to Living Room TV · Original quality", play/pause for files, Stop. Enter opens the casting view.
- **Live TV while casting** (sketch B), and **quiet fallbacks**: the badge changes, and a small toast says so ("Now converting the audio for Living Room TV").
- **Settings → Casting** (sketch C): known devices with HEVC (Automatic / Yes / No), the largest picture learned with Reset, Forget for manual ones; Dolby passthrough; Low-latency mode; Smooth interlaced; firewall help.
- **Keyboard:** everything above by keys alone, with the design system's focus. In the casting view: ↑/↓ change channel (live), Space and ←/→ for files, M mutes, Esc goes back while the cast carries on.
- **Verify:**
  - widget tests for every state of the picker, the view (live and file), the bar, Live TV while casting, and Settings → Casting;
  - goldens at 1280 × 800 and 1920 × 1080, checked against the canvas (read with the Artifact tool first);
  - **a keyboard walk on the real app** (fake panel, fake receiver by address): C → the picker → Enter → the casting view → ↓ zaps → Esc → the bar → Home → a movie → Play goes to the TV → seek → Stop casting.

## Step 8 — The casting matrix on your TV, and the phase exit
- **The matrix** (docs/04), with your go-ahead and you watching, on Living Room TV, from the fake panel's samples:
  - H.264 1080p50 TS + AAC;
  - H.264 1080p + AC-3;
  - H.264 1080i + MP2;
  - HEVC 2160p (open GOP, continuous fMP4) + E-AC-3;
  - HEVC 1080p with the TV set to "HEVC: No" (standing in for an H.264-only device);
  - 4K with Input Signal Plus turned off for the test (learning, then a 1080p transcode and the hint);
  - MPEG-2 576i;
  - a mid-stream codec change;
  - a provider drop every 60 s, on HLS and on the continuous stream;
  - a relay restart during a continuous stream (re-LOAD);
  - an 8 s slow start;
  - a one-connection source while the laptop plays it;
  - plus: a movie direct with seeks, a movie through the relay with seeks and resume, and the TV's own remote pausing and stopping.
- **Measured, with budgets proposed for docs/06:**
  - cast start to picture: ≤ 8 s when the receiver app isn't running, ≤ 5 s when it is;
  - zapping while casting: ≤ 6 s;
  - relay copy of H.264 1080p50: ≤ 5 % of one core;
  - the UI isolate while casting 4K: no pause over 32 ms.
  - Transcode CPU is recorded, not budgeted.
- **If you want it, with its own pop-up:** one channel cast from your provider.
- **Docs:** ADR-014 Accepted; docs/04 "As built"; docs/05's casting sections; docs/06 (the fake receiver, the budgets); docs/02's schema v8; progress and the handoff.

**Alongside, one small commit each:** whatever CI still names, and Phase 6's small loose ends if a step passes near them.

## Sketches for approval (not on the canvas)

**A. The casting view for a movie** (decision 1):
```
PLAYING ON LIVING ROOM TV
[poster]  Blue Water
          2024 · Drama
          0:42:10 ━━━━━━━━━━●──────────────────── 1:58:00
          [TRANSCODED]  1080p · 25 fps · H.264 · AAC 2.0
          Your TV said no to HEVC, so the video is re-encoded to H.264.
          [ ❚❚ ]  [ −10 ]  [ +10 ]    🔊 ━━━━━──    [ Stop casting ]
```
A seek past what is ready shows "Preparing…" over the bar for a few seconds.

**B. Live TV while casting** (decision 2): the preview pane, in place of a picture:
```
┌──────────────────────────────────────────┐
│  ⧉  Playing on Living Room TV            │
│  201 · Arena Sports 1                    │
│  Continental Cup · Semi-final · 8–10 PM  │
│  Enter on a channel plays it on the TV.  │
│  [ Open casting view ]  [ Stop casting ] │
└──────────────────────────────────────────┘
```

**C. Settings → Casting:**
```
Casting
DEVICES
 Living Room TV      Chromecast · 192.168.1.155                     [ ⋯ ]
   HEVC  [ Automatic ▾ ]    Largest picture: 4K (learned)   [ Reset ]
 Bedroom             added by address · 192.168.1.60           [ Forget ]
Dolby passthrough    [ Off ]  Send Dolby audio untouched, for a TV on an AV receiver.
Low-latency mode     [ Off ]  One continuous stream for every channel: less delay,
                              but a restart shows on the TV.
Smooth interlaced    [ Off ]  Re-encode interlaced channels with deinterlacing (uses CPU).
Your TV reaches this computer on ports 38400–38499.   [ Firewall help ]
```

**D. The casting view's states:**
```
Connecting to Living Room TV…                  (spinner)
Preparing the stream…                          (spinner)

Living Room TV couldn't reach this computer.
Check that a firewall lets it in on ports 38400–38499.
[ Try again ]  [ Play here ]  [ Details ]
```

**E. Add a device by address:**
```
Add a device by address
[ 192.168.1.60                 ]
Found "Bedroom" (Chromecast).        ← or: Nothing answered at 192.168.1.60.
                          [ Cancel ]  [ Add ]
```

## Verification (every step and at the exit)
The same set every step:
- `flutter analyze`;
- `dart format --set-exit-if-changed lib test integration_test tools`;
- `TZ=UTC flutter test` (unit, widget, golden);
- the fake panel's and the fake receiver's own suites;
- the integration tests the step touches, one file per run under `xvfb-run -a`.

What the tests must cover:
- The planner and the protocol get exhaustive unit tests, malformed messages included (hard rules 1 and 10).
- Every process the app starts is shown to end: on stop, on failure, on quit and after SIGKILL.
- Every screen state gets a widget test.
- Timings and CPU are measured, not assumed.
- Nothing the relay logs carries a credential: the hard-rule-3 test grows to cover the relay's log and FFmpeg's stderr.

## Risks
- **One real device.** Only Living Room TV answers on your network (the second Google TV doesn't). Other models may refuse things yours plays. Learning from failures and the per-device settings are the safety net.
- **Windows can't be tried here.** Discovery (bonsoir's Windows issue #156), the firewall prompt, keeping the PC awake, TerminateProcess and the relay itself wait for your Windows PC. CI builds and runs the unit tests on Windows, but it never casts.
- **A mid-stream codec change** (H.264 → HEVC) while FFmpeg copies: FFmpeg keeps copying the stream it opened, so the TV could be left without video. The fake receiver's ffprobe check catches it, and the relay plans again with a new LOAD.
- **Zapping while casting is slower than on the laptop:** the relay's first segments plus a LOAD. If it misses the budget: shorter segments, or keep the TV's playlist and restart FFmpeg behind it without a new LOAD.
- **A continuous stream's restart shows on the TV** (about 4 s of buffer, then FINISHED and a new LOAD; ADR-004). Only HEVC and low-latency mode use it, and HLS rides through.
- **The proxy's cost at 4K** (decisions 3 and 5). Step 5 measures it. If it is too high, FFmpeg reads the provider itself, with the credential exposure accepted and recorded.
- **Firewalls:** Ubuntu's ufw is off by default. If it is on, or a VPN is in the way, the TV can't fetch the stream. The app notices (no request within 10 s) and says why, rather than failing silently.
- **Size:** this is the largest phase (docs/08: 2–3 weeks). The steps are ordered so that each stands on tested ground: protocol, then planner, then relay, then orchestration, then UI, then the TV.
