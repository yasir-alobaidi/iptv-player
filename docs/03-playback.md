# 03 — Playback (desktop)

## Engine: media_kit (libmpv)
`MediaKitPlayerEngine implements PlayerEngine`. Set libmpv properties through media_kit's native player API. Use media_kit's hardware-accelerated video output.

On Linux the app depends on our patched media_kit_video (ADR-003). Every unpatched build hits media_kit #1404: no EGL context is current on the platform thread, so it falls back to S/W rendering with copy-back decoding and drops frames at 50 fps. The patch keeps rendering and decoding on the GPU (zero-copy `vaapi` on Intel, `nvdec` on NVIDIA).

### Base options
| Option | Value | Why |
|---|---|---|
| hwdec | `auto-safe`, or `no` when Settings → Playback → Hardware decoding is Off | GPU decoding (VA-API/NVDEC on Linux, D3D11VA on Windows) with safe fallback. Set before every open, so a change applies to the next thing played (ADR-016, step 2) |
| cache | `yes` | required for network streams |
| cache-on-disk | `no` | libmpv 0.34.1 otherwise logs `Failed to create file cache` on every open |
| network-timeout | `10` | fail fast; the watchdog retries |
| user-agent | source UA | many panels require it |
| stream-lavf-o | `reconnect=1,reconnect_streamed=1,reconnect_delay_max=5` | FFmpeg-level reconnect for short drops |
| demuxer-max-back-bytes | 16MiB live, 64MiB a file; 16MiB for both on a TV | bound memory |
| alang / slang | from settings | preferred audio/subtitle languages |

### Buffer presets (Settings → Playback)
| Preset | cache-secs | demuxer-max-bytes | demuxer-readahead-secs | lavf probesize | lavf analyzeduration (s) | For |
|---|---|---|---|---|---|---|
| Low latency | 2 | 32MiB | 2 | 500000 | 0.5 | sports, strong connection |
| **Balanced (default)** | 8 | 64MiB | 8 | 1000000 | 1 | most cases |
| Stable | 20 | 128MiB | 20 | 2000000 | 2 | weak Wi-Fi, unstable providers |

On a TV (Android) `demuxer-max-bytes` is at most 32MiB, whatever the preset, and 16MiB is kept behind, a film's too (ADR-031): the Chromecast with Google TV had about 200 MB free with a film playing. A seek further back than what is kept asks the server again.

**A file reads ahead as far as its bytes allow, whatever the preset** (`cache-secs` and `demuxer-readahead-secs` 3600, so the bytes above stop it; ADR-046, ADR-048): Balanced's 8 s put every 10 s jump just outside the buffer, and each went back to the provider (0.6–0.9 s on the user's panel: the range's answer and its first data). On a TV's 32 MiB a 1.3 Mb/s film holds about 150 s ahead, so a held key's jump of a minute or two plays again in ~0.1 s. A channel keeps the preset's seconds. When a file stops or another opens, mpv frees its buffer (the next one starts empty). The player logs each seek once its clock has moved on past the target (mpv says the target from the moment a seek starts): "Seek +10 s: playing again in N ms (S s was buffered ahead)".

**A TV's sound goes through AudioTrack** (`ao=audiotrack,opensles`; ADR-046): media_kit's OpenSL ES moves mpv's clock in coarse steps, and the frames mpv times by it came a refresh early or late (a 25 fps channel's ticker stuttered at 50 Hz); with AudioTrack every frame holds its refreshes exactly.

Android's direct output (`vo=mediacodec_embed`) sets `force-window=no` at every open (ADR-032): media_kit's `force-window=yes` kept the output alive with nothing to show, and its thread spun a core of the TV after every film. mpv drops the output when the video ends and makes it again for the next one (the `vo` option and `wid` stay set).

Every option and property name in this doc was verified against the system libmpv 0.34.1 (Ubuntu 22.04) in ADR-003. media_kit also sets `subs-fallback`, which 0.34.1 doesn't have; it logs one harmless error.

### Hardware decoding check
Show `hwdec-current` in the stream info overlay. Confirmed on Linux in Phase 0 (ADR-003): zero-copy hardware decoding for H.264, HEVC, and HEVC 4K on Intel (`vaapi`) and NVIDIA (`nvdec`), on native Wayland and Xorg, with the patched media_kit_video. Windows (D3D11VA) stays unverified until a real Windows PC is available; check it before release (Phase 10). `hwdec-current = no` while playing HEVC 4K is a blocker.
- `hwdec=auto-safe` doesn't GPU-decode MPEG-2. SD MPEG-2 costs about 1 % CPU, which is acceptable.
- Under XWayland (`GDK_BACKEND=x11` inside a Wayland session) VA-API falls back to `vaapi-copy` and drops frames at 50 fps. The app runs as a native Wayland client there; never force the X11 backend.
- NVIDIA isn't required: Intel meets every budget. Whether to offer "use discrete GPU" is a Phase 10 packaging question.

### Deinterlacing
Setting: Auto (default) / On / Off. libmpv 0.34.1's `deinterlace` is only yes/no, so Auto reads `video-frame-info/interlaced` (it reports `yes` for 1080i50 and 576i25) and sets `deinterlace` to match.

### As built (Phase 3 step 1)
`PlayerEngine` (`lib/core/player/`) is the seam; `MediaKitPlayerEngine` sets the base options once and `mpvOptionsFor(request)` before each open. First frame: `playback-time` set and `video-params/w` known (or no video track). A failure: mpv idle before the first frame. media_kit's `error` stream is built from log lines (decoder hiccups included), so it is only ever the failure's detail. Our own property calls pass `waitForInitialization: false`: media_kit otherwise waits for the video controller's first texture, which needs frames drawn. Headless (`vo=null`) needs `vid=auto` set by hand.

## Playback coordinator
- Single owner of what's playing where (local player, cast relay) and of each source's connections
- Enforces connection policy: with `max_connections = 1`, stop the current stream on that source and wait for it to close before opening another
- Downloads (docs/09) hold connections too, but playback and casting come first: when no connection is free, pause a download on that source and resume it afterwards
- Records history: live = last watched time; VOD = position every 10 s of playing, on pause, seek, stop and failure, and at the end (Phase 5)

## Watchdog (stability core)
As built (ADR-010 step 4): in `PlaybackCoordinator`. A failure is classified by one GET of the stream's URL after mpv lets go (status and the first bytes; on an Xtream refusal the account is read too), then closed at once. A full account (`connectionLimit`) is tried 3 times, not 6. A first frame resets the count. The fault suite (`integration_test/playback_faults_test.dart`) proves each class against the fake provider.

States: `idle → opening → playing ⇄ buffering → reconnecting → failed`
- **Open timeout:** no first frame within 12 s (Balanced preset) → reconnect
- **Stall:** playing but position/cache not advancing for 8 s, or buffering longer than 15 s → reconnect
- **EOF on a live stream** → reconnect (a "finished" live stream is a dropped connection)
- **Error classes:**
  - network → retry
  - HTTP 401/403 auth → stop; account message
  - HTTP 404 → channel offline; offer next channel
  - connection limit (429, panel-specific 403, or immediate close while another stream is active) → explain the limit
  - unsupported codec → stop; show details
- **Backoff:** 1, 2, 4, 8, 15, 30 s; after 6 failed attempts → failed state with Retry / Next channel / Details
- **UI:** small "Reconnecting…" pill during automatic retries; never a modal
- Rebuild the URL from the source on every reconnect (never reuse redirected URLs)
- A codec or resolution change restarts mpv's video output and resets `frame-drop-count`; a lower count isn't an error

## Channel zapping
- Up/Down, PageUp/PageDown: show the channel banner immediately; open the stream at once when the keys were at rest, else after they rest 350 ms, so a burst or a held key opens its first channel and then only its last (ADR-052; the wait was a third of a zap on the TV)
- Number entry: overlay; commits after 1.5 s or Enter
- Backspace: last channel
- Reuse one engine instance across channels
- Preload now/next EPG for neighbors in the current list
- Target: p50 ≤ 1.5 s on the fake provider (the Phase 0 spike measured p50 / p95 320 / 597 ms over loopback, ADR-003)
- **Measured (Phase 3 step 9, `integration_test/zap_benchmark_test.dart`):** on a one-connection source (the old stream closed before the new one opens), 50 zaps from the key press to the first frame including the 350 ms debounce: **p50 961 ms, p95 972 ms** on the Wayland desktop with `vaapi` (xvfb: 1205 / 1373 ms). On the user's real provider (one connection): the old stream closes in 43 ms and the next is accepted at once; its first frame took 1.1 s on one channel and ~4.7 s on another every time, cold or zapped — that stream's keyframe interval, not the zap.

## VOD & series
- Resume prompt when position > 60 s and < 95 % (Resume / Start over)
- Mark complete at ≥ 95 %
- Series: a "Next episode · N" card counting down in the last minute (Next episode / Hide); never on a film (ADR-033)
- Seek: ←/→ 10 s, Shift+←/→ 60 s, time bubble on the seek bar

### As built (Phase 5 step 6; ADR-012)
- **One coordinator for live and files.** Its states carry a sealed `Playable` (`PlayableChannel`, `PlayableMovie`, `PlayableEpisode`); `playVod(item, from:)` opens a file, and a resume is one open that starts there (`PlayRequest.start`, mpv's `start`), not an open and a seek. `seek`, `setPaused` and `timelines` (position, length, buffered ahead, paused) serve the player; a file's end is `PlaybackEnded`.
- **A file's watchdog:** the end is finished unless it came 10 s or more short of the player's own length, which is a drop: the file reconnects where it was, with its URL built again. A stall or a failure reconnects at the last position. Paused is never a stall. The first frame gets at least 30 s, so a resume on a panel that ignores Range can read its way to the position. **A resume's first frame is the one at its place** (mpv's `seeking` is no): the frame mpv decodes before the panel lets the resume's range in is not it, so neither the 8 s stall check nor the picture starts early (ADR-027). **A seek still waiting after 0.5 s is buffering** (15 s, the spinner over the picture), not a stall. **Reconnecting shows the item's own last picture, or none** until it has shown one: the surface may still hold the stream before it (ADR-027).
- **A resume after a pause starts the sound afresh with the picture (ADR-054):** a file (not a channel) that has played and stood paused a second or more is seeked exactly to where it stands, still paused (`seek <time-pos> absolute+exact`), then plays. mpv's audio clock can come back off after a pause (PulseAudio; it also sends a quiet output to sleep after 5 s), and the picture then follows a sound that is early or late until a seek: the user's own way out. Logged: "Resumed after N s: sound and picture start together from T s".
- **Progress** (`WatchProgress`): saved every 10 s of playing, on pause, after a seek, on leaving (a stop, another item), on a failure and at the end; nothing for a file that never showed a picture. Watched at 95 %. Continue watching lists what is between a minute and 95 %, and a series' next episode after a watched one.
- **The player stops a file** whenever it closes (Esc, a destination shortcut, the end); Live TV and the Guide stop only a channel.
- **Keys:** Space, ←/→ 10 s and Shift+←/→ 60 s (the bar moves on the key's press and the seek runs as it is let go, ADR-048; a key that never comes up seeks once the keys rest 300 ms; the OSD's −10/+10 seek at once), Home to the start, M/A/S/I/F as for live; the seek bar isn't a Tab stop. On a TV (ADR-030) ←/→ held seek in growing steps (10 s, then 30 s after about a second, a minute after about three), on the picture or on the seek bar, which is a stop above Play there; OK while a seek waits runs it now and plays. "Resumed from 24:10 · Home starts over" for 5 s; "Preparing…" while a file opens.
- **The next episode (ADR-033):** an episode with one after it has Next episode in the row. From 60 s left (an episode over 4 minutes) the card counts: "Next episode · N", N the seconds until it plays by itself (50 at a minute left), read off the episode's own time, so a pause holds it and a seek moves it; its bar drains out of 50; at 10 s left the next episode plays (where it was left). Next episode plays it at once; Hide. A shorter episode counts from 10 at 20 s left, a second at a time, the same labels (the user, on the Bedroom TV: "it should show the count down if u won't click anything then u will go to the next"). Hide, Esc or a remote's Back hide the card for the episode: nothing plays by itself, and the end card offers Play next episode / Back to series. Seeking back out of the last minute takes the card away; the last minute brings it back unless hidden. The card stands on its own, bottom right: it doesn't pin the OSD, which shows and hides around it without moving it (the end card pins it). **The focus:** on the desktop the picture keeps it, so ←/→ seek and Space pauses with the card up; Tab reaches its buttons, Enter/Space press. On a TV its first button takes it unless the remote is on one of the OSD's controls (scrubbing on the seek bar, say), and then gets it when the OSD hides; ←/→ move between its two buttons (they don't seek there), OK presses. The end card takes it on both. After Hide the picture has it. After the last episode, the series page. A film has neither the card nor the button.
- **Tracks are named by what is true (ADR-065, `track_text.dart`):** a track's language is the file's own tag, and a lone tag proves nothing (an encoder's default "eng"; Matroska reads an untagged track as English): the user's Turkish episode, one sound track tagged "eng", said "Audio: English". A language is named only when the tracks of a kind carry **two different languages** ("en" and "eng" are one; "und" and empty are none). Otherwise the Audio control says what the decoder measures, **"Audio: Stereo"** / "5.1" / "Mono" ("Audio" when not known), and Subtitles says the track's title or **"Subtitles: On"**; a menu's line is the language or the title or "Track 2", then the channels and the codec as people say them: "Track 1 · Stereo · AAC", "English · Commentary · 5.1 · AC3", "SRT", "PGS". No guess from the catalogue's category ("TR | مترجم") is shown as fact. The TV and the desktop share it (the same engine).
- **The OSD's menus** (Audio, Subtitles, Speed, Picture size) hold it up while open, since their keys never reach the player; closed, the focus is back on the control that opened it and the OSD's clock starts again.
- **The keyboard is the player's while it is on top:** a page under it that takes the focus gives it back (the series page's autofocus did, when the episode just watched changed what it would play next, and Esc then left the player).
- **Measured on the fake panel:** 532 ms to the first frame 30 s into the MP4 sample; mpv and FFmpeg ride through a connection dropped mid-file by themselves. The user's own panel: ADR-012 step 8.

## Local files and downloads
- Library items (docs/09) play as `PlayableSource` kind `file` with the VOD rules above and no provider connection
- No reconnects: a read error means the file is missing or damaged → failed state with Show in folder / Remove from library
- External subtitle files beside the video are added as subtitle tracks

## Stream info overlay (key I)
Resolution, fps, video codec/profile, hwdec-current, audio codec/channels/language, bitrate estimate, cache seconds, dropped frames, **A/V sync** (mpv's `avsync`, signed, to the millisecond; whether sound and picture stay together after Match frame rate's switch), redacted source URL. A frame rate shows to three places when it isn't whole (23.976 fps, never "24"). **On a TV, a Display row** (ADR-035 §2): the display's mode, `3840×2160 · 23.976 Hz`, and for a film at 23.976 or 24 fps whether it is at the film's rate (`· matched` / `· not matched`).

## Subtitles' size (ADR-038)
media_kit_video's `SubtitleView` draws them over the picture: 32 px for a 1920×1080 box, scaled by √(box area / 1920×1080), white on a translucent black box, bottom centre. **Settings → Playback → Subtitle size** (TV and desktop): **Small · Medium · Large**, Medium by default (JSON `subtitleSize`; anything else reads as Medium). A desktop's Medium is media_kit's own size; a TV's is 1.4× it (about 45 px of a 1080-line screen, where the TV's 1280×720 canvas left 32); Small is 0.8× and Large 1.3× of the platform's Medium (`AppPlayerTokens.subtitleScale`). Only the font's size changes; the place, colours and box stay media_kit's. **It applies at once to what is playing:** `PlayerSurface` passes the scale to `PlayerEngine.videoView`, and the media_kit engine hands one `SubtitleViewConfiguration` per scale (`subtitle_style.dart`) to the TV layer's `SubtitleView` and to every `Video`, which takes it at the next frame.

## Time on screen
**With the OSD up, the clock top right says when a file ends** (ADR-065): "Ends 10:42 PM" under it, the time what is left ends at the speed it plays (`osdEndsAt`; to the nearest minute), for a film, an episode or a library file whose length is known, not while it opens, in its last minute or at its end card; a channel says nothing more (its programme's times are on the bottom bar). Paused, the OSD stays up and the end moves later with the clock: the OSD's clock (`OsdClock`) turns with the minute on its own, since a paused picture rebuilds nothing. The end shown holds through the position's and the clock's small steps (half a minute) and moves at once for a seek or a speed.

While the full-screen player's OSD is hidden, **the clock stays top left** (ADR-053), where Back is when the OSD shows, in the middle of the top bar's row (`s32` in, `s24` down, a control tall): as large and heavy as the OSD's clock (22 px at 700, the primary text colour) and **without AM/PM** ("2:15"; `formatClockShort`, so a 24-hour clock stays "14:15"). The user's words, third time: first (ADR-047) the clock and "1 h 12 min left" on a shaded box at the OSD clock's place ("so big and annoying"), then (ADR-051) a small clock alone (14, then 17 px: hard to read; the OSD's "big and thick, and clear to see"). No box and no time left: a soft dark halo (`elevation.textOverPicture`) keeps it legible over a bright picture; the time left is on the controls, a key away. Not while a file opens or a channel has no picture yet, nor with the failure card, the channel panel or anything else that holds the OSD up (paused, a seek, a menu, the end card). It scales with the OSD (`OsdScale`), takes no clicks and no focus, and stays clear of the stream info and the number overlay. **Cheap on a TV:** the picture is on a layer of its own and Flutter draws nothing while the OSD is hidden, so the corner (`PlayerTimeCorner`, behind a `RepaintBoundary`) is drawn again only at the clock's next minute (a timer); gone, it keeps no timer and no text. **Settings → Playback → Time on screen** (TV and desktop): **Always** (default) or **With the controls** (nothing while the OSD is hidden); JSON `timeOnScreen`, `always` / `controls`, anything else reads as Always. It applies at once to what is playing.

## The desktop's picture quality (ADR-035 §3)
media_kit draws mpv into a texture and Flutter scales it to the screen (bilinear). **Settings → Playback → Picture quality** (desktop only): **High** (the default since ADR-055; JSON `picture`, anything but `standard` reads as High, the old `quality` key ignored) has mpv draw at the picture's size on screen (`VideoController.setSize` from the widget's box in physical pixels, whole-pixel bars, at most every 150 ms while the box changes) with mpv 0.34's `gpu-hq` options one by one (`scale`/`cscale=spline36`, `dscale=mitchell`, `dither-depth=auto`, `correct-downscaling`, `linear-downscaling`, `sigmoid-upscaling`, `deband`); **Standard** leaves the texture at the video's own size and puts back the running mpv's own values; an option an mpv doesn't have is left alone both ways (logged once). Applies to the next thing played. **High's safety net (ADR-055):** for its first 30 s of playing, in 5 s windows (one with a pause, a seek or buffering counts for nothing), a window in which mpv's output dropped more than 5 % of the frames, and at least five (`frame-drop-count`, `estimated-vf-fps`), steps that title down to Standard, logged ("High picture quality dropped N frames in 5 s: Standard for this title"); the next title tries High again. Measured on this laptop (Intel, VA-API, 1080p50 H.264 in a 1280×720 window): 2.36 % of all cores with Standard, 2.38 % with High, no dropped frames either way.
**Picture size on the desktop:** Fill and Stretch are the picture widget's fit (`cover` / `fill`) for Standard, as on a TV's direct output (mpv's `panscan` acts inside a texture that already has the video's shape, so they did nothing before); for High the texture takes the whole box and mpv crops or stretches into it.

## Match frame rate on a TV (ADR-035 §2, ADR-044)
**Channels (ADR-044), on by default:** a channel at 25 or 50 fps (nearly every channel outside the Americas) moves the display to its 50 Hz mode at the same size at its first frame, when the TV has one (the Living Room's Samsung does; the Bedroom's Hisense doesn't), with no pause and no wait: live plays on while the TV re-locks. The next channel at 25/50 keeps it, so the screen goes dark only as Live TV starts and ends, never between channels; a channel at another rate takes the TV's own mode back; Live TV closing lets it go after the 2 s grace. Settings → Playback (TV) "Match frame rate for channels". **Only the TV's own Never stops a switch** Bijou's settings ask for (Seamless only, Google TV's default, no longer does: ADR-044). Stream info's Display row says matched / not matched for a 25/50 fps channel too.

**Films** (below; "Match frame rate for films", Off by default since ADR-042):
A film (not a channel) of 15 minutes or more at 23.9–24.1 fps moves the display to a mode at the current resolution within 0.01 Hz of its rate (one at 25 or 50 fps, ±0.1, to the 50 Hz mode, as a channel, where the TV has one: ADR-049), **at the first frame, as part of the open**: "Preparing…" stays, the file is paused (not the user's pause), the window's `preferredDisplayModeId` is set (`bijou/display`, `DisplayModes.kt`), the change is awaited (5 s at most) plus ~1.5 s to settle, then it plays; neither the open's timeout nor the stall check runs meanwhile. With no length yet, the first frame waits up to a second for the player's. Nothing for 25/50 (no such mode on the Bedroom TV) or 29.97–60. **Back to the TV's own mode** 2 s after the player closes or a channel plays (a next episode at the same rate keeps it), and at once when the app leaves the screen. **On by default and following the TV's own Match content frame rate:** Always switches, Seamless only switches only seamlessly (never on the Bedroom TV, each mode its own group), Never never; Settings → Playback (TV only) turns it off for Bijou alone. Log lines (`[display]`): the switch asked (from → to, the film's fps, the TV's preference), landed or timed out, and the way back.
