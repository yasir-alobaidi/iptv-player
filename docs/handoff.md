# Handoff — 2026-09-15 (session 4)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user, 1 minute)
1. Log out. On the login screen, click your name, then the gear icon (bottom right), choose **"Ubuntu"** (not "Ubuntu on Xorg"), and log in.
2. Optional check in a terminal: `echo $XDG_SESSION_TYPE` should print `wayland`.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
I'm logged in with the Wayland session. Run the NVIDIA Wayland runs from the handoff, finish step 4, and stop for my OK.
```

## Where things stand
- **Phase 0 steps 1–3 done**; step 4 (Intel) pushed by the user.
- **Step 4 (Spike A) is done except NVIDIA on native Wayland.** Results in ADR-003 (docs/decisions.md), Findings 1–5.
- **Decided this session:** the media_kit #1404 fix ships as a **pinned patched fork of media_kit_video** (not posted upstream unless the user asks). A real Windows PC exists but isn't available yet, so the Windows run is deferred and doesn't block step 4.
- **ADR-006:** Spike B discovery with multicast_dns + manual IP.
- Step 5 (Spike B, casting) still needs the home network and the Google TV model.

## Done this session (2026-09-15)
- Reboot confirmed: `nvidia-smi` lists the GTX 1650 Ti, driver 595.91.07. The login after the reboot was **"Ubuntu on Xorg"**. GDM doesn't block Wayland (its udev rules prefer Wayland on hybrid NVIDIA laptops, and no runtime config disables it), so switching back is a login-screen choice, no sudo.
- NVIDIA, Xorg, PRIME offload: unpatched pub 1.2.6 hits #1404 (S/W rendering, `nvdec-copy`, up to 112 % of one core on HEVC 4K, zap 525/812 ms). Patched: zero-copy `nvdec` (`cuda-nvdec` interop), 0 drops, ≤ 1.2 % CPU, zap 328/614 ms, process on the GPU in nvidia-smi. Three patched runs agree.
- Intel on a real Xorg session, patched: zero-copy `vaapi`, 0 drops, ≤ 2.3 % CPU, zap 378/624 ms, video confirmed in grabbed frames. Only XWayland (Finding 3) loses zero-copy.
- NVIDIA frame grabs failed: `grab_frame.sh` took the first window named playback_spike, and GTK also creates an unmapped one (BadMatch). A screen-region attempt captured the user's editor instead; those PNGs were deleted. `grab_frame.sh` now picks a viewable window and fails if no PNG is written. NVIDIA's picture is still unconfirmed.
- Earlier results that re-runs overwrote are kept as `results/patched_intel_xwayland.*`, `results/patched_nvidia_x11_run1.*`, and `results/patched_nvidia_x11_run2.*`; `results/patched_nvidia_x11.*` is run 3 (all gitignored).

## Instructions for the next session
1. Check `echo $XDG_SESSION_TYPE` is `wayland` and `WAYLAND_DISPLAY` is set. If not, tell the user how to pick the "Ubuntu" session and stop. `run_matrix.sh` exits 0 even when the app can't open a display, so always check the log ends with a `done` event.
2. From `spike/playback_spike`, one at a time (shared build folder; CPU numbers):
   - `./run_matrix.sh patched nvidia wayland`, then `./run_matrix.sh pub nvidia wayland`
   - Check the log for `H/W rendering` and `SPIKE PATCH … (same)`. Under PRIME offload on Wayland the EGLDisplay may come from Mesa (Intel) while the NVIDIA offload goes through EGL's vendor dispatch; record `hwdec-current` and `hwdec-interop`, and whether nvidia-smi lists the process. `hwdec-current = no` on HEVC 4K is a blocker.
   - `python3 summarize.py patched_nvidia_wayland pub_nvidia_wayland patched_nvidia_x11 patched_intel_wayland` prints the tables.
   - Frame grabs don't work on native Wayland windows. Before `patched nvidia wayland`, ask the user to watch the spike window and confirm the video moves (color bars with a moving diagonal line) on the first sample (H.264 1080p50, 0–18 s) and the 4K sample (about 70–88 s). This is the NVIDIA visual check; record the answer in ADR-003.
3. Add the Wayland NVIDIA results to ADR-003 (Finding 5), set its status to done for Linux, and stop after step 4 with a summary. Wait for the user's OK before step 5 (needs the Google TV model and the home network).
4. At the end: analyze/format the spike, update docs/progress.md, overwrite this file, and commit (the user pushes).

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
