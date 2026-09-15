# Handoff — 2026-09-15 (session 3)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user, 2 minutes)
1. **Reboot.** The NVIDIA driver (595-open) was installed at 03:05, but the laptop hasn't rebooted since 01:08, so the old `nouveau` driver is still loaded.
2. After the reboot, in a terminal: `nvidia-smi` should list the GTX 1650 Ti.
3. Decide whether you have a real Windows PC (not a VM) for a playback test.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 0 step 4 is done on Intel. Check nvidia-smi, then run Spike A on NVIDIA as the handoff describes, finish step 4, and stop for my OK.
```

## Where things stand
- **Phase 0 steps 1–3 done** and pushed by the user.
- **Step 4 (Spike A) is done on Intel**, not yet on NVIDIA or Windows. Results are in ADR-003 (docs/decisions.md).
- **ADR-006:** the user approved discovery with multicast_dns + manual IP in Spike B; bonsoir is tested inside the app in Phase 7.
- Step 5 (Spike B, casting) still needs the home network and the Google TV model.

## Done this session (2026-09-15)
- Setup verified: Flutter 3.47.4 on PATH, Linux toolchain ✓, VA-API (iHD 22.3.1) lists H.264, HEVC, and HEVC 10-bit, libmpv 0.34.1 (FFmpeg 4.4.2). The NVIDIA driver isn't loaded yet (needs the reboot).
- `spike/playback_spike`: Flutter Linux app with media_kit plus a loopback server that plays each sample as endless MPEG-TS (bundled ffmpeg `-re -stream_loop -1 -c copy`). The overlay shows mpv stats and process CPU; automatic runs write JSONL.
  - `run_matrix.sh <pub|git|patched> <intel|nvidia> [wayland|x11]` builds and runs one combination and writes to `results/` (gitignored)
  - `summarize.py [labels…]` prints the ADR tables
  - `grab_frame.sh out.png [delay]` grabs the spike window (X11 runs only)
- **Key finding:** media_kit #1404 reproduces on pub 1.2.6 and main@c533e44 (Wayland and X11): `EGL display or context is invalid` → S/W rendering → `vaapi-copy` and heavy drops at 50 fps. `spike/vendor/media_kit_video_egl_display.patch` (EGLDisplay from GDK instead of the platform thread) fixes it: H/W rendering, zero-copy `vaapi`, 0 drops, ≤ 1.7 % CPU, zap p50/p95 320/597 ms. Frames grabbed from the window show real video.
- Under XWayland, zero-copy fails (libva-x11 is DRI2-only), so it falls back to `vaapi-copy`. Native Wayland is fine.
- All docs/03 libmpv option and property names verified against 0.34.1 (notes in ADR-003).

## Instructions for the next session
1. `nvidia-smi` must work. If it doesn't, check `lsmod | grep nvidia` and give the user the exact fix; never run sudo.
2. NVIDIA runs, from `spike/playback_spike`:
   - `./run_matrix.sh patched nvidia wayland`, then `./run_matrix.sh pub nvidia wayland`
   - Each run takes about 6 minutes, and the spike window appears on the user's screen. Run one at a time (shared build folder; CPU numbers).
   - Check the log for `H/W rendering` and `SPIKE PATCH … (same)`. Under PRIME offload the EGLDisplay may belong to NVIDIA while VA-API is Intel. Record `hwdec-current` (expect `nvdec`/`nvdec-copy` or `vaapi-copy`) and whether HEVC 4K is GPU-decoded. `hwdec-current = no` on HEVC 4K is a blocker.
   - `results/<label>.nvidia-smi.txt` is captured 25 s in and shows whether the process is on the GPU.
   - If NVIDIA hwdec fails or playback is unstable, build an fvp comparison spike (fvp 0.38.1 is already in the pub cache; its Linux texture renders in Flutter's raster-thread context, so #1404 doesn't affect it).
3. Ask about the Windows PC (step 4). If yes, give steps; the patch is Linux-only, so Windows uses pub media_kit.
4. Stop after step 4 with a summary and wait for the user's OK. Then step 5 needs the Google TV model and the home network.
5. At the end: update docs/progress.md and docs/decisions.md (ADR-003), overwrite this file, and commit.

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001); fvp is the only playback fallback.
- Casting through our own Cast v2 client and a bundled FFmpeg relay (docs/04).
- Downloads and the local library are in v1 (ADR-005).
- Package choices in ADR-002. media_kit's source (pub, git, or pinned patched fork) is decided in step 6.
- Spike B discovery: multicast_dns + manual IP (ADR-006).

## Open questions for the user
- Exact Google TV model
- Whether a real Windows PC is available for testing
- App name and icon (placeholder "IPTV Player")
- How to ship the media_kit fix: pinned fork (recommended) vs offering the patch upstream on #1404 (outward-facing; only with the user's OK) vs fvp. Decided in step 6
