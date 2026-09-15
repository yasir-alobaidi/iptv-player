# Handoff — 2026-09-15 (session 2)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user, about 30 minutes)
Claude can't run sudo: it needs a password and a Claude Code session has no terminal to type it into. Run these in your own terminal:

```bash
# 1. System packages (docs/setup.md section 1)
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libsecret-1-dev libjsoncpp-dev \
  libmpv-dev mpv libmimalloc-dev \
  vainfo intel-media-va-driver-non-free \
  avahi-daemon protobuf-compiler

# 2. NVIDIA driver (docs/setup.md section 2), then reboot
sudo ubuntu-drivers autoinstall
```
Then in fish:
```fish
fish_add_path ~/develop/flutter/bin   # Flutter 3.47.4 is already extracted there
flutter config --enable-linux-desktop --enable-windows-desktop
```
Reboot, then check: `nvidia-smi` lists the GTX 1650 Ti, `vainfo` lists H264 and HEVC, `flutter doctor -v` shows Linux toolchain ✓.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 0 steps 1–3 are done. Verify the setup checks in the handoff, then run Phase 0 from step 4 in docs/08-phases-and-prompts.md: stop after each numbered step and wait for my OK.
```

## Where things stand
- **Phase 0 steps 1–3 done** (commits `bdab868`, `1d7e320`, plus the docs commit for ADR-002). Commits are on `main` and **not pushed** to GitHub.
- **Step 4 (Spike A, playback) is next** and blocked only on the sudo setup and reboot above.
- Step 5 (Spike B, casting) needs the home network and the Google TV. On 2026-09-15 the laptop was on hotel Wi-Fi.

## Done this session (2026-09-15)
- **Step 1:** `.gitignore` for Flutter, `third_party/ffmpeg/`, `tools/media_samples/out/`, spike outputs, and the generated design bundle. `design/iptv-player-ui.html` was untracked with `git rm --cached` and is still on disk. `tools/fetch_ffmpeg.sh` downloads BtbN FFmpeg (GPL, branch 8.1) with SHA-256 checks; it ran, and FFmpeg 8.1.2 is in `third_party/ffmpeg/linux-x64/`. It needs only glibc ≥ 2.28 and includes libx264/libx265, NVENC, VA-API, QSV, AC-3/E-AC-3, and WebVTT.
- **Flutter 3.47.4** (Dart 3.13.3) downloaded, SHA-256 checked, and extracted to `~/develop/flutter`. Not on PATH yet.
- **Step 2:** ADR-002 in docs/decisions.md. Main findings:
  - `sqlite3_flutter_libs` is end-of-life. Use `sqlite3: ^3.6.0`; its bundled SQLite includes FTS5.
  - `extended_image` instead of `cached_network_image`, which pulls in sqflite (no native desktop backend).
  - **media_kit is provisional.** The last pub release is from Dec 2025. Main (`c533e44`) has unreleased Linux fixes. Open issue #1404: on Flutter ≥ 3.38, Linux video can fall back to software rendering.
  - Dependency resolution: every ADR-002 package resolves together on Flutter 3.47.4, all at latest versions. media_kit from git main also resolves, but only when all eight media_kit packages are overridden to the same SHA (details in ADR-002).
- **Step 3:** `tools/media_samples/generate.sh` makes all 11 samples from docs/06 in about 6 minutes; each was checked with ffprobe. It skips existing files; use `--force <name>` to redo one.
- docs/setup.md: sudo package list gained `libmimalloc-dev` and `protobuf-compiler`; state table updated.

## What's left
| Phase | What | Blocked on |
|---|---|---|
| 0 step 4 | Spike A: media_kit playback on Intel + NVIDIA, hwdec for H.264/HEVC, zap p50/p95, libmpv property names; fvp if needed; Windows PC question | sudo setup + reboot |
| 0 step 5 | Spike B: Cast discovery, Cast v2 client, FFmpeg HLS relay, plain MP4 with seeking; verify LOAD fields on the device | home network, Google TV model, **answer on the bonsoir question below** |
| 0 step 6 | ADR-003, ADR-004, GO / NO-GO; update docs/03, 04, setup | steps 4–5 |
| 1–10 | Foundation → sources/sync → live TV → EPG → movies/series → search/favorites → casting → downloads/library → settings/polish → packaging | Phase 0 GO |
| TV-0…TV-5 | Google TV version (docs/07) | desktop v1 |

## Instructions for the next session
1. Confirm the setup checks above (`nvidia-smi`, `vainfo`, `flutter doctor -v`, `pkg-config --modversion mpv`). If anything is missing, give the user the exact command; never run sudo.
2. Spike A (step 4):
   - Test **both** media_kit pub 1.2.6 and git main `c533e446755f51cf53c7e57aea873f2aa5355f81` (paths `media_kit`, `media_kit_video`, `libs/universal/media_kit_libs_video`).
   - Look for `media_kit: VideoOutput: S/W rendering` in the log (issue #1404) on both GPUs; NVIDIA may need `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`.
   - Ubuntu 22.04's libmpv is 0.34.1; record whether that's good enough.
   - Samples are in `tools/media_samples/out/` (run `generate.sh` if missing).
3. Before step 5, get the user's answer on the bonsoir question and their Google TV model.
   - In LOAD, send `hlsSegmentFormat` and `hlsVideoSegmentFormat`. Google's docs show them only as JS constants (`HlsSegmentFormat.FMP4`, `HlsVideoSegmentFormat.MPEG2_TS`/`FMP4`), so try lowercase wire values (`"fmp4"`, `"ts"`, `"mpeg2_ts"`) and record what the device accepts.
   - Confirmed field names: `contentId`, `contentUrl` (wins over `contentId` when both are set), `contentType`, `streamType` (`BUFFERED`/`LIVE`), `duration` (-1 for LIVE), `metadata`, `tracks`, `textTrackStyle`; LOAD request: `media`, `autoplay`, `currentTime`, `activeTrackIds`.
4. At the end: update docs/progress.md and docs/decisions.md, overwrite this file, and commit.

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001); fvp is the only playback fallback.
- Casting through our own Cast v2 client and a bundled FFmpeg relay (docs/04).
- Downloads and the local library are in v1 (ADR-005). Recording live channels stays out of v1 unless the user asks.
- Package choices in ADR-002, except media_kit's pub-vs-git choice, which Spike A settles.

## Open questions for the user
- **Spike B discovery:** the step 5 prompt says "Dart CLI … bonsoir", but bonsoir needs the Flutter SDK and can't run in a plain Dart CLI. Recommendation: the CLI uses `multicast_dns` (the documented fallback) plus manual IP, and bonsoir is tested inside the app in Phase 7. Record the answer in docs/decisions.md.
- Exact Google TV model
- Whether a real Windows PC is available for testing
- App name and icon (placeholder "IPTV Player")
- Push the commits to GitHub (`origin`)? Not done without asking.
