# Handoff — 2026-09-15 (session 5)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Step 5 (Spike B, casting) needs:
1. Your OK on step 4 (summary under "Where things stand").
2. Your exact Google TV model: Chromecast with Google TV 4K or HD, Google TV Streamer, or a TV with Google TV built in.
3. The Google TV switched on and on the same home network as the laptop.

Either login session works for step 5 ("Ubuntu" or "Ubuntu on Xorg").

## Start prompt
Open Claude Code in this folder and paste (fill in the model):

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Step 4 is OK. My Google TV is: <model>. It's on and on the same network as the laptop. Start Phase 0 step 5 (Spike B) and stop for my OK.
```

## Where things stand
- **Phase 0 steps 1–4 done on Linux.** Step 4 results are in ADR-003 (docs/decisions.md), Findings 1–5, status "Done for Linux (Windows deferred)".
- media_kit #1404 hits every unpatched build, on both GPUs and both session types. With `spike/vendor/media_kit_video_egl_display.patch`, Intel (`vaapi`) and NVIDIA (`nvdec`) play zero-copy on native Wayland and Xorg: 0 drops, ≤ 2.7 % CPU, zap p95 ≤ 624 ms. The one exception is Intel under XWayland (Finding 3).
- Decided: ship the fix as a pinned patched fork of media_kit_video (ADR-003). The Windows run waits for the PC. Spike B discovery uses multicast_dns + manual IP (ADR-006).

## Done this session (2026-09-15)
- Confirmed the "Ubuntu" (Wayland) login: `XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-0`.
- NVIDIA, native Wayland, unpatched pub 1.2.6: #1404 (`EGL display or context is invalid` → S/W rendering), `nvdec-copy`, 0 drops, 3.0–9.7 % CPU (117 % of one core on HEVC 4K), zap 541/823 ms. Matches Xorg.
- NVIDIA, native Wayland, patched: same EGLDisplay, H/W rendering, zero-copy `nvdec` on every H.264/HEVC sample, 0 drops (8 during the codec switch), 1.4–2.7 % CPU, zap 342/624 ms (327/338 with a burst), process on the GPU in nvidia-smi. CPU is about twice Xorg's (one run each); far under budget, not investigated.
- NVIDIA picture confirmed by eye. The user missed the window during the full run, so a short patched run (`--auto samples --only h264_1080p50_aac.ts,hevc_2160p25_eac3.ts`) was repeated while they watched; both samples showed moving video. Its results are `results/patched_nvidia_wayland_visual.*`; `results/patched_nvidia_wayland.*` is the full run (all gitignored).
- ADR-003 finished for Linux; progress.md updated. Spike analyze and format are clean (no spike code changed).

## Instructions for the next session
1. Don't start step 5 without the user's OK on step 4 and the Google TV model. If either is missing, ask and stop.
2. Step 5 is Spike B as written in docs/08-phases-and-prompts.md; read it and docs/04-casting.md first. Discovery follows ADR-006. Confirm on the device the HLS segment format string sent on the wire (`"fmp4"` vs `"FMP4"`, see Known issues in progress.md).
3. Record results in ADR-004, stop with a summary, and wait for the user's OK before step 6.
4. At the end: analyze/format, update docs/progress.md, overwrite this file, and commit (the user pushes).

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001); media_kit_video as a pinned patched fork (ADR-003). fvp only if Windows fails.
- Casting through our own Cast v2 client and a bundled FFmpeg relay (docs/04).
- Downloads and the local library are in v1 (ADR-005).
- Package choices in ADR-002.
- Spike B discovery: multicast_dns + manual IP (ADR-006).
- The app doesn't require NVIDIA; Intel meets every budget. A "use discrete GPU" option is a Phase 10 packaging question.

## Open questions for the user
- Exact Google TV model
- When the Windows PC is available for the Windows playback run
- App name and icon (placeholder "IPTV Player")
