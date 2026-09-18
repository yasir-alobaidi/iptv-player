# Phase 2 — Sources, onboarding, sync: plan

**Status: approved 2026-09-18** — all four recommendations below accepted as written, and the three layout sketches with them.

## Context
Phase 1 left a running app with no data in it: the design system, the keyboard-first shell, a drift database with only `sources` and `settings`, and a fake provider that already serves the whole Xtream API (ADR-008). Phase 2 is where the app first shows a real catalogue: a source is added, its credentials are stored safely, its data is synced into the database, and the user picks what they want to see.

Exit criteria (docs/08): the sync budget is met · every quirk fixture passes · onboarding works against the fake provider **and against your real provider**.

What Phase 2 does **not** own: XMLTV and the guide (Phase 4 — the fake provider's `xmltv.php` arrives with it), the Live TV screen and playback (Phase 3), search and favourites polish (Phase 6). Phase 2 stops at "the data is in the database and the user chose their categories".

Carried in from Phase 1, not to be relitigated without new evidence (ADR-008): `DateTime` columns are ISO-8601 UTC text; provider items are keyed by `(source_id, remote_key)`; no password ever reaches the database; parsing is tolerant and bad rows are skipped, never thrown at the UI; the fake provider's `quirky` profile turns on every docs/02 quirk at once.

Working rhythm, as in Phase 1: one numbered step at a time; after each, analyze + format + tests, commit locally without trailers, and stop for your review.

## Decisions (approved 2026-09-18: the recommendation in each)
1. **Your real provider.** The exit criterion needs credentials and your own hands — I can't reach a real panel, and I won't ask you to paste credentials into this session. Plan: you run the onboarding flow yourself at the end of step 6, on your own machine, and tell me what broke. Anything you paste from a failure gets `redact()`ed before it lands in a log or a doc.
2. **`favorites` and `watch_history` tables: not in this phase** (my recommendation). They belong to the phases that write them (3, 5, 6), migrations are cheap, and mark-and-sweep only touches provider tables so nothing is lost by waiting. Say the word if you'd rather have the whole docs/02 schema in one migration.
3. **M3U file *and* M3U URL both in this phase** (my recommendation): the parser is the same code and the file picker already exists.
4. **How hard to push on the frame budget.** docs/06 asks for "no UI frame over 32 ms during sync". Timeline-based frame assertions in integration tests are historically flaky. My plan: assert the sync *duration* budget in the integration test, and measure frame times in a separate, manually-run benchmark whose numbers go in progress.md — rather than a flaky gate in CI. Tell me if you want it as a hard gate instead.

## Step 1 — Schema v2: the catalogue tables
- New tables from docs/02: `categories`, `channels`, `movies`, `movie_details`, `series`, `episodes`, each keyed by `(source_id, remote_key)` with a unique index on that pair, plus the display/hidden/sort columns docs/02 lists.
- Sync bookkeeping: a `last_seen_run` column (or a per-run marker table) so mark-and-sweep can delete what a completed run didn't see, and nothing else.
- FTS5: `channels_fts`, `movies_fts`, `series_fts` (programs_fts is Phase 4). Decide and record whether they are kept current by SQL triggers or by the repository's own writes — triggers are fewer moving parts, repository writes are easier to batch during a 50k sync. I'll measure both in step 5 if it isn't obvious.
- Migration v1 → v2 with `drift_dev make-migrations`, the new dump committed, a verifier test, and a test that migrates a **populated** v1 database rather than an empty one.
- DAOs for each table, batched (`batch()`), with unit tests on an in-memory database.
- Verify: analyze, format, tests; the schema test passes for v1 and v2.

## Step 2 — Credentials and the source repository
- `CredentialStore` in `lib/core/`: `read`/`write`/`delete`, keyed by source id. Implementation over flutter_secure_storage in `lib/data/`, and an in-memory fake for tests. **CI has no keyring**, so tests and the integration test use the fake; the real store is exercised by hand on this machine and the result recorded.
- `SourceRepository`: add, edit, remove, list, reorder; writes `credential_ref` only, never a password; deleting a source deletes its secret.
- A test asserts that a full source round-trip leaves no password in the database file and nothing credential-shaped in the log (hard rule 3).
- Verify: the secure store works on this machine (manual, recorded), the fake covers the tests.

## Step 3 — The Xtream client
- `XtreamClient` on dio in `lib/data/providers/xtream/`: account, live/vod/series categories and lists, `get_vod_info`, `get_series_info`, `get_short_epg`. Returns `Result`, never throws across the layer.
- **Tolerant DTOs** (freezed + hand-written converters): numbers as strings, `""`/null for missing, `info: []` vs `{}`, episodes as a map or a list, dangling and missing `category_id` → "Uncategorized", junk `stream_icon`, HTML entities and stray whitespace, invalid UTF-8 (`allowMalformed: true`), `exp_date` null. **One fixture test per quirk**, plus a run against the fake provider's `quirky` profile so the quirks are tested together as well as apart.
- Request discipline: one request at a time per source, backoff on 429 and 5xx, a configurable User-Agent, and the URL always rebuilt from the original server (docs/02: redirect tokens expire). Big list bodies are decoded in an isolate.
- `StreamUrlBuilder` is **not** here — it belongs to Phase 3 with the player.
- Verify: fixtures, the fake provider's three profiles, and a manual run against the `large` profile to see the isolate decode hold up.

## Step 4 — M3U (URL and file) and the fake provider's `get.php`
- Streaming line-by-line parser in an isolate, gzip transparently handled, 50 MB+ files without loading them whole.
- Attributes per docs/02 (`tvg-id`, `tvg-name`, `tvg-logo`, `group-title`, `tvg-chno`, catchup*), `#EXTVLCOPT` for user agent and referrer, unknown directives such as `#KODIPROP` ignored safely.
- Classification by URL path (`/movie/` → movie, `/series/` → episode, else live), and the **stable identity hash** of tvg-id + name + credential-free URL path, so favourites and history survive a refresh.
- Fixtures: a clean playlist, a malformed one (truncated mid-line, bad attributes, CRLF, BOM, invalid UTF-8), a gzip one, and a generated 50 MB one for the isolate and memory check.
- The fake provider gains `get.php` (m3u_plus output, mixing live/movie/series lines, honouring the profile's quirks) so the parser is tested against a server rather than only fixtures.
- Verify: fixtures, the 50 MB file parsed without a frame drop in a widget test harness, `get.php` round-tripped.

## Step 5 — The sync engine
- `SyncEngine` in `lib/features/sources/domain` + `lib/data/sync/`: runs in a **background isolate with its own database connection** (drift's `computeWithDatabase`; if the connection can't be handed over cleanly, a `DriftIsolate` — this is the one unknown in the phase and gets spiked first, before the rest of the step is written).
- Stages in order: account → categories → live → movies → series, emitting progress events (stage, counts, current item) that the UI shows. EPG is not a stage in this phase.
- Upsert by `(source_id, remote_key)` in batches of ~5,000 per transaction; **mark-and-sweep** removes what the run didn't see; hidden flags, renames, sort order and (later) favourites, history and mappings are preserved — with a test that sets all of them, re-syncs a changed catalogue, and asserts they survived.
- One sync per source at a time; a failed sync **keeps the previous data** and surfaces a non-blocking banner with Retry; a cancelled sync leaves the database consistent.
- Triggers: after onboarding, on app start when `last_synced_at` is older than `refresh_hours` (default 12), and manual refresh.
- Verify: the `large` profile synced end to end (50k channels + 30k movies) inside the 60 s budget, measured and written into progress.md; the preserve-user-data test; a kill-the-app-mid-sync test.

## Step 6 — Onboarding
- The flow from docs/05: Welcome → choose type (Xtream / M3U URL / M3U file) → credentials with inline validation and **Test connection** → result card (status, expiry, connections, server time zone) → sync progress with live counts → **Pick what you watch** → Home.
- The canvas has `Onboarding`, `OnboardingSync` and `OnboardingCategories`; **the Welcome step has no artboard** — the sketch below needs your approval first (docs/05 asks for exactly that).
- Every screen has loading, empty, error and offline states (hard rule 4), is fully keyboard navigable with visible focus (hard rule 5), and shows `failureMessage()` text, never a raw exception.
- Widget tests for every state of every step; a golden for the Welcome and Pick-categories screens.
- **You run this against your real provider at the end of this step.**

## Step 7 — Settings → Sources, the Categories manager, and the shell's source slots
- Settings → Sources: the list, add/edit/remove/refresh, account details, reorder. **No artboard — sketch below.**
- The Categories manager: hide, reorder, rename per source, reusing the Pick-categories layout as docs/05 instructs. **Sketch below.**
- The shell's `shellSourceProvider` and `shellSyncStatusProvider` finally get real data: the top bar's source switcher, the sync status line, and an expiry banner when `exp_date` is near or past. The shell itself does not change — the providers are overridden by this feature, as ADR-008 requires.
- Verify: widget tests per state; the shell tests still pass unchanged.

## Step 8 — Integration, performance, and the phase exit
- Integration test against the fake provider: onboarding → sync (the `large` profile) → category picker → Home shows data. Uses the in-memory credential store.
- The sync duration budget asserted in the test; frame times measured by a separate benchmark script (see decision 4) and recorded in progress.md.
- CI: the new integration test runs in the existing Linux job; the fake provider is started and stopped by the test, not by the workflow.
- Docs at the end of the phase: ADR-009 (Phase 2 choices — the sync isolate mechanism, FTS maintenance, the tolerant-decoding approach, the M3U identity hash), docs/02 corrected wherever the real API disagreed with it, docs/05 updated with the three approved layouts, progress.md and handoff.md.

## Layouts that need your approval (docs/05 has no artboard)
**Welcome (onboarding step 1)** — one card, centred, 560 px wide:
```
┌──────────────────────────────────────────────────────────┐
│                        ▶  IPTV Player                    │
│                                                          │
│            Your channels, movies and series              │
│                 in one calm place.                       │
│                                                          │
│   Add the provider you already pay for. Nothing is       │
│   uploaded anywhere; your credentials stay on this PC.   │
│                                                          │
│                 [ Add your first source ]                │
│                                                          │
│   Already have a playlist file?  Open a file instead     │
└──────────────────────────────────────────────────────────┘
```
**Settings → Sources**:
```
Sources                                    [ + Add source ]
┌──────────────────────────────────────────────────────────┐
│ ● Northwind TV            Xtream · Active · exp 3 Nov    │
│   12,340 channels · 8,021 movies · synced 12 min ago     │
│                        [Refresh] [Edit] [⋯ Remove]       │
├──────────────────────────────────────────────────────────┤
│ ● Backup playlist         M3U URL · never synced         │
│   Last attempt failed: the server took too long          │
│                        [Retry]   [Edit] [⋯ Remove]       │
└──────────────────────────────────────────────────────────┘
Drag to reorder · the first source is the default
```
**Categories manager** (the Pick-categories layout plus per-row controls):
```
Categories · Northwind TV          [ Live | Movies | Series ]
[ Search categories            ]   [Show hidden] [Select all]
┌──────────────────────────────────────────────────────────┐
│ ☑ UK | Sports            412 channels     ⋮⋮  ✎ rename   │
│ ☑ UK | General           128 channels     ⋮⋮  ✎ rename   │
│ ☐ DE | Kids               64 channels     ⋮⋮  ✎ rename   │
└──────────────────────────────────────────────────────────┘
Hidden categories stay hidden after a re-sync.
```

## Verification (per step and at exit)
- Every step: `flutter analyze`, the format check over `lib test integration_test tools`, `flutter test`, the fake provider's `dart test`, and `flutter build linux --debug`.
- Steps 6–7: `flutter run -d linux`, walked with the keyboard only, every state visited.
- Exit: the sync budget measured on the `large` profile · every quirk fixture green · onboarding working against the fake provider **and your real one** · CI green.

## Risks
- **drift in a background isolate** with its own connection is the phase's one real unknown; it is spiked at the start of step 5 rather than discovered at the end of it.
- **flutter_secure_storage needs a keyring**, which CI has not got: the fake store keeps CI honest, but the real store is then only ever tested by hand on this machine.
- **FTS5 maintenance during a 50k sync** may cost more than the budget allows; triggers versus repository writes is measured, not guessed.
- **A real provider will have quirks the fake does not.** The fake gets a new toggle for each one we meet, so the fixture suite grows from reality rather than from imagination.
- Frame-time assertions are flaky; decision 4 keeps them out of the gate unless you want them in.
- A 50 MB M3U and a 50k-row sync both risk memory growth that only shows up over a long session; the soak script is Phase 3, so this phase only watches peak memory.
