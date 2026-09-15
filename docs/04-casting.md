# 04 — Casting (desktop → Chromecast / Google TV)

## How it works
The desktop app is a **Cast sender**. It tells the receiver to load a URL, and the receiver downloads the media itself. We use Google's **Default Media Receiver** (app id `CC1AD845`), which needs no registration.

Most IPTV URLs can't be played by the receiver directly: raw MPEG-TS, no CORS headers, Dolby audio, connection limits, required User-Agent, expiring redirect tokens. So the app runs a **local relay**: one connection to the provider, FFmpeg repackages the stream without touching the video, and a local HTTP server serves it to the receiver.

## Components (lib/data/cast/)
| Component | Responsibility |
|---|---|
| CastDiscovery | bonsoir browse `_googlecast._tcp`; TXT `fn` (name), `md` (model), `id`; manual IP devices; dedupe by id |
| CastV2Client | TLS socket to host:8009 (device uses a self-signed cert), framing (4-byte big-endian length + protobuf `CastMessage`), namespaces, request ids, heartbeat |
| MediaChannel | LOAD, PLAY, PAUSE, STOP, SEEK, GET_STATUS; volume via receiver namespace; MEDIA_STATUS parsing |
| StreamProbe | bundled ffprobe on the source (UA, 8 s timeout): codecs, profile, level, resolution, fps, field order, audio tracks, bitrate |
| CastPlanner | pure function (probe, device profile, settings) → CastPlan (direct / relay-copy / relay-transcode, container, audio action) |
| RelayServer | shelf server bound to the LAN interface sharing the device's subnet; port 38400–38499; random session token in path; CORS; MIME |
| FfmpegRelay | builds args from the plan, starts bundled ffmpeg, writes PID file, pipes stderr to logs (redacted) |
| RelaySupervisor | stall detection, restart from original URL, restart budget, cleanup |
| CastCoordinator | orchestration: plan, relay, LOAD, fallbacks, device learning, local-player suspension, sleep inhibition, session state |

## Cast v2 protocol essentials
- `CastMessage` protobuf (Chromium `cast_channel.proto`): protocol_version CASTV2_1_0, source_id `sender-0`, destination_id (`receiver-0` or the app transportId), namespace, payload_type STRING, payload_utf8 (JSON). Generate Dart code once and commit it.
- Namespaces:
  - `urn:x-cast:com.google.cast.tp.connection` → `CONNECT` / `CLOSE`
  - `urn:x-cast:com.google.cast.tp.heartbeat` → send `PING` every 5 s, answer `PING` with `PONG`; 3 missed → reconnect
  - `urn:x-cast:com.google.cast.receiver` → `LAUNCH {appId}`, `GET_STATUS`, `SET_VOLUME`, `STOP`; `RECEIVER_STATUS` gives the app's `transportId`
  - `urn:x-cast:com.google.cast.media` → `LOAD`, `PLAY`, `PAUSE`, `STOP`, `SEEK`, `GET_STATUS`; `MEDIA_STATUS` with `playerState` and `idleReason` (FINISHED, CANCELLED, INTERRUPTED, ERROR)
- Sequence: TLS connect → CONNECT receiver-0 → GET_STATUS → LAUNCH CC1AD845 → RECEIVER_STATUS with app → CONNECT transportId → LOAD
- LOAD media: `contentId` (relay URL), `contentType`, `streamType` (`LIVE` or `BUFFERED`), `metadata` (title, subtitle, images), HLS segment format fields when using fMP4, `autoplay: true`
- Phase 0 verifies field names (especially the HLS segment format fields) against current Google Cast docs and records them in docs/decisions.md.

## Device capability profiles
Seeded by model name (`md`); every value can be overridden per device in Settings.
| Model family | H.264 | HEVC | Max | Notes |
|---|---|---|---|---|
| Chromecast (1080p generations) | yes | no | 1080p | treat as H.264-only |
| Chromecast Ultra | yes | yes | 4K HDR | |
| Chromecast with Google TV (4K) | yes | yes | 4K HDR | |
| Chromecast with Google TV (HD) | yes | verify | 1080p | |
| Google TV Streamer | yes | yes | 4K HDR | |
| TVs with Chromecast built-in / unknown | yes | auto | unknown | learn from failures |

Learning: if a relay-copy plan fails with `idleReason: ERROR` within 15 s, record the failing trait for that device (e.g., `hevc_support = no`), then retry with transcode automatically.

## Planner rules
1. **Direct fast path:** only when the source is HLS (`.m3u8`) + H.264 + AAC and this provider/device pair has worked direct before (or has never been tried). ERROR within 10 s → relay automatically and remember.
2. **Video:**
   - supported codec, progressive → **copy** (original quality)
   - supported codec, interlaced → copy first; if the receiver errors, or the user enabled "Smooth interlaced", transcode with deinterlacing
   - unsupported codec (HEVC on an H.264-only device, MPEG-2) → **hardware transcode** to H.264
3. **Encoder selection** (probe once with a 1-second test encode; cache the result): Windows `h264_nvenc` → `h264_qsv` → `h264_amf`; Linux `h264_nvenc` → `h264_vaapi` → `h264_qsv`; last resort `libx264 -preset veryfast` for ≤ 1080p only. Bitrate: 1.3 × source, minimum 6 Mbps at 1080p.
4. **Audio:** AAC/MP3 → copy; AC-3/E-AC-3/MP2/other → AAC 192 kbps stereo. Advanced setting "Dolby passthrough" copies E-AC-3 for receivers connected to AV receivers.
5. **Container:** H.264 → HLS with MPEG-TS segments; HEVC → HLS with fMP4 segments + `-tag:v hvc1`. Advanced setting "Low-latency mode" → progressive fragmented MP4 over one HTTP response.
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
Relay-copy, HEVC → HLS/fMP4: same, plus `-tag:v hvc1 -hls_segment_type fmp4`.
Low-latency progressive: `-c:v copy -c:a aac -f mp4 -movflags frag_keyframe+empty_moov+default_base_moof pipe:1`, served as `video/mp4`.
When copying, segments are cut at source keyframes; `-hls_time` is a target, not a guarantee.

## Relay HTTP server
- Bind to the LAN IP on the same subnet as the device (fallback 0.0.0.0)
- Routes: `/r/<sessionToken>/index.m3u8` and `/r/<sessionToken>/<segment>`; for library items `/f/<sessionToken>/media.<ext>` (Range requests: `Accept-Ranges: bytes`, 206 responses) and `/f/<sessionToken>/subs/<n>.vtt`; each token maps to exactly one session or file; everything else 404
- Headers: `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: *`, `Access-Control-Allow-Methods: GET, HEAD, OPTIONS`; `Cache-Control: no-cache` on playlists
- MIME: `.m3u8` application/vnd.apple.mpegurl · `.ts` video/mp2t · `.m4s` video/iso.segment · `.mp4`, `.m4v`, `.mov` video/mp4 · `.webm` video/webm · `.vtt` text/vtt
- Send LOAD only after the playlist lists at least 2 segments

## Supervisor
- Stall: newest segment older than max(3 × hls_time, 10 s) → restart FFmpeg from the original URL, keeping the session dir and token so the receiver keeps polling
- Budget: 5 restarts within 2 minutes → stop and show an error with Details
- Session end (media IDLE after fallbacks, receiver app stopped, user stops, app quits) → SIGTERM, SIGKILL after 3 s (TerminateProcess on Windows), delete session dir
- On app start: read PID files in the relay temp root, kill leftovers, delete stale dirs

## Local files and downloads (docs/09)
Library items cast as seekable VOD (`streamType: BUFFERED`) and use no provider connection. CastPlanner decides from a probe of the file:
1. **Direct file:** MP4/M4V/MOV or WebM + video the device supports + AAC or MP3 as the first audio track → the relay server serves the file itself with Range requests. Original quality, native seeking, almost no CPU.
2. **Relay:** anything else (MKV, TS, AVI; AC-3/E-AC-3/DTS audio; unsupported video) → the planner rules above (copy supported video, audio to AAC, transcode otherwise). For files: no `-re`, `-hls_playlist_type event`, no `delete_segments` — the relay repackages the whole file quickly and the TV can seek anywhere that's ready (the session dir can grow to the file's size and is deleted when casting ends). A seek past the ready part restarts the relay at that position (`-ss` before `-i`) with a new LOAD; the sender adds the start offset so the timeline and saved progress stay continuous.
3. **Subtitles:** text subtitles (external srt/ass/vtt or embedded text tracks) → WebVTT made by the bundled ffmpeg (shifted by the relay start offset), served by the relay, listed in LOAD `tracks` as TEXT tracks, switched with `activeTrackIds`. Bitmap subtitles (PGS, VobSub) aren't cast in v1.
4. **Progress:** the MEDIA_STATUS position plus the start offset is saved like local playback, so Resume works across the laptop and the TV.
5. **Verify in Phase 8** on each owned device: which containers and audio codecs play direct, and WebVTT timing after relay restarts.

## Casting UX
- Cast button in the top bar and player OSD opens the device picker (name, model, status, "Add by IP address", "Device not showing?" help)
- While casting, local playback stops. The player area shows "Playing on <device>": artwork/logo, title, now/next, play/pause, volume, stop, and a quality badge — **Original** / **Converted audio** / **Transcoded** — with a tooltip explaining why
- Channel up/down while casting re-plans and reloads on the receiver
- Persistent casting bar at the bottom of the shell while browsing
- Automatic fallbacks are quiet: badge change + small toast
- First relay start on Windows: explain the firewall prompt before it appears
- Inhibit system sleep while casting (Windows `SetThreadExecutionState`; Linux logind inhibit over D-Bus)

## Casting test matrix (Phase 7 exit)
Synthetic samples from the fake provider, cast to each owned device:
H.264 1080p50 TS + AAC · H.264 1080p + AC-3 · H.264 1080i + MP2 · HEVC 2160p HLS + E-AC-3 · HEVC 1080p on an H.264-only device · MPEG-2 576i · mid-stream codec change · provider drop every 60 s · 8 s slow start · connection limit 1 while local playback is active.

## Library casting matrix (Phase 8 exit)
Cast to each owned device: MP4 H.264 + AAC (direct) with seeks · MKV H.264 + AC-3 (relay) with seeks before and after the relay finishes · MKV HEVC + E-AC-3 on an HEVC device (and on an H.264-only device, if owned) · external SRT subtitles, direct and relay · a movie downloaded from the fake provider · resume on the TV from a position saved on the laptop.
