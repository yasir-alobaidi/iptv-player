# 04 — Casting (desktop → Chromecast / Google TV)

## How it works
The desktop app is a **Cast sender**. It tells the receiver to load a URL, and the receiver downloads the media itself. We use Google's **Default Media Receiver** (app id `CC1AD845`), which needs no registration.

Most IPTV URLs can't be played by the receiver directly: raw MPEG-TS, no CORS headers, Dolby audio, connection limits, required User-Agent, expiring redirect tokens. So the app runs a **local relay**: one connection to the provider, FFmpeg repackages the stream without touching the video, and a local HTTP server serves it to the receiver.

Phase 0 proved this end to end on a Chromecast with Google TV (4K) with our own Cast v2 client and the bundled FFmpeg (ADR-004). The receiver plays HLS with Shaka Player, the Web Receiver's default HLS player since SDK 3.0.0150.

## Components (lib/data/cast/)
| Component | Responsibility |
|---|---|
| CastDiscovery | bonsoir browse `_googlecast._tcp`; TXT `fn` (name), `md` (model), `id`, `ca` (capability bits: devices without bit 0, video out, are audio-only speakers and aren't listed); manual IP devices; dedupe by id. multicast_dns (proven in Phase 0) is the fallback if bonsoir fails |
| CastV2Client | TLS socket to host:8009 (device uses a self-signed cert), framing (4-byte big-endian length + protobuf `CastMessage`), namespaces, request ids, heartbeat; tolerant parsing (unknown namespaces and types, a `status` that isn't an object, messages arriving after CLOSE). As built (Phase 7 step 2): `CastChannel`, `ReceiverChannel`, `MediaChannel`, `CastV2Receivers` behind `CastReceivers` / `CastReceiverSession` in `lib/core/cast/` |
| MediaChannel | LOAD, PLAY, PAUSE, STOP, SEEK, GET_STATUS; volume via receiver namespace; MEDIA_STATUS parsing |
| StreamProbe | bundled ffprobe on the source (UA, 8 s timeout): codecs, profile, level, resolution, fps, field order, audio tracks, bitrate. As built (Phase 7 step 3): `FfprobeStreamProbe` in `lib/data/cast/` reads 2 s of a stream (`-analyzeduration 2000000 -probesize 5000000`; 0.5–1.7 s on the fake panel's live channels, against 4–4.8 s for ffprobe's own 5 s) through the `ProcessSupervisor`; `readFfprobeJson` reads its JSON tolerantly. `StreamFactsLookup` (`lib/features/casting/domain/`) asks the laptop's player first, then what this run remembers, then the probe (Phase 7 decision 4) |
| CastPlanner | pure function (probe, device profile, settings) → CastPlan (direct / relay-copy / relay-transcode, container, audio action). As built: `planCast` in `lib/core/cast/` (domain code never imports `lib/data/`), with `CastDeviceProfile`, `CastPlan` and the badge's words in `lib/features/casting/presentation/cast_plan_text.dart` |
| CastEncoderDetection | the H.264 encoders that work here (rule 3), each with what its chip decodes, found by test encodes and decodes and remembered per FFmpeg. As built (Phase 7 step 4): `FfmpegEncoderDetector` and `videoTranscodeArgs` in `lib/data/cast/`, the domain in `lib/core/cast/cast_encoders.dart` |
| ProcessSupervisor | every FFmpeg and ffprobe (hard rule 8): a PID file per process (`<app support>/processes/`), a timeout, SIGTERM then SIGKILL after 3 s, `stopAll` on quit, and the launch sweep, which kills a leftover only if it still runs the executable its file names and the app that started it is gone. `lib/data/process/` (Phase 7 step 3) |
| RelayServer | shelf server bound to the LAN interface sharing the device's subnet; port 38400–38499; random session token in path; CORS; MIME; serves HLS sessions, continuous fragmented MP4 streams, and files with Range. As built (Phase 7 step 5): `RelayServer` on dart:io, bound to the Cast connection's own local address; beside it the loopback `RelayProxy` FFmpeg and ffprobe read the provider through (decision 3), both in the relay's own isolate (`IsolateCastRelay`, decision 5) behind `CastRelay` in `lib/core/cast/` |
| FfmpegRelay | builds args from the plan, starts bundled ffmpeg, writes PID file, pipes stderr to logs (redacted). As built: `castRelayJob` (the plan's maps and codecs, app side) and `relayArguments` (the input and the muxer, in the isolate); FFmpeg runs under the `ProcessSupervisor` as "relay"; its warnings logged (10 a minute), its input's description reported (`CastRelayOpened`) |
| RelaySupervisor | stall detection, restart from original URL, restart budget, cleanup. As built: `RelayRuntime`, below "Supervisor"; plus the proxy's watch of a live MPEG-TS stream's program map, which tells a codec switch FFmpeg never reports |
| CastCoordinator | orchestration: plan, relay, LOAD, fallbacks, device learning, re-LOAD after a continuous stream ends, local-player suspension, sleep inhibition, session state |

## Cast v2 protocol essentials
- `CastMessage` protobuf (Chromium `cast_channel.proto`): protocol_version CASTV2_1_0, source_id `sender-0`, destination_id (`receiver-0` or the app transportId), namespace, payload_type STRING, payload_utf8 (JSON). The generated Dart code is committed in `lib/data/cast/proto/` (`tools/gen_cast_proto.sh` regenerates it).
- Namespaces:
  - `urn:x-cast:com.google.cast.tp.connection` → `CONNECT` / `CLOSE`
  - `urn:x-cast:com.google.cast.tp.heartbeat` → send `PING` every 5 s, answer `PING` with `PONG`; 3 intervals with nothing heard from the device (any message counts) → reconnect, and join the same receiver by its session id
  - `urn:x-cast:com.google.cast.receiver` → `LAUNCH {appId}`, `GET_STATUS`, `SET_VOLUME`, `STOP`; `RECEIVER_STATUS` gives the app's `transportId`. After LAUNCH the device also sends `LAUNCH_STATUS`, whose `status` is a string (`USER_ALLOWED`)
  - `urn:x-cast:com.google.cast.media` → `LOAD`, `PLAY`, `PAUSE`, `STOP`, `SEEK`, `GET_STATUS`; `MEDIA_STATUS` with `playerState` and `idleReason` (FINISHED, CANCELLED, INTERRUPTED, ERROR)
  - `urn:x-cast:com.google.cast.multizone` → the device sends `MULTIZONE_STATUS` on its own, and answers `GET_STATUS` with it: `devices` with each one's `name`, `deviceId` (a UUID) and `capabilities`. Add by address uses it to name a device its mDNS port didn't answer for (ADR-014 step 2). Ignore namespaces and types we don't use
- Sequence: TLS connect → CONNECT receiver-0 → GET_STATUS → LAUNCH CC1AD845 → RECEIVER_STATUS with app → CONNECT transportId → LOAD. LAUNCH took 3–6 s when the receiver app wasn't running; reuse a running app
- LOAD (fields verified against the Google Cast docs and on the device, ADR-004): top-level `media`, `autoplay: true`, `currentTime`; `media.contentId` (relay URL), `contentType` (`application/x-mpegurl` for HLS, `video/mp4` for continuous fMP4 and files), `streamType` (`LIVE` or `BUFFERED`), `metadata` (`metadataType` 0, title, subtitle, images). Don't send `hlsSegmentFormat` / `hlsVideoSegmentFormat`: the receiver ignores them (any value, or none, plays), and the planner never uses HLS with fMP4 segments
- Errors: a LOAD the receiver can't play is answered with a bare `LOAD_FAILED` (no reason) plus `MEDIA_STATUS` IDLE/ERROR; the media session is then gone (STOP → `INVALID_REQUEST` / `INVALID_MEDIA_SESSION_ID`). **A LOAD gets two answers under one request id when it fails:** first a `MEDIA_STATUS` (IDLE, `extendedStatus.playerState` LOADING) at once, then the `LOAD_FAILED` (1.6 s later in Phase 0). Status updates leave out `media` once it was sent
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

As built (Phase 7 step 3, ADR-014), the planner also:
- re-encodes H.264 that Cast devices don't decode (more than 8 bits, 4:2:2, 4:4:4) and HEVC beyond Main and Main 10, an unknown video codec, and VP8/VP9/AV1 (the `md` can't tell which models play them);
- re-encodes at the source's height, else at most 1080p when the height isn't known, and deinterlaces whatever interlaced picture it re-encodes, one picture per field (up to 60);
- bit rates: 1.3 × the source's, scaled by pixels when made smaller, between a floor and a ceiling per height (1080p: 6–15 Mbps; 2160p: 16–40 Mbps; an unknown source gets the floor);
- converts LATM AAC (`aac_latm`) and any audio codec the device refused before;
- plays direct only with no User-Agent of the source's own, the stream's first audio track, and (live) Low-latency mode off; a file goes direct as MP4/M4V/MOV with AAC or MP3, and through the relay as one continuous fragmented MP4 otherwise (decision 1);
- picks the audio track: the laptop's, then the first preferred language (two- and three-letter codes both), then the stream's default, then the first;
- lets the user's HEVC "Yes" win over a learned refusal.

### Encoders, as built (Phase 7 step 4, ADR-014)
- **Detection:** FFmpeg's version, then what was remembered for it (`<app support>/cast/encoders.json`, at most 7 days old), else a 1 s 1080p test encode per candidate in rule 3's order with the re-encode's own arguments, VA-API and Quick Sync on every render node (the first isn't always the right GPU). For each hardware encoder that passes, a test decode on its chip of each kind it may take off the processor: 8-bit H.264, HEVC Main, HEVC Main 10, MPEG-2. A test passes only when FFmpeg ends well **and** reports pictures made. Every encoder that works is kept, in order (`CastEncoders.after` gives the next after a failure).
- **The arguments per encoder:** decoded, scaled and deinterlaced on the chip when it decodes the source (NVENC `scale_cuda`/`bwdif_cuda`; VA-API `scale_vaapi`/`deinterlace_vaapi`; Quick Sync `vpp_qsv`); otherwise on the processor (`bwdif`, `scale`) and handed to the encoder. Deinterlacing gives one picture per field. H.264 High, 8-bit 4:2:0; `-maxrate` 1.5 × and `-bufsize` 2 × the bit rate; a keyframe every 2 s; never made taller.
- **libva:** the bundled FFmpeg needs libva 2.21 or newer for VA-API (`vaMapBuffer2`); Ubuntu 22.04 and 24.04 have older ones, on which it aborts. The Linux build carries libva 2.22 in `ffmpeg/libva/` (`tools/fetch_libva.sh`); FFmpeg tries it first, then the system's.
- **Measured** (this laptop, % of one core at the stream's pace): HEVC 4K → H.264 1080p NVENC 7 %, VA-API 8 %, libx264 219 %; MPEG-2 576i → 576p50 4 / 7 / 117 %; 1080i50 → 1080p50 6 / 7 / 311 %.

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

As built (Phase 7 step 5, ADR-014): the input is the relay's loopback proxy, never the provider (decision 3), so there is **no `-user_agent`** (the proxy sends the source's) and **`-reconnect_delay_max 1`** (FFmpeg's one peer is the proxy, which retries the provider itself: after the app's SIGKILL FFmpeg ends in about 3 s, not 16); **`-analyzeduration 2000000 -probesize 5000000`**, as the probe reads; `-loglevel repeat+level+info -nostats`; `-map 0:V:0` (never a cover picture); `-max_muxing_queue_size 1024`; **AAC copied into MP4 needs `-bsf:a aac_adtstoasc`** (FFmpeg 8 doesn't add it); segments named `seg%05d.ts`; a restarted HLS FFmpeg adds `append_list` to `-hls_flags`, so its playlist carries on behind an `#EXT-X-DISCONTINUITY`.

## Relay HTTP server
- Bind to the LAN IP on the same subnet as the device (fallback 0.0.0.0)
- Routes: `/r/<sessionToken>/index.m3u8` and `/r/<sessionToken>/<segment>` (HLS); `/p/<sessionToken>/stream.mp4` (continuous fMP4); for library items `/f/<sessionToken>/media.<ext>` (Range requests: `Accept-Ranges: bytes`, 206 responses) and `/f/<sessionToken>/subs/<n>.vtt`; each token maps to exactly one session or file; everything else 404
- Continuous fMP4: the TV opens the URL once (with `Range: bytes=0-`) and gets `200` with chunked transfer from an FFmpeg started for that request; kill the FFmpeg when the TV disconnects
- Headers: `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Headers: *`, `Access-Control-Allow-Methods: GET, HEAD, OPTIONS` (receiver requests carry `Origin: https://www.gstatic.com`); `Cache-Control: no-cache` on playlists and continuous streams
- MIME: `.m3u8` application/vnd.apple.mpegurl · `.ts` video/mp2t · `.m4s` video/iso.segment · `.mp4`, `.m4v`, `.mov` video/mp4 · `.webm` video/webm · `.vtt` text/vtt
- HLS: send LOAD only after the playlist lists at least 2 segments. With 2–3 segments listed the receiver started near the live edge and reported BUFFERING more often than with about 4 (one run each; Phase 7 tunes this). Continuous fMP4: send LOAD right away (PLAYING about 3 s later at 4K)
- As built (Phase 7 step 5): CORS on every answer, 404s and OPTIONS (204) included; JPEG, PNG and WebP served too (the LOAD's picture); a port that won't bind moves on, an address that isn't this computer's fails at once. **The continuous stream is written on the TV's own connection** (ADR-010), so a TV that leaves is seen at once. The relay's **loopback proxy** (decision 3) serves FFmpeg and ffprobe `http://127.0.0.1:<port>/in/<token>`: every connection asks the app for the stream's URL; a live stream that ends, breaks or goes quiet for 8 s reaches FFmpeg as a cut, so FFmpeg reconnects and a fresh connection is made; a provider's HLS playlists are rewritten so their segments come through it; the source's connections are counted, and a full account is tried again after 1, 1 and 2 s

## Supervisor
- HLS stall: newest segment older than max(3 × hls_time, 10 s) → restart FFmpeg from the original URL, keeping the session dir and token so the receiver keeps polling
- Continuous fMP4: when the FFmpeg exits, the response ends; the TV plays out its buffer (about 4 s), doesn't reconnect, and reports IDLE/FINISHED (ADR-004). The coordinator treats FINISHED on a `LIVE` stream as a drop: new FFmpeg, new token, new LOAD, counted against the restart budget
- Budget: 5 restarts within 2 minutes → stop and show an error with Details
- Session end (media IDLE after fallbacks, receiver app stopped, user stops, app quits) → SIGTERM, SIGKILL after 3 s (TerminateProcess on Windows), delete session dir
- On app start: read PID files in the relay temp root, kill leftovers, delete stale dirs
- As built (Phase 7 step 5): HLS also restarts when no first segment comes within 20 s and when FFmpeg ends; a stalled FFmpeg is SIGKILLed at once (it ignores SIGTERM while blocked on its input); an FFmpeg that ends before any output fails the session (a re-encode at once, as the encoder's failure; anything else after two); a recent refusal by the provider fails it with the provider's status and words. Restarts wait 0.5, 1, 2 s. The session folders are `<cache>/relay/<pid>/`; the launch sweep deletes those whose app is gone. A codec switch, which FFmpeg copying never reports, is told by the proxy's watch of the PAT and PMT

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
