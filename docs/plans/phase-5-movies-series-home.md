# Phase 5 — Movies, series, home: plan

**Status: approved 2026-09-27, being built.** What is built, and every departure from this plan, is recorded in ADR-012 (docs/decisions.md) as the steps land.

## Context
Phase 4 finished the guide. Home, Movies and Series are still placeholders. Phase 5 fills them: poster grids, details pages that fetch lazily and cache, VOD in the full-screen player (seeking, resume, progress, completion, the next episode), and Home's rows.

Exit criteria (docs/08): movie and series details load lazily and are cached (a second open makes no network request) · map and list episode shapes pass fixture tests · resume prompt, progress saving, completion at 95 % and the next-episode countdown pass integration tests against the fake provider · Home shows every row and the first-run hero · every new screen has widget tests for its loading, empty, error and content states.

Already in place, so the phase starts further along than docs/08 suggests:
- **The catalogue:** sync already fills `movies` and `series` (and a playlist's `episodes`). `movie_details` and Xtream `episodes` exist and wait for a lazy fetch (ADR-009).
- **The Xtream client** already reads `get_vod_info` and `get_series_info`, including both episode shapes, with fixtures (Phase 2 step 3). It drops the series' own `info` (backdrop, cast, director) and the probe blocks that give a movie's resolution and audio layout.
- **`favorites` and `watch_history`** (schema v4) key items by (type, source, remote key). Only live channels use them so far.
- **`PlaybackCoordinator` and `PlayerEngine` play live channels only:** no seek, no duration, no start position.
- **The fake panel** answers `get_vod_info` and `get_series_info`, with the map-shaped episodes behind the `episodesAsMap` quirk. Its `/movie/` and `/series/` stream URLs answer 501, and its artwork URLs point at a `.invalid` host.
- **Unused Phase 1 components:** `PosterCard`, `LandscapeCard`, `HorizontalRail`, `SectionHeader` and `AppSlider` (buffered range, time bubble) exist but no screen uses them yet.
- **Images** are plain `NetworkImage` (channel logos, six places): no disk cache and no memory bound.

What Phase 5 does **not** own:
- **Download buttons and Downloaded badges** (Phase 8) and **Cast** (Phase 7). The details pages leave both out, rather than showing buttons that do nothing, and the layout keeps room for them.
- **The Favorites screen** (Phase 6). This phase lets F add movies and series to favorites.
- **Search, and name cleanup with quality badges from names** (Phase 6).
- **Home's offline banner.** It points at the Library, so it waits for Phase 8.
- **Catch-up.**

Carried in, not to be relitigated without new evidence:
- **Hard rule 7 and ADR-010:** the coordinator is the only owner of the player and of each source's connections. A movie is a stream like a channel: on a one-connection panel the preview's stream closes before the movie opens.
- **ADR-009:** favorites and history are keyed by remote key. `replaceEpisodes` is all or nothing. `episodes_fetched_at` belongs to the app, and sync never writes it.
- **docs/02:** stream URLs are rebuilt from the source on every open and every reconnect, so a movie resumed after a drop gets a fresh URL.
- **Hard rule 2:** 30,000 movies is a list the screen reads in windows (a count, then the rows on screen), never all at once.

Working rhythm, as before: one numbered step at a time. After each: analyze, format, `TZ=UTC flutter test`, a local commit without trailers, and a stop for your review.

## Decisions (my recommendation first in each)
1. **One coordinator, and a playable item.** VOD needs what live already has — the connection policy, the watchdog, history — plus seeking and a saved position.
   - **Recommendation:** `PlaybackCoordinator` stays the only owner and gains `playVod(item, {from})`. Its states carry a sealed item: a live channel, a movie or an episode (Phase 8 adds a local file). `state.channel` stays for live, so Live TV and the Guide don't change.
   - **The watchdog learns VOD's differences:**
     - the end of the file means finished, not reconnect, unless it came early;
     - a drop reconnects at the last position, with a fresh URL;
     - a paused player is never a stall.
   - **`PlayerEngine` gains:**
     - `seek`;
     - an open that starts at a position (mpv's `start`, which media_kit's `Media.start` sets), so a resume is one request rather than an open followed by a seek;
     - the duration;
     - the paused state.
   - **Rejected alternative: a second coordinator for VOD.** That makes two owners of one player and one connection budget, which the single owner of hard rule 7 exists to prevent.
2. **Lazy details, cached.**
   - **Recommendation:** a movie's `get_vod_info` is fetched the first time its page opens and kept in `movie_details`. Every later open reads the database and makes no request. It is refreshed in the background after 7 days.
   - **Series:** `get_series_info` works the same way and replaces the series' episodes all or nothing. It is refreshed in the background in two cases:
     - the list's `last_modified` has moved past `episodes_fetched_at`;
     - 24 hours have passed. Some panels never move `last_modified`, and a running series gains an episode a week.
   - **How the page behaves:**
     - A page with a cache shows it at once and never waits for a refresh.
     - A failed refresh keeps the cache and says nothing.
     - A failed first fetch shows what the list row knows (title, poster, year, rating), the reason, and Retry.
     - Opening the page again while a fetch runs joins that fetch.
   - **M3U sources** fetch nothing: their details are what the playlist gave, and their episodes came with the sync.
   - **Requests:** these run beside a sync, because they are small and the user is waiting for them. There is one at a time per source.
   - **Rejected alternative: fetching details during sync.** On your panel that is about 20,000 requests, mostly for pages nobody opens.
3. **Where resume is chosen.** docs/03 asks for a resume prompt when the saved position is between 60 s and 95 %.
   - **Recommendation:** the canvas already draws that prompt on Movie details: **Resume from 1:12:40** (primary) and **Start over**. That page is the prompt. Below 60 s, or once the movie is finished, it shows **Play**.
   - **Paths that already mean "continue" don't ask again.** These resume at once:
     - a Continue watching card;
     - the series page's **Continue S2 · E4**;
     - Enter on an episode row that has progress (the row already shows "31 min left"). The row's menu offers **Start over**.
   - **After a resume,** the player shows "Resumed from 24:10 · Home starts over" for 5 s.
   - **Rejected alternative: a dialog before every play that has progress** (Kodi's way). It adds a key press to the most common path and repeats what the page already offered.
4. **The next episode.**
   - **Recommendation:** when 20 s of an episode remain, a "Next episode" card counts down from 10, then plays the next episode from its own resume point, if it has one.
     - "Next" is the next episode in the season, otherwise the first episode of the next season.
     - Enter plays it now.
     - Esc cancels: the episode plays to the end and stops on a card with **Play next episode** and **Back to series**.
     - The last episode of a series shows no card and returns to the series page.
   - **Completion** is at 95 % either way, so the episode you leave early still counts as watched.
   - **Rejected alternative: showing the card only at the end of the file.** Every episode would then play its credits to the last second first.
5. **Home's rows, and which sources they cover.**
   - **Recommendation:** docs/05's rows in docs/05's order. A row shows only when it has something in it, because an empty row on a home screen is noise. The first-run hero shows while nothing has been watched yet.
   - **Continue watching covers every source.** It is your history, and each card plays from its own source. Up to 20 cards, newest first:
     - movies between 60 s and 95 %;
     - for each series, the episode to continue: the one in progress, otherwise the one after the last finished.
   - **The other rows follow the source being browsed,** as Live TV and the Guide do:
     - **Favorite channels** (the canvas's tiles, with the programme on now and its progress);
     - **Recently watched channels**;
     - **Recently added movies** and **Recently added series**, 20 each.
   - **What "recently added" means:**
     - For movies: the provider's date, otherwise the order the app first saw them, so an M3U source still gets a sensible row.
     - For series: `last_modified`. A panel moves it when new episodes arrive, which is what a series row should surface.
   - **See all** appears only where another screen lists the same thing: Favorite channels opens Live TV on Favorites, and each added row opens Movies or Series sorted by Recently added.
   - **Remove from Continue watching** is in the card's menu.
6. **Images.** 30,000 posters is the app's first real image load. docs/06 caps the image cache at 150 MB in memory and 500 MB on disk.
   - **The problem with extended_image:** ADR-002 chose it for its disk cache. Its folder is fixed to the system temp folder — on Linux, `/tmp/cacheimage` — and can't be moved. That folder is shared by every account on the machine and emptied at each reboot.
   - **Recommendation:** our own small image provider.
     - HTTP with the app's client rules (User-Agent, timeouts), and `redact()` on any URL that gets logged.
     - Files in the app's own cache folder, named by a hash of the URL.
     - A sweeper keeps the folder under 500 MB, deleting least recently used files first, at launch and after every 50 MB written.
     - At most 6 downloads at once. The newest request goes first, and requests for posters already scrolled away are dropped before they start.
     - Each image is decoded at the size drawn: a 2,000 px poster costs a 170 px bitmap.
     - Flutter's image cache is capped at 150 MB.
     - A 120 ms fade-in, and the generated tile for a missing or broken image.
   - **What changes elsewhere:** the six `NetworkImage`s move onto it, and extended_image leaves `pubspec.yaml` (ADR-002 amended).
   - **Rejected alternative: keeping extended_image as it is.** Your posters would sit in a shared folder and be downloaded again after every reboot.
7. **Schema v6.**
   - **Recommendation:** add only what the screens need and the provider sends.
     - **`series`** gains `backdrop_url`, `cast_names`, `director` and `genre`. The list already sends the genre, but today it is parsed and dropped.
     - **`movie_details`** gains `video_height` and `audio_channels`, for the FHD and 5.1 badges, when a panel includes its probe data.
     - **`watch_history`** gains `series_key` and `dismissed`. `series_key` means Continue watching needs no join through the episode cache, which a re-fetch replaces. `dismissed` backs Remove from Continue watching and is cleared when you watch the item again.
   - **Indexes** only where step 2's timing of a window query over 30,000 movies shows one is needed.
   - **A v5 → v6 migration test** on a populated database.

## Step 1 — The fake panel serves VOD and artwork
- **VOD streams:** `/movie/{u}/{p}/{id}.{ext}` and `/series/{u}/{p}/{id}.{ext}` serve the VOD samples with Range (206, suffix ranges, 416), ETag, Last-Modified and HEAD, as docs/06 asks. An unknown id answers 404. A VOD body counts against `max_connections` while it is open.
- **VOD faults** from docs/06 that this phase's player must survive: `drop_after_bytes`, `http_status`, `ignore_range` (a panel that sends the whole file for every seek) and `throttle_kbps`. `change_etag`, `wrong_content_length`, `size_mb` and `vod_as_hls` wait for Phase 8's downloads.
- **Artwork:** posters, backdrops and episode stills become the panel's own URLs, following the request's host as `server_info` does. Behind them is a handful of generated JPEGs at real sizes, served under many names with an ETag, so the image pipeline gets exercised end to end. `junk_icons` still breaks some of them.
- **Metadata:**
  - `get_vod_info` gains the `video` and `audio` probe blocks real panels send.
  - `get_series_info.info` gains a backdrop, cast and director.
  - An episode's `duration_secs` becomes its sample's real length.
- **CI** also generates `vod_h264_aac_10min`, at `VOD_SECONDS=120`.
- **Verify:** fake-provider tests for each Range shape, each fault, HEAD, the connection count and the artwork.

## Step 2 — Schema v6, and the catalogue and history repositories
- **Schema:** decision 7's columns, the migration and its test.
- **`MovieRepository` and `SeriesRepository`**, in their features' domain folders:
  - a count and a window of rows for any query: a category, Uncategorized or all; a text filter; a sort (Recently added, Name or Rating);
  - the categories for the chips, and favorites;
  - `details()`, with decision 2's policy, as a stream: cached → refreshing → fresh, or failed along with the row's data;
  - for series, the seasons and their episodes.
- **`WatchProgress`:** save a position and read it back, the Continue watching list (decision 5), watched marks, and dismiss.
- **Client parsers:**
  - `parseSeriesInfo` keeps the series' own `info`;
  - `parseMovieInfo` keeps the probe blocks;
  - fixtures for both, including a panel that sends neither.
- **Verify:** repository tests on a real in-memory database, against the fake panel running in-process:
  - **a second open makes no request** (checked in the panel's request log);
  - the refresh rules, under a fake clock;
  - **both episode shapes end to end** (`episodesAsMap` on and off), as well as the fixtures;
  - an M3U source fetches nothing;
  - `{}`, `info: []` and an HTML page never throw (hard rule 1);
  - the window query, timed over the `large` profile's 30,000 movies.

## Step 3 — Images
- **The pipeline (decision 6):**
  - `ArtworkImages`: an interface in `lib/core`, implemented in `lib/data/images/` and overridden in `bootstrap()`, so presentation code never imports `dart:io`;
  - the sweeper, the memory cap, the fade-in and the fallback tile;
  - the six logo sites switched over.
- **Verify:**
  - sweeper tests: the size cap, oldest first, a file still being written is never deleted, a damaged file is fetched again;
  - queue tests: the cap, newest first, dropped requests;
  - a widget test that a broken URL draws the generated tile;
  - the layering test still green.

## Step 4 — The Movies and Series grids
- **Layout:** the canvas's `Movies` artboard; Series uses the same grid (docs/05).
  - **Header:** "All movies · 8,021 movies", a 220 px filter field, and the sort control (Recently added / Name / Rating), remembered separately for movies and series.
  - **Category chips** in your order: hidden categories left out, Uncategorized last, and **More ▾** opening the rest in a menu.
  - **The grid:**
    - columns from the width, at a 160 px minimum (7 at 1440 px, as the canvas draws);
    - 2:3 posters with NEW (added in the last 7 days), a progress line on a movie in progress, and a ★ on a favorite;
    - the focused card scales to 1.03, and its line adds the runtime once that is known.
- **Loading:** windowed like Live TV — a count, then pages of rows around what is on screen. Rows still loading show skeleton cards (the canvas draws them).
- **Keyboard:**
  - the grid is one Tab stop;
  - arrows move one card, PageUp/PageDown one screen, Home/End to the ends;
  - Enter opens details, and F toggles the favorite;
  - typing a letter goes to the filter field.
  - Coming back from details restores the scroll position and puts focus back on the same card.
- **States:**
  - no source;
  - loading;
  - still getting the catalogue during a first sync;
  - a source with no movies ("Your provider doesn't offer movies" — many M3U lists are live only);
  - an empty category;
  - nothing matches the filter (with Clear filter);
  - an error, with Retry.
- **Verify:** widget tests for every state, goldens at 1280×800 and 1920×1080, and a keyboard walk.

## Step 5 — Movie details and Series details
- **Routes:** inside their branch (`/movies/:sourceId/:key` and `/series/:sourceId/:key`), so the nav rail stays and the branch remembers the page.
  - The canvas draws no top bar on these pages, so the shell hides it there. Ctrl+K and the other shortcuts still work.
  - The canvas's "‹ Movies" chip or Esc goes back to the grid. Esc leaves what you stepped into (ADR-008).
- **Movie details, as the canvas draws it:**
  - **Artwork:** the backdrop, or the poster blurred when there is no backdrop, and the 240 × 360 poster.
  - **Text:** "MOVIE / DRAMA", the title, then year · runtime · ★ rating · genres, with FHD and 5.1 badges when they are known. Then the plot, Director and Cast.
  - **Actions:** decision 3's buttons plus Favorite, with the progress line ("46 min left") under them.
  - **Loading order:** what the list row already knows shows at once, and the rest fills in.
- **Series details, as the canvas draws it:**
  - **Left column:** backdrop, 200 × 300 poster, title, then year · N seasons · ★ · genre, and the plot.
  - **Actions:** **Continue S2 · E4** — **Play S1 · E1** before you start, **Play again** once every episode is watched — and Favorite.
  - **Right side:** season tabs with the episode count, and episode rows. Each row has:
    - a 176 × 99 still with its progress line;
    - the number (E4) and title;
    - a ✓ with "Watched", or the time left ("31 min left");
    - the description, on the focused row only.
  - **An episode's menu:** Start over, and Mark as watched / unwatched.
- **Keyboard:**
  - focus lands on the primary action;
  - the season tabs take ←/→;
  - the episode list is one Tab stop, with ↑/↓ inside and Enter to play;
  - opening a series lands the list on the episode to continue.
- **States:**
  - loading: skeleton lines where the fetched parts will go;
  - a failed first fetch: the row's data, the reason, and Retry;
  - a cache on screen while it refreshes (nothing on screen says so);
  - no episodes ("Your provider lists no episodes for this series yet", with Retry);
  - no plot ("No description from your provider").
- **Verify:** widget tests for every state of both pages, goldens, a keyboard walk, and, at widget level too, that a second open makes no request.

## Step 6 — VOD in the full-screen player
- **The pieces:**
  - decision 1 in the engine, the coordinator and `DbStreamResolver`: the movie and episode URLs from docs/02, or an M3U line's template filled in;
  - decision 3's "Resumed from" line;
  - decision 4's card.
- **The player's VOD face is not on the canvas** (the canvas's player is live). Sketch for approval:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Glass Tide                                           FHD   5.1     9:22 PM  │
│  S2 · E4 · Undertow                                                          │
│                                                                              │
│                                   (picture)                                  │
│                                                                              │
│  Resumed from 24:10 · Home starts over             ← the first 5 s only      │
│                                    ┌───────┐                                 │
│                                    │ 31:40 │      ← the bubble, when seeking │
│  24:10 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━──────────────── −31:06   │
│  [Pause] [−10] [+10] [Vol]  English · AAC 2.0  Subs off  Fit  [Info] [Exit]  │
└──────────────────────────────────────────────────────────────────────────────┘

The next-episode card, bottom right above the seek bar (the OSD stays up while it shows):
                                        ┌──────────────────────────────────────┐
                                        │ NEXT EPISODE                         │
                                        │ ┌────────────┐  S2 · E5              │
                                        │ │   still    │  Northbound           │
                                        │ └────────────┘  49 min               │
                                        │ [ ▶ Play now · 7 ]     [ Cancel ]    │
                                        └──────────────────────────────────────┘
Play now is focused, and its fill runs down with the count. Enter plays now, Esc cancels.
After a cancel, the end of the episode shows the same card without the count:
[ Play next episode ]  [ Back to series ].
```
  The gradients, the controls' look and the stream info are the live player's. The seek bar is `AppSlider` with its buffered range and time bubble.
- **Keys:**
  - Space plays and pauses;
  - ←/→ seek 10 s, and Shift+←/→ 60 s. The bar and bubble move at once, and one seek runs when the keys rest for 300 ms;
  - Home goes to the start;
  - M, A, S, I and F work as they do for live;
  - Esc saves the position, stops, and goes back to the page the video was opened from;
  - ↑/↓ and the digits do nothing during VOD.
- **Saving progress:**
  - every 10 s while playing, on pause, after a seek settles, and on leaving;
  - completed at ≥ 95 % (the episode gets its ✓, the movie shows "Watched");
  - a movie that ends goes back to its page.
- **The failure card:** Retry and Details, plus Next episode for an episode. A 404 says "This movie is no longer available from your provider." (docs/05).
- **Verify:**
  - coordinator unit tests with the fake engine and a fake clock: the saving cadence, 95 %, an early end reconnecting at its position, a pause never counted as a stall, and a live preview closed before a movie opens on a one-connection source;
  - widget tests of the OSD, the next-episode card and the end card;
  - **integration tests with the real player against the fake panel:**
    - **the resume choice on Movie details: Resume opens at the saved position, Start over at 0;**
    - **progress saved, and read back after leaving the player;**
    - **completion at 95 %;**
    - **the next-episode countdown: it plays the next episode, and Esc cancels it;**
    - a drop mid-movie resumes where it was.
  - The fault suite, the Live TV walk and the Guide's Watch test must stay green, because the coordinator changes underneath them.

## Step 7 — Home
- **Decision 5's rows, at the canvas's measures:**
  - Continue watching: 16:9 cards, 4 across at 1440 px, a 4 px progress line, and "Movie · 46 min left" or "S2 · E4 · 31 min left";
  - channel tiles: 84 px tall, with a 44 px logo, the name, the programme on now and a 3 px progress line;
  - posters: 8 across.
  - Each row is a rail that scrolls sideways past what fits.
- **The first-run hero** is not on the canvas. Sketch for approval:

```
Home                                                          (the shared top bar)
┌──────────────────────────────────────────────────────────────────────────────┐
│ ░ the newest movie's backdrop, faded into the page (or the app's gradient) ░ │
│                                                                              │
│   WELCOME                                                                    │
│   Start watching                                                             │
│   12,340 channels, 8,021 movies and 1,204 series from Home provider.         │
│                                                                              │
│   [ ▶ Open Live TV ]   [ Browse movies ]                                     │
└──────────────────────────────────────────────────────────────────────────────┘

Recently added movies                                                  See all
[poster] [poster] [poster] [poster] [poster] [poster] [poster] [poster]    ›

Recently added series                                                  See all
[poster] [poster] [poster] [poster] [poster] [poster] [poster] [poster]    ›
```
  - It shows until something has been watched; a channel counts.
  - Open Live TV has the focus.
  - Browse movies becomes Browse series, or goes away, when the source has no movies.
  - A count of zero is left out of the line.
  - The favorite and recently watched channel rows join once they have something in them.
- **Keyboard:**
  - one Tab stop per row;
  - ←/→ within a row, and ↑/↓ between rows, staying in the same column;
  - Enter on a continue card or a channel plays it (a channel full screen, as Enter does in Live TV); Enter on a poster opens its details;
  - F toggles a favorite;
  - the Menu key opens the item's menu: Remove from Continue watching, Go to series, Remove from favorites.
- **Live updates:** the rows follow the database as it changes, so after the player, Continue watching has already moved. The channel tiles get their programme on now as Live TV's rows do (warmed in one query, redrawn every minute).
- **States:**
  - skeleton rows;
  - a first sync still running ("Getting your catalogue…", plus the rows that have arrived);
  - an error, with Retry.
- **Verify:**
  - widget tests for every row and state;
  - goldens with history and at first run;
  - a keyboard walk;
  - an integration test: play a movie to 30 %, press Esc, go Home, check that its card shows the progress, and that Enter resumes it there.

## Step 8 — The phase exit
- **An end-to-end keyboard walk** against the fake panel: Home → Movies → a movie → Play → Esc → Home's Continue watching → Series → an episode → the countdown → the next episode.
- **Measurements**, measured rather than assumed, in tests tagged `benchmark`:
  - cold start to an interactive Home with cached data (docs/06: ≤ 2.0 s);
  - scrolling the poster grid over 30,000 movies with their artwork, against the channel list's 16 ms frame budget, since docs/06 has no row for a grid;
  - the image cache's memory after scrolling the grid end to end (≤ 150 MB of decoded images).
- **Docs:**
  - ADR-012 Accepted;
  - docs/05 "As built" for Home, Movies, Series and the VOD player;
  - docs/03's VOD section, and docs/06;
  - progress and the handoff.
- **With your go-ahead** (a pop-up first, because it uses your one connection): one movie and one episode from your panel, to see its real VOD: containers, codecs, and whether it honours Range.

**Alongside, one small commit each:** the Windows test failures. Run 36310668594 fails 10, up from 6; 7 of them are 30-second timeouts in guarded-job tests, so there is probably one cause. Each fix is confirmed by the CI run after you push.

## Verification (every step and at the exit)
`flutter analyze` · `dart format --set-exit-if-changed lib test integration_test tools` · `TZ=UTC flutter test` (unit, widget, golden) · the fake-provider suite · the integration tests, one file per run under `xvfb-run -a`. Parsers get fixture tests including malformed input. State logic gets unit tests with a fake clock. Every screen state gets a widget test. The budgets above are measured, not assumed (hard rule 10).

## Risks
- **The coordinator changes under Live TV and the Guide.** Every step 6 commit runs the fault suite, the Live TV walk and the Guide's Watch test, not only the new tests.
- **Seeking on a real panel.** A server that ignores Range turns every seek and every resume into a download from the start. The `ignore_range` fault shows what mpv does there. If a resume takes more than a few seconds, the player says "Preparing…" rather than looking frozen. Your panel's answer in step 8 says whether it matters in practice.
- **30,000 posters.** Decoding at the size drawn and the download queue are the plan. Step 8's measurement decides whether more is needed, such as asking TMDB for a smaller poster size.
- **Real VOD formats are unknown.** The samples cover MKV with HEVC, E-AC-3 and embedded subtitles (`vod_hevc_eac3_subs.mkv`). Your panel's own files are only covered by step 8's play.
- **Continue watching needs an episode's series.** Every episode history row carries its series from step 2 on. Nothing was watched before this phase, so there is nothing to back-fill.
