# playback_spike (Phase 0 step 4, throwaway)

Minimal Flutter Linux app: media_kit plays each sample from `tools/media_samples/out/` as an endless
MPEG-TS stream (loopback server + bundled ffmpeg `-re -stream_loop -1 -c copy`). The overlay shows
hwdec-current, codec, size, fps, dropped frames, and process CPU.

```bash
./run_matrix.sh <pub|git|patched> <intel|nvidia> [wayland|x11] [--auto all|samples|zap] [--only a.ts,b.ts]
```
- `pub`: media_kit 1.2.6 from pub · `git`: all eight media_kit packages at main@c533e44 ·
  `patched`: pub + `../vendor/media_kit_video_egl_display.patch` (media_kit #1404)
- Results: `results/<variant>_<gpu>_<backend>.jsonl` (`start`, `tick`, `sample_result`, `zap_run`, `zap_result`) and `.log`
- Check the log for `media_kit: VideoOutput: H/W rendering` vs `S/W rendering`
- First frame = `open()` until mpv's `path` is the new URL, `playback-time` is available, and video params are known
- Zap: 20 alternating opens of h264_1080p50_aac ↔ h264_1080p25_ac3, once with plain `-re` and once with a 2 s initial burst
- Manual mode (no `--auto`): keys 0–9 open a sample, `z` runs the zap test
