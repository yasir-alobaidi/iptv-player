# Handoff — 2026-09-15 (session 6)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Step 6 (GO / NO-GO) needs your OK on step 5 (summary under "Where things stand"). It doesn't need the TV. If you want the likely fix for the 4K HEVC stutter tried on the TV in that session, say so in the prompt; Claude will still ask before every cast.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Step 5 is OK. Start Phase 0 step 6 (GO / NO-GO) and stop for my OK.
```

## Where things stand
- **Phase 0 steps 1–5 done** (step 4 on Linux only; Windows deferred). Step 5 results are in ADR-004 (docs/decisions.md), Findings 1–8.
- Casting works end to end with our own Cast v2 client, the Default Media Receiver, and the FFmpeg relay on a Chromecast with Google TV (4K): H.264 relay-copy over HLS/TS (1080p50, 1080p25 with AC-3 → AAC, 4K), HEVC over HLS/fMP4 at 1080p, and a plain MP4 over Range with working seeks and pause.
- Open problem: open-GOP HEVC (x265's default) stutters over HLS fMP4 because FFmpeg's segmenter mistimes frames at every cut (proven on the laptop). One continuous fragmented MP4 response is clean on the laptop; it hasn't been tried on the TV.
- 4K only works with Samsung's Input Signal Plus on for the Chromecast's HDMI port (now on). Without it, every 4K stream fails with a bare LOAD_FAILED.
- The H.264 4K freeze the user saw came from the spike's looping test source, not the TV or the relay (Finding 8).

## Done this session (2026-09-15)
- Git history: Co-Authored-By trailers removed from all 5 commits; the user force-pushed
- `spike/cast_spike`: `discover` and `cast` commands, generated `CastMessage` protobuf, heartbeat, tolerant message parsing, shelf relay and Range server, FFmpeg relay with PID files and a startup sweep, JSONL results
- On-device runs with the user watching: the three required live samples, the VOD file with seeks, extra 1080p HEVC and 4K H.264 cases, segment-format variants, and 4K before and after the TV setting
- Laptop checks: fMP4 frame timing (open vs closed GOP, HLS vs one continuous stream) and the test source's loop point
- ADR-004 written; progress.md and the spike README updated

## Instructions for the next session
1. Don't start step 6 without the user's OK on step 5. If it's missing, ask and stop.
2. **Never cast to "Living Room TV" or send it any Cast command without asking first (AskUserQuestion) and getting a yes.** One watched cast at a time; say what will appear on screen. The user stopped testing on 2026-09-15 after back-to-back diagnostic casts looked like a fail loop.
3. Step 6 is written in docs/08-phases-and-prompts.md: GO / NO-GO for Linux in docs/decisions.md; update docs/03, docs/04, and docs/setup.md with what changed. For docs/04 that includes: a second HEVC path for open-GOP sources (candidate: one continuous fragmented MP4), learning maximum resolution from a bare LOAD_FAILED, BUFFERING isn't a stall, `ca` bit 0 marks video devices, `md` can't seed capabilities, the receiver ignores the segment-format fields, and whether to send LOAD after more than 2 segments. For docs/setup.md: Samsung Input Signal Plus for 4K. Also set up the pinned patched media_kit_video fork (ADR-003).
4. Commit messages have no Co-Authored-By or other trailers. Commit locally; the user pushes.
5. At the end: analyze/format, update docs/progress.md, overwrite this file, and commit.

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001); media_kit_video as a pinned patched fork (ADR-003). fvp only if Windows fails.
- Casting through our own Cast v2 client, the Default Media Receiver, and a bundled FFmpeg relay works on the device (docs/04, ADR-004). The receiver's HLS player is Shaka.
- The `hlsSegmentFormat` value doesn't matter on current receivers: `"fmp4"`, `"FMP4"`, `"bogus"`, and no field all play.
- The 4K failures were the TV's HDMI mode, not the relay or the codec.
- Downloads and the local library are in v1 (ADR-005).
- Package choices in ADR-002.
- Spike B discovery: multicast_dns + manual IP (ADR-006); it works next to avahi-daemon.
- The app doesn't require NVIDIA; Intel meets every budget. A "use discrete GPU" option is a Phase 10 packaging question.

## Open questions for the user
- The second Google TV doesn't answer on the network (only "Living Room TV" and a Nest Mini do). Is it on another network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run
- App name and icon (placeholder "IPTV Player")
