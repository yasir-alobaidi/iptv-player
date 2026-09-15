# 04 — Casting (desktop → Chromecast / Google TV)

## How it works
The desktop app is a **Cast sender**. It tells the receiver to load a URL, and the receiver downloads the media itself. We use Google's **Default Media Receiver** (app id `CC1AD845`), which needs no registration.

Most IPTV URLs can't be played by the receiver directly: raw MPEG-TS, no CORS headers, Dolby audio, connection limits, required User-Agent, expiring redirect tokens. So the app runs a **local relay**: one connection to the provider, FFmpeg repackages the stream without touching the video, and a local HTTP server serves it to the receiver.

Phase 0 proved this end to end on a Chromecast with Google TV (4K) with our own Cast v2 client and the bundled FFmpeg (ADR-004). The receiver plays HLS with Shaka Player, the Web Receiver's default HLS player since SDK 3.0.0150.

## Components (lib/data/cast/)
| Component | Responsibility |
|---|---|
| CastDiscovery | bonsoir browse `_googlecast._tcp`; TXT `fn` (name), `md` (model), `id`, `ca` (capability bits: devices without bit 0, video out, are audio-only speakers and aren't listed); manual IP devices; dedupe by id. multicast_dns (proven in Phase 0) is the fallback if bonsoir fails |
| CastV2Client | TLS socket to host:8009 (device uses a self-signed cert), framing (4-byte big-endian length + protobuf `CastMessage`), namespaces, request ids, heartbeat; tolerant parsing (unknown namespaces and types, a `status` that isn't an object, messages arriving after CLOSE) |
| MediaChannel | LOAD, PLAY, PAUSE, STOP, SEEK, GET_STATUS; volume via receiver namespace; MEDIA_STATUS parsing |
| StreamProbe | bundled ffprobe on the source (UA, 8 s timeout): codecs, profile, level, resolution, fps, field order, audio tracks, bitrate |
| CastPlanner | pure function (probe, device profile, settings) → CastPlan (direct / relay-copy / relay-transcode, container, audio action) |
| RelayServer | shelf server bound to the LAN interface sharing the device's subnet; port 38400–38499; random session token in path; CORS; MIME; serves HLS sessions, continuous fragmented MP4 streams, and files with Range |
| FfmpegRelay | builds args from the plan, starts bundled ffmpeg, writes PID file, pipes stderr to logs (redacted) |
| RelaySupervisor | stall detection, restart from original URL, restart budget, cleanup |
| CastCoordinator | orchestration: plan, relay, LOAD, fallbacks, device learning, re-LOAD after a continuous stream ends, local-player suspension, sleep inhibition, session state |

## Cast v2 protocol essentials
- `CastMessage` protobuf (Chromium `cast_channel.proto`): protocol_version CASTV2_1_0, source_id `sender-0`, destination_id (`receiver-0` or the app transportId), namespace, payload_type STRING, payload_utf8 (JSON). Generate Dart code once and commit it (`spike/cast_spike/tool/gen_proto.sh` shows how).
- Namespaces:
  - `urn:x-cast:com.google.cast.tp.connection` → `CONNECT` / `CLOSE`
  - `urn:x-cast:com.google.cast.tp.heartbeat` → send `PING` every 5 s, answer `PING` with `PONG`; 3 missed → reconnect
  - `urn:x-cast:com.google.cast.receiver` → `LAUNCH {appId}`, `GET_STATUS`, `SET_VOLUME`, `STOP`; `RECEIVER_STATUS` gives the app's `transportId`. After LAUNCH the device also sends `LAUNCH_STATUS`, whose `status` is a string (`USER_ALLOWED`)
  - `urn:x-cast:com.google.cast.media` → `LOAD`, `PLAY`, `PAUSE`, `STOP`, `SEEK`, `GET_STATUS`; `MEDIA_STATUS` with `playerState` and `idleReason` (FINISHED, CANCELLED, INTERRUPTED, ERROR)
  - The device also sends `urn:x-cast:com.google.cast.multizone` (`MULTIZONE_STATUS`); ignore namespaces and types we don't use
- Sequence: TLS connect → CONNECT receiver-0 → GET_STATUS → LAUNCH CC1AD845 → RECEIVER_STATUS with app → CONNECT transportId → LOAD. LAUNCH took 3–6 s when the receiver app wasn't running; reuse a running app
- LOAD (fields verified against the Google Cast docs and on the device, ADR-004): top-level `media`, `autoplay: true`, `currentTime`; `media.contentId` (relay URL), `contentType` (`application/x-mpegurl` for HLS, `video/mp4` for continuous fMP4 and files), `streamType` (`LIVE` or `BUFFERED`), `metadata` (`metadataType` 0, title, subtitle, images). Don't send `hlsSegmentFormat` / `hlsVideoSegmentFormat`: the receiver ignores them (any value, or none, plays), and the planner never uses HLS with fMP4 segments
- Errors: a LOAD the receiver can't play is answered with a bare `LOAD_FAILED` (no reason) plus `MEDIA_STATUS` IDLE/ERROR; the media session is then gone (STOP → `INVALID_REQUEST` / `INVALID_MEDIA_SESSION_ID`)
- `playerState` isn't a quality signal: on live HLS it flips between PLAYING and BUFFERING many times a minute (up to 46 % of the time in BUFFERING) with no visible stall, and a stream that visibly stutters can still report PLAYING. Stalls are detected on the relay side (segment age, FFmpeg exit) and by IDLE with an `idleReason`

## Device capability profiles
Seeded by model name (`md`) where it's unambiguous; every value can be overridden per device in Settings.
| Model family (`md`) | H.264 | HEVC | Max | Notes |
|---|---|---|---|---|
| `Chromecast`: the 1080p generations **and** Chromecast with Google TV (4K) | yes | auto | auto | the 4K Google TV model reports the same `md`, so learn |
| Chromecast Ultra | yes | yes | 4K HDR | |
| Chromecast with Google TV (HD) | yes | verify | 1080p | `md` not yet seen |
| Google TV Streamer | yes | yes | 4K HDR | `md` not yet seen |
| TVs with Chromecast built-in / unknown | yes | auto | auto | learn from failures |

Even a 4K-capable device can refuse 4K: when its HDMI link runs at 1080p (on Samsung TVs, Input Signal Plus off for that input), it answers every 4K stream, H.264 or HEVC, with a bare `LOAD_FAILED` about 1 s after the first segment.

Learning: if a relay-copy plan fails with `LOAD_FAILED` or `idleReason: ERROR` within 15 s:
1. Source above 1080p → record `max_height = 1080` for that device, retry transcoded to 1080p, and show a hint that a TV setting may unlock 4K.
2. Otherwise record the failing codec trait (e.g., `hevc_support = no`) and retry with transcode.

## Planner rules
1. **Direct fast path:** only when the source is HLS (`.m3u8`) + H.264 + AAC and this provider/device pair has worked direct before (or has never been tried). ERROR within 10 s → relay automatically and remember.
2. **Video:**
   - supported codec, progressive → **copy** (original quality)
   - supported codec, interlaced → copy first; if the receiver errors, or the user enabled "Smooth interlaced", transcode with deinterlacing
   - unsupported codec (HEVC on an H.264-only device, MPEG-2) → **hardware transcode** to H.264
   - above the device's learned maximum resolution → **hardware transcode** down to it
3. **Encoder selection** (probe once with a 1-second test encode; cache the result): Windows `h264_nvenc` → `h264_qsv` → `h264_amf`; Linux `h264_nvenc` → `h264_vaapi` → `h264_qsv`; last resort `libx264 -preset veryfast` for ≤ 1080p only. Bitrate: 1.3 × source, minimum 6 Mbps at 1080p.
4. **Audio:** AAC/MP3 → copy; AC-3/E-AC-3/MP2/other → AAC 192 kbps stereo (AC-3 5.1 → AAC stereo verified). Advanced setting "Dolby passthrough" copies E-AC-3 for receivers connected to AV receivers.
5. **Container:**
   - H.264 → HLS with MPEG-TS segments (smooth at 1080p50 and 4K in Phase 0; the TV keeps polling through a relay restart).
   - **HEVC → one continuous fragmented MP4 response** (`video/mp4`, `-tag:v hvc1`; smooth at 4K). Not HLS with fMP4 segments: FFmpeg's HLS segmenter mistimes open-GOP HEVC (CRA keyframes with leading frames, x265's default) at every segment cut, which visibly stutters on the TV (ADR-004 Finding 7). The Cast docs say HEVC isn't supported in TS (untested).
   - Advanced setting "Low-latency mode" → continuous fragmented MP4 for H.264 too.
6. **Tracks:** map the audio track selected in the local player (or preferred language); never send bitmap subtitles.

## FFmpeg (bundled recent static build — never the system 4.4)
Input options for every plan:
```
-hide_banner -loglevel warning -nostdin
-user_agent <UA>
-reconnect 1 -reconnect_streamed 1 -reconnect_on_network_error 1 -reconnect_delay_max 5
-fflags +genpts+discardcorrupt
-i <source url>
```
Relay-copy, H.264 → HLS/TS:
```
-map 0:v:0 -map 0:a:<n>? -c:v copy -c:a aac -b:a 192k -ac 2
-f hls -hls_time 2 -hls_list_size 6
-hls_flags delete_segments+independent_segments+omit_endlist
-hls_segment_type mpegts <session_dir>/index.m3u8
```
Relay-copy, HEVC (and low-latency mode) → one continuous fragmented MP4:
```
-map 0:v:0 -map 0:a:<n>? -c:v copy -tag:v hvc1 -c:a aac -b:a 192k -ac 2
-f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1
```
(drop `-tag:v hvc1` for H.264). When copying, HLS segments are cut at source keyframes; `-hls_time` is a target, not a guarantee.

## Relay HTTP server
- Bind to the LAN IP on the same subnet as the device (fallback 0.0.0.0)
- Routes: `/r/<sessionToken>/index.m3u8` and `/r/<sessionToken>/<segment>` (HLS); `/p/<sessionToken>/stream.mp4` (continuous fMP4); for library items `/f/<sessionToken>/media.<ext>` (Range requests: `Accept-Ranges: bytes`, 206 responses) and `/f/<sessionToken>/subs/<n>.vtt`; each token maps to exactly one session or file; everything else 404
- Continuous fMP4: the TV opens the URL once (with `Range: bytes=0-`) and gets `200` with chunked transfer from an FFmpeg started for that request; kill the FFmpeg when the TV disconnects
- Headers: `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: *`, `Access-Control-Allow-Methods: GET, HEAD, OPTIONS` (receiver requests carry `Origin: https://www.gstatic.com`); `Cache-Control: no-cache` on playlists and continuous streams
- MIME: `.m3u8` application/vnd.apple.mpegurl · `.ts` video/mp2t · `.m4s` video/iso.segment · `.mp4`, `.m4v`, `.mov` video/mp4 · `.webm` video/webm · `.vtt` text/vtt
- HLS: send LOAD only after the playlist lists at least 2 segments. With 2–3 segments listed the receiver started near the live edge and reported BUFFERING more often than with about 4 (one run each; Phase 7 tunes this). Continuous fMP4: send LOAD right away (PLAYING about 3 s later at 4K)

## Supervisor
- HLS stall: newest segment older than max(3 × hls_time, 10 s) → restart FFmpeg from the original URL, keeping the session dir and token so the receiver keeps polling
- Continuous fMP4: when the FFmpeg exits, the response ends; the TV plays out its buffer (about 4 s), doesn't reconnect, and reports IDLE/FINISHED (ADR-004). The coordinator treats FINISHED on a `LIVE` stream as a drop: new FFmpeg, new token, new LOAD, counted against the restart budget
- Budget: 5 restarts within 2 minutes → stop and show an error with Details
- Session end (media IDLE after fallbacks, receiver app stopped, user stops, app quits) → SIGTERM, SIGKILL after 3 s (TerminateProcess on Windows), delete session dir
- On app start: read PID files in the relay temp root, kill leftovers, delete stale dirs

## Local files and downloads (docs/09)
Library items cast as seekable VOD (`streamType: BUFFERED`) and use no provider connection. CastPlanner decides from a probe of the file:
1. **Direct file:** MP4/M4V/MOV or WebM + video the device supports + AAC or MP3 as the first audio track → the relay server serves the file itself with Range requests. Original quality, native seeking, almost no CPU. Verified in Phase 0: PLAYING 1.1 s after LOAD; each SEEK made the TV open a new Range request at the matching byte offset and play from the target within 200 ms.
2. **Relay:** anything else (MKV, TS, AVI; AC-3/E-AC-3/DTS audio; unsupported video) → the planner rules above (copy supported video, audio to AAC, transcode otherwise). For files: no `-re`, `-hls_playlist_type event`, no `delete_segments` — the relay repackages the whole file quickly and the TV can seek anywhere that's ready (the session dir can grow to the file's size and is deleted when casting ends). A seek past the ready part restarts the relay at that position (`-ss` before `-i`) with a new LOAD; the sender adds the start offset so the timeline and saved progress stay continuous. **Open for Phase 8:** HEVC files hit the same open-GOP fault in HLS fMP4 segments; a likely path is remuxing to an MP4 on disk and serving it as a direct file.
3. **Subtitles:** text subtitles (external srt/ass/vtt or embedded text tracks) → WebVTT made by the bundled ffmpeg (shifted by the relay start offset), served by the relay, listed in LOAD `tracks` as TEXT tracks, switched with `activeTrackIds`. Bitmap subtitles (PGS, VobSub) aren't cast in v1.
4. **Progress:** the MEDIA_STATUS position plus the start offset is saved like local playback, so Resume works across the laptop and the TV.
5. **Verify in Phase 8** on each owned device: which containers and audio codecs play direct, and WebVTT timing after relay restarts.

## Casting UX
- Cast button in the top bar and player OSD opens the device picker (name, model, status, "Add by IP address", "Device not showing?" help)
- While casting, local playback stops. The player area shows "Playing on <device>": artwork/logo, title, now/next, play/pause, volume, stop, and a quality badge — **Original** / **Converted audio** / **Transcoded** — with a tooltip explaining why
- When a device refused 4K, the Transcoded tooltip says the TV's HDMI input may be limited to HD and a TV setting may unlock 4K
- Channel up/down while casting re-plans and reloads on the receiver
- Persistent casting bar at the bottom of the shell while browsing
- Automatic fallbacks are quiet: badge change + small toast
- First relay start on Windows: explain the firewall prompt before it appears
- Inhibit system sleep while casting (Windows `SetThreadExecutionState`; Linux logind inhibit over D-Bus)

## Casting test matrix (Phase 7 exit)
Synthetic samples from the fake provider, cast to each owned device:
H.264 1080p50 TS + AAC · H.264 1080p + AC-3 · H.264 1080i + MP2 · HEVC 2160p (open GOP, continuous fMP4) + E-AC-3 · HEVC 1080p on an H.264-only device · 4K on a device whose HDMI link is 1080p (learning + transcode) · MPEG-2 576i · mid-stream codec change · provider drop every 60 s (HLS and continuous fMP4) · relay restart during continuous fMP4 (re-LOAD) · 8 s slow start · connection limit 1 while local playback is active.

## Library casting matrix (Phase 8 exit)
Cast to each owned device: MP4 H.264 + AAC (direct) with seeks · MKV H.264 + AC-3 (relay) with seeks before and after the relay finishes · MKV HEVC + E-AC-3 on an HEVC device (and on an H.264-only device, if owned) · external SRT subtitles, direct and relay · a movie downloaded from the fake provider · resume on the TV from a position saved on the laptop.
