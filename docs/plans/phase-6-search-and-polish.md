# Phase 6 — Search, favorites, names and hiding: plan

**Status: for your approval (written 2026-09-29).** Once approved, what is built and every departure from this plan go into ADR-013 (docs/decisions.md) as the steps land.

## Context
Phase 5 finished Movies, Series and Home. Four things are still missing or rough:
- **Search** is a frame with no results.
- **Favorites** is a placeholder screen.
- **Channel names** are shown as the provider wrote them (`UK: BBC One ᴴᴰ`).
- **Hiding** works in a few places but can't be undone from one place.

Exit criteria (docs/08):
- Ctrl+K search returns grouped results on the 50k-channel / 30k-movie fake dataset, and works with the keyboard alone.
- Favorites' order and groups survive a restart and a re-sync.
- Name cleanup tests cover every pattern in docs/05.
- Hidden items stay hidden in Live TV, Guide, Search and Home, and can be restored from Settings.

Already in place, so the phase starts further along than docs/08 suggests:
- **The search index.**
  - FTS5 tables for channels, movies, series and programmes (`search.drift`, schema v2 and v5), kept current by triggers.
  - A migration test proves the index works on an upgraded database.
  - Nothing queries it yet.
- **The overlay's frame** (Phase 1):
  - Ctrl+K, `/` and the top bar's field open it; Esc or a click on the scrim closes it.
  - It is a route, not a dialog (ADR-008), with the canvas's 760 px panel and 64 px query bar.
- **Favorites and names in the database:**
  - `favorites` already has `group_name` and `sort_order` (schema v4). Nothing writes either.
  - F toggles a favorite in Live TV, the grids, the details pages and Home.
  - `channels.display_name` is the user's rename. Sync never writes it. Live TV has Rename… with "Use provider's name".
- **Hiding:**
  - Live TV has Hide channel / Show channel and, in an empty category, Show hidden channels.
  - Settings → Categories hides, reorders and renames categories.
  - The Guide and Home already leave hidden channels out.
- **Name rules for matching:**
  - `normalizeChannelName` (Phase 4) already strips country and quality tags to match channels to the guide.
  - A 144-line corpus of real-shaped names pins how it behaves.
  - It lower-cases and removes punctuation, so it can't be shown. Its tag tables are where cleanup starts.
- **Test data:** the fake panel's channel names already carry `UK: `, `|EN| `, `[US] `, `FR | ` and HD / FHD / UHD / 4K / SD / H265.

What Phase 6 does **not** own:
- **The Library group in search** and the DOWNLOADED badge (Phase 8).
- **Cast** in the item menus (Phase 7).
- **"Remind me" on upcoming programmes.** The canvas draws it, but see decision 5.
- **A switch that turns name cleanup off** (Settings → Appearance, Phase 9). Until then, Rename fixes any single name.
- **The on-screen keyboard for search** (Google TV).

Carried in, not to be relitigated without new evidence:
- **Hard rule 1:** a name that cleans to nothing, or a search that FTS can't parse, never throws.
- **Hard rule 2:** search runs on the database isolate, and lists stay windowed.
- **ADR-009:**
  - user-owned columns (`display_name`, `is_hidden`, a category's `sort_order`) are never written by sync;
  - favorites are keyed by remote key, so they survive a re-sync that renumbers rows;
  - triggers are rebuilt after every upgrade.
- **ADR-012:** a list re-reads on a revision and in place, so it never loses the focused row.

Working rhythm, as before: one numbered step at a time. After each: analyze, format, `TZ=UTC flutter test`, a local commit without trailers, and a stop for your review.

## Decisions (my recommendation first in each)

1. **Cleaned names are stored, not worked out on screen.**
   - **Recommendation:** schema v7 adds `channels.clean_name` and `channels.quality`.
     - Sync fills both, in its isolate, from the provider's name. They are provider-derived, so a re-sync rewrites them.
     - `display_name` stays the user's rename.
     - What a screen shows is the rename, else the clean name, else the provider's name.
     - Sorting by name and the list filters use that same order.
   - **Existing catalogues:** a one-off guarded job (the sync's own isolate machinery) fills the two columns after the upgrade, in batches. Until it finishes, rows show the provider's name.
   - **Rejected alternative: cleaning names on screen only.** Sorting is SQL, and SQL can't run the cleanup. Sort by name would still file every `UK: …` channel under U.

2. **What cleanup removes and what it keeps.**
   - **docs/05's rules:**
     - strip leading country and language tags (`UK:`, `US |`, `[EN]`, `|AR|`), only where a separator marks them, as the matcher does — so `TV 5 Monde` and `ABC News` keep their first word;
     - strip trailing quality tags (HD, FHD, UHD, 4K, SD, H265), which become a badge;
     - collapse whitespace;
     - decode HTML entities.
   - **The patterns real panels add**, which the matcher's corpus already shows:
     - superscript tags (`ᴴᴰ`, `ᶠᴴᴰ`, `⁴ᴷ`);
     - bracketed tags (`(HD)`, `[FHD]`);
     - `1080p` / `720p` / `50fps`, `HEVC`, `H.265`, `Backup`.
   - **What is kept:**
     - `+1` (a timeshift is a different channel);
     - numbers (`Sky Sports 2`);
     - the provider's capitals.
   - **The badge:** one of SD, HD, FHD or 4K.
     - UHD and 2160p show as 4K; 1080p as FHD; 720p as HD.
     - A codec tag (HEVC, H.265) is removed with no badge, because it says nothing about the picture.
   - **The country tag is not shown.** The category already says it. Where two results with the same clean name could meet — search across categories — the row adds its category.
   - **A name that cleans to nothing** (`|UK| HD`) keeps the provider's name.
   - **Channels only in this phase,** as docs/05 says. Movie and series names are left alone until step 8 has looked at your panel's names.

3. **Search's scope and its order.**
   - **Scope:**
     - Every source, the one you're browsing first; with two or more sources, each row names its source.
     - Hidden channels are left out, and so is anything in a hidden category unless it is a favorite (decision 8's rule).
   - **Groups:** the canvas's order, fixed: Channels · On TV now & upcoming · Movies · Series.
     - Up to 5 rows each. A group with nothing is left out.
     - A group with more ends in **Show all in Live TV / Movies / Series**. That opens the screen with its filter already holding your text.
   - **Order within a group:**
     - names that start with the text first, then names with a word that starts with it, then FTS's own rank;
     - among channels, favorites before the rest;
     - among programmes, what is on now first, then by start time, one row per programme (an HD/SD pair shares one guide id).
   - **Matching:**
     - Each word typed must start a word in the name, and accents and case are ignored (the index's `unicode61 remove_diacritics 2`).
     - Programmes match on title and subtitle, not description, which brings in noise.
     - Results start at the first character typed, 150 ms after the last key (docs/05). Step 3's timing decides whether programmes need three characters.
   - **Rejected alternative: only the browsed source.** Search is where you go when you don't know where something is.

4. **What Enter does on each kind of result.** Search closes on any action.
   - **A channel:** plays full screen, as a Home tile does. Esc returns to the screen you searched from.
   - **A programme on now:** plays its channel full screen.
   - **An upcoming programme:** opens the Guide on that programme, with its sheet open.
   - **A movie or a series:** opens its details page, which is where Resume lives.
   - **The Menu key** opens the row's menu: favorite, Show in Live TV, Hide channel.
   - **Recent searches:** the text is saved to them when you open a result, not on every keystroke. The last 8 are kept on this computer and can be cleared.

5. **"Remind me" (canvas, upcoming programmes).**
   - **Recommendation:** not in this phase.
     - An upcoming programme opens the Guide instead.
     - A reminder is worth having only as a system notification: the app often sits behind other windows. That is a new package (Linux libnotify, Windows toast notifications) and its own Windows work.
     - I'd put it in Phase 9, or after v1 — your call.
     - **Answered 2026-09-29: Phase 9** (ADR-013).
   - **Rejected alternative: an in-app toast at the start time.** It is missed whenever the window is covered, which is when a reminder matters.

6. **Favorite groups, and where they live.**
   - **Recommendation:** a small `favorite_groups` table: source, name, order, collapsed.
     - `favorites.group_name` becomes `group_id`. Nothing ever wrote the old column.
     - Groups are per source, and the Favorites screen follows the source being browsed, as Live TV and Home do.
     - F adds a channel at the end of the list, outside any group.
     - Once at least one group exists, the channels in no group show under an **Ungrouped** header at the end.
     - A deleted group's channels stay favorites, in Ungrouped.
   - **Rejected alternative: groups as a name on each favorite.** A group made with New group has no channel in it yet, and a name on each row can't record the groups' own order or whether one is collapsed.

7. **Your favorites' order carries into Live TV and Home.**
   - **Recommendation:**
     - Live TV's Favorites list, the player's ↑/↓ from it, and Home's Favorite channels row follow the order you set.
     - Each group shows under Favorites in Live TV's categories pane as its own list, so a group is somewhere you can zap through.
     - This is an addition to the Live TV canvas; sketch A.
   - **Rejected alternative: order and groups only on the Favorites screen.** Arranging channels you can't then zap through in that order is arranging for nothing.

8. **What can be hidden, and where it comes back.**
   - **What can be hidden:** channels and categories, as now.
     - A movie or a series is hidden with its category. No spec asks for hiding a single title.
   - **The rule Live TV, the Guide and Home already share (ADR-010), carried into Search and Favorites:**
     - A channel you hid yourself is gone everywhere, including your favorites.
     - A channel in a category you hid is left out everywhere except where it is a favorite. The favorite is the more specific choice: hiding "UK | Sports" at onboarding shouldn't take away the two sports channels you starred.
   - **Where it comes back:** Settings → Categories gains a **Hidden channels** tab beside Live / Movies / Series, shown once a channel is hidden, with Show on each row and Show all (sketch B).
     - Live TV's "N categories hidden · Manage" also counts channels and opens that tab.
   - **No dead ends in search:** when nothing visible matches but hidden channels do, the empty state says "2 hidden channels match" and offers **Show in Settings**.

## Step 1 — Channel name cleanup (data)
- **`cleanChannelName(raw)`:** returns the name to show and its quality. It is pure, in `lib/features/live_tv/domain/` (Google TV reuses it).
  - It shares the tag tables with `normalizeChannelName` rather than copying them.
  - The matcher's 144-line corpus must not move.
- **Schema v7:**
  - `channels.clean_name` and `quality`;
  - `favorite_groups`, and `favorites.group_id` in place of `group_name` (decision 6);
  - the migration, with a test on a populated v6 database.
- **Sync:** Xtream and M3U write both columns in the sync isolate, and both go in the channels DAO's `DoUpdate` list.
- **The fill for existing catalogues** (decision 1): a guarded job at launch when any channel lacks a clean name, in batches of 5,000.
- **Repositories:**
  - `ChannelItem` gains `quality`;
  - its `name` follows decision 1's order;
  - sorting and the text filters use the same order, in Live TV and in the Guide's own list.
- **Verify:**
  - a fixture corpus (`test_fixtures/channel_names/names.tsv`) with every docs/05 pattern and decision 2's additions;
  - malformed and odd names: empty, only tags, entities escaped twice, U+FFFD, Arabic and Cyrillic, 500 characters;
  - sync tests for both kinds of source, and that a rename survives a re-sync;
  - the migration test;
  - the fill job, including a kill mid-batch;
  - name sort ignoring the tags.

## Step 2 — Clean names and badges on screen
- **The badge:** `ChannelRow` draws the quality badge after the name, as the canvas's Live TV rows do (`AppBadge`'s outline tone).
- **Everywhere else the name appears** gets the clean name too:
  - the preview;
  - the player's OSD and channel panel;
  - the Guide's channel column;
  - Home's tiles;
  - Settings → Guide's rows.
- **Rename…:**
  - opens with the name as shown;
  - shows the provider's own name under the field ("Provider's name: UK: BBC One ᴴᴰ");
  - "Use provider's name" goes back to the cleaned name.
- **Verify:** widget tests of the badge and the dialog; the Live TV, Guide and Home goldens re-recorded and looked at.

## Step 3 — Search: the query
- **`SearchRepository`** (a domain interface; the data side runs on the database isolate):
  - `search(text)` returns the four groups (decision 3), each with up to 5 results and whether there are more;
  - and how many hidden channels match.
- **The query:**
  - The text is split into words, and each becomes a quoted FTS5 prefix term, all of them required.
  - No input can make MATCH fail. A fuzz test sends quotes, `*`, `-`, `NEAR`, lone surrogates and emoji.
- **Programmes:**
  - Only those not yet finished.
  - They reach channels through `epg_matches`, and only visible channels count.
  - One row per programme.
- **Recent searches:** the last 8, in the settings table, and Clear.
- **Verify:**
  - repository tests on a real in-memory database for every group, every ranking rule, the hidden rules and multiple sources;
  - a benchmark over the `large` catalogue with a 7-day guide (50,000 channels, 30,000 movies, 3,000 series, ~600,000 programmes): the time per query for texts of 1 to 20 characters, on the file database.
- **Proposed budget for docs/06:** ≤ 50 ms per query on the database isolate, and no UI frame over 16 ms while typing (step 8 measures the frames).

## Step 4 — Search: the overlay
- **Layout, from the canvas:**
  - the 64 px query bar with the result count and Esc;
  - group headings (`CHANNELS`, `ON TV NOW & UPCOMING`, `MOVIES`, `SERIES`);
  - 52 px rows with a 56 px picture slot: a logo at 36 px, a poster at 30 × 44;
  - the typed text in bold in the name, found with the index's own folding (case and accents);
  - subtitles:
    - a channel: "118 · Evening Bulletin, until 8:30 PM";
    - a programme: "Courtside · ends 10:55 PM", with the LIVE badge, or "Blue Water · Tomorrow, 9:30 PM";
    - a movie: "2024 · Drama · Resume at 1:12:40", with the category when the genre isn't known yet;
    - a series: "Series · 3 seasons · Crime", with seasons once they are known;
  - the footer: ↑↓ Move · Enter Open · Esc Close · Recent: ….
  - The panel grows to the window's height, then its results scroll.
- **Keyboard** (the focus stays in the field, as in the Match… picker):
  - ↑/↓ move through every group, and PageUp/PageDown by a screen;
  - Tab and Shift+Tab jump to the next or previous group;
  - Enter opens (decision 4), and the Menu key opens the row's menu;
  - Esc closes.
  - The mouse: hover highlights, and a click opens.
- **Where results lead:**
  - a Live TV request that selects All channels with the text in its filter;
  - the same for the Movies and Series grids;
  - a Guide request that places the cursor on a programme and opens its sheet.
- **States** (not on the canvas; sketch C):
  - no text: your recent searches, or a line saying what search covers;
  - the first results arriving: skeleton rows;
  - later keystrokes: the old results stay until the new ones replace them, with no spinner;
  - no results: "No results for "xyz"", plus the hidden-matches line when there are some;
  - a failed query: Retry;
  - no source: Add a source;
  - a first sync still running: "Your catalogue is still arriving";
  - offline: nothing changes, because everything search reads is on this computer.
- **Verify:**
  - widget tests for every state and every kind of row;
  - goldens at 1280 × 800 and 1920 × 1080;
  - **an integration test on the `large` catalogue, keys only (exit criterion 1):** Ctrl+K → type → ↓ into Movies → Enter opens the movie; `/` → a channel → Enter plays it → Esc; Ctrl+K → Show all in Movies lands on the filtered grid.

## Step 5 — Favorites: order and groups (data, Live TV, Home)
- **`FavoritesRepository`:**
  - the channels in order (groups in their order, then Ungrouped);
  - add (at the end), remove, move to an index or into a group;
  - new, rename, reorder, delete and collapse groups;
  - movies and series, most recently added first.
- **Live TV** (decision 7):
  - Favorites in your order, and the groups under it in the categories pane;
  - the channel menu's **Add to group ▸**;
  - the player zaps through the list it was opened from, as it does now.
- **Home:** Favorite channels in your order.
- **Verify:**
  - repository tests: the order after every kind of move, and the groups' order;
  - **order and groups survive closing and reopening the database, and a re-sync that renumbers every row (exit criterion 2, against the fake panel)**;
  - widget tests of the categories pane with groups.

## Step 6 — The Favorites screen
- **Layout, from the canvas:**
  - tabs Channels · Movies · Series with counts;
  - "Drag to reorder" and **New group** on the Channels tab;
  - group headers: collapse chevron, NAME, count, Rename;
  - 60 px rows: grip, number, logo, name with its quality badge, the programme on now with its bar, the time left, and the star;
  - the footer hint: "Press F on any channel, movie, or series to add it here or remove it."
  - A row being dragged lifts, and an accent line shows where it will land (canvas).
- **Movies and Series tabs:** the poster grid of your favorites, newest first, with Enter to open the page and F to remove.
- **Keyboard:**
  - the list is one Tab stop, ↑/↓ inside it;
  - Enter plays full screen;
  - F removes, with an Undo toast;
  - Alt+↑/↓ moves a row, past a group's edge into the next group, as the Categories manager moves categories;
  - on a group header: Enter, ← and → collapse and expand;
  - the Menu key:
    - a channel: Move to group ▸, Rename…, Hide channel, Remove from favorites;
    - a group: Rename…, Move up/down, Delete group.
  - New group asks for a name and adds the empty group at the end.
- **States:**
  - loading skeletons;
  - no source;
  - each tab empty ("No favorite channels yet. Press F on a channel in Live TV to add it here." with **Open Live TV**, and the same for movies and series);
  - an error, with Retry.
- **Verify:** widget tests for every state, dragging and Alt+↑/↓ across groups, goldens, a keyboard walk.

## Step 7 — Hide, unhide and reorder, everywhere
- **One channel menu** wherever a channel row is — Live TV, the Guide's channel column, Home's tiles, Favorites and Search: Watch, favorite, Add to group ▸, Rename…, Hide channel.
- **Hiding:**
  - is shown at once and says **"Channel hidden · Undo"** in a toast (docs/05: optimistic updates for favorite and hide);
  - decision 8's rule in every list: Live TV, the Guide, Home, Favorites and Search.
- **Live TV:**
  - the categories pane gets its item menu: Hide category, Rename…, Move up / Move down, and Alt+↑/↓, as the Categories manager has;
  - the channel list's menu gets **Show hidden channels**, which draws hidden rows dimmed with an eye-off mark;
  - the foot counts hidden categories and channels and opens Settings.
- **Settings → Categories:**
  - the Hidden channels tab (sketch B);
  - the manager's list becomes one Tab stop (Known issues).
- **The Live TV list keeps the keyboard when the mouse wheel scrolls the focused row away** (Known issues; the poster grid's fix from Phase 5).
- **Verify:**
  - **a hidden channel, and a channel in a hidden category that isn't a favorite, are absent from Live TV, the Guide, Search and Home, and come back from Settings (exit criterion 4):** repository tests per screen, widget tests, and an integration walk;
  - the Undo toast;
  - the categories pane's menu and moves.

## Step 8 — The phase exit
- **A keyboard walk against the fake panel:**
  - Ctrl+K → a channel → play → Esc;
  - F on three channels → Favorites → New group → Alt+↓ two channels into it;
  - the app closed and reopened on the same database, then a re-sync: the order and the group are still there;
  - Live TV → the group → ↓ zaps in its order;
  - hide a channel → gone from Live TV, Guide, Search and Home → Settings → Hidden channels → Show → back.
- **Measurements** (tests tagged `benchmark`):
  - search per query (step 3);
  - frames while typing into search on the `large` catalogue, in profile mode on the real display;
  - the fill job over 50,000 names.
- **With your go-ahead** (a pop-up first): one sync of your panel into a throwaway database. It makes only the catalogue's API calls, no stream.
  - It runs the cleanup over its 12,610 channel names, and a before/after list goes in ADR-013 for your review.
  - It looks at its 20,072 movie names for tags, which decides whether movies get cleanup later (decision 2).
- **Docs:**
  - ADR-013 Accepted;
  - docs/05 "As built" for Search, Favorites and names;
  - docs/02's schema v7;
  - docs/06's search budget;
  - progress and the handoff.

**Alongside, one small commit each:** the Windows test failures (progress.md Known issues). Each fix is confirmed by the CI run after you push.

## Sketches for approval (not on the canvas)

**A. Live TV's categories pane with favorite groups** (decision 7):
```
★ Favorites                 8      ← every favorite, in your order
    Sports                  5      ← a group: its own list
    News                    3
All channels           12,340
UK | Sports               412
UK | News                  96
…
3 categories · 2 channels hidden · Manage
```

**B. Settings → Categories → Hidden channels** (decision 8):
```
Categories                                           [ Home provider ▾ ]
Live 146 · Movies 60 · Series 41 · Hidden channels 2
┌─────────────────────────────────────────────────────────────────────┐
│ [Filter hidden channels]                                 [ Show all ]│
│  118  [HC]  Harbor City Local      UK | News                 [ Show ]│
│  147  [HW]  Harborview Weather     UK | News                 [ Show ]│
└─────────────────────────────────────────────────────────────────────┘
Hidden channels are left out of Live TV, the Guide, Search and Home.
They stay hidden after a re-sync.
```
One Tab stop, ↑/↓ inside it, and Enter shows the channel. The row leaves the list, and the focus goes to the next row.

**C. Search with no text, and with no result:**
```
┌ 🔍 Search channels, shows, movies                               Esc ┐
│ RECENT SEARCHES                                              Clear  │
│  ↺  tennis open                                                     │
│  ↺  cup final                                                       │
├─────────────────────────────────────────────────────────────────────┤
│ ↑↓ Move   Enter Search again   Del Remove   Esc Close               │
└─────────────────────────────────────────────────────────────────────┘

┌ 🔍 harbour                                             0 results Esc ┐
│              No results for "harbour"                               │
│              2 hidden channels match.   [ Show in Settings ]        │
└─────────────────────────────────────────────────────────────────────┘
```
With no recent searches, the body says "Channels, what's on now and next, movies and series, from every source."

## Verification (every step and at the exit)
The same set every step:
- `flutter analyze`;
- `dart format --set-exit-if-changed lib test integration_test tools`;
- `TZ=UTC flutter test` (unit, widget, golden);
- the fake-provider suite;
- the integration tests the step touches, one file per run under `xvfb-run -a`.

What the tests must cover:
- The cleanup and the FTS queries get fixture and fuzz tests, malformed input included.
- The repositories are tested on a real in-memory database.
- Every screen state gets a widget test.
- The search timings and the typing frames are measured, not assumed (hard rule 10).

## Risks
- **Short queries against 600,000 programmes.** A one- or two-letter prefix matches a large share of the index before the "not finished" and "visible channel" filters apply. Step 3 times it.
  - If it is slow, programmes wait for three characters, and channels, movies and series still answer from the first.
- **Cleanup that eats part of a real name.** "Sky Sports **Main Event** FHD" is safe. A channel called "HD Kids" or "Arena 4K"? Only trailing tags go, and only whole words.
  - The corpus pins these cases.
  - Step 8 checks your panel's 12,610 names, and Rename fixes any one of them.
- **The fill job on an upgraded catalogue** runs once. It uses the guarded isolate machinery the sync uses (a kill mid-batch leaves the database usable), and rows keep the provider's name until it is done.
- **Live TV's categories pane changes shape** (groups under Favorites). Its keyboard walk and goldens run in steps 5 and 7, not only the new tests.
- **Dragging across group edges.** Flutter's reorderable list has no groups. The plan is one flat list of headers and rows, where a drop takes the group of the header above it. Alt+↑/↓ does the same move with the keyboard, so both paths are tested against one model.
