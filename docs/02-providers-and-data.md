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
| sources | id, type, name, server_url, username, credential_ref, m3u_url, epg_url_override, user_agent, live_format, epg_offset_min, refresh_hours, max_connections_override, account_json, exp_date, last_synced_at, sort_order |
| categories | id, source_id, kind (live/movie/series), remote_key, name, display_name, is_hidden, sort_order |
| channels | id, source_id, category_id, remote_key, number, name, display_name, logo_url, epg_key, archive_days, ext, is_hidden, added_at |
| movies | id, source_id, category_id, remote_key, name, poster_url, rating, year, ext, added_at |
| movie_details | movie_id, plot, cast, director, genre, runtime_min, backdrop_url, fetched_at |
| series | id, source_id, category_id, remote_key, name, poster_url, rating, year, plot, updated_at |
| episodes | id, series_id, season, episode, remote_key, title, ext, duration_s, plot, still_url |
| epg_channels | id, source_id, xmltv_id, display_name, icon_url |
| epg_programs | id, source_id, epg_channel_id, start_utc, end_utc, title, subtitle, description, category — index (epg_channel_id, start_utc) |
| epg_mappings | source_id, channel_remote_key, xmltv_id |
| favorites | id, item_type, source_id, remote_key, group_name, sort_order, added_at |
| watch_history | id, item_type, source_id, remote_key, position_ms, duration_ms, completed, updated_at |
| cast_devices | device_id, name, model, last_host, is_manual, hevc_support (auto/yes/no), learned_json, last_used_at |
| settings | key, value_json |
| FTS5 | channels_fts, movies_fts, series_fts, programs_fts |

Every schema change: bump the schema version, write a migration, add a migration test (drift schema dumps + verifier).

The flow is `dart run drift_dev make-migrations`, which writes the dump for the current version into `drift_schemas/app/` (committed), followed by `dart run drift_dev schema generate drift_schemas/app/ test/data/db/generated/` for the verifier's helpers. `test/data/db/schema_v1_test.dart` checks the live schema against the committed dump; `test/data/db/generated/` is excluded from the analyzer because drift_dev owns it.

Downloads and the local library (tables `library_folders`, `library_items`, `downloads`, `library_fts`) are specified in docs/09 and added by a migration in Phase 8. `favorites` and `watch_history` also hold local files (`item_type = local`, `remote_key` = quick hash).

## Sync engine
- Runs in a background isolate with its own DB connection; emits progress events (stage, counts) to the UI
- Order: account → categories → live → movies → series; EPG runs separately at lower priority
- Upsert by `(source_id, remote_key)`; mark-and-sweep removes items not seen in this run; hidden flags, renames, favorites, history, and mappings are preserved
- Triggers: after onboarding; on app start when `last_synced_at` is older than `refresh_hours` (default 12); manual refresh
- One sync per source at a time; a failed sync keeps the previous data and shows a non-blocking banner with Retry
