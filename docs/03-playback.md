# 03 — Playback (desktop)

## Engine: media_kit (libmpv)
`MediaKitPlayerEngine implements PlayerEngine`. Set libmpv properties through media_kit's native player API. Use media_kit's hardware-accelerated video output.

On Linux the app depends on our patched media_kit_video (ADR-003). Every unpatched build hits media_kit #1404: no EGL context is current on the platform thread, so it falls back to S/W rendering with copy-back decoding and drops frames at 50 fps. The patch keeps rendering and decoding on the GPU (zero-copy `vaapi` on Intel, `nvdec` on NVIDIA).

### Base options
| Option | Value | Why |
|---|---|---|
| hwdec | `auto-safe` | GPU decoding (VA-API/NVDEC on Linux, D3D11VA on Windows) with safe fallback |
| cache | `yes` | required for network streams |
| cache-on-disk | `no` | libmpv 0.34.1 otherwise logs `Failed to create file cache` on every open |
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

Every option and property name in this doc was verified against the system libmpv 0.34.1 (Ubuntu 22.04) in ADR-003. media_kit also sets `subs-fallback`, which 0.34.1 doesn't have; it logs one harmless error.

### Hardware decoding check
Show `hwdec-current` in the stream info overlay. Confirmed on Linux in Phase 0 (ADR-003): zero-copy hardware decoding for H.264, HEVC, and HEVC 4K on Intel (`vaapi`) and NVIDIA (`nvdec`), on native Wayland and Xorg, with the patched media_kit_video. Windows (D3D11VA) stays unverified until a real Windows PC is available; check it before release (Phase 10). `hwdec-current = no` while playing HEVC 4K is a blocker.
- `hwdec=auto-safe` doesn't GPU-decode MPEG-2. SD MPEG-2 costs about 1 % CPU, which is acceptable.
- Under XWayland (`GDK_BACKEND=x11` inside a Wayland session) VA-API falls back to `vaapi-copy` and drops frames at 50 fps. The app runs as a native Wayland client there; never force the X11 backend.
- NVIDIA isn't required: Intel meets every budget. Whether to offer "use discrete GPU" is a Phase 10 packaging question.

### Deinterlacing
Setting: Auto (default) / On / Off. libmpv 0.34.1's `deinterlace` is only yes/no, so Auto reads `video-frame-info/interlaced` (it reports `yes` for 1080i50 and 576i25) and sets `deinterlace` to match.

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
- A codec or resolution change restarts mpv's video output and resets `frame-drop-count`; a lower count isn't an error

## Channel zapping
- Up/Down, PageUp/PageDown: show the channel banner immediately; open the stream after a 350 ms debounce
- Number entry: overlay; commits after 1.5 s or Enter
- Backspace: last channel
- Reuse one engine instance across channels
- Preload now/next EPG for neighbors in the current list
- Target: p50 ≤ 1.5 s on the fake provider (the Phase 0 spike measured p50 / p95 320 / 597 ms over loopback, ADR-003)

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
