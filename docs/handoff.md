# Handoff — 2026-09-15

For the next Claude Code session on this project, and for the user starting it.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Then run Phase 0 from docs/08-phases-and-prompts.md exactly as written: stop after each numbered step and wait for my OK.
```

## Where things stand
- Planning is finished. No app code exists yet, and git is not initialized (Phase 0 step 1 does that).
- The laptop setup in docs/setup.md has **not** been done: Flutter, build tools, libmpv, VA-API tools, and the NVIDIA driver are all missing (checked 2026-09-15; details in the setup state table).
- On 2026-09-15 the laptop was on hotel Wi-Fi. Casting tests need the user's home network and their Google TV.

## Done on 2026-09-15
- **Plan fixes:** every phase now has exit criteria; Phase 0 asks whether a real Windows PC exists and also casts a plain MP4 with seeking; Flutter is installed by the manual method, not the snap.
- **New feature (user request):** download IPTV movies and episodes, plus a local library of the user's own videos; both play offline and cast to Google TV.
  - Spec: docs/09-downloads-and-library.md
  - Decision: ADR-005 in docs/decisions.md
  - Build phase: Phase 8. Settings and polish moved to Phase 9, packaging to Phase 10.
- **Design canvas:** now 18 screens at the same link, https://claude.ai/artifact/TpHN4beb7RandXcH3tEa99. New: Home, Movies grid, Search, Library, Downloads, Settings · Downloads and library, Favorites, onboarding Sync and Pick categories. Working files live in design/; design/iptv-player-ui.html is generated, so don't hand-edit it.

## Instructions for the next session
1. First ask whether the sudo steps in docs/setup.md (sections 1–3) are done and the laptop was rebooted. If not, list the exact commands; never run sudo yourself.
2. Follow the Phase 0 prompt in docs/08 step by step, with the user's OK between steps.
3. During step 4, ask about a real Windows PC. Before step 5, ask for the exact Google TV model and confirm the laptop is on the home network.
4. At the end of the session, update docs/progress.md and docs/decisions.md, and overwrite this file with a new handoff.

## Don't reopen without new evidence
- Flutter + media_kit for desktop, Google TV later (ADR-001).
- Casting through our own Cast v2 client and a bundled FFmpeg relay (docs/04).
- Downloads and the local library are in v1 (ADR-005). Recording live channels stays out of v1 unless the user asks for it.

## Open questions for the user
- Exact Google TV model
- Whether a real Windows PC is available for testing
- App name and icon (placeholder "IPTV Player")
