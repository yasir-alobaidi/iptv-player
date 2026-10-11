import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_names.dart';

void main() {
  LibraryItem item({
    LibraryKind kind = LibraryKind.movie,
    String title = 'Paper Kites',
    int? year,
    String? show,
    int? season,
    int? episode,
    String? poster,
    String? frame,
  }) => LibraryItem(
    id: 1,
    folderId: 1,
    relPath: 'a.mkv',
    sizeBytes: 1,
    modifiedAt: DateTime.utc(2026),
    quickHash: 'h',
    kind: kind,
    title: title,
    year: year,
    showTitle: show,
    season: season,
    episode: episode,
    addedAt: DateTime.utc(2026),
    artworkPath: poster,
    thumbnailPath: frame,
  );

  LibraryItem episode(String title, {int? number = 4}) => item(
    kind: LibraryKind.episode,
    title: title,
    show: 'Glass Tide',
    season: 2,
    episode: number,
  );

  test('two lines: an episode under its show, a movie over its year', () {
    expect(libraryItemNames(item(year: 2019)), (
      title: 'Paper Kites',
      over: '2019',
    ));
    expect(libraryItemNames(item()), (title: 'Paper Kites', over: null));
    expect(libraryItemNames(episode('Undertow')), (
      title: 'Undertow',
      over: 'Glass Tide · S2 E4',
    ));
    // A name that gave no title, or only the show's again.
    for (final none in ['', '  ', 'glass tide']) {
      expect(libraryItemNames(episode(none)).title, 'Episode 4', reason: none);
    }
    expect(libraryItemNames(episode('', number: null)), (
      title: 'Episode',
      over: 'Glass Tide · S2 E1',
    ));
    // A video says its name and nothing else, whatever its year.
    expect(
      libraryItemNames(
        item(kind: LibraryKind.unsorted, title: 'Beach', year: 2021),
      ),
      (title: 'Beach', over: null),
    );
    // An episode with no show is named as it is.
    expect(libraryItemNames(item(kind: LibraryKind.episode, title: 'Pilot')), (
      title: 'Pilot',
      over: null,
    ));
  });

  test('one line: the show and number, or the title', () {
    expect(libraryItemLine(episode('Undertow')), 'Glass Tide · S2 E4');
    expect(libraryItemLine(item(year: 2019)), 'Paper Kites');
  });

  test('its picture: the poster beside it, else the frame grabbed', () {
    expect(
      libraryItemPicture(item(poster: '/p.jpg', frame: '/f.jpg')),
      '/p.jpg',
    );
    expect(libraryItemPicture(item(frame: '/f.jpg')), '/f.jpg');
    expect(libraryItemPicture(item()), isNull);
  });
}
