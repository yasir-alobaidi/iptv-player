import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:path/path.dart' as p;

void main() {
  final at = DateTime.utc(2026, 10, 4, 12);

  LibraryItem item({
    String title = 'Paper Kites',
    int? year = 2019,
    bool download = false,
    DateTime? away,
    Duration? duration,
  }) => LibraryItem(
    id: 1,
    folderId: 1,
    relPath: 'a.mkv',
    sizeBytes: 2254857830,
    modifiedAt: at,
    quickHash: 'h',
    kind: LibraryKind.movie,
    title: title,
    year: year,
    addedAt: at,
    duration: duration,
    unavailableSince: away,
    provider: download
        ? const ProviderLink(sourceId: 's', type: VodType.movie, remoteKey: '1')
        : null,
  );

  test('sizes as the canvas writes them', () {
    expect(librarySize(512), '512 bytes');
    expect(librarySize(2254857830), '2.1 GB');
    expect(librarySize(186 * 1024 * 1024 * 1024), '186 GB');
    expect(librarySize(640 * 1024 * 1024), '640 MB');
  });

  test('the count line, the titles and the lines under a card', () {
    expect(
      libraryCountLine(
        LibraryTab.movies,
        const LibraryCount(count: 42, bytes: 186 * 1024 * 1024 * 1024),
      ),
      '42 movies · 186 GB on this computer',
    );
    expect(
      libraryCountLine(
        LibraryTab.videos,
        const LibraryCount(count: 1, bytes: 0),
      ),
      '1 video · 0 bytes on this computer',
    );
    expect(libraryMovieTitle(item()), 'Paper Kites (2019)');
    expect(libraryMovieTitle(item(download: true)), 'Paper Kites');
    expect(libraryItemPlace(item(), 'Movies HDD'), 'Movies HDD');
    expect(libraryItemPlace(item(download: true), null), 'Downloaded · 2.1 GB');
    expect(libraryItemPlace(item(away: at), 'Movies HDD'), driveNotConnected);
    expect(
      libraryVideoLine(
        item(duration: const Duration(minutes: 12)),
        'Home videos',
      ),
      '12 min · Home videos',
    );
  });

  test("a show's line: seasons, or one season's episodes; its place", () {
    LibraryShow show({int seasons = 1, int episodes = 2, bool dl = false}) =>
        LibraryShow(
          key: 'k',
          title: 'Kettle Bay',
          episodes: episodes,
          seasons: seasons,
          bytes: 0,
          downloaded: dl,
        );
    expect(
      libraryShowLine(show(seasons: 3), 'Movies HDD'),
      '3 seasons · Movies HDD',
    );
    expect(libraryShowLine(show(dl: true), null), '2 episodes · Downloaded');
    expect(libraryShowLine(show(episodes: 1), null), '1 episode');
  });

  test("a folder's line, and its path under the home folder", () {
    final hdd = LibraryFolder(
      id: 2,
      path: '/media/data/Movies',
      label: 'Movies HDD',
      isDownloadFolder: false,
      isAvailable: true,
      addedAt: at,
      lastScanAt: at.subtract(const Duration(minutes: 5)),
    );
    expect(
      folderLine(hdd, (items: 1204, bytes: 0), at),
      'Movies HDD · 1,204 videos · scanned 5 min ago',
    );
    expect(
      folderLine(hdd.copyWith(isAvailable: false), (items: 64, bytes: 0), at),
      'Movies HDD · not connected · its 64 videos stay listed for 30 days',
    );
    expect(
      folderLine(hdd.copyWith(isDownloadFolder: true, label: 'Downloads'), (
        items: 38,
        bytes: 45419279155,
      ), at),
      'Downloads · 38 videos · 42.3 GB',
    );
    final home = p.join(p.separator, 'home', 'me');
    expect(
      displayFolderPath(p.join(home, 'Videos', 'IPTV Player'), home),
      p.join('~', 'Videos', 'IPTV Player'),
    );
    expect(displayFolderPath('/media/usb', home), '/media/usb');
  });

  test('an episode with no title of its own is "Episode 4"', () {
    final episode = item(
      title: 'Kettle Bay',
    ).copyWith(kind: LibraryKind.episode, showTitle: 'Kettle Bay', episode: 4);
    expect(libraryEpisodeTitle(episode), 'Episode 4');
    expect(
      libraryEpisodeTitle(episode.copyWith(title: 'The Long Tide')),
      'The Long Tide',
    );
  });

  test('language names, and a code not listed as itself', () {
    expect(languageName('en'), 'English');
    expect(languageName('eng'), 'English');
    expect(languageName('pt-BR'), 'Portuguese');
    expect(languageName('xx'), 'XX');
  });
}
