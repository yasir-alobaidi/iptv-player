# cast_spike (Phase 0 step 5, throwaway)

Dart CLI that casts to a Chromecast / Google TV with our own Cast v2 client. Discovery uses
multicast_dns plus a manual IP (ADR-006). Results and conclusions: ADR-004 in `docs/decisions.md`.

**Ask the user before casting anything to their TV.**

```bash
cd spike/cast_spike
dart run bin/cast_spike.dart discover
dart run bin/cast_spike.dart cast --case <case> --host <ip> [options]
```
- Cases: `h264_1080p50_aac`, `h264_1080p25_ac3`, `h264_2160p25_aac` → HLS/TS relay-copy (`--fmp4` for fMP4
  segments); `hevc_2160p25_eac3`, `hevc_1080p50_aac` → HLS/fMP4 with `-tag:v hvc1` (`--vtag hev1|none`);
  `vod_file` → `vod_h264_aac_10min.mp4` as a plain file with Range (`BUFFERED`), then seeks (`--seek 300,60`)
  and a pause/resume
- Options: `--seg-format fmp4|FMP4|none|<any>` (sets `hlsSegmentFormat` and `hlsVideoSegmentFormat`),
  `--content-type`, `--hold <s>`, `--keep-app` (leave the receiver app open for the next run), `--label <suffix>`,
  `--hls-time`, `--min-segments` (LOAD after N segments), `--start-offset` (adds `#EXT-X-START`; not tried on a
  device)
- HLS cases: a loopback "provider" plays the sample as an endless real-time MPEG-TS stream
  (`-re -stream_loop -1`; its loop point breaks video timestamps, ADR-004 Finding 8), the relay runs the docs/04
  FFmpeg command against it over HTTP, and a shelf server on the LAN address serves `/r/<token>/…` and
  `/f/<token>/media.mp4` with CORS. LOAD goes out once the playlist lists 2 segments
- `h264_2160p25_aac.ts` isn't made by `tools/media_samples/generate.sh`. Create it from the repo root with:
  ```bash
  third_party/ffmpeg/linux-x64/ffmpeg -f lavfi -i testsrc2=size=3840x2160:rate=25 \
    -f lavfi -i sine=frequency=784:sample_rate=48000 -t 30 -map 0:v -map 1:a \
    -c:v libx264 -preset veryfast -profile:v high -level:v 5.1 -pix_fmt yuv420p -g 50 -keyint_min 50 \
    -sc_threshold 0 -b:v 15M -maxrate 20M -bufsize 30M -c:a aac -b:a 128k -ac 2 \
    -f mpegts tools/media_samples/out/h264_2160p25_aac.ts
  ```
- Results: `results/<case>[_label].log` and `.jsonl` (`http`, `receiver`, `media_status`, `load_reply`,
  `message`, `summary`). Stop early with Ctrl+C, SIGTERM, or `touch results/stop`
- FFmpeg PID files live in `results/run/`; every start kills leftovers and deletes their session dirs
- `tool/gen_proto.sh` regenerates `lib/src/proto/` (needs `protoc`); the generated code is committed
