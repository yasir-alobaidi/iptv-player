# Phase 4 — EPG & guide: plan

**Status: proposed 2026-09-19** — waiting for your approval on the seven decisions and the two sketches.

## Context
Phase 3 left a player that zaps, recovers and explains itself, and a `GuideService` seam whose only implementation is Xtream's `get_short_epg` (ADR-010 decision 2): now/next for the previewed channel and its neighbours, cached 5 minutes, nothing for M3U sources. Phase 4 fills that seam with a real guide: XMLTV imported in an isolate, matched to channels, shown as now/next everywhere and as the Guide grid, refreshed daily.

Exit criteria (docs/08): a 300 MB XMLTV import within budget and without jank · the guide grid scrolls smoothly with 50,000 channels × 7 days.

What Phase 4 does **not** own: Home's rows (Phase 5 — the Home screen is still a placeholder, so "now/next on Home favourites" from the phase prompt moves there), the search overlay (Phase 6 — this phase builds the programs FTS index but no search UI), catch-up/archive playback (the detail sheet's Catch-up button stays out until the phase that plays archive), casting (Phase 7).

Carried in, not to be relitigated without new evidence:
- **Hard rule 2 and the Phase 2 spike:** the sync isolate writes **single batches, never a transaction** — a killed isolate's open transaction blocks the database for everyone. The EPG import obeys the same rule, which is exactly why the staging tables below exist.
- **Hard rule 7:** one active stream per source, sync requests serialized with backoff. A guide fetch is another request to the same panel, so it queues behind sync and never runs while a download or a stream is being set up.
- **Hard rule 1:** provider data never crashes us. XMLTV in the wild has bad dates, unknown encodings, unclosed tags and duplicate ids; every one of those is a skipped row with a reason, never an exception.
- **ADR-010:** `redact()` covers the EPG URL too — it lives in the keyring, and the database keeps only its origin.

Working rhythm, as before: one numbered step at a time; after each, analyze + format + tests, a local commit without trailers, and a stop for your review.

## Decisions (my recommendation first in each)
1. **Which guide wins.** Once XMLTV is imported, a channel can have both a matched XMLTV feed and the panel's short EPG. **Recommendation:** XMLTV is the source of truth; the short EPG only answers for a channel with no match or whose guide window has run out (it is also all an M3U source without an XMLTV URL ever has). One `CompositeGuide` in front of both, so screens keep asking `GuideService` and never learn where the answer came from. The alternative — always preferring the panel's own now/next — is one request per channel and wrong as soon as the guide is imported.
2. **Staging tables and the swap.** docs/02 asks for staging plus an atomic swap so the guide never shows half-loaded data. **Recommendation:** the isolate writes batches of ~5,000 rows into `epg_channels_staging` / `epg_programs_staging` (plain batches, no transaction), and when it finishes, the **UI isolate** runs one short transaction that deletes this source's live rows and renames the staged ones into place. A killed import leaves staging rows behind and the live guide untouched; the next launch sweeps them by run id. The alternative (delete-then-insert live, in the isolate) is the exact shape the Phase 2 spike showed can block the whole database.
3. **Schema v5.** **Recommendation:** `epg_channels` (source, xmltv_id, display_name, icon_url), `epg_programs` (source, epg_channel_id, start_utc, end_utc, title, subtitle, description, category — index on `(epg_channel_id, start_utc)`), `epg_mappings` (source, channel_remote_key, xmltv_id — user-made, never touched by sync), the two staging tables, and `programs_fts` (external-content FTS5 over titles and descriptions, triggers as in `search.drift`) built now but queried in Phase 6. Times stay integer epoch ms in their own columns (docs/02). A v4 → v5 migration test on a populated database.
4. **The retention window and the offset.** **Recommendation:** keep now − 1 day to now + 7 days, skipped while parsing so the rows never exist; the number of days is one global setting (Settings → Guide, default 7), while the **time offset stays per source** (`sources.epg_offset_minutes`, already in the schema) and is applied at import. Changing either re-imports rather than re-reading, so the database always holds what the window says.
5. **Refresh scheduling.** **Recommendation:** the guide refreshes when it is older than 24 hours, checked at launch and every hour after; it runs **after** a catalogue sync for that source, never beside it, and one source at a time. Manual "Refresh guide" per source in Settings → Guide. A finished import raises the background toast docs/05 already specifies: "Guide updated · 142 channels matched". A failed import keeps the old guide and says so in Settings, not as a pop-up.
6. **How the grid scrolls.** 50,000 channels × 7 days is far past a widget per program. **Recommendation:** a vertical `ListView` of channel rows over a **shared horizontal offset** (one `ScrollController` driving every row and the time ruler), each row painting only the programs inside the visible time window from a windowed cache; the channel column is a second `ListView` pinned at 220 px and tied to the same vertical offset. The alternative, Flutter's `TwoDimensionalScrollView`, wants cells on a uniform grid, and our cells are time-width — it would fight us at every row.
7. **What the grid asks the database for.** **Recommendation:** one query per visible window — the channels on screen (a page of the same `ChannelRepository` Live TV uses) × the time window, plus one screen of rows above and below and one hour either side, kept in a small LRU cache keyed by `(channel, hour bucket)`. Scrolling fast cancels in-flight queries instead of queueing them. The alternative, loading a whole day for every channel, is the 50k × 7 days problem again.

## Step 1 — The fake provider serves a guide (and the `cut` fault)
- `xmltv.php?username=&password=`: XMLTV generated from the same catalogue the API serves, so ids match; `--epg-days` and `--epg-gzip`, scalable to 300 MB for the benchmark (docs/06 asks for exactly this). `Content-Encoding: gzip` when asked.
- Quirks behind the `quirky` profile and per-request flags, because the app must survive all of them: a programme with no `stop`, a bad date, an unknown timezone, an unknown encoding declared in the XML header, a duplicate channel id, an unclosed tag at the end of the file, and a channel id that matches no stream.
- The **`cut` fault** the soak turned up (ADR-010): the live body's connection is closed mid-stream with no clean end, so mpv's own `reconnect_streamed` reconnects underneath us. It goes in here with the other faults; step 7's suite asserts what the player does.
- Verify: fake-provider tests per quirk and for gzip; a 300 MB generation timed once so the benchmark isn't measuring the generator.

## Step 2 — Schema v5 and the EPG store
- The tables from decision 3, their DAOs, and `EpgRepository` (sealed `Result`, domain models, never drift rows outside `lib/data/`): now/next per channel, a time window per channel page, "the guide's coverage for this source" (first and last programme, matched channel count), and the staging swap.
- The swap: one transaction on the UI isolate, plus a sweep of staging rows whose run is not the current one, called from the same launch path that fails interrupted syncs (`SyncService.startUp()`).
- Verify: DAO tests including the swap under a simulated kill (staging rows left, live guide intact), the v4 → v5 migration test, and an FTS test that a programme inserted, renamed and deleted keeps the index right.

## Step 3 — The XMLTV parser in an isolate
- A streaming parser over the byte stream (gzip decoded on the fly), emitting channels and programmes as they are read — never a DOM, never the whole file in memory. Times like `20260914180000 +0200` → epoch ms UTC, plus the source's offset; the retention window is applied while parsing, so a 300 MB file with a year of data costs only the days we keep.
- Tolerant by rule 1: every bad row is counted and logged with a reason (bad date, missing id, unknown encoding, duplicate); a truncated file imports what it read and reports the truncation rather than failing.
- It runs in the sync isolate infrastructure Phase 2 built (`runSyncWork`-shaped, progress reported back, cancellable, its closure built in a top-level function so it doesn't drag scope along), writing staged batches as it goes.
- Verify: fixture tests for every quirk and every malformed shape (`test_fixtures/xmltv/`), a memory assertion on a generated large file (peak RSS bounded, docs/06's XMLTV budget is +300 MB), and a cancel test.

## Step 4 — Matching, and now/next everywhere
- `EpgMatcher` in the order docs/02 sets: exact `epg_channel_id`/`tvg-id` → case-insensitive id → normalized name (lowercase, quality tags, country and language prefixes, punctuation, collapsed spaces) → the manual mapping, which always wins and is never overwritten by a sync or an import.
- `DbGuide` implements `GuideService` from the imported guide; `CompositeGuide` (decision 1) puts it in front of `ShortEpgGuide`. Nothing in Live TV, the preview or the player OSD changes except what they are given — they already render `NowNext`.
- The unmatched case is visible, not silent: the channel row and the grid row say "No guide information", with the link to the mapping page.
- Verify: matcher unit tests over a corpus of real-shaped names (the fixtures plus the ones from the name-cleanup list in docs/05), tests that a manual mapping survives a re-sync and a re-import, and widget tests that Live TV shows now/next from the database with no network at all.

## Step 5 — Settings → Guide
Not on the canvas (docs/05 lists Settings sections other than Downloads and library as sketch-first). Sketch for approval:

```
Settings › Guide
┌──────────────────────────────────────────────────────────────────────┐
│ Guide                                                                │
│                                                                      │
│ Source  [ Main provider ▾ ]                                          │
│ Guide data    From your provider's XMLTV · updated 2 hours ago       │
│               1,284 of 1,310 channels matched      [ Refresh guide ] │
│                                                                      │
│ Keep          [ 7 days ▾ ]  of guide data                            │
│ Time offset   [ −60 ] minutes        (use when programmes look       │
│                                       shifted by a whole hour)       │
│                                                                      │
│ Unmatched channels (26)                          [ type to filter ]  │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ 201  Arena Sports 1        no guide channel      [ Match… ]      │ │
│ │ 214  Velocity Motors HD    no guide channel      [ Match… ]      │ │
│ │ 233  Summit Outdoor        → summit.outdoor.uk   [ Change ]      │ │
│ └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘

[ Match… ] opens a picker: type a name, the guide's channels ranked by
the matcher's own normalized score, Enter maps, Esc cancels.
```
- Keyboard first, like every Settings page: the unmatched list is one Tab stop with arrows inside (`FocusPane(tabStop: true)`), Enter opens the picker.
- Verify: widget tests for loading, no guide yet, all matched, failed import, and the picker; a keyboard walk.

## Step 6 — The Guide grid
The canvas's `Guide` artboard, read back from the published canvas and identical to `design/Guide.dc.html`: header with day pills (Today, Tomorrow, then weekdays), "Jump to now", a category filter; the grid card inset 16 × 24 with a 44 px ruler (a label each 30 minutes, **240 px per hour**), a 220 px channel column (number, 32 px logo, name), 72 px rows, program cells inset 6 px with 8 px radius — now `#1F2430`, later `#171B23`, past `#0E1116` and dimmed, a `‹` prefix when a programme started before the window — the focus ring `0 0 0 2px #5B8CFF, 0 0 0 6px rgba(91,140,255,.25)`, the red now line (2 px `#FF4D5E`) with its time pill on the ruler, and the dashed "No guide information · Match to a guide channel" row for an unmatched channel. All of it from `lib/design/` tokens (hard rule 9), so these hex values land in the token file, not in the screen.
- Scrolling and data per decisions 6 and 7; the now line is redrawn on a minute timer, not per frame.
- Keyboard: ←/→ between programmes on a channel (moving the time window when it leaves the screen), ↑/↓ between channels, PageUp/PageDown by a screen, Home = now, Enter = the detail sheet, Esc = back. G from anywhere opens the Guide, Ctrl+3 as today.
- The program detail sheet is **not** on the canvas. Sketch for approval:

```
        ┌───────────────────────────────────────────────┐
        │ Continental Cup · Semi-final                  │
        │ Tue 15 Sep · 8:00 – 10:00 PM · Sport          │
        │ ───────────────────────────────────────────── │
        │ Arena Sports 1 · 201                          │
        │                                               │
        │ The two surviving sides meet at Riverside      │
        │ Arena for a place in Sunday's final. Coverage │
        │ starts with build-up from the tunnel.         │
        │                                               │
        │ [ Watch channel ]  [ ☆ Favourite ]   (Esc)    │
        └───────────────────────────────────────────────┘
```
  A centred sheet over a scrim, first focus on Watch, Esc closes (the global Esc action), Tab cycles inside it. "Watch channel" plays the channel now — it does not pretend to play a programme that has ended; a past programme shows the same sheet with Watch replaced by a dimmed "Already finished", and Catch-up arrives with the archive phase.
- Every state (hard rule 4): loading skeleton rows, no source, no guide imported yet ("No guide yet. Import one from Settings → Guide."), a guide that covers nothing today, an import running (a thin progress line in the header, the old guide still shown), and offline.
- Verify: widget tests per state, a keyboard walk, goldens at 1280×800 and 1920×1080.

## Step 7 — Refresh scheduling, the toast, and the phase exit
- The scheduler from decision 5 (launch check, hourly, after a sync, one at a time, manual refresh), the "Guide updated · N channels matched" toast, and diagnostics: the import's counts and skipped-row reasons in the same place the sync report lives.
- **Exit measurements**, both in tests tagged `benchmark` so CI doesn't time them: a 300 MB import (≤ 4 min, peak RSS +300 MB, no UI frame > 32 ms — the fake provider in its own process, per docs/06) and a guide scroll over the `large` profile with 7 days imported (no frame > 16 ms at 60 Hz, measured with `flutter drive --profile`).
- An integration test against the fake provider: import a guide → Live TV shows now/next → open the Guide → arrow to a programme → Enter → Watch → the player opens that channel.
- Then the phase exit: numbers into docs/progress.md, ADR-011 Accepted, handoff rewritten.

## Verification (every step and at the exit)
`flutter analyze` · `dart format --set-exit-if-changed lib test integration_test tools` · `flutter test` (unit, widget, golden) · the fake-provider suite · the integration tests one file per run. Parsers get fixture tests including malformed input, state logic gets unit tests with a fake clock, every screen state gets a widget test, and the two budgets above are measured, not assumed (hard rule 10).

## Risks
- **The 300 MB budget is the whole phase's risk.** If a streaming parse in Dart can't hold 4 minutes and +300 MB, the fallback is a coarser first pass (channels and the retention window only) before the full parse, and I bring you numbers before choosing.
- **Matching quality is a long tail.** The four rules will leave channels unmatched on a real provider; that is what the mapping page is for, and the unmatched count is shown rather than hidden.
- **A provider whose XMLTV is one huge line** breaks naive chunk splitting; the parser is fed by bytes, not lines, and a fixture covers it.
- **Your provider's guide is unknown to me.** Once the fake-provider path is green I'd like one import from your real panel (no stream needed, so no connection is used) to see its real shape — with your go-ahead, as agreed for anything touching your provider.
