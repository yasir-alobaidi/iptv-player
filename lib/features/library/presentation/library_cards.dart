import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:iptv_player/features/vod/presentation/title_cards.dart';

/// A picture on disk for [artworkFor], or null.
ImageProvider? _onDisk(BuildContext context, String? path, double width) =>
    path == null
    ? null
    : artworkFor(context, localArtworkUrl(path), width: width);

double? _progress(WatchMark? mark) =>
    mark != null && mark.resumable ? mark.fraction : null;

/// A movie of the library as the canvas draws it: its poster — or, with
/// none, its own frame across the middle — the Downloaded mark or its
/// folder under the title, faded with "Drive not connected" when its
/// drive is away, and the bar of a movie in progress.
class LibraryMovieCard extends ConsumerWidget {
  const new({
    required this.item,
    required this.folderLabel,
    required this.focus,
    required this.width,
    required this.onOpen,
    this.onMenu,
    super.key,
  });

  final LibraryItem item;
  final String? folderLabel;
  final FocusNode focus;
  final double width;
  final VoidCallback onOpen;
  final void Function(BuildContext anchor)? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mark = ref.watch(libraryMarkProvider(item)).value;
    final favorite = ref.watch(libraryFavoriteProvider(item)).value ?? false;
    final poster = item.artworkPath;
    final frame = poster == null && item.available
        ? ref.watch(libraryThumbnailProvider(item.id)).value
        : null;
    return PosterCard(
      title: libraryMovieTitle(item),
      image: _onDisk(context, poster, width),
      frame: _onDisk(context, frame, width),
      meta: libraryItemPlace(item, folderLabel),
      metaIcon: !item.available
          ? AppIcons.alertTriangle
          : item.isDownload
          ? AppIcons.download
          : AppIcons.folder,
      metaTone: !item.available
          ? CardMetaTone.warning
          : item.isDownload
          ? CardMetaTone.success
          : CardMetaTone.plain,
      dimmed: !item.available,
      progress: _progress(mark),
      cornerBadge: favorite ? const FavoriteMark() : null,
      width: width,
      focusNode: focus,
      onPressed: onOpen,
      onMenu: onMenu == null ? null : () => onMenu!(context),
    );
  }
}

/// A show of the Series tab (sketch B): "3 seasons · Movies HDD", "2
/// episodes · Downloaded".
class LibraryShowCard extends StatelessWidget {
  const new({
    required this.show,
    required this.folderLabel,
    required this.focus,
    required this.width,
    required this.onOpen,
    this.onMenu,
    super.key,
  });

  final LibraryShow show;
  final String? folderLabel;
  final FocusNode focus;
  final double width;
  final VoidCallback onOpen;
  final void Function(BuildContext anchor)? onMenu;

  @override
  Widget build(BuildContext context) => PosterCard(
    title: show.title,
    image: _onDisk(context, show.artworkPath, width),
    meta: libraryShowLine(show, folderLabel),
    metaIcon: !show.available
        ? AppIcons.alertTriangle
        : show.downloaded
        ? AppIcons.download
        : folderLabel == null
        ? null
        : AppIcons.folder,
    metaTone: !show.available
        ? CardMetaTone.warning
        : show.downloaded
        ? CardMetaTone.success
        : CardMetaTone.plain,
    dimmed: !show.available,
    width: width,
    focusNode: focus,
    onPressed: onOpen,
    onMenu: onMenu == null ? null : () => onMenu!(context),
  );
}

/// A video of the user's own (sketch C): its frame, "12 min · Home
/// videos", the bar of one in progress. Enter plays it.
class LibraryVideoCard extends ConsumerWidget {
  const new({
    required this.item,
    required this.folderLabel,
    required this.focus,
    required this.width,
    required this.onPlay,
    this.onMenu,
    super.key,
  });

  final LibraryItem item;
  final String? folderLabel;
  final FocusNode focus;
  final double width;
  final VoidCallback onPlay;
  final void Function(BuildContext anchor)? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mark = ref.watch(libraryMarkProvider(item)).value;
    final frame = item.available
        ? ref.watch(libraryThumbnailProvider(item.id)).value
        : null;
    return LandscapeCard(
      title: item.title,
      image: _onDisk(context, frame ?? item.artworkPath, width),
      subtitle: libraryVideoLine(item, folderLabel),
      subtitleTone: item.available ? CardMetaTone.plain : CardMetaTone.warning,
      dimmed: !item.available,
      progress: _progress(mark),
      width: width,
      focusNode: focus,
      onPressed: onPlay,
      onMenu: onMenu == null ? null : () => onMenu!(context),
    );
  }
}
