# 09 — Downloads & local library

One **Library** for video stored on the laptop:
1. **Downloads** — movies and episodes from an IPTV source.
2. **Local files** — the user's own videos, from folders they add.

Library items play offline in the desktop player and cast to Chromecast / Google TV (docs/04 → "Local files and downloads"). Live channels can't be downloaded; recording/DVR stays a v1 non-goal (docs/00).

## What can be downloaded
| Item | URL | Method |
|---|---|---|
| Xtream movie | `{server}/movie/{u}/{p}/{stream_id}.{container_extension}` | HTTP download with resume |
| Xtream episode | `{server}/series/{u}/{p}/{episode_id}.{container_extension}` | HTTP download with resume |
| M3U movie or episode entry | the entry URL | HTTP download with resume |
| Any of these that returns an HLS playlist (content type, or a body starting with `#EXTM3U`) | same | bundled FFmpeg `-c copy` to `.mkv`; no resume (starts over after a failure) |
| Live channel | — | not offered |

URLs contain credentials: rebuild them from the source at every start and resume; never store or log them.

## Download engine (lib/data/downloads/)
| Component | Responsibility |
|---|---|
| DownloadQueue | persisted queue and state machine: order, pause/resume/cancel/retry, resume on launch |
| HttpDownloader | streams the response into `<final name>.part` with Range resume, speed limit, and progress events |
| HlsDownloader | FFmpeg remux for HLS items, supervised like the relay (owner, watchdog, PID file, cleanup) |
| DownloadFinalizer | verifies the file, renames `.part` to the final name, saves artwork, adds the library item |

States: `queued → connecting → downloading ⇄ paused → verifying → completed`, plus `waiting_for_connection`, `retrying`, `failed`, `canceled`.

### Rules
- **Connections:** each active download holds one of the source's connections through the PlaybackCoordinator's connection policy (docs/03). Default 1 download at a time (setting 1–3), never more than the source has free. Playback and casting come first: if they need a connection and none is free, the most recently started download on that source pauses (`waiting_for_connection`) and resumes when the connection frees up.
- **Resume:** request `Range: bytes=<.part size>-` with `If-Range` (stored ETag, else Last-Modified). 206 → append. 200 → the server ignored Range or the file changed → truncate and start over. 416 → complete if the size matches the expected total, otherwise start over.
- **Writing:** stream chunks straight to disk, never a whole file in memory; flush every 8 MB and on pause. After a crash, the `.part` size on disk is the truth.
- **Disk space:** check before starting (expected size + 1 GB) and every 256 MB; below that, pause all downloads and show a banner.
- **Errors** (the watchdog's classes): network → retry after 2, 4, 8, 15, 30, 60 s, then every 60 s, `failed` after 30 min without progress · 401/403 → pause that source's downloads and show the account message · 404 → `failed`, "No longer available from your provider" · 429 or connection limit → `waiting_for_connection`, retry after 60 s · disk write error → `failed` with Details.
- **Verification:** the size matches Content-Length (when sent) and ffprobe reads a duration → rename to the final name. Otherwise `failed` ("The download is damaged") and the `.part` is deleted. A file under a final name is always complete.
- **Speed limit:** Unlimited (default) · 50 · 20 · 10 Mbps.
- **App lifecycle:** quitting pauses and flushes; launching resumes unfinished downloads (setting, default on). Keep the system awake while downloads run (setting, default on; same inhibitor as casting).
- **Series:** "Download season" queues every episode not yet downloaded, in episode order.
- **Download folder:** defaults to the OS Videos folder + `IPTV Player`. Changing it affects new downloads only; existing files stay where they are and stay in the Library.

### File layout
Plex/Jellyfin-style, so other apps can read the folder too:
```
<download folder>/Movies/<Title> (<Year>)/<Title> (<Year>).<ext>                 + poster.jpg
<download folder>/Series/<Show>/Season 02/<Show> - S02E04 - <Episode title>.<ext>  + <Show>/poster.jpg
```
Filenames: remove characters Windows rejects (`< > : " / \ | ? *`, control characters), trailing dots and spaces, and reserved names (CON, NUL, COM1 …); cap each path part at 120 characters and the full path at 240 on Windows; add ` (2)` on a name collision.

## Local library (lib/data/library/)
| Component | Responsibility |
|---|---|
| LibraryScanner | background isolate: walks library folders, filters video files, parses names, diffs against the DB; items appear while the scan runs |
| NameParser | pure: path → movie (title, year), episode (show, season, episode, title), or unsorted |
| File probe | docs/04's StreamProbe run on local files: duration, container, codecs, resolution, HDR, audio and subtitle tracks (20 s timeout, 4 at a time) |
| ThumbnailGenerator | bundled ffmpeg grabs a frame at 10 % of the duration on first display → cached JPEG |
| FolderWatcher | package:watcher on library folders with debounced rescans; also rescans on launch and on demand |

### Rules
- **Video files:** mkv, mp4, m4v, mov, avi, ts, m2ts, mts, webm, wmv, mpg, mpeg. Skip hidden files and folders, `.part` files, files under 20 MB (configurable), and names containing "sample", "trailer", or "featurette".
- **Identity:** a quick hash (file size + first and last 64 KB). Watch history, favorites, and edits follow a file across renames and moves. Files with unchanged path, size, and mtime are never probed again.
- **Missing files:** when a folder disappears (e.g., an unplugged USB drive), its items are dimmed as "Drive not connected" and removed only after 30 days.
- **External subtitles:** same base name plus optional language and flags (`Movie.en.srt`, `Movie.eng.forced.srt`); srt, ass, ssa, vtt.
- **Metadata:** no online lookups in v1. Titles come from names and embedded tags; artwork from `poster.jpg`, `folder.jpg`, or `cover.jpg` beside the file or in its folder, else the generated thumbnail. Downloads keep the provider's poster, plot, and rating through their link to the provider item.
- **Edits:** title, year, type (movie / episode / unsorted), show, season, episode; hide; remove from library (the file stays). Edits survive rescans.
- **Delete file:** only after confirmation. Moves the video and its matching subtitle files to the system trash (for downloads, also the app's artwork and the emptied folder); if no trash is available, deletes permanently after a second confirmation.
- **Hands off otherwise:** the app never renames, moves, or changes files in folders the user added.

### NameParser cases (one fixture test each)
| Path | Result |
|---|---|
| `Show.Name.S02E04.Episode.Title.1080p.WEB-DL.x264-GRP.mkv` | episode · Show Name · S2 E4 · "Episode Title" |
| `Show Name - 2x04 - Title.mp4` | episode · Show Name · S2 E4 · "Title" |
| `Show Name/Season 2/04 - Title.mkv` | episode, from the folder names |
| `Show.Name.S02E04E05.mkv` | episodes 4–5 |
| `Movie.Title.2019.2160p.UHD.BluRay.x265.mkv` | movie · Movie Title (2019) |
| `Movie Title (2019)/Movie Title (2019).mkv` | movie · Movie Title (2019) |
| `Some video.mp4` | unsorted |

Release tags to strip: resolution, source (BluRay, WEB-DL, WEBRip, HDTV), codec (x264, x265, HEVC, H.264), audio (DTS, AC3, DDP5.1, Atmos), group suffixes, bracketed tags.

## Data (drift migration in Phase 8)
| Table | Columns |
|---|---|
| library_folders | id, path, is_download_folder, is_available, last_scan_at, added_at |
| library_items | id, folder_id, rel_path, size_bytes, mtime, quick_hash, kind (movie/episode/unsorted), title, year, show_title, season, episode, episode_end, duration_ms, probe_json, thumbnail_path, artwork_path, subtitles_json, user_edits_json, provider_source_id, provider_item_type, provider_remote_key, is_hidden, unavailable_since, added_at |
| downloads | id, source_id, item_type (movie/episode), remote_key, series_remote_key, season, episode, title, artwork_url, target_path, total_bytes, downloaded_bytes, etag, last_modified, state, error_class, error_detail (redacted), attempts, library_item_id, created_at, completed_at |
| library_fts | title, show_title |

- Downloads use the provider item's key in `watch_history` and `favorites`, so progress is shared between streaming and the downloaded file.
- Local files use `item_type = local` with `remote_key` = quick hash.

## Playback
Library items open through `PlayerEngine` as `PlayableSource` kind `file`:
- No reconnect logic: a read error means the file is missing or damaged → failed state with Show in folder / Remove from library.
- External subtitle files are attached automatically; the VOD rules in docs/03 (resume, completion, next episode) apply.
- Once a movie or episode is downloaded, Play on its details page uses the local file — no provider connection needed.
