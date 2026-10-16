import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_actions.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/domain/next_up.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/title_details_screen.dart';

/// A show of the library (sketch B; the Series details layout): the
/// user's own episodes of one show, across folders, or the downloaded
/// episodes of a series its provider no longer lists. Seasons as tabs, the
/// episodes with their frames, and Continue by the rule Continue watching
/// uses.
///
/// No favorite here: a file is a favorite by itself, and a show of files
/// is not something the library keeps (ADR-015).
class LibraryShowScreen extends ConsumerWidget {
  const new({required this.showKey, super.key});

  final String showKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(libraryShowEpisodesProvider(showKey));
    final shows = ref.watch(libraryShowsProvider(LibraryOrigin.all)).value;
    final show = shows?.where((s) => s.key == showKey).firstOrNull;
    return DetailsFrame(
      back: 'Library',
      loading: episodes is! AsyncData && episodes is! AsyncError,
      child: switch (episodes) {
        AsyncError(:final error) => ErrorState(
          title: "Couldn't open this show",
          details: '$error',
          onRetry: () => ref.invalidate(libraryShowEpisodesProvider(showKey)),
        ),
        AsyncData(:final value) when value.isEmpty => const DetailsGone(
          message: 'This show is no longer in your library.',
        ),
        AsyncData(:final value) => _ShowPage(
          showKey: showKey,
          show: show,
          episodes: value,
        ),
        _ => const DetailsPageLoading(),
      },
    );
  }
}

class _ShowPage extends ConsumerStatefulWidget {
  const new({
    required this.showKey,
    required this.show,
    required this.episodes,
  });

  final String showKey;

  /// The Series tab's row for it; null for a moment after its last
  /// change.
  final LibraryShow? show;

  /// By season and episode.
  final List<LibraryItem> episodes;

  @override
  ConsumerState<_ShowPage> createState() => _ShowPageState();
}

class _ShowPageState extends ConsumerState<_ShowPage> {
  final _list = FocusPaneController();
  final _tabs = FocusPaneController();

  /// Continue: where ← from the seasons and the episodes goes.
  final _primary = FocusNode(debugLabel: 'show primary');
  final _rows = <int, FocusNode>{};
  final _rowKeys = <int, GlobalKey>{};

  /// The season shown: the one to continue in, once the marks are read,
  /// then whichever the user picks. It stays when a mark changes — marking
  /// an episode as watched must not swap the list under the keyboard.
  int? _season;
  bool _placed = false;

  @override
  void dispose() {
    _list.dispose();
    _tabs.dispose();
    _primary.dispose();
    for (final node in _rows.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _rowNode(int id) =>
      _rows.putIfAbsent(id, () => FocusNode(debugLabel: 'episode $id'));

  GlobalKey _rowKey(int id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  /// A file with no season in its name sits in season 1.
  static int _seasonOf(LibraryItem episode) => episode.season ?? 1;

  void _play(LibraryItem episode, {Duration? from}) {
    if (!episode.available) {
      final folders = ref.read(libraryFoldersProvider).value ?? const [];
      final folder = folders.where((f) => f.id == episode.folderId).firstOrNull;
      ref
          .read(appNoticesProvider)
          .show(AppNotice(driveAwayNotice(folder?.label)));
      return;
    }
    unawaited(
      ref.read(vodLauncherProvider).playLibraryItem(episode, from: from),
    );
  }

  /// The list lands on the episode to continue: shown, and the list's
  /// first Tab stop.
  void _placeOn(LibraryItem episode) {
    if (_placed) return;
    _placed = true;
    _season ??= _seasonOf(episode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _list.remember(_rowNode(episode.id));
      final row = _rowKey(episode.id).currentContext;
      if (row != null) Scrollable.ensureVisible(row, alignment: 0.3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.details;
    final episodes = widget.episodes;
    final read = ref.watch(libraryShowMarksProvider(widget.showKey));
    final marks = read ?? const <int, WatchMark>{};
    // Until the marks are read there is no telling where to continue.
    final nextUp = read == null
        ? null
        : nextUpAmong(episodes, (episode) => marks[episode.id]);
    if (nextUp != null) _placeOn(nextUp.episode);

    final seasons = {for (final e in episodes) _seasonOf(e)}.toList()..sort();
    final shown = seasons.contains(_season) ? _season! : seasons.first;
    final listed = [
      for (final episode in episodes)
        if (_seasonOf(episode) == shown) episode,
    ];

    final first = episodes.first;
    final stored = first.details ?? const <String, Object?>{};
    String? text(String key) => switch (stored[key]) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    final show = widget.show;
    final title = show?.title ?? first.showTitle ?? first.title;
    final posterUrl = switch (show?.artworkPath) {
      final path? => localArtworkUrl(path),
      null => text('series_poster_url'),
    };
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final folder = folders.where((f) => f.id == show?.folderId).firstOrNull;
    final plot = text('series_plot');

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.bg),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width:
              layout.seriesColumnFor(MediaQuery.sizeOf(context).width) +
              tokens.spacing.s64,
          child: DetailsBackdrop(
            backdropUrl: text('series_backdrop_url'),
            posterUrl: posterUrl,
            fadeRight: true,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: layout.seriesColumnFor(MediaQuery.sizeOf(context).width),
              child: Padding(
                padding: layout.seriesPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    DetailsPoster(
                      title: title,
                      url: posterUrl,
                      size: layout.seriesPoster,
                    ),
                    SizedBox(height: tokens.spacing.s16 + 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.seriesTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (show != null) ...[
                      SizedBox(height: tokens.spacing.s16 + 2),
                      Text(
                        libraryShowLine(show, folder?.label),
                        style: tokens.text.body
                            .withWeight(600)
                            .copyWith(
                              color: show.available
                                  ? colors.textSecondary
                                  : colors.warning,
                            ),
                      ),
                    ],
                    if (plot != null) ...[
                      SizedBox(height: tokens.spacing.s16 + 2),
                      Text(
                        plot,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spacing.s16 + 2),
                    if (nextUp != null)
                      Row(
                        children: [
                          Flexible(
                            child: AppButton(
                              label: switch (nextUp.kind) {
                                NextUpKind.again => 'Play again',
                                NextUpKind.start => libraryContinueLabel(
                                  'Play',
                                  nextUp.episode,
                                ),
                                _ => libraryContinueLabel(
                                  'Continue',
                                  nextUp.episode,
                                ),
                              },
                              icon: AppIcons.play,
                              size: AppButtonSize.xl,
                              autofocus: true,
                              focusNode: _primary,
                              onPressed: () =>
                                  _play(nextUp.episode, from: nextUp.from),
                            ),
                          ),
                          SizedBox(width: tokens.spacing.s12),
                          // As the provider's Series page has it: the
                          // episode Play would start, on the TV.
                          AppIconButton(
                            icon: AppIcons.cast,
                            tooltip: 'Cast',
                            bordered: true,
                            size: layout.movieActionHeight,
                            onPressed: () => unawaited(
                              castLibraryItem(
                                context,
                                nextUp.episode,
                                folderLabel: folder?.label,
                                from: nextUp.from,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.s8,
                  tokens.spacing.s32,
                  tokens.spacing.s40,
                  tokens.spacing.s32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DetailsSeasonTabs(
                      seasons: seasons,
                      shown: shown,
                      episodes: listed.length,
                      controller: _tabs,
                      onPick: (season) => setState(() => _season = season),
                      onLeaveLeft: _primary.requestFocus,
                    ),
                    SizedBox(height: tokens.spacing.s16),
                    Expanded(
                      child: DetailsEpisodeList(
                        controller: _list,
                        onLeaveLeft: _primary.requestFocus,
                        itemCount: listed.length,
                        itemBuilder: (context, index) {
                          final episode = listed[index];
                          return _EpisodeRow(
                            key: _rowKey(episode.id),
                            episode: episode,
                            mark: marks[episode.id],
                            focus: _rowNode(episode.id),
                            onPlay: _play,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One episode (sketch B, drawn as the provider's page draws one): its
/// frame with the progress line, "S2 · E3" and the title — "Episode 4"
/// when the name gave none — and under them its length, "Watched" or the
/// time left. Enter plays it from where it was left; its menu starts over
/// or marks it.
class _EpisodeRow extends ConsumerWidget {
  const new({
    required this.episode,
    required this.mark,
    required this.focus,
    required this.onPlay,
    super.key,
  });

  final LibraryItem episode;
  final WatchMark? mark;
  final FocusNode focus;
  final void Function(LibraryItem episode, {Duration? from}) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final still = tokens.details.episodeStill;
    final mark = this.mark;
    final watched = mark?.completed ?? false;
    final resumable = mark != null && mark.resumable;
    final remaining = resumable ? mark.remaining : null;
    final away = !episode.available;
    final length = episode.duration ?? episode.media?.duration;
    final line = away
        ? driveNotConnected
        : [
            if (remaining == null && length != null) formatRuntime(length),
            if (watched) 'Watched',
            if (remaining != null) formatTimeLeft(remaining),
          ].join(' · ');
    final frame = away
        ? null
        : ref.watch(libraryThumbnailProvider(episode.id)).value;
    final picture = frame ?? episode.artworkPath;
    final number = libraryEpisodeNumber(episode);
    final title = libraryEpisodeTitle(episode);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
      child: FocusableSurface(
        ringPlacement: RingPlacement.inside,
        focusNode: focus,
        borderRadius: tokens.radii.mdAll,
        semanticLabel: number.isEmpty ? title : '$number, $title',
        onPressed: () =>
            onPlay(episode, from: resumable ? mark.position : null),
        // The item menu (sketch D).
        onMenu: () => unawaited(showLibraryItemMenu(context, episode)),
        builder: (context, states) => Opacity(
          opacity: away ? tokens.library.unavailableOpacity : 1,
          child: Container(
            padding: EdgeInsets.all(tokens.spacing.s8 + 2),
            decoration: BoxDecoration(
              color: states.highlighted
                  ? colors.surface3
                  : colors.surface3.withValues(alpha: 0),
              borderRadius: tokens.radii.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: tokens.radii.smAll,
                  child: SizedBox(
                    width: still.width,
                    height: still.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PosterArtwork(
                          title: '',
                          image: picture == null
                              ? null
                              : artworkFor(
                                  context,
                                  localArtworkUrl(picture),
                                  width: still.width,
                                ),
                        ),
                        if (mark != null && mark.position > Duration.zero)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ProgressBar(
                              value: watched ? 1 : mark.fraction,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.s16 + 2),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (number.isNotEmpty) ...[
                              Text(
                                number,
                                style: tokens.text.labelSmall
                                    .withWeight(700)
                                    .copyWith(
                                      color: states.focused
                                          ? colors.accentBase
                                          : colors.textTertiary,
                                    ),
                              ),
                              SizedBox(width: tokens.spacing.s8 + 2),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens.text.bodyStrong.copyWith(
                                  color: watched && !states.focused
                                      ? colors.textSecondary
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            if (watched)
                              AppIcon(
                                AppIcons.check,
                                size: 18,
                                color: colors.success,
                              ),
                          ],
                        ),
                        if (line.isNotEmpty) ...[
                          SizedBox(height: tokens.spacing.s4),
                          Text(
                            line,
                            style: tokens.text.labelSmall.copyWith(
                              color: away
                                  ? colors.warning
                                  : colors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
