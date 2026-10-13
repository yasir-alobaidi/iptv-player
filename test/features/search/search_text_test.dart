import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_text.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

void main() {
  group('highlightRanges', () {
    test('each word where it starts a word of the name', () {
      expect(highlightRanges('Harbor City Local', ['harbor']), [(0, 6)]);
      expect(highlightRanges('The Quiet Harbor', ['harbor']), [(10, 16)]);
      expect(highlightRanges('Harborview Weather', ['harbor']), [(0, 6)]);
      expect(highlightRanges('Arena Sports 1', ['sp', 'ar']), [(0, 2), (6, 8)]);
    });

    test('not inside a word', () {
      expect(highlightRanges('Shipyard', ['yard']), isEmpty);
      expect(highlightRanges('Sky-Sports', ['sports']), [(4, 10)]);
    });

    test('case and accents fold, as the index folds them', () {
      expect(highlightRanges('Télé-Québec', ['quebec']), [(5, 11)]);
      expect(highlightRanges('ÉCOLE', ['ecole']), [(0, 5)]);
      expect(highlightRanges('Straße', ['strasse']), [(0, 6)]);
    });

    test('overlapping words merge; nothing found, nothing bold', () {
      expect(highlightRanges('Arena', ['ar', 'arena']), [(0, 5)]);
      expect(highlightRanges('Arena', ['zzz']), isEmpty);
      expect(highlightRanges('', ['a']), isEmpty);
      expect(highlightRanges('Arena', []), isEmpty);
    });

    test('never cuts a surrogate pair', () {
      final ranges = highlightRanges('📺 News', ['news']);
      expect(ranges, [(3, 7)]);
    });
  });

  group('lines', () {
    final now = DateTime(2026, 9, 14, 20);
    const channel = ChannelItem(
      id: 1,
      sourceId: 's',
      remoteKey: '118',
      name: 'Harbor City Local',
      number: 118,
    );
    const hit = ChannelHit(
      channel: channel,
      sourceName: 'Northwind TV',
      categoryName: 'UK | News',
    );

    test('a channel: its number and what is on, then the category when two '
        'share its name, then the source when there are several', () {
      final guide = NowNext(
        now: Programme(
          title: 'Evening Bulletin',
          start: now,
          end: DateTime(2026, 9, 14, 20, 30),
        ),
      );
      expect(
        channelHitLine(
          hit,
          guide: guide,
          sameName: false,
          sources: 1,
          style: TimeStyle.h12,
        ),
        '118 · Evening Bulletin, until 8:30 PM',
      );
      expect(
        channelHitLine(
          hit,
          guide: null,
          sameName: true,
          sources: 2,
          style: TimeStyle.h24,
        ),
        '118 · UK | News · Northwind TV',
      );
    });

    test('a programme: ends at, while on; the day and time, before', () {
      ProgrammeHit at(DateTime start, DateTime end) => ProgrammeHit(
        programme: EpgProgramme(
          id: 1,
          channelId: 'c',
          start: start,
          end: end,
          title: 'Harbor Kings vs Ridge City',
        ),
        channel: channel.copyWithName('Courtside'),
        sourceName: 'Northwind TV',
      );
      expect(
        programmeHitLine(
          at(
            now.subtract(const Duration(hours: 1)),
            DateTime(2026, 9, 14, 22, 55),
          ),
          now: now,
          sources: 1,
          style: TimeStyle.h12,
        ),
        'Courtside · ends 10:55 PM',
      );
      expect(
        programmeHitLine(
          at(DateTime(2026, 9, 15, 21, 30), DateTime(2026, 9, 15, 22, 30)),
          now: now,
          sources: 1,
          style: TimeStyle.h12,
        ),
        'Courtside · Tomorrow, 9:30 PM',
      );
    });

    test('a movie: year, genre else category, where to resume', () {
      final movie = MovieHit(
        movie: MovieItem(
          id: 1,
          sourceId: 's',
          remoteKey: 'm',
          name: 'The Quiet Harbor',
          year: 2024,
          watch: WatchMark(
            position: const Duration(hours: 1, minutes: 12, seconds: 40),
            duration: const Duration(hours: 2),
            updatedAt: now,
          ),
        ),
        sourceName: 'Northwind TV',
        genre: 'Drama',
        categoryName: 'Films',
      );
      expect(
        movieHitLine(movie, sources: 1),
        '2024 · Drama · Resume at 1:12:40',
      );
      const bare = MovieHit(
        movie: MovieItem(id: 2, sourceId: 's', remoteKey: 'n', name: 'X'),
        sourceName: 'Northwind TV',
        categoryName: 'Films',
      );
      expect(movieHitLine(bare, sources: 1), 'Films');
    });

    test('a series: seasons once known, genre else category', () {
      const series = SeriesHit(
        series: SeriesItem(
          id: 1,
          sourceId: 's',
          remoteKey: 's',
          name: 'Harbor Nine',
          genre: 'Crime',
        ),
        sourceName: 'Northwind TV',
        seasons: 3,
      );
      expect(seriesHitLine(series, sources: 1), 'Series · 3 seasons · Crime');
      const one = SeriesHit(
        series: SeriesItem(id: 2, sourceId: 's', remoteKey: 't', name: 'Y'),
        sourceName: 'Northwind TV',
        seasons: 1,
        categoryName: 'Kids',
      );
      expect(seriesHitLine(one, sources: 1), 'Series · 1 season · Kids');
    });

    test('the library: where it is, then how long', () {
      final added = DateTime.utc(2026, 10, 4);
      LibraryItem file(
        String title, {
        LibraryKind kind = LibraryKind.movie,
        int? year,
        String? show,
        int? season,
        int? episode,
        Duration? length = const Duration(minutes: 12),
        bool downloaded = false,
        bool away = false,
      }) => LibraryItem(
        id: 1,
        folderId: 1,
        relPath: '$title.mkv',
        sizeBytes: 1,
        modifiedAt: added,
        quickHash: 'h',
        kind: kind,
        title: title,
        addedAt: added,
        year: year,
        showTitle: show,
        season: season,
        episode: episode,
        duration: length,
        downloaded: downloaded,
        unavailableSince: away ? added : null,
      );

      // The canvas's row: "Harbor Walk (2021)", "Home videos · 12 min".
      final walk = LibraryItemHit(
        file('Harbor Walk', year: 2021),
        folderLabel: 'Home videos',
      );
      expect(libraryHitTitle(walk), 'Harbor Walk (2021)');
      expect(libraryHitLine(walk), 'Home videos · 12 min');
      expect(libraryHitMark(walk), LibraryHitMark.folder);

      final download = LibraryItemHit(
        file(
          'Copper Hollow',
          year: 2025,
          length: const Duration(hours: 1, minutes: 52),
          downloaded: true,
        ),
        folderLabel: 'Downloads',
      );
      expect(libraryHitTitle(download), 'Copper Hollow');
      expect(libraryHitLine(download), 'Downloaded · 1 h 52 min');
      expect(libraryHitMark(download), LibraryHitMark.downloaded);

      final video = LibraryItemHit(
        file('Garden timelapse', kind: LibraryKind.unsorted, length: null),
        folderLabel: 'Home videos',
      );
      expect(libraryHitTitle(video), 'Garden timelapse');
      expect(libraryHitLine(video), 'Home videos', reason: 'not probed yet');

      final episode = LibraryItemHit(
        file(
          'The Long Tide',
          kind: LibraryKind.episode,
          show: 'Kettle Bay',
          season: 2,
          episode: 3,
          length: const Duration(minutes: 44),
        ),
        folderLabel: 'Movies HDD',
      );
      expect(libraryHitTitle(episode), 'The Long Tide');
      expect(libraryHitLine(episode), 'Kettle Bay · S2 · E3 · 44 min');

      final away = LibraryItemHit(
        file('Paper Kites', away: true),
        folderLabel: 'Movies HDD',
      );
      expect(libraryHitLine(away), 'Drive not connected');
      expect(libraryHitMark(away), LibraryHitMark.driveAway);
    });

    test('a show of the library: where it is, then its seasons or '
        'episodes', () {
      LibraryShow show({
        int episodes = 14,
        int seasons = 3,
        bool downloaded = false,
        bool available = true,
      }) => LibraryShow(
        key: 'l:harbor nine',
        title: 'Harbor Nine',
        episodes: episodes,
        seasons: seasons,
        bytes: 1,
        downloaded: downloaded,
        available: available,
      );

      final own = LibraryShowHit(show(), folderLabel: 'Movies HDD');
      expect(libraryHitTitle(own), 'Harbor Nine');
      expect(libraryHitLine(own), 'Movies HDD · 3 seasons');
      expect(libraryHitMark(own), LibraryHitMark.folder);
      expect(
        libraryHitLine(
          LibraryShowHit(show(episodes: 2, seasons: 1, downloaded: true)),
        ),
        'Downloaded · 2 episodes',
      );
      expect(
        libraryHitLine(LibraryShowHit(show(episodes: 1, seasons: 1))),
        '1 episode',
        reason: 'across several folders: none named',
      );
      expect(
        libraryHitLine(
          LibraryShowHit(show(available: false), folderLabel: 'Movies HDD'),
        ),
        'Drive not connected',
      );
    });

    test('Show all: where a screen can list them', () {
      expect(showAllLabel(SearchGroupKind.channels), 'Show all in Live TV');
      expect(showAllLabel(SearchGroupKind.programmes), isNull);
      expect(showAllLabel(SearchGroupKind.library), isNull);
    });

    test('counts and the empty state', () {
      expect(resultCountLabel(1), '1 result');
      expect(resultCountLabel(7), '7 results');
      expect(noResultsTitle(' harbour '), 'No results for "harbour"');
      expect(hiddenMatchesLine(1), '1 hidden channel matches.');
      expect(hiddenMatchesLine(2), '2 hidden channels match.');
      expect(recentLine(['a', 'b', 'c', 'd']), 'Recent: a · b · c');
      expect(recentLine(const []), '');
    });
  });
}

extension on ChannelItem {
  ChannelItem copyWithName(String name) => ChannelItem(
    id: id,
    sourceId: sourceId,
    remoteKey: remoteKey,
    name: name,
    number: number,
  );
}
