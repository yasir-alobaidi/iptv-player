# Handoff — 2026-09-15 (session 7)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Phase 0 is finished. Phase 1 (Foundation) needs your OK on the GO decision in ADR-007 (summary under "Where things stand"). Phase 1 doesn't need the TV.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
The Phase 0 GO (ADR-007) is OK. Start Phase 1 (Foundation) as written in docs/08-phases-and-prompts.md: propose the plan first and stop for my OK.
```

## Where things stand
- **Phase 0 done; GO for Linux proposed** (ADR-007). Windows hardware decoding is still unverified (no PC yet).
- Playback: media_kit 1.2.6 with our patched media_kit_video in `third_party/media_kit_video` (ADR-003): zero-copy `vaapi` / `nvdec`, ≤ 2.7 % CPU, zap p95 ≤ 624 ms. `tools/vendor_media_kit_video.sh` rebuilds the copy from pub.dev and `third_party/patches/`.
- Casting (ADR-004, docs/04), on a Chromecast with Google TV (4K) with our own Cast v2 client, the Default Media Receiver, and the FFmpeg relay: H.264 relay-copy as HLS/TS; HEVC as one continuous fragmented MP4 (HLS fMP4 segments stutter with open-GOP HEVC); a plain MP4 over Range seeks fine. 4K needs the TV's full-bandwidth HDMI mode (Samsung Input Signal Plus, now on). A continuous stream that ends is reported FINISHED, so the app re-LOADs.

## Done this session (2026-09-15)
- TV tests with the user watching (they allowed testing for the session): continuous fMP4 4K HEVC smooth; HLS fMP4 control still stutters; H.264 4K with no loop freeze; a deliberate stream cut → IDLE/FINISHED with no reconnect
- Cast spike: `--progressive` relay mode, MKV-looping test source, `tool/progressive_smoke.dart` for checks without a TV
- `third_party/media_kit_video`, `third_party/patches/media_kit_video-2.0.1-egl-display.patch`, `tools/vendor_media_kit_video.sh`; `run_matrix.sh vendored` confirmed zero-copy playback from that copy
- ADR-007 written; ADR-002/003/004, docs/01/03/04/06, docs/setup.md, CLAUDE.md, and progress.md updated

## Instructions for the next session
1. Don't start Phase 1 without the user's OK on ADR-007. If it's missing, ask and stop. When the OK comes, mark ADR-007 Accepted.
2. Phase 1 is written in docs/08-phases-and-prompts.md: propose the plan first (plan mode) and stop after each numbered step for review.
3. Carry these Phase 0 results into Phase 1: root `pubspec.yaml` with `dependency_overrides: media_kit_video: path: third_party/media_kit_video`; root `analysis_options.yaml` excluding `third_party/**` and `spike/**`; formatting of first-party folders only (`dart format --set-exit-if-changed lib test integration_test tools`), in CI too. Phase 3 sets `cache-on-disk=no`.
4. The fake provider (Phase 1 step 6) loops MKV remuxes of the samples, never the `.ts` files (docs/06).
5. Casting to "Living Room TV": ask first (AskUserQuestion) unless the user allows testing for the session; one announced, watched cast at a time.
6. Commit messages have no Co-Authored-By or other trailers. Commit locally; the user pushes.
7. At the end: analyze/format, update docs/progress.md, overwrite this file, and commit.

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001); the patched media_kit_video lives in `third_party/` (ADR-003). fvp only if Windows fails.
- Casting through our own Cast v2 client, the Default Media Receiver, and a bundled FFmpeg relay (docs/04, ADR-004). H.264 → HLS/TS; HEVC → one continuous fragmented MP4.
- The `hlsSegmentFormat` fields aren't sent; the receiver ignores them.
- The 4K failures were the TV's HDMI mode, not the relay or the codec.
- Downloads and the local library are in v1 (ADR-005).
- Package choices in ADR-002.
- Discovery: bonsoir in the app, with multicast_dns + manual IP as the proven fallback (ADR-006, ADR-004).
- The app doesn't require NVIDIA; Intel meets every budget. A "use discrete GPU" option is a Phase 10 packaging question.

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run
- App name and icon (placeholder "IPTV Player")
