# 02 — Providers & data

## Source types
| Type | Input | Notes |
|---|---|---|
| Xtream Codes | server URL (scheme, host, port), username, password | Preferred: structured API, VOD/series metadata, short EPG, catch-up flags |
| M3U URL | playlist URL (+ optional XMLTV URL) | May be gzip; may declare `url-tvg` / `x-tvg-url` |
| M3U file | local file | Same parser |

Per-source settings: display name · User-Agent (default: a common media-player UA, editable) · live format (`ts` default, `m3u8` option) · EPG URL override · EPG time offset · refresh interval · connection limit override.

## Xtream Codes API
Base: `{server}/player_api.php?username={u}&password={p}`

| Call | Returns |
|---|---|
| (no action) | `user_info` (status, exp_date, max_connections, active_cons, allowed_output_formats) + `server_info` (url, port, https_port, server_protocol, timezone) |
| `&action=get_live_categories` | live categories |
| `&action=get_live_streams[&category_id=]` | channels: stream_id, num, name, stream_icon, epg_channel_id, category_id, tv_archive, tv_archive_duration, added |
| `&action=get_vod_categories` · `get_vod_streams` | movies: stream_id, name, stream_icon, rating, added, container_extension |
| `&action=get_vod_info&vod_id=` | movie details (fetched lazily on the details page) |
| `&action=get_series_categories` · `get_series` | series list |
| `&action=get_series_info&series_id=` | seasons + episodes (lazy) |
| `&action=get_short_epg&stream_id=&limit=` | now/next — **title and description are base64** |
| `{server}/xmltv.php?username=&password=` | full XMLTV |

Stream URLs:
- Live: `{server}/live/{u}/{p}/{stream_id}.{ts|m3u8}`
- Movie: `{server}/movie/{u}/{p}/{stream_id}.{container_extension}`
- Episode: `{server}/series/{u}/{p}/{episode_id}.{container_extension}`
- Catch-up (later): `{server}/timeshift/{u}/{p}/{duration_min}/{YYYY-MM-DD:HH-MM}/{stream_id}.ts` — varies by panel; verify against a real provider before building

### Quirks the parser MUST tolerate (one fixture test each)
- Numbers as strings (`"num": "12"`), booleans as `"1"`/`"0"`, timestamps as strings
- `""` or `null` for missing values; `info: []` instead of `{}`
- `get_series_info.episodes` as a map keyed by season (`{"1": [...]}`) or as a list
- `category_id` null or pointing at a missing category → "Uncategorized"
- Broken or junk `stream_icon` URLs → generated placeholder tiles
- HTML entities and stray whitespace in names; occasional invalid UTF-8 (decode with `allowMalformed: true`)
- `exp_date` null means no expiry
- Redirects (http→https, load-balancer hosts); tokens in redirected URLs can expire → always rebuild URLs from the original server
- Rate limiting or blocking of rapid calls / unknown User-Agents → serialize requests, back off on 429/5xx, configurable UA
- Very large responses (50k+ items) → decode in an isolate

How the client (`lib/data/providers/xtream/`) meets these, and the few found while building it: fixtures live in `test_fixtures/xtream/`, one per quirk.
- **Rows keyed by id** (`{"101": {...}, "102": {...}}`) instead of an array are read as their values; a list body that is not a list or an object is no rows, not an error.
- **A row is dropped only when it can't be identified** (not an object, no id, a repeated id — the first wins); a bad field loses the field, not the row. Every parse returns the count of dropped rows, for the sync to log.
- A dangling `category_id` passes through the client untouched; the sync, which knows the categories, files it under "Uncategorized".
- **Ratings** of `0`, `""` or over 10 read as unrated; `"7,4"` reads as 7.4. **Years** come from `year`, then `releaseDate`, then a trailing `(1995)` in the name. **Extensions** are lower-cased and must look like one (`MKV` → `mkv`, `m k v` → none).
- `get_short_epg` text is base64, decoded strictly: plain text such as `News` is valid base64 too, and what gives it away is that its bytes aren't UTF-8. Times come from the unix timestamps, never the formatted strings (those are in the panel's zone).
- The account keeps an allow-list of fields, so the `username` and `password` a panel echoes back in `user_info` never reach `sources.account_json`.
- **The default User-Agent is `VLC/3.0.20 LibVLC/3.0.20`**; a source can override it.
- **Retries:** 429 and 5xx back off 1 s, 2 s (±20 %), or `Retry-After` capped at 30 s, three attempts in all; a body cut off or silent for 30 s mid-transfer is retried too. A refused connection is not retried, and the onboarding check (`account(retry: false)`) never retries — the user is waiting. 401 and 403 are auth failures; 404 is not found.
- **Bodies over 256 KB are decoded and parsed in a background isolate.** dio's `receiveTimeout` is not used: it replaces a `Timer` on every chunk, which blocked the UI isolate for ~1 s on a 50k-row list; the client reads the body as a stream with one watchdog timer per request instead.

## M3U
```
#EXTM3U url-tvg="http://example/epg.xml.gz"
#EXTINF:-1 tvg-id="bbc1.uk" tvg-name="BBC One" tvg-logo="http://example/logo.png" group-title="UK | General" tvg-chno="101",BBC One HD
#EXTVLCOPT:http-user-agent=Mozilla/5.0
http://example/live/u/p/123.ts
```
- Streaming line-by-line parser in an isolate (files can exceed 50 MB; gzip supported)
- Attributes: tvg-id, tvg-name, tvg-logo, group-title, tvg-chno, catchup, catchup-days, catchup-source; `#EXTVLCOPT` for user-agent/referrer; ignore unknown directives such as `#KODIPROP` safely
- Classify: URL path `/movie/` → movie, `/series/` → episode, otherwise live (Xtream m3u_plus exports mix them)
- Stable identity (M3U has no IDs): hash of tvg-id + name + URL path without credentials, so favorites/history survive refreshes

How the parser (`lib/data/providers/m3u/`) meets these; fixtures in `test_fixtures/m3u/` (byte-exact: `.gitattributes` marks `test_fixtures/**` `-text`):
- **Streaming:** bytes → gunzip if the first two bytes are gzip's magic number (a `.m3u.gz`, or a server that gzips without `Content-Encoding`; with the header, `HttpClient` has already unpacked it) → UTF-8 with malformed sequences replaced → lines. Only the current line is ever held. `readM3u` runs in the caller's isolate (the sync engine's); `readM3uInBackground` runs it in a new one and hands entries back in batches of 5,000. **Measured:** a generated 50 MB playlist (221k entries) in 3.8 s, worst UI-isolate gap 17 ms, peak RSS 238 MB for the whole test process.
- **Tolerated:** no `#EXTM3U`; BOM; CRLF and lone CR; invalid UTF-8; unclosed quotes (the value ends at the next comma, so the title survives); unquoted and single-quoted attributes; commas in titles (the title starts after the first comma outside quotes); unknown directives (`#KODIPROP`, `#EXT-X-…`) between `#EXTINF` and its URL; a bare URL with no `#EXTINF` (named after its file); lines over 32 KB (skipped). Skipped and counted: an `#EXTINF` whose URL never comes (including a truncated last line), a line that isn't a URL, a repeated identity. An HTML or JSON body is `ParseFailure`, not an empty playlist.
- **Names:** the title, else `tvg-name`, else the URL's file name; cleaned like Xtream names (entities, U+FFFD, whitespace). `#EXTGRP` stands in for a missing `group-title`. `#EXTVLCOPT` `http-user-agent` and `http-referrer`/`http-referer` apply to the next URL only.
- **Classification** by path (`/series/` episode, `/movie/` movie), then a video-file extension (`.mp4`, `.mkv`, …) as a movie — a plain VOD list has no `/movie/` — else live. Episode names give series, season and episode (`Dark S01 E02`, `s3 e10`, `2x05`, `Season 1 Episode 3`); the sync groups them.
- **Credentials (hard rule 3):** the playlist URL's `username`/`user`/`login`, `password`/`pass`/`pwd`/`passwd` and `token` query values (2+ characters) become `{username}`, `{password}`, `{token}` in every stream URL — whole path segments and query values only, other encoding untouched, username then password then token where two share a value. They are filled back from the secure store at play time (`fillUrl`). A token the playlist URL doesn't carry can't be known, so it stays in the stream URL as sent.
- **Identity:** FNV-1a 64-bit over `tvg-id`, the name and the URL path without its query and without an Xtream path's two credential segments (`/live/u/p/42.ts` → `/live/42.ts`), as 16 hex digits. So a new password, a new load-balanced host or a rotated token keeps the identity; a rename or a new stream id doesn't. Two values are pinned in the tests and were cross-checked against an independent implementation: changing the hash orphans every user's favourites.
- **HTTP:** the default User-Agent (or the source's), 15 s to connect, 30 s idle (the cheap `idleTimeout`, not a timer per chunk), 401/403 `AuthFailure`, 404 `NotFoundFailure`. The `url-tvg`/`x-tvg-url`/`tvg-url` header values come back in the summary as sent; they often carry the credentials, so the caller keeps them in the secure store.

## XMLTV
- Streamed parse in an isolate (files can be 100–500 MB; gzip)
- `<channel id>` with `<display-name>`, `<icon src>`; `<programme start stop channel>` with `<title>`, `<sub-title>`, `<desc>`, `<category>`, `<episode-num>`
- Times like `20260914180000 +0200` → store UTC epoch ms; apply the per-source offset setting
- Retention window: now − 1 day to now + 7 days (configurable); skip everything outside while parsing
- Insert in batches (~5,000 rows per transaction) into staging tables, then swap atomically so the guide never shows half-loaded data
- Refresh daily and on demand; keep the previous guide until the new import completes

### EPG ↔ channel matching (in order)
1. Exact match: Xtream `epg_channel_id` or M3U `tvg-id` = XMLTV channel id
2. Case-insensitive id match
3. Normalized name match: lowercase; strip quality tags (HD, FHD, UHD, 4K, SD, H265); strip country/language prefixes (`UK:`, `|EN|`, `[US]`); strip punctuation; collapse spaces
4. Manual mapping (Settings → Guide), stored per source and never overwritten by sync

## Database (drift)
All provider items are keyed by `(source_id, remote_key)` so user data survives re-syncs.

`DateTime` columns are stored as ISO-8601 UTC text (`store_date_time_values_as_text: true` in `build.yaml`): drift's other option is unix seconds, and it reads those back as *local* time, so a UTC value does not survive a round trip. EPG times stay integer epoch ms in their own columns, as above.

| Table | Columns |
|---|---|
| sources | id, type, name, url (the Xtream server without credentials, a playlist URL's origin only — `http://host/…` — or a file path), username, credential_ref, epg_url (origin only), user_agent, live_format, epg_offset_minutes, refresh_hours, max_connections_override, account_json, expires_at, last_synced_at, sort_order, created_at, updated_at |
| sync_runs | id, source_id, started_at, finished_at, outcome (running/succeeded/failed/cancelled), failure, counts_json — the id is the mark-and-sweep marker |
| categories | id, source_id, kind (live/movie/series), remote_key, name, display_name, is_hidden, sort_order (the user's; null until reordered), position (the provider's), seen_run — unique (source_id, kind, remote_key): Xtream numbers each kind's categories separately |
| channels | id, source_id, category_id, remote_key, number, name, display_name, logo_url, epg_key, archive_days, stream_url, extras_json, is_hidden, added_at, position, seen_run |
| movies | id, source_id, category_id, remote_key, name, poster_url, rating, year, ext, stream_url, extras_json, added_at, position, seen_run |
| movie_details | movie_id, plot, cast_names, director, genre, runtime_minutes, backdrop_url, fetched_at |
| series | id, source_id, category_id, remote_key, name, poster_url, rating, year, plot, updated_at, episodes_fetched_at, position, seen_run |
| episodes | id, series_id, season, episode, remote_key, title, ext, duration_seconds, plot, still_url, stream_url, extras_json, seen_run — unique (series_id, remote_key) |
| epg_channels | id, source_id, xmltv_id, display_name, icon_url |
| epg_programs | id, source_id, epg_channel_id, start_utc, end_utc, title, subtitle, description, category — index (epg_channel_id, start_utc) |
| epg_mappings | source_id, channel_remote_key, xmltv_id |
| favorites | id, item_type, source_id, remote_key, group_name, sort_order, added_at |
| watch_history | id, item_type, source_id, remote_key, position_ms, duration_ms, completed, updated_at |
| cast_devices | device_id, name, model, last_host, is_manual, hevc_support (auto/yes/no), learned_json, last_used_at |
| settings | key, value_json |
| FTS5 | channels_fts (name, display_name), movies_fts, series_fts (name), programs_fts — external-content tables kept current by triggers |

**Secrets (hard rule 3).** A source's secrets live in the system keyring as one JSON document under `credential_ref` (`source.<id>`): the Xtream password, the real playlist URL, and the real EPG override URL. Playlist and EPG URLs go there whole whatever they look like, and the database keeps only their origin: `redact()` can't recognize a token in a path (`/p/9c2e81d4/list.m3u`), so a masked URL is not safe to store, and only the origin is. The Xtream server URL is normalized on save (scheme assumed `http://` if missing; user-info, query, fragment and trailing slashes dropped). `SourceRepository.credentialsFor()` is the only way back to the real values, and it adds every value it returns to the log's `SecretRegistry`. There is no fallback to a file when the keyring is missing or locked: saving fails with a message asking the user to unlock or install one.

Every schema change: bump the schema version, write a migration, add a migration test (drift schema dumps + verifier).

The flow: bump `schemaVersion`, run `dart run build_runner build`, then `dart run drift_dev make-migrations`. That one command writes the new dump into `drift_schemas/app/` (committed), the step-by-step helpers into `lib/data/db/app_database.steps.dart`, and the verifier's helpers into `test/drift/app/generated/` (excluded from the analyzer; drift_dev owns it). Write the new `fromNToM` step in `AppDatabase`, and add a data case to `test/drift/app/migration_test.dart` — the tool creates that file only when it is missing, so it is ours to edit.

Items are keyed by `(source_id, remote_key)`; the columns a sync writes and the ones it never touches are fixed per table:
- **Provider-owned** (rewritten by every sync): everything that comes from the provider, plus `position` and `seen_run`.
- **User-owned** (never written by sync): `display_name`, `is_hidden`, a category's `sort_order`, a series' `episodes_fetched_at`, and `movie_details` / `episodes`, which hang off a row id that an upsert keeps.
- `stream_url` and `extras_json` are for M3U items only: the stream URL has the source's credentials replaced by placeholders, and the extras hold the per-item `#EXTVLCOPT` and catch-up attributes. Xtream URLs are built from the source instead.

Triggers are derived state: drift's versioned schemas leave them out, and its schema verifier does not compare them. So every upgrade drops and recreates all triggers once the tables are final, and a migration test proves the search index works on a migrated database.

Downloads and the local library (tables `library_folders`, `library_items`, `downloads`, `library_fts`) are specified in docs/09 and added by a migration in Phase 8. `favorites` and `watch_history` also hold local files (`item_type = local`, `remote_key` = quick hash).

## Sync engine
- Runs in a background isolate connected straight to the database isolate (`serializableConnection()`, which is why `openAppDatabase` returns drift's `createBackgroundConnection` and not a `LazyDatabase`); emits progress events to the UI: the stage, a count per list, the current list's total once it has arrived, and the account (ADR-009)
- Order: account → categories → live → movies → series for Xtream; an M3U playlist is one stage. EPG runs separately at lower priority (Phase 4)
- Upsert by `(source_id, remote_key)` in batches of 5,000; mark-and-sweep removes items not seen in this run, only after the run succeeded; hidden flags, renames, favorites, history, and mappings are preserved
- **The sync isolate writes only in single batches, never in a transaction**, so cancel and timeout can simply kill it: a killed isolate's open transaction would block the database for everyone. The run's start and its finish (sweep, outcome, `last_synced_at`, in one transaction) happen on the UI isolate's connection
- An Xtream list that comes back empty keeps the previous one (and its categories, with the user's hidden flags) instead of sweeping it; an M3U playlist with no entries fails the run
- A missing or dangling `category_id` is stored as a null `category_id`; the UI files those items under "Uncategorized". There is no synthetic category row
- M3U: categories come from `group-title` per kind; episodes are grouped into series by `(group, series name)` (`seriesIdentity`); an episode whose name has no numbering joins a series named after its group, numbered in playlist order; with no group either, it is filed as a movie. M3U episodes are upserted and swept with the run; Xtream episodes are fetched lazily and replaced as a set. The playlist header's EPG URLs go to the secure store
- Triggers: after onboarding; on app start (after the first frame and 2 s) when `last_synced_at` is older than `refresh_hours` (default 12), one source after another, once interrupted runs are marked failed; manual refresh
- One sync per source at a time (a second request joins the first); a failed sync keeps the previous data and shows a non-blocking banner with Retry
