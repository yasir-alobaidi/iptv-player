# 03 — Playback (desktop)

## Engine: media_kit (libmpv)
`MediaKitPlayerEngine implements PlayerEngine`. Set libmpv properties through media_kit's native player API. Use media_kit's hardware-accelerated video output.

### Base options
| Option | Value | Why |
|---|---|---|
| hwdec | `auto-safe` | GPU decoding (VA-API/NVDEC on Linux, D3D11VA on Windows) with safe fallback |
| cache | `yes` | required for network streams |
| network-timeout | `10` | fail fast; the watchdog retries |
| user-agent | source UA | many panels require it |
| stream-lavf-o | `reconnect=1,reconnect_streamed=1,reconnect_delay_max=5` | FFmpeg-level reconnect for short drops |
| demuxer-max-back-bytes | small for live | bound memory |
| alang / slang | from settings | preferred audio/subtitle languages |

### Buffer presets (Settings → Playback)
| Preset | cache-secs | demuxer-max-bytes | demuxer-readahead-secs | lavf probesize | lavf analyzeduration (s) | For |
|---|---|---|---|---|---|---|
| Low latency | 2 | 32MiB | 2 | 500000 | 0.5 | sports, strong connection |
| **Balanced (default)** | 8 | 64MiB | 8 | 1000000 | 1 | most cases |
| Stable | 20 | 128MiB | 20 | 2000000 | 2 | weak Wi-Fi, unstable providers |

Phase 0 verifies every property name against the bundled libmpv version and records it in docs/decisions.md.

### Hardware decoding check
Show `hwdec-current` in the stream info overlay. Phase 0 must confirm hardware decoding for H.264 and HEVC on Linux (Intel and NVIDIA). Windows (D3D11VA) is confirmed in Phase 0 if a real Windows PC is available; otherwise ADR-003 marks it unverified and it's checked before release (Phase 10). `hwdec-current = no` while playing HEVC 4K is a blocker.

### Deinterlacing
Setting: Auto (default) / On / Off. Auto enables deinterlacing when frames are reported as interlaced (confirm the mpv property in Phase 0).

## Playback coordinator
- Single owner of what's playing where (local player, cast relay) and of each source's connections
- Enforces connection policy: with `max_connections = 1`, stop the current stream on that source and wait for it to close before opening another
- Downloads (docs/09) hold connections too, but playback and casting come first: when no connection is free, pause a download on that source and resume it afterwards
- Records history: live = last watched time; VOD = position every 10 s and on stop

## Watchdog (stability core)
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

## Channel zapping
- Up/Down, PageUp/PageDown: show the channel banner immediately; open the stream after a 350 ms debounce
- Number entry: overlay; commits after 1.5 s or Enter
- Backspace: last channel
- Reuse one engine instance across channels
- Preload now/next EPG for neighbors in the current list
- Target: p50 ≤ 1.5 s on the fake provider

## VOD & series
- Resume prompt when position > 60 s and < 95 % (Resume / Start over)
- Mark complete at ≥ 95 %
- Series: "Next episode" card with a cancelable 10 s countdown
- Seek: ←/→ 10 s, Shift+←/→ 60 s, time bubble on the seek bar

## Local files and downloads
- Library items (docs/09) play as `PlayableSource` kind `file` with the VOD rules above and no provider connection
- No reconnects: a read error means the file is missing or damaged → failed state with Show in folder / Remove from library
- External subtitle files beside the video are added as subtitle tracks

## Stream info overlay (key I)
Resolution, fps, video codec/profile, hwdec-current, audio codec/channels/language, bitrate estimate, cache seconds, dropped frames, redacted source URL.
