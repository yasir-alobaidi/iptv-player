import 'package:iptv_player/core/library/library_item.dart';

/// What a library item is called where two lines name it (the TV's
/// screen while it loads, the casting view): an episode by its own title
/// under its show and number — "Episode 4" when its name gave none — a
/// movie over its year, a video by its name.
({String title, String? over}) libraryItemNames(LibraryItem item) {
  final show = item.showTitle?.trim() ?? '';
  if (item.kind == LibraryKind.episode && show.isNotEmpty) {
    final title = item.title.trim();
    final own = title.isNotEmpty && title.toLowerCase() != show.toLowerCase();
    return (
      title: own
          ? title
          : item.episode == null
          ? 'Episode'
          : 'Episode ${item.episode}',
      over: '$show · S${item.season ?? 1} E${item.episode ?? 1}',
    );
  }
  return (
    title: item.title,
    over: item.kind == LibraryKind.movie ? item.year?.toString() : null,
  );
}

/// One line for it (the casting bar, a toast): "Glass Tide · S2 E4", a
/// movie's or a video's title.
String libraryItemLine(LibraryItem item) {
  final show = item.showTitle?.trim() ?? '';
  return item.kind == LibraryKind.episode && show.isNotEmpty
      ? '$show · S${item.season ?? 1} E${item.episode ?? 1}'
      : item.title;
}

/// Its picture on this computer: the poster beside it, else the frame
/// the app grabbed from it; null when it has neither yet.
String? libraryItemPicture(LibraryItem item) =>
    item.artworkPath ?? item.thumbnailPath;
