# Phase 8 — Downloads and the local library: plan

**Status: approved 2026-10-04, every recommendation and the eight sketches (the user: "all approved based on ur recommendations").** What is built and every departure from this plan goes into ADR-015 (docs/decisions.md) as the steps land.

## Context
Phase 7 is built. Only its TV sitting is left: step 2's 30-second check, then the casting matrix, about 25 minutes. Phase 8 adds the second half of ADR-005:
- movies and episodes downloaded from your sources;
- your own video folders;
- both playable offline, and castable to the TV.

Exit criteria (docs/08):
- Downloads resume after network drops and after SIGKILL + relaunch, with no damaged file under a final name.
- Playback on a one-connection source pauses downloads, and they resume afterwards.
- A downloaded movie plays with the network off and shares its progress with streaming.
- docs/06's library budgets are met: a scan of 5,000 new files ≤ 5 min (browsable meanwhile), a rescan of 5,000 unchanged files ≤ 5 s, download speed ≥ 90 % of curl's, and memory growth ≤ 30 MB over a 4 GB download.
- The library casting matrix (docs/04) passes on your TV.
- No FFmpeg is left behind after SIGKILL + relaunch.

Already in place, so the phase starts further along than docs/08 suggests:
- **Connections:** `SourceConnections` counts each source's connections by holder (the player, the cast). Its doc comment already names downloads as the third holder, the one that yields. The player waits for room before it opens a stream (up to 5 s).
- **Processes:** `ProcessSupervisor` gives every FFmpeg and ffprobe a PID file, a timeout, SIGTERM then SIGKILL, and the launch sweep. `FfprobeStreamProbe` and `StreamFacts` read a file's streams. `FfmpegBinaries` finds the bundled binaries.
- **Sleep:** `SleepInhibitor` (the desktop portal, logind, Windows), whose doc already says downloads will hold it too.
- **Casting a file:**
  - the relay serves a file with Range (`serveFile`, `/f/<token>/media.<ext>`, already used for direct plays);
  - the planner's direct-file rule;
  - the continuous relay for files, where a seek restarts it and the place stays right;
  - the backpressure rules from step 7.
- **Playback:** the VOD rules (resume, 95 % watched, the next episode, the player's "Resumed from" line), `WatchProgress`, and Continue watching.
- **The database:** `favorites` and `watch_history` already allow `item_type = local` with no source.
- **Design pieces from Phase 1:**
  - `DownloadButton` (every state), `DownloadRow`, `StorageMeter` and the Downloaded badge;
  - the top bar's download slot (`ShellDownloads`, empty until now);
  - the Library item in the nav rail and Ctrl+7, with a "Phase 8" placeholder;
  - Settings → Downloads & library, marked "Phase 8".
- **Packages already in pubspec:** `watcher`, `file_selector` (the folder picker), `desktop_drop` (a folder dropped on the window), `xdg_directories` (the Videos folder), `ffi`, `win32`, `dbus`.
- **The fake panel's files:** Range, ETag, Last-Modified, If-Range, HEAD, and the faults `ignore_range`, `drop_after_bytes` and `throttle_kbps`. `change_etag` and `wrong_content_length` are parsed but do nothing yet; `size_mb` and `vod_as_hls` aren't there.
- **Samples:** `vod_h264_aac_10min.mp4`, `vod_h264_ac3_10min.mkv` with its `.en.srt`, and `vod_hevc_eac3_subs.mkv`. `tools/media_samples/library_tree.sh` doesn't exist yet.
- **The canvas** draws Library (the Movies tab), Library · Downloads and Settings · Downloads and library, plus the Downloaded marks on Movie details, Series details, Home and Search.

What Phase 8 does **not** own:
- **Online metadata lookups:** a v1 non-goal (docs/09). Titles come from names, tags and the provider.
- **Recording live channels:** a v1 non-goal.
- **Downloads in the Google TV app** (ADR-005).
- **Bitmap subtitles (PGS, VobSub) on the TV** (docs/04).
- **Scheduled downloads** (time windows) and any re-encoding of downloads.
- **Windows runs:** the trash, free space, the Videos folder, file locking, the watcher on NTFS. They are written, and CI runs their unit tests, but they wait for your Windows PC.

Carried in, not to be relitigated without new evidence:
- **Hard rules:**
  - **7:** downloads count as streams and yield to playback;
  - **8:** every FFmpeg and ffprobe is supervised;
  - **11:** `.part` until verified; nothing in your own folders is renamed, moved or changed; Delete is confirmed and goes to the trash;
  - **3:** no credentials in logs, or in the database's error columns.
- **ADR-005 and docs/09:** the layout, the rules, the tables.
- **Phase 7 decision 3:** no credentials on a command line. FFmpeg reads the provider through a loopback proxy, and the app sees the connection open and close.
- **ADR-010:** whoever holds a connection must notice when the other end goes away.
- **ADR-014's relay rules for files:** a seek on a continuous stream restarts it; a TV that holds back is never a stall.
- **Your standing rules:**
  - ask before any stream from your real provider (a real download is one);
  - ask before every cast to the Living Room TV.

Working rhythm, as before: one numbered step at a time, as docs/08 asks. After each step: analyze, format, `TZ=UTC flutter test`, a local commit without trailers, and a stop for your review.

Every download in this phase comes from the fake panel, never your provider. If you want one at the very end, it gets its own pop-up, since your plan allows one connection. Your TV is needed only in step 8, for the library casting matrix, with your go-ahead and you watching. If the TV is still away by then, it joins Phase 7's sitting.

## Decisions (my recommendation first in each)

1. **Start Phase 8 now, while Phase 7's TV sitting waits.**
   - **Recommendation:**
     - docs/08 says a phase starts only once the one before has met its exit criteria. What Phase 7 lacks is a 25-minute sitting that waits only for the TV to be back on your network.
     - Steps 1–6 here don't touch casting. Step 7 builds on Phase 7's relay, and can go ahead against the fake TV.
     - Both TV sittings can happen together when the TV is back. Phase 7 is accepted at its own sitting.
   - **Rejected alternative: wait for the TV.** Nothing would move until then, and the two sittings would still be the same length.

2. **Downloads move their bytes in an isolate of their own; the queue's rules stay in the app's isolate.**
   - **Recommendation:**
     - **The downloads isolate** starts with the first download and stays until the app quits, like the relay's. It reads the provider with dart:io's `HttpClient` and writes with a `RandomAccessFile`. It sends progress about 4 times a second.
     - **The queue** (`DownloadQueue`, domain code) decides what runs, when it pauses, and what an error means. It needs the playback and cast holders and `StreamResolver` (the keyring), which live in the app's isolate. It writes the `downloads` rows: progress every 8 MB, and every state change.
     - **Credentials stay in the app:** the isolate asks it for the URL on every connection, as the relay's proxy does.
   - **Why dart:io and not dio:** a download needs the socket's backpressure (pausing the read is how the speed limit and a full TV-style hold work), Range and If-Range, and nothing buffered. The relay's proxy already does exactly that with dart:io. dio stays for the API.
   - **Rejected alternative: downloads in the UI isolate.** On a fast network, or on the fake panel over loopback, it is thousands of chunks a second through the UI's event loop. That breaks hard rule 2, which is why the relay got its own isolate (Phase 7 decision 5).

3. **Downloads yield to playback through `SourceConnections`.**
   - **Recommendation:**
     - Downloads are a holder that **yields**. When the player or the cast wants room on a source and a download holds a connection there, the newest download on that source pauses at once (`waiting_for_connection`) and closes its connection. The player's wait then ends as soon as the slot is free, not after its 5 s.
     - **Downloads come back 10 s after the source's last other holder lets go.** Zapping, a seek that reopens, or moving to the next episode would otherwise see a download take the slot in between.
     - Downloads never start while a one-connection source is in use, and never take more than the source's free connections (setting 1–3; default 1).
     - The first pause in a viewing says so once: "Downloads paused while you watch — your provider allows 1 connection." (docs/05).
     - A cast's direct play of a provider file holds the connection like the player, so a download waits for it too.
   - **Rejected alternative: the queue polls the connection count.** A player would wait for the poll, and a panel slow to free a slot would make every open slower.

4. **A provider item that answers with HLS is saved with FFmpeg through a loopback proxy, with no resume.**
   - **Recommendation:**
     - Detected by the content type, or by a body that starts with `#EXTM3U`.
     - FFmpeg `-c copy -f matroska` writes `<final name>.part`. It reads `http://127.0.0.1:<port>/in/<token>` from the relay's `RelayProxy`, run inside the downloads isolate: no credentials in its arguments, the connection counted, the URL rebuilt for every request.
     - A failure starts it over, as docs/09 says. Supervised like the relay's FFmpeg (hard rule 8).
   - Your panel serves MKV files (Phase 5), so this path is for other panels. It is kept small.
   - **Rejected alternative: FFmpeg reads the provider's URL.** The credentials would sit in its command line, readable by any local user (`/proc/<pid>/cmdline`).

5. **A download keeps a copy of its details**, so its page works offline, and after the provider drops the title.
   - **Recommendation:**
     - The finalizer writes `poster.jpg` from the app's own picture cache (no extra request), as docs/09's layout has it.
     - It also stores the title's details (plot, rating, genres, cast, runtime, and an episode's title and still) in a new column, `library_items.details_json`.
     - While the provider still lists the title, the provider's page is used. When it doesn't, or offline, the stored copy fills the same page.
   - **Departure from docs/09's table:** one extra column. docs/09 says the details come "through their link to the provider item", but a sync that sweeps the title, or removing the source, breaks that link.
   - **Rejected alternative: the link only.** A downloaded movie would lose its plot the day the provider drops it, which is often exactly why it was downloaded.

6. **The scanner works in two passes, as a guarded background job like sync.**
   - **Recommendation:**
     - **Pass 1, fast:**
       - walk the folder with docs/09's skip rules;
       - `stat` every file; a file with the same path, size and modification time is done;
       - quick-hash each new or changed file (size + the first and last 64 KB) and parse its name;
       - write in batches every 500 files or half a second, so the Library fills while the scan runs.
       - A new hash that matches a missing file is a **move**: the row, its history, favorites and edits follow the file.
     - **Pass 2, slow:** ffprobe on the new files, 4 at a time, 20 s each (docs/09). The length, the quality line and the tracks arrive a moment later.
     - **Missing files:**
       - a whole folder gone (a USB drive unplugged) → its items are dimmed with "Drive not connected" and removed after 30 days;
       - a single file gone from a folder that is there → removed at once (its history stays, keyed by the hash, in case it comes back).
     - **Thumbnails** are made when first shown: the bundled FFmpeg grabs a frame at 10 % of the length, 2 at a time, 15 s each, cached by hash. `poster.jpg`, `folder.jpg` or `cover.jpg` beside the file come first.
   - That fits the budgets: a rescan of unchanged files is `stat` only, and new files show before they are probed.
   - **Rejected alternative: probe while walking.** 5,000 new files would show only as fast as ffprobe runs, about 2 minutes behind.

7. **Folders are watched with package:watcher, with a fallback.**
   - **Recommendation:**
     - Each library folder is watched. Changes rescan only the folder they happened in, 3 s after the last change (copying a big file is many changes).
     - Where a watch can't be set (Linux's inotify limit on a huge tree, a network share), the folder's row says "Updates when rescanned". It is then rescanned at launch, when the Library opens, and with Rescan.
     - The download folder is told about new files by the finalizer, so it needs no watch for its own downloads.
   - **Rejected alternative: rescans only** (at launch and on demand). A file copied into a watched folder should just appear.

8. **Every Play of a downloaded movie or episode uses the file; your own files are a new `Playable`.**
   - **Recommendation:**
     - **`StreamResolver.movie` and `.episode` look for a finished download first.** Every place that plays a title then uses the file without knowing it: Home, a details page, search, Continue watching and the next-episode card. It holds no connection, and history stays keyed to the provider's title, so the progress is shared (docs/09).
     - **Your own files** play as `PlayableLibraryItem`, keyed in history as `local` + the quick hash.
     - **No reconnects for files on disk:** a read error means the file is missing or damaged. The failed state offers Show in folder and Remove from library (docs/03).
     - **External subtitles** beside the file are added as subtitle tracks (mpv's `sub-files`). S cycles through them as through the file's own.
     - **The next episode** of your own show is the next file in it by season and episode. For a downloaded series, it is the next downloaded episode, else the provider's (streamed, which needs the network).
   - **Rejected alternative: a separate "Play downloaded" action.** You would have to know which copy you have. docs/05 says "Once downloaded, Play uses the local file".

9. **What Enter opens in the Library.**
   - **Recommendation:**
     - **Movies and Series** open a page, as the Movies and Series grids do. That page is also the resume prompt.
       - A download whose title the provider still lists opens the provider's page, with Downloaded and Play using the file.
       - Your own movies, your own shows, and downloads the provider dropped open the same layouts, filled from the library: the length, the file's quality line (1080p · H.264 · AC-3 5.1), the folder and file name, and the subtitles found. Sketches A and B.
     - **Videos** (unsorted) play at once, resuming where they were left; the player's "Resumed from … · Home starts over" is the prompt. A page would hold nothing but a name and a length. Sketch C.
     - **The menu key** on any library item: Play from the start, Cast, Show in folder, Edit details…, Hide, Remove from library, Delete file… (docs/05). Sketch D.
   - **Rejected alternative: Enter plays everything.** Movies and shows would lose the place that says what the file is, and where it was left.

10. **Delete goes to the trash with our own small implementation of the freedesktop trash spec on Linux.**
    - **Recommendation:**
      - **Linux:** a file on the home drive goes to `~/.local/share/Trash`. A file on another drive goes to that drive's own trash (`.Trash/<uid>` when it exists and is safe, else `.Trash-<uid>`). Each gets its `.trashinfo`, so the desktop's trash can put it back. A trash is always on the same drive, so it is a rename and never a copy.
      - **Windows:** `SHFileOperationW` with `FOF_ALLOWUNDO` through win32 (the Recycle Bin). Untried here.
      - **No trash** (a read-only drive, a network share): a second confirmation, then a permanent delete (docs/09).
      - It moves the video and its subtitle files. For a download, it also removes the app's artwork and the folder left empty.
    - **Rejected alternative: `gio trash`.** It isn't on every desktop, it is a process to supervise, and it can copy across drives without saying so.

11. **"Offline" comes from the system, with the app's own failures as the fallback.**
    - **Recommendation:**
      - **Linux:** NetworkManager's state over D-Bus (`dbus` is already a dependency; Ubuntu's desktop has it). Below "connected to the internet" is offline, and its signal says when that changes.
      - **Windows:** the Network List Manager through win32. Untried here.
      - **Where neither answers:** a request to a source that got no answer at all counts, until the next success.
      - The banner on Home: "You're offline — downloads and local files still play" with Open Library (docs/05). Nothing in the Library depends on it.
    - **Rejected alternative: pinging a public host.** It sends a request to a third party every few seconds, and still can't tell your provider being down from the internet being down.

12. **Casting a library file: direct when the TV can play it as it is. Otherwise the continuous relay at once, plus an MP4 made in the background so that later seeks are native.**
    - **Recommendation:**
      - **Direct:** MP4, M4V, MOV or WebM, video the TV takes, and AAC or MP3 first. The relay serves the file with Range (already built). Phase 0 measured seeks within 200 ms.
      - **Anything else:**
        - Phase 7's continuous relay starts at once from the place. A seek restarts it, with "Preparing…".
        - **Beside it**, when the video is copied (not re-encoded), FFmpeg writes a complete MP4 into the cast's cache at full speed: video copied (`hvc1` for HEVC), audio to AAC, `+faststart`. A 2 GB movie should take under a minute here (step 7 measures it). Once it is ready, the next seek LOADs it as a direct file at that place, and every seek after that is native, with no restart.
        - The MP4 is deleted when casting ends. It isn't made when the drive lacks its size + 1 GB free.
      - **Subtitles:** text subtitles (an external srt, ass or vtt file, or an embedded text track) are turned into WebVTT by FFmpeg and served by the relay. They are listed in the LOAD's `tracks` and switched with S in the casting view. Times are shifted when the continuous stream started past 0:00.
      - **A downloaded movie casts from its file,** not from the provider. That means no connection used, and a download can keep running.
    - **Departure from docs/04,** which describes an HLS EVENT playlist the TV can seek inside. That works only for H.264: this receiver can't take HEVC in TS segments, and HEVC in fMP4 segments stutters on open GOP (ADR-004). The MP4 path works for both, and it is the direct-file path Phase 0 proved.
    - **Rejected alternative: every seek restarts the relay** (Phase 7's way, alone). It works, and it stays the path for re-encoded files, but a movie with a few seeks would show "Preparing…" every time.

## Step 1 — Schema v9, the domain, the download folder
- **Schema v9:** docs/09's four tables, plus three columns and one index:
  - `library_items.details_json` (decision 5);
  - `library_folders.label` ("Movies HDD", as the canvas shows): the drive's label for a folder on a removable drive, else the folder's name; renamable in Settings;
  - `downloads.sort_order` (the queue's order; docs/05 has drag to reorder);
  - **a unique index for local rows in `favorites` and `watch_history`.** SQLite treats NULLs as distinct, so the existing `(item_type, source_id, remote_key)` key would let one file get two history rows.
  - Plus the indexes the Library's queries need, and `library_fts` (title, show title) with its triggers, recreated on every upgrade like the others.
  - The migration test with data cases.
- **The domain** (`lib/core/library/`, `lib/core/downloads/`, as docs/01 lays out): `LibraryFolder`, `LibraryItem`, `LibraryItemEdit`, `LibraryQuery`, `DownloadTask`, `DownloadState` (docs/09's states), `DownloadRequest`, and the `LibraryRepository` and `DownloadService` interfaces.
- **DAOs:** `LibraryDao` and `DownloadsDao`, on a real in-memory database in tests.
- **The download folder:** the system's Videos folder (`xdg-user-dirs` on Linux, the Videos known folder on Windows, `~/Videos` as the fallback) + `IPTV Player`. It is registered as the library's download folder at launch and created only by the first download.

## Step 2 — The fake panel's downloads, and the library tree
- **The fake panel** (docs/06):
  - `change_etag`: every answer has a new ETag and Last-Modified, so a resume's If-Range fails and gets the whole file;
  - `wrong_content_length`: a Content-Length longer than the body;
  - `size_mb`: a sample padded to any size, made as it is sent (nothing stored), for the 4 GB measurement;
  - `vod_as_hls`: a movie or episode answered as an HLS VOD playlist, with segments made once with FFmpeg into the fake panel's cache. Each segment request holds a connection slot.
  - The existing `http_status` (401, 403, 404, 429), `max_connections`, `drop_after_bytes`, `ignore_range` and `throttle_kbps` complete docs/09's error classes.
- **`tools/media_samples/library_tree.sh <dir> <count>`** (docs/06): short low-resolution clips, each with its own title tag so the quick hashes differ. It writes:
  - movies in folders and loose;
  - shows with nested seasons;
  - junk release names;
  - subtitles in every naming docs/09 lists;
  - "sample", "trailer" and "featurette" files;
  - files under the minimum size, hidden folders, and a `.part` file.
  - All the names are fictional.
- **Verify:** the fake panel's own suite (each fault), and the tree script's output read back with ffprobe.

## Step 3 — The download engine
- **`DownloadQueue`** (domain, pure, tested under fake time):
  - order, 1–3 at a time, pause, resume, cancel (deletes the `.part`), retry;
  - docs/09's error classes:
    - network → 2, 4, 8, 15, 30, 60 s, then every 60 s; failed after 30 min without progress;
    - 401/403 → that source's downloads pause, with the account message;
    - 404 → failed, "No longer available from your provider";
    - 429 or the connection limit → `waiting_for_connection`, again after 60 s;
    - a disk write error → failed, with Details;
  - the disk-space rule: expected size + 1 GB before starting, checked again every 256 MB. Short of it, everything pauses and a banner says so;
  - **at launch,** unfinished downloads resume (the setting, on by default) from the `.part` file's real size;
  - **at quit,** downloads pause and flush within the window's close, beside the cast's quit tasks.
- **The downloads isolate** (decision 2):
  - `HttpDownloader`: Range + If-Range (the stored ETag, else Last-Modified); 206 appends; 200 truncates and starts over; 416 is complete if the size matches, else it starts over; a flush every 8 MB and on pause; the speed limit (Unlimited, 50, 20, 10 Mbps) by pausing the read;
  - `HlsDownloader` (decision 4).
- **`DownloadFinalizer`:**
  - verify: the size matches Content-Length when one was sent, and ffprobe reads a length;
  - rename the `.part` to the final name;
  - write `poster.jpg` and the details copy (decision 5), and add the library item, linked to the provider's title;
  - a failed check → failed, "The download is damaged", and the `.part` deleted.
  - **A file under a final name is always complete.**
- **`DownloadPaths`** (pure):
  - docs/09's layout;
  - the filename rules: characters Windows refuses, trailing dots and spaces, reserved names, 120 per part and 240 in all on Windows, ` (2)` on a collision.
  - Tested on Linux for Windows' rules too.
- **Connections** (decision 3): `SourceConnections` learns about a holder that yields. The player and the cast ask for room; the newest download on that source lets go; downloads come back 10 s after the source is free.
- **Shared sleep hold:** the cast and the downloads each hold it; the system can sleep again only when neither does. Setting: keep awake while downloading, on by default.
- **Free space:** `statvfs` through FFI on Linux, `GetDiskFreeSpaceExW` on Windows.
- **Series:** "Download season" queues every episode not yet downloaded, in episode order.
- **Verify:**
  - the queue's rules under fake time;
  - the downloader against a scripted server (each status, If-Range, a body cut short, a Content-Length that lies);
  - end to end against the fake panel in-process for every fault, with the downloaded file byte-identical to the sample;
  - a one-connection source: Play while a download runs → the download pauses at once, the player opens, the download resumes 10 s after Stop. The same with a cast;
  - **SIGKILL:** a separate process downloading is killed; the next start resumes from the `.part`, and no file ever exists under its final name before it is verified (the pattern of `sync_kill_test`). An HLS download's FFmpeg ends and is swept;
  - **measured:** speed against curl on the same URL (the fake panel in its own process); memory over a 4 GB download (`size_mb`).

## Step 4 — Names and the scanner
- **`NameParser`** (pure), with a fixture corpus:
  - docs/09's seven cases;
  - many more: `1x04`, `S01E01-E02`, a season folder with numbered files, a year in the title (`Blade Runner 2049 (2017)`, `2001 A Space Odyssey (1968)`), bracketed groups (`[Group] Show - 04 [1080p]`), dates, accents and other scripts, names Windows would refuse;
  - each with what it must give.
- **`LibraryScanner`** (decision 6):
  - as a guarded job with its own process supervisor for ffprobe;
  - moves by hash; missing files; folders unplugged and plugged back; the 30-day rule;
  - external subtitles (`Movie.en.srt`, `Movie.eng.forced.srt`; srt, ass, ssa, vtt);
  - artwork files beside the video;
  - `.part` files and the size minimum (20 MB, configurable; tests lower it).
- **`FolderWatcher`** (decision 7) and **thumbnails** (decision 6), on demand.
- **`LibraryRepository`:**
  - the tabs' queries, with your edits laid over what was parsed (edits survive rescans);
  - search through `library_fts`;
  - hide; remove from library (the file stays); Delete file (decision 10);
  - add, rename and remove folders. Removing a folder leaves its files on disk.
- **Verify:**
  - the parser's corpus;
  - the scanner on `library_tree.sh` trees in temporary folders: new, unchanged, renamed, moved, deleted, a folder made unavailable and brought back, edits kept;
  - the watcher with real file events;
  - **measured:** 5,000 new files ≤ 5 min with the UI isolate's longest pause recorded (browsable meanwhile); 5,000 unchanged files ≤ 5 s.

## Step 5 — Playback of library items, offline
- Decision 8:
  - the resolver's file-first rule for downloads;
  - `PlayableLibraryItem` for your own files;
  - no connection held, no reconnects;
  - the failed state with Show in folder and Remove from library;
  - external subtitles as tracks;
  - resume, 95 % watched, and the next episode within a show.
- **Favorites and history for local files** (the index from step 1). Continue watching lists your own files and downloads too, with the Downloaded badge, as the canvas's Home draws.
- **Offline** (decision 11): the system signal, and the Home banner's state, which the UI step draws.
- **Verify:**
  - unit tests on the fake engine;
  - integration with the real player: a library file plays with the fake panel stopped, with its external subtitles listed, and resumes where it was left; a downloaded movie plays from its file and its progress shows on the provider's page.

## Step 6 — The UI
Read the canvas with the Artifact tool first (Library, Library · Downloads, Settings · Downloads and library).
- **Library** (canvas):
  - tabs Movies · Series · Videos · Downloads · Folders, with counts;
  - chips All · Downloaded · Local folders;
  - "42 movies · 186 GB on this computer"; Add folder;
  - the poster grids with "Downloaded · 2.1 GB" or the folder's name;
  - unavailable items dimmed with "Drive not connected";
  - a scan running shows in the header, and items appear while it runs.
  - Series and Videos (sketches B and C); Folders (the same list as Settings').
  - Empty first run: "Add a folder with your own movies and shows" [Add folder], and "Press D on a movie or episode to download it."
- **Library · Downloads** (canvas):
  - IN PROGRESS (percent, size, speed, time left; Queued "starts after …");
  - NEEDS ATTENTION (the reason, Retry, Remove; an account problem with Edit source);
  - FINISHED TODAY (Play, Clear list);
  - Pause all / Resume all;
  - the StorageMeter with the folder and Change folder;
  - reorder by dragging, or Alt+↑/↓;
  - the empty state.
- **The pages** (decision 9, sketches A and B): the provider's pages gain the DownloadButton (sketch E):
  - Movie details;
  - Series details, with "Download season" and a button per episode;
  - **D** on a movie or episode anywhere (docs/05's shortcut table).
- **The item menu, Edit details and Delete** (sketches D and F); Hidden videos in Settings (sketch H).
- **The top bar's indicator** "↓ 2 · 34 %" opens Library → Downloads.
- **Search's Library group,** as the canvas draws it ("Harbor Walk (2021) · Home videos · 12 min").
- **Settings → Downloads & library** (canvas):
  - the folder with Change…;
  - downloads at a time 1/2/3 ("Never more than your provider's free connections. Watching always comes first.");
  - the speed limit;
  - resume on launch;
  - keep awake;
  - LIBRARY FOLDERS: Add folder, Rescan, Remove, "Updates automatically" or "Updates when rescanned", "not connected · its 64 videos stay listed for 30 days"; a folder's menu has Rename.
- **Banners and toasts:**
  - offline on Home, and disk space (sketch G);
  - "Download finished · <title>" [Play];
  - "Downloads paused while you watch — your provider allows 1 connection."
- **Keyboard:** everything above by keys alone, with the design system's focus. Each grid and list is one Tab stop with arrows inside. Ctrl+7 goes to the Library.
- **Verify:**
  - widget tests for every state of every screen above;
  - goldens at 1280 × 800 and 1920 × 1080, checked against the canvas;
  - **a keyboard walk on the real app** with the fake panel and a `library_tree.sh` folder: D on a movie → the top bar's indicator → Ctrl+7 → Downloads → it finishes → Play → Esc → Movies → a local movie's page → Resume → Esc → its menu → Edit details → Save → Delete file → Keep.

## Step 7 — Casting library items
- **Decision 12:**
  - direct with Range;
  - the continuous relay at once, then the MP4 made beside it for native seeks;
  - WebVTT subtitles, with S in the casting view;
  - a downloaded movie casts from its file.
- **The fake TV learns:**
  - text tracks in LOAD;
  - `EDIT_TRACKS_INFO`;
  - fetching and checking the WebVTT file;
  - a SEEK on a direct file read as a new Range request at the right offset.
- **Verify:**
  - end to end against the fake TV for every row of docs/04's library matrix;
  - the casting view and bar for a library item (widget tests);
  - **the matrix runner** (`cast_matrix_tv_test.dart`) gains the library rows, checked against the fake TV first.

## Step 8 — Integration, the library matrix on your TV, and the exit
- **Integration tests** (docs/06):
  - download → kill the app → relaunch → resume → play offline;
  - library scan → play → resume;
  - after SIGKILL + relaunch, no FFmpeg left from the HLS downloader, the thumbnails or the cast's MP4.
- **With your go-ahead and you watching, on Living Room TV:** docs/04's library matrix:
  - MP4 H.264 + AAC direct, with seeks;
  - MKV H.264 + AC-3 through the relay, with seeks before and after its MP4 is ready;
  - MKV HEVC + E-AC-3;
  - external SRT subtitles, direct and through the relay;
  - a movie downloaded from the fake panel;
  - resume on the TV from a place saved on the laptop.
  - Together with Phase 7's sitting if that hasn't happened yet.
- **If you want it, with its own pop-up:** one real download from your provider (a short episode), since your plan allows one connection.
- **Docs:**
  - ADR-015 Accepted;
  - docs/09 and docs/04 "As built";
  - docs/05 (the Library as built);
  - docs/06's library budgets and fakes;
  - docs/02's schema v9;
  - progress and the handoff.

**Alongside, one small commit each:** whatever CI names after you push Phase 7, and Phase 6's small loose ends if a step passes near them.

## Sketches for approval (not on the canvas)

**A. A movie from your own folder** (decision 9; the Movie details layout):
```
‹ Library
[poster or frame]  Paper Kites
                   2019 · 1 h 52 min · 1080p · H.264 · AC-3 5.1
                   Movies HDD · Paper Kites (2019)/Paper Kites (2019).mkv
                   Subtitles: English · English (forced)
                   ━━━━━━━━━━━━━━●───────────────  1 h 10 min left
                   [ ▶ Resume from 0:42:10 ]  [ Start over ]  [ ⧉ ]  [ ☆ ]  [ ⋯ ]
```
A download the provider dropped looks the same, with its stored poster and plot, and "Downloaded" where the folder is.

**B. Library → Series, and one of your own shows** (the Series details layout):
```
Harbor Nine            Kettle Bay              Glass Tide
3 seasons · Movies HDD 1 season · Downloaded   2 episodes · Downloaded

‹ Library
Kettle Bay                       [ Season 1 ] [ Season 2 ]
2 seasons · Movies HDD           ┌──────┐ S2 · E3  The Long Tide       44 min ━━━──
[ ▶ Continue S2 · E4 ] [ ☆ ]     └──────┘ S2 · E4  Episode 4           41 min
                                 (an episode with no title in its name is "Episode 4")
```
Downloaded episodes of a provider's series stay under that series, on its own page.

**C. Library → Videos** (unsorted; landscape cards; Enter plays):
```
┌────────────┐ Birthday at the lake        ┌────────────┐ Garden timelapse
│   frame    │ 12 min · Home videos        │   frame    │ 4 min · Home videos
└────────────┘                             └────────────┘ ━━━━━──
```

**D. The item menu** (the menu key, Shift+F10, or right-click):
```
▶ Resume                 Enter
  Play from the start
  Cast                   C
  Show in folder
  Edit details…
  Hide
  Remove from library
  Delete file…
```

**E. Downloading from Movie details** (the canvas draws only the Downloaded state):
```
[ ▶ Resume from 1:12:40 ]  [ Start over ]  [ ↓ Download ]          [ ☆ ]  [ ⧉ ]
[ ▶ Resume from 1:12:40 ]  [ Start over ]  [ ◔ 49 % · 2 min left ] [ ☆ ]  [ ⧉ ]
[ ▶ Resume from 1:12:40 ]  [ Start over ]  [ ✓ Downloaded ]        [ ☆ ]  [ ⧉ ]
```
Enter on a running download opens its menu (Pause, Cancel download). On a finished one: Show in folder, Delete download…. On a failed one: Retry, with the reason.

**F. Edit details, and Delete:**
```
Edit details
File   Show.Name.S02E04.Episode.Title.1080p.WEB-DL.x264-GRP.mkv
Type   ( Movie | Episode | Video )
Show   [ Show Name        ]   Season [ 2 ]   Episode [ 4 ]
Title  [ Episode Title    ]   Year   [    ]
               [ Use the file's name ]   [ Cancel ]  [ Save ]

Delete "Paper Kites (2019).mkv"?
The video and its 2 subtitle files go to the trash (2.1 GB).
                                   [ Keep ]  [ Move to trash ]

This drive has no trash. Delete "Paper Kites (2019).mkv" for good?
It can't be undone.                [ Keep ]  [ Delete for good ]
```
Keep has the focus in both.

**G. Banners:**
```
⚠ You're offline — downloads and local files still play.                 [ Open Library ]
⚠ Downloads paused: not enough disk space. Free up 3.2 GB or choose another download folder.
                                                                          [ Change folder ]
```

**H. Hidden videos** (Settings → Downloads & library, under LIBRARY FOLDERS):
```
Hidden videos · 3                                                         [ Show ]
  → a list: frame, name, folder, [ Show ]   ("Hidden videos are left out of the Library, Search and Home.")
```

## Verification (every step and at the exit)
The same set every step:
- `flutter analyze`;
- `dart format --set-exit-if-changed lib test integration_test tools`;
- `TZ=UTC flutter test` (unit, widget, golden);
- the fake panel's and the fake TV's own suites;
- the integration tests the step touches, one file per run under `xvfb-run -a`.

What the tests must cover:
- **Every rule in docs/09** gets a unit test: the queue, resume, verification, the filename rules and the parser (hard rule 10).
- **A file under a final name is complete,** shown by the SIGKILL test and by a scripted server that cuts every way it can.
- **Nothing in a folder you added is renamed, moved or changed.** A test compares the tree's names, sizes and modification times before and after every scanner run and every library action except Delete.
- **Every process the app starts is shown to end:** on stop, on failure, on quit and after SIGKILL.
- **No credentials** in the `downloads` table's error column, the logs, or FFmpeg's arguments. The hard-rule-3 test grows to cover them.
- Every screen state gets a widget test; timings and memory are measured, not assumed.

## Risks
- **Windows can't be tried here:** the trash, free space, the Videos folder, the watcher on NTFS, its path limits, and files that can't be renamed or deleted while open. Delete while a file plays has to stop the player first, on every system. Unit tests run in CI; the rest waits for your PC.
- **Panels differ in Range support.** One that ignores Range can't resume: each break starts over, and 30 minutes without progress fails it. The fake panel's `ignore_range` covers this.
- **Your provider allows one connection, and another of your devices uses it.** A real download would be refused, or would cut that device off. The app can't see the other device; a refusal waits 60 s and tries again. Real downloads only with your go-ahead.
- **Big trees and inotify:** a tree with tens of thousands of folders can pass the system's watch limit. The fallback (decision 7) keeps it correct, if less immediate.
- **Network shares:** quick-hashing reads 128 KB per new file, slow over a network, and modification times there can be unreliable. Measured if you add one; not budgeted.
- **Name parsing is a guess.** Edit details fixes a wrong one, and edits survive rescans.
- **The cast's MP4 needs the file's size free** in the cache; without it, seeks keep restarting.
- **Size:** docs/08 says 1.5–2 weeks. The steps are ordered so each stands on tested ground: the data, then the engine, then the scanner, then playback, then the UI, then casting, then the TV.
