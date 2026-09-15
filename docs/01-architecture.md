# 01 — Architecture

## Why Flutter (ADR-001)
- One codebase for Linux, Windows, and later Google TV (Android TV): shared data layer, state, and design system.
- GPU-rendered UI makes a polished, animated interface practical.
- Video still runs in native engines (libmpv on desktop; libmpv or Media3 on TV), so Dart never touches frames.

Rejected: Python/PySide6 (no Google TV path), Electron/web (Chromium can't decode AC-3/E-AC-3 and Electron has no Cast support), Kotlin Multiplatform (weak desktop video embedding), separate native apps (double the work).

## Layers
```
presentation  widgets, screens, Riverpod notifiers
     │ depends on
domain        entities, repository interfaces, PlayerEngine / CastService interfaces
     │ implemented by
data          Xtream/M3U/XMLTV clients, drift DB, sync isolate, media_kit engine, Cast client, relay, downloads, library scanner
```
Presentation never imports media_kit, drift, dio, dart:io sockets, or Process.

## Folder layout
```
iptv-player/
├── CLAUDE.md
├── docs/
├── lib/
│   ├── main.dart                   # chooses shell by form factor (desktop now, TV in v2)
│   ├── app/                        # App widget, router, desktop_shell.dart (tv_shell.dart in v2)
│   ├── core/
│   │   ├── result.dart             # sealed Result<T>, AppFailure
│   │   ├── logging/                # logger, rotating file sink, redact()
│   │   ├── platform/               # form factor, sleep inhibitor, firewall helpers, paths
│   │   ├── player/                 # PlayerEngine, PlayerSnapshot, TrackInfo, BufferPreset, PlayableSource
│   │   ├── cast/                   # CastService, CastDevice, CastSessionState, CastOptions
│   │   ├── downloads/              # DownloadService, DownloadTask, DownloadRequest
│   │   ├── library/                # LibraryRepository, LibraryItem, LibraryFolder
│   │   ├── isolates/               # background worker helpers
│   │   └── utils/
│   ├── data/
│   │   ├── db/                     # drift database, tables, DAOs, migrations, FTS
│   │   ├── providers/xtream/       # API client, tolerant DTOs, URL builder
│   │   ├── providers/m3u/          # streaming parser
│   │   ├── epg/                    # XMLTV streaming parser, short EPG, matcher
│   │   ├── sync/                   # sync engine (isolate), mark-and-sweep
│   │   ├── secure/                 # credential store
│   │   ├── player_mediakit/        # PlayerEngine implementation (desktop)
│   │   ├── cast/                   # castv2 client, discovery, probe, planner, relay, supervisor
│   │   ├── downloads/              # queue, HTTP + HLS downloaders, finalizer
│   │   └── library/                # scanner isolate, name parser, thumbnails, folder watcher
│   ├── design/                     # tokens, theme, typography, motion, focus system, components
│   └── features/
│       ├── onboarding/  home/  live_tv/  player/  guide/
│       ├── movies/  series/  search/  favorites/  casting/  library/  settings/
├── test/                           # mirrors lib/
├── test_fixtures/                  # JSON / M3U / XMLTV fixtures, including malformed ones
├── integration_test/
├── tools/
│   ├── fake_provider/              # Dart shelf server: Xtream + M3U + XMLTV + looping streams + VOD files + fault injection
│   ├── media_samples/              # generate.sh: synthetic test streams via ffmpeg; library_tree.sh: fake library folders (no copyrighted content)
│   ├── soak/                       # long-run playback + fault script
│   ├── fetch_ffmpeg.sh             # downloads bundled ffmpeg/ffprobe builds
│   └── vendor_media_kit_video.sh   # rebuilds third_party/media_kit_video from pub.dev + our patch (ADR-003)
├── third_party/
│   ├── ffmpeg/                     # per-platform binaries (gitignored)
│   ├── media_kit_video/            # patched media_kit_video 2.0.1, used through dependency_overrides (committed)
│   └── patches/                    # patches applied by tools/vendor_media_kit_video.sh
├── linux/  windows/  android/      # android/ used in v2
└── pubspec.yaml
```

## Packages (chosen in Phase 0; versions in ADR-002)
| Need | Primary | Fallback |
|---|---|---|
| State | flutter_riverpod + riverpod_generator | — |
| Routing | go_router | — |
| Database | drift + sqlite3 3.x (FTS5; sqlite3_flutter_libs is end-of-life) | — |
| HTTP | dio | package:http |
| Models | freezed + json_serializable | — |
| Desktop video | media_kit + media_kit_video (our patched copy, ADR-003) + media_kit_libs_video | fvp |
| mDNS discovery | bonsoir | multicast_dns + manual IP |
| Local HTTP server | shelf + shelf_router | dart:io HttpServer |
| Cast protobuf | protobuf (generated code committed) | minimal hand-written encoder |
| Window control | window_manager | — |
| Secrets | flutter_secure_storage (libsecret on Linux, Credential Manager on Windows) | encrypted file |
| Images | extended_image or cached_network_image | — |
| XML | xml (event/streaming API) | custom streaming tokenizer |
| File and folder pickers | file_selector | file_picker |
| Drag and drop | desktop_drop | pickers only |
| Folder watching | watcher | rescan on launch and on demand |
| Standard folders | path_provider (+ xdg_directories on Linux) | environment variables |
| Free disk space | FFI: statvfs (Linux), GetDiskFreeSpaceExW (Windows) | `df` on Linux |
| Move to trash | `gio trash` (Linux), IFileOperation via win32 (Windows) | permanent delete after a second confirmation |
| Logging | logger + rotating file sink | — |
| Lints | very_good_analysis | strict flutter_lints |
| Tests | flutter_test, mocktail, integration_test, golden files | — |

## Key domain interfaces
```dart
abstract interface class PlayerEngine {
  Stream<PlayerSnapshot> get snapshots; // state, position, buffer, tracks, video params, hwdec, errors
  Future<void> open(PlayableSource source, {Duration? startAt});
  Future<void> stop();
  Future<void> setPaused(bool paused);
  Future<void> seek(Duration position);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String? id);
  Future<void> setAspectMode(AspectMode mode);
  Future<void> setVolume(double volume); // 0..1
  Future<void> applyPreset(BufferPreset preset);
  Future<void> dispose();
}

abstract interface class CastService {
  Stream<List<CastDevice>> get devices;
  Stream<CastSessionState> get session;
  Future<void> addManualDevice(String host);
  Future<Result<void>> cast(CastDevice device, PlayableSource source, CastOptions options);
  Future<void> setPaused(bool paused);
  Future<void> setVolume(double volume);
  Future<void> stop();
}

abstract interface class DownloadService {
  Stream<List<DownloadTask>> get tasks; // state, bytes, speed, time left, error
  Future<Result<void>> enqueue(DownloadRequest request); // movie, episode, or season
  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId); // deletes the .part file
  Future<void> pauseAll();
  Future<void> resumeAll();
}

abstract interface class LibraryRepository {
  Stream<List<LibraryItem>> watch(LibraryQuery query);
  Future<Result<void>> addFolder(String path);
  Future<void> removeFolder(String folderId); // files stay on disk
  Future<void> rescan({String? folderId});
  Future<Result<void>> editItem(String itemId, LibraryItemEdit edit);
  Future<Result<void>> deleteFile(String itemId); // system trash when possible
}
```
`PlayableSource`: URL builder reference (not a raw URL, so reconnects rebuild it) or a library item reference for local files, headers (User-Agent), kind (live/movie/episode/file), title, subtitle, artwork, source id, remote key, connection policy.

## Runtime flow: live channel (desktop)
1. User selects a channel → `LiveTvController` requests a `PlayableSource`.
2. `PlaybackCoordinator` enforces the connection policy (stops cast relay or current stream when required).
3. `PlayerEngine.open()` → media_kit/libmpv with the active buffer preset.
4. `PlaybackWatchdog` watches snapshots; on stall or error it reconnects with backoff and publishes status for the UI.
5. History and last-channel are recorded.

## Runtime flow: casting
See docs/04-casting.md. `CastCoordinator` owns the device session, relay lifecycle, local-player suspension, and sleep inhibition.

## Runtime flow: download
1. User presses Download (or D) on a movie or episode → `DownloadService.enqueue()` stores the task (item reference only, never the URL).
2. `DownloadQueue` asks the `PlaybackCoordinator` for a connection on that source; if none is free, the task waits.
3. `HttpDownloader` rebuilds the URL and streams into a `.part` file with resume; if playback needs the connection, the download pauses.
4. `DownloadFinalizer` verifies the file, renames it, and adds the library item, linked to the provider item so watch progress is shared.
5. Library screens, details pages, and search pick up the new item from the DB.

## Form factors
`FormFactor.desktop` now, `FormFactor.tv` in v2. Shells differ (navigation, layouts, input); repositories, providers, and most components are shared. Keep each feature's presentation split into reusable widgets and desktop layouts so TV layouts can be added without touching logic.
