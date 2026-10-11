import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_media.dart';
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

  test('an empty list has no count line; a scan says what it found', () {
    expect(
      libraryCountLine(
        LibraryTab.movies,
        const LibraryCount(count: 0, bytes: 0),
      ),
      '',
    );
    expect(libraryScanLine(0), 'Scanning');
    expect(libraryScanLine(1204), 'Scanning · 1,204 found');
  });

  test('every tab and chip has its own words when empty', () {
    final texts = {
      for (final tab in [
        LibraryTab.movies,
        LibraryTab.series,
        LibraryTab.videos,
      ])
        for (final origin in LibraryOrigin.values)
          if (tab != LibraryTab.videos || origin == LibraryOrigin.all)
            libraryEmptyText(tab, origin).title,
    };
    expect(texts, hasLength(7));
    expect(
      libraryEmptyText(LibraryTab.series, LibraryOrigin.downloaded).message,
      'Press D on an episode to download it.',
    );
  });

  test("a video's page: where it is, its subtitles, its number", () {
    final file = item().copyWith(
      relPath: 'Paper Kites (2019)/Paper Kites (2019).mkv',
    );
    expect(
      libraryFileLine(file, 'Movies HDD'),
      'Movies HDD · Paper Kites (2019)/Paper Kites (2019).mkv · 2.1 GB',
    );
    expect(
      libraryFileLine(item(download: true), 'Downloads'),
      'Downloaded · a.mkv · 2.1 GB',
    );
    expect(
      libraryFileLine(item(away: at), 'Movies HDD'),
      startsWith('Drive not connected · Movies HDD'),
    );

    expect(librarySubtitleNames(item()), isEmpty);
    expect(
      librarySubtitleNames(
        item().copyWith(
          subtitles: const [
            ExternalSubtitle(
              fileName: 'a.en.srt',
              format: 'srt',
              language: 'en',
            ),
            ExternalSubtitle(fileName: 'a.srt', format: 'srt'),
          ],
          media: const LibraryMedia(
            subtitles: [
              LibrarySubtitle(language: 'eng'),
              LibrarySubtitle(language: 'eng', forced: true),
              LibrarySubtitle(language: 'und', title: 'Signs'),
            ],
          ),
        ),
      ),
      ['English', 'Unknown', 'English (forced)', 'Signs'],
      reason: 'each once: the file and the track in English are one',
    );

    final episode = item().copyWith(
      kind: LibraryKind.episode,
      season: 2,
      episode: 4,
    );
    expect(libraryEpisodeNumber(episode), 'S2 · E4');
    expect(libraryEpisodeNumber(episode.copyWith(episodeEnd: 5)), 'S2 · E4–5');
    expect(libraryEpisodeNumber(episode.copyWith(season: null)), 'E4');
    expect(libraryEpisodeNumber(item()), '');
    expect(libraryContinueLabel('Continue', episode), 'Continue S2 · E4');
    expect(libraryContinueLabel('Play', item()), 'Play');
    expect(
      driveAwayNotice('Movies HDD'),
      "Movies HDD isn't connected. Connect its drive to play this.",
    );
  });

  test('language names, and a code not listed as itself', () {
    expect(languageName('en'), 'English');
    expect(languageName('eng'), 'English');
    expect(languageName('pt-BR'), 'Portuguese');
    expect(languageName('xx'), 'XX');
  });
}
