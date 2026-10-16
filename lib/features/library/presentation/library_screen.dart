import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_text.dart';
import 'package:iptv_player/features/downloads/presentation/downloads_panel.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_actions.dart';
import 'package:iptv_player/features/library/presentation/library_cards.dart';
import 'package:iptv_player/features/library/presentation/library_folders.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';

/// Library (canvas `Library`, sketches B and C; docs/05, docs/09): the
/// downloads and the user's own folders, by tab — Movies and Series as
/// posters, Videos as frames, Folders as Settings lists them — with the
/// count and the size on this computer, a scan as it runs, and the All ·
/// Downloaded · Local folders chips.
///
/// Each grid is one Tab stop with the arrows inside. Enter opens a movie
/// or a show — at its provider's page while the provider still lists it —
/// and plays a video; F keeps a movie or a video as a favorite. A folder
/// dropped on the window is added.
class LibraryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _grid = FocusPaneController();
  GoRouter? _router;

  /// Whether the Library itself is what the app shows.
  bool _shown = false;

  /// A folder is being dragged over the window.
  bool _dropping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router..routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _grid.dispose();
    super.dispose();
  }

  /// The screen stays built while another destination shows: coming back
  /// to it is when it "opens".
  void _onRoute() {
    final shown = _router?.state.uri.path == AppDestination.library.path;
    if (shown && !_shown) unawaited(_scanUnwatched());
    _shown = shown;
  }

  /// A folder the system can't watch is read again when the Library
  /// opens (Phase 8 decision 7): the scan walks it and reads only what
  /// changed.
  Future<void> _scanUnwatched() async {
    final library = ref.read(libraryRepositoryProvider);
    final List<LibraryFolder> folders;
    try {
      folders = await library.watchFolders().first;
    } on Object {
      // Nothing to scan when the folders can't be read; the screen says
      // what it couldn't load.
      return;
    }
    if (!mounted || folders.isEmpty) return;
    final scans = ref.read(libraryScansProvider);
    for (final folder in folders) {
      if (folder.isAvailable && scans.watched(folder.id) == false) {
        unawaited(library.rescan(folderId: folder.id));
      }
    }
  }

  void _dropped(DropDoneDetails details) {
    setState(() => _dropping = false);
    for (final item in details.files) {
      unawaited(addLibraryFolder(ref, path: item.path));
    }
  }

  ProviderContainer get _container =>
      ProviderScope.containerOf(context, listen: false);

  Future<void> _openMovie(LibraryItem item) async {
    final location = await libraryMovieLocation(_container, item);
    if (mounted) context.go(location);
  }

  Future<void> _openShow(LibraryShow show) async {
    final location = await libraryShowLocation(_container, show);
    if (mounted) context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final view = ref.watch(libraryViewProvider);
    final tab = view.tab;
    // Videos and Folders have no chips: nothing downloaded is unsorted.
    final chips = tab == LibraryTab.movies || tab == LibraryTab.series;
    final origin = chips ? view.origin : LibraryOrigin.all;

    final everything = ref.watch(libraryCountProvider(const LibraryQuery()));
    final movies = ref.watch(
      libraryCountProvider(
        libraryQueryFor(LibraryTab.movies, LibraryOrigin.all),
      ),
    );
    final videos = ref.watch(
      libraryCountProvider(
        libraryQueryFor(LibraryTab.videos, LibraryOrigin.all),
      ),
    );
    final shows = ref.watch(libraryShowsProvider(LibraryOrigin.all));
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final labels = {for (final folder in folders) folder.id: folder.label};
    final scan = ref.watch(libraryScanStateProvider).value?.progress;
    final firstRun = everything.value?.count == 0;
    // What is still on its way: the Downloads tab's count, lit while any
    // is, and what Pause all and Resume all act on.
    final downloading = downloadSections(
      ref.watch(downloadTasksProvider).value ?? const [],
      ref.watch(appClockProvider)(),
    ).inProgress;
    final allPaused =
        downloading.isNotEmpty &&
        downloading.every((task) => task.state == DownloadTaskState.paused);
    // Movies, Series and Videos list the library; the other two tabs have
    // their own lists.
    final listsLibrary =
        tab != LibraryTab.folders && tab != LibraryTab.downloads;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dropping = true),
      onDragExited: (_) => setState(() => _dropping = false),
      onDragDone: _dropped,
      child: FocusPane(
        debugLabel: 'screen-library',
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(
              color: _dropping
                  ? colors.accentBase
                  : colors.accentBase.withValues(alpha: 0),
              width: tokens.focus.ringWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.s32,
              spacing.s12,
              spacing.s32,
              spacing.s20,
            ),
            // Downloads and Folders are rows, which have a measure; the
            // grids fill the window.
            child: PageMeasure(
              maxWidth: listsLibrary ? double.infinity : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.surface3),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final (each, count) in [
                          (LibraryTab.movies, movies.value?.count),
                          (LibraryTab.series, shows.value?.length),
                          (LibraryTab.videos, videos.value?.count),
                          (
                            LibraryTab.downloads,
                            downloading.isEmpty ? null : downloading.length,
                          ),
                          (LibraryTab.folders, null),
                        ]) ...[
                          CountTab(
                            label: libraryTabLabel(each),
                            count: count,
                            highlightCount: each == LibraryTab.downloads,
                            selected: tab == each,
                            onPressed: () => ref
                                .read(libraryViewProvider.notifier)
                                .showTab(each),
                          ),
                          SizedBox(width: spacing.s16),
                        ],
                        const Spacer(),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: CountTab.underlineRoom(context),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (tab != LibraryTab.downloads)
                                AppButton(
                                  label: 'Add folder',
                                  icon: AppIcons.plus,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.s,
                                  onPressed: () =>
                                      unawaited(addLibraryFolder(ref)),
                                )
                              else if (downloading.isNotEmpty)
                                AppButton(
                                  label: allPaused ? 'Resume all' : 'Pause all',
                                  icon: allPaused
                                      ? AppIcons.play
                                      : AppIcons.pause,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.s,
                                  onPressed: () {
                                    final downloads = ref.read(
                                      downloadServiceProvider,
                                    );
                                    unawaited(
                                      allPaused
                                          ? downloads.resumeAll()
                                          : downloads.pauseAll(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.s16),
                  // Downloads go straight to their sections (canvas).
                  if (tab != LibraryTab.downloads) ...[
                    _Header(
                      line: _countLine(tab, origin),
                      scanning: scan == null
                          ? null
                          : libraryScanLine(scan.found),
                      origin: chips && !firstRun ? origin : null,
                      onOrigin: (origin) => ref
                          .read(libraryViewProvider.notifier)
                          .showOrigin(origin),
                    ),
                    SizedBox(height: spacing.s16),
                  ],
                  Expanded(
                    child: firstRun && listsLibrary
                        ? EmptyState(
                            icon: AppIcons.library,
                            title: libraryFirstRunTitle,
                            message: libraryFirstRunMessage,
                            actionLabel: 'Add folder',
                            onAction: () => unawaited(addLibraryFolder(ref)),
                          )
                        : switch (tab) {
                            LibraryTab.movies ||
                            LibraryTab.videos => _items(tab, origin, labels),
                            LibraryTab.series => _shows(origin, labels),
                            LibraryTab.downloads => const DownloadsPanel(),
                            LibraryTab.folders => const SingleChildScrollView(
                              child: LibraryFolderList(),
                            ),
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "42 movies · 186 GB on this computer": what the tab lists under the
  /// chip chosen; null until it is known.
  String? _countLine(LibraryTab tab, LibraryOrigin origin) {
    switch (tab) {
      case LibraryTab.movies || LibraryTab.videos:
        final count = ref
            .watch(libraryCountProvider(libraryQueryFor(tab, origin)))
            .value;
        return count == null ? null : libraryCountLine(tab, count);
      case LibraryTab.series:
        final shows = ref.watch(libraryShowsProvider(origin)).value;
        if (shows == null) return null;
        return libraryCountLine(
          tab,
          LibraryCount(
            count: shows.length,
            bytes: shows.fold(0, (sum, show) => sum + show.bytes),
          ),
        );
      case LibraryTab.downloads:
        return null;
      case LibraryTab.folders:
        final folders = ref.watch(libraryFoldersProvider).value;
        final totals = ref.watch(libraryFolderTotalsProvider).value;
        if (folders == null || totals == null) return null;
        return libraryCountLine(
          tab,
          LibraryCount(
            count: folders.length,
            bytes: totals.values.fold(0, (sum, each) => sum + each.bytes),
          ),
        );
    }
  }

  Widget _empty(LibraryTab tab, LibraryOrigin origin) {
    final text = libraryEmptyText(tab, origin);
    // What is downloaded comes from the provider's pages; anything else
    // from a folder.
    final toProvider = origin == LibraryOrigin.downloaded;
    final destination = tab == LibraryTab.series
        ? AppDestination.series
        : AppDestination.movies;
    return EmptyState(
      compact: true,
      icon: switch (tab) {
        LibraryTab.series => AppIcons.series,
        LibraryTab.videos => AppIcons.folder,
        _ => AppIcons.movies,
      },
      title: text.title,
      message: text.message,
      actionLabel: toProvider ? 'Open ${destination.label}' : 'Add folder',
      onAction: toProvider
          ? () => context.go(destination.path)
          : () => unawaited(addLibraryFolder(ref)),
    );
  }

  Widget _failed(String what, Object error, VoidCallback retry) => ErrorState(
    compact: true,
    title: "Couldn't load your $what",
    message: 'The list could not be read.',
    details: '$error',
    onRetry: retry,
  );

  /// Movies (posters) and Videos (frames): a window of the list at a
  /// time.
  Widget _items(LibraryTab tab, LibraryOrigin origin, Map<int, String> labels) {
    final tokens = context.tokens;
    final query = libraryQueryFor(tab, origin);
    final count = ref.watch(libraryCountProvider(query));
    final videos = tab == LibraryTab.videos;
    final shape = videos
        ? TitleGridShape.landscape(tokens.library.videoCardMinWidth)
        : TitleGridShape.poster;
    if (count.hasError) {
      return _failed(
        videos ? 'videos' : 'movies',
        count.error!,
        () => ref.invalidate(libraryCountProvider(query)),
      );
    }
    final counted = count.value;
    if (counted == null) return TitleGridSkeleton(shape: shape);
    if (counted.count == 0) return _empty(tab, origin);
    final library = ref.read(libraryRepositoryProvider);
    return TitleGrid<LibraryItem>(
      key: ValueKey(tab),
      total: counted.count,
      controller: _grid,
      query: query,
      revision: counted.revision,
      shape: shape,
      identity: (item) => item.id,
      load: (offset, limit) => library.range(query, offset, limit),
      onFavorite: (item) =>
          unawaited(ref.read(libraryFavoritesProvider).toggle(item)),
      card: (context, item, focus, width) => videos
          ? LibraryVideoCard(
              item: item,
              folderLabel: labels[item.folderId],
              focus: focus,
              width: width,
              onPlay: () => unawaited(
                playLibraryItem(
                  _container,
                  item,
                  folderLabel: labels[item.folderId],
                ),
              ),
              onMenu: (anchor) => unawaited(
                showLibraryItemMenu(
                  anchor,
                  item,
                  folderLabel: labels[item.folderId],
                ),
              ),
            )
          : LibraryMovieCard(
              item: item,
              folderLabel: labels[item.folderId],
              focus: focus,
              width: width,
              onOpen: () => unawaited(_openMovie(item)),
              onMenu: (anchor) => unawaited(
                showLibraryItemMenu(
                  anchor,
                  item,
                  folderLabel: labels[item.folderId],
                ),
              ),
            ),
    );
  }

  /// Series: the shows, each its episodes across folders (sketch B).
  Widget _shows(LibraryOrigin origin, Map<int, String> labels) {
    final shows = ref.watch(libraryShowsProvider(origin));
    if (shows.hasError) {
      return _failed(
        'shows',
        shows.error!,
        () => ref.invalidate(libraryShowsProvider(origin)),
      );
    }
    final listed = shows.value;
    if (listed == null) return const TitleGridSkeleton();
    if (listed.isEmpty) return _empty(LibraryTab.series, origin);
    return TitleGrid<LibraryShow>(
      key: const ValueKey(LibraryTab.series),
      total: listed.length,
      controller: _grid,
      query: origin,
      revision: Object.hashAll(listed),
      identity: (show) => show.key,
      load: (offset, limit) async =>
          Ok(listed.skip(offset).take(limit).toList()),
      card: (context, show, focus, width) => LibraryShowCard(
        show: show,
        folderLabel: labels[show.folderId],
        focus: focus,
        width: width,
        onOpen: () => unawaited(_openShow(show)),
      ),
    );
  }
}

/// Under the tabs: the count and the size, a scan as it runs, and the
/// chips at the right.
class _Header extends StatelessWidget {
  const new({
    required this.line,
    required this.scanning,
    required this.origin,
    required this.onOrigin,
  });

  final String? line;
  final String? scanning;

  /// The chip chosen; null where the tab has none.
  final LibraryOrigin? origin;
  final ValueChanged<LibraryOrigin> onOrigin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = tokens.text.caption.copyWith(color: colors.textTertiary);
    return ConstrainedBox(
      // The chips' height, so the grid stays put where a tab has none.
      constraints: BoxConstraints(
        minHeight: tokens.spacing.s32 + tokens.spacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    line ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                if (scanning case final scanning?) ...[
                  SizedBox(width: tokens.spacing.s16),
                  const AppSpinner(size: 12),
                  SizedBox(width: tokens.spacing.s8),
                  Text(
                    scanning,
                    style: style.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s12),
          if (origin case final origin?)
            SegmentedControl<LibraryOrigin>(
              value: origin,
              onChanged: onOrigin,
              options: [
                for (final each in LibraryOrigin.values)
                  SegmentOption(value: each, label: libraryOriginLabel(each)),
              ],
            ),
        ],
      ),
    );
  }
}
