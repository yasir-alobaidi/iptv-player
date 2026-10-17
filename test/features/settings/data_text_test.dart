import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/settings/presentation/data_text.dart';

void main() {
  test('sizes: a whole number from 100 of a unit up', () {
    expect(dataSize(0), '0 bytes');
    expect(dataSize(1536), '1.5 KB');
    expect(dataSize(412 * 1024 * 1024), '412 MB');
    expect(dataSize(500 * 1024 * 1024), '500 MB');
    expect(dataSize((1.2 * 1024 * 1024 * 1024).round()), '1.2 GB');
  });

  test('sizes: no ".0" under 100, as the database line says them', () {
    expect(dataSize(77 * 1024 * 1024), '77 MB');
    expect(dataSize(2048), '2 KB');
    expect(dataSize((99.97 * 1024 * 1024).round()), '100 MB');
    expect(dataSize((52.4 * 1024 * 1024).round()), '52.4 MB');
  });

  group('Watch history and Database (ADR-031)', () {
    const kept =
        'Channels are forgotten after 3 months unwatched, finished films '
        'and episodes after 4 months.';

    test('the history line: what was watched, how long it is kept, and '
        'nothing said of what there is none of', () {
      expect(
        historyLine((channels: 12, titles: 38)),
        '12 channels, 38 films and episodes. $kept',
      );
      expect(
        historyLine((channels: 1, titles: 1)),
        '1 channel, 1 film or episode. $kept',
      );
      expect(
        historyLine((channels: 0, titles: 3)),
        '3 films and episodes. $kept',
      );
      expect(
        historyLine((channels: 0, titles: 0), device: 'this TV'),
        'Nothing watched on this TV yet.',
      );
    });

    test("each choice's line, with and without counts", () {
      const counts = (channels: 1200, titles: 38);
      expect(
        historyChoiceLine(HistoryChoice.channels, counts),
        '1,200 channels, on Home and for Last channel',
      );
      expect(
        historyChoiceLine(HistoryChoice.titles, null),
        'Films and episodes, started or finished',
      );
      // A kind with none: nothing to clear, and it can't be chosen.
      const noChannels = (channels: 0, titles: 38);
      expect(
        historyChoiceLine(HistoryChoice.channels, noChannels),
        'Nothing to clear',
      );
      expect(historyChoiceEmpty(HistoryChoice.channels, noChannels), isTrue);
      expect(historyChoiceEmpty(HistoryChoice.titles, noChannels), isFalse);
      expect(historyChoiceEmpty(HistoryChoice.everything, noChannels), isFalse);
      expect(historyChoiceEmpty(HistoryChoice.channels, null), isFalse);
      expect(historyCleared(HistoryChoice.everything), 'Watch history cleared');
      expect(
        historyCleared(HistoryChoice.titles),
        'Continue watching and watched marks cleared',
      );
    });

    test('the database line: free room said only when there is some', () {
      const mb = 1024 * 1024;
      expect(
        databaseLine(
          const DatabaseRoom(
            bytes: 77 * mb,
            pagesBytes: 77 * mb,
            freeBytes: 25 * mb,
          ),
          device: 'this TV',
        ),
        'Your sources, catalogues, guide and history on this TV: 77 MB, '
        '25 MB of it unused. Compact gives that room back.',
      );
      expect(
        databaseLine(
          const DatabaseRoom(bytes: 52 * mb, pagesBytes: 52 * mb, freeBytes: 0),
        ),
        'Your sources, catalogues, guide and history on this computer: '
        '52 MB.',
      );
    });

    test('why Compact waits, and what it gave back', () {
      expect(UpkeepBlocker.values.map(compactWaits), [
        'It can be compacted once nothing is playing.',
        'It can be compacted once the sync is done.',
        'It can be compacted once the guide is imported.',
        'It can be compacted once the downloads are done.',
      ]);
      const mb = 1024 * 1024;
      expect(
        databaseCompacted((before: 77 * mb, after: 52 * mb)),
        'Database compacted · 77 MB → 52 MB',
      );
      expect(
        databaseCompacted((before: 52 * mb, after: 52 * mb)),
        'Database compacted · 52 MB',
      );
    });
  });

  test('the pictures line: what is kept, of how much', () {
    const what = 'Posters, logos and stills kept on this computer.';
    expect(
      picturesLine(bytes: 412 * 1024 * 1024, maxBytes: 500 * 1024 * 1024),
      '$what 412 MB of 500 MB.',
    );
    expect(
      picturesLine(bytes: 0, maxBytes: 500 * 1024 * 1024),
      '$what None are kept right now.',
    );
    expect(picturesLine(bytes: 2048, maxBytes: 0), '$what 2 KB.');
  });

  test('the guide line: how much, until when, and what Clear leaves', () {
    expect(
      guideLine(
        programmes: 142880,
        until: DateTime(2026, 10, 19, 6),
        importing: false,
      ),
      '142,880 programmes until Oct 19. Your channel matches are kept, and '
      'the guide comes back at its next refresh.',
    );
    expect(
      guideLine(programmes: 1, until: null, importing: false),
      startsWith('1 programme. '),
    );
    expect(
      guideLine(programmes: 0, until: null, importing: false),
      'There is no guide on this computer.',
    );
    expect(
      guideLine(programmes: 500, until: null, importing: true),
      'A guide is being imported. It can be cleared once that is done.',
    );
  });

  test('what Clear asks, and says after', () {
    expect(
      clearPicturesBody(412 * 1024 * 1024),
      '412 MB of pictures will be deleted from this computer. They are '
      'fetched again as you browse.',
    );
    expect(clearPicturesBody(0), startsWith('Every kept picture will be'));
    expect(
      picturesCleared(412 * 1024 * 1024),
      'Pictures cleared · 412 MB freed',
    );
    expect(picturesCleared(0), 'Pictures cleared');
  });

  test('each reason a file is refused has its own words, and none is a raw '
      'error', () {
    final damaged = fileProblem(SettingsFileProblem.damaged);
    final notOurs = fileProblem(SettingsFileProblem.notOurs);
    final newer = fileProblem(SettingsFileProblem.newer, format: 3);

    expect({damaged, notOurs, newer}, hasLength(3));
    expect(damaged, contains('damaged or incomplete'));
    expect(notOurs, contains("isn't a settings file from Bijou"));
    expect(newer, contains('newer version of Bijou (format 3)'));
    expect(newer, contains('Update this app'));
    expect(fileProblem(SettingsFileProblem.newer), isNot(contains('format')));
  });

  test('a source’s line in the preview names only what it has', () {
    expect(
      importSourceLine(
        ExportedSource(
          name: 'Northwind TV',
          type: 'xtream',
          fingerprint: 'x',
          favorites: [
            for (var i = 0; i < 212; i++)
              ExportedFavorite(type: 'live', key: '$i'),
          ],
          favoriteGroups: const [
            ExportedFavoriteGroup(name: 'a'),
            ExportedFavoriteGroup(name: 'b'),
            ExportedFavoriteGroup(name: 'c'),
          ],
          categories: [
            for (var i = 0; i < 41; i++)
              ExportedCategory(kind: 'live', key: '$i', hidden: true),
            const ExportedCategory(kind: 'live', key: 'shown'),
          ],
          guideMatches: [
            for (var i = 0; i < 9; i++)
              ExportedGuideMatch(channel: '$i', xmltvId: 'x$i'),
          ],
        ),
      ),
      '212 favorites · 3 groups · 41 hidden categories · 9 guide matches',
    );
    expect(
      importSourceLine(
        const ExportedSource(
          name: 'n',
          type: 'xtream',
          fingerprint: 'x',
          favorites: [ExportedFavorite(type: 'live', key: '1')],
          categories: [
            ExportedCategory(kind: 'live', key: '1', hidden: true, name: 'R'),
          ],
          channels: [
            ExportedChannel(key: '1', hidden: true),
            ExportedChannel(key: '2', name: 'Renamed'),
          ],
          guideMatches: [ExportedGuideMatch(channel: '1', xmltvId: 'x')],
          reminders: [
            {'title': 'T'},
          ],
        ),
      ),
      '1 favorite · 1 hidden category · 1 renamed category · '
      '1 hidden channel · 1 renamed channel · 1 guide match · 1 reminder',
    );
    expect(
      importSourceLine(
        const ExportedSource(name: 'n', type: 'xtream', fingerprint: 'x'),
      ),
      'nothing to bring over',
    );
  });

  test('the toasts after an export and an import', () {
    expect(
      exportDone(
        const ExportSummary(path: 'p', sources: 2, favorites: 212, bytes: 1),
      ),
      'Exported your settings and choices · 2 sources · 212 favorites',
    );
    expect(
      exportDone(
        const ExportSummary(path: 'p', sources: 0, favorites: 0, bytes: 1),
      ),
      'Exported your settings and choices',
    );

    ImportSummary summary({
      List<String> pages = const [],
      int sources = 0,
      int skipped = 0,
      int favorites = 0,
      int matches = 0,
    }) => ImportSummary(
      settingsPages: pages,
      sources: sources,
      skippedSources: skipped,
      favorites: favorites,
      categories: 0,
      channels: 0,
      guideMatches: matches,
      reminders: 0,
      notHere: 0,
    );
    expect(
      importDone(
        summary(
          pages: ['appearance'],
          sources: 1,
          skipped: 1,
          favorites: 212,
          matches: 9,
        ),
      ),
      'Imported · settings replaced · 1 source merged in · 212 favorites · '
      '9 guide matches · 1 source not on this computer',
    );
    expect(importDone(summary()), 'Nothing to import');
  });

  test('on a TV the device is "this TV"', () {
    expect(
      picturesLine(bytes: 0, maxBytes: 0, device: 'this TV'),
      startsWith('Posters, logos and stills kept on this TV.'),
    );
    expect(
      guideLine(
        programmes: 0,
        until: null,
        importing: false,
        device: 'this TV',
      ),
      'There is no guide on this TV.',
    );
    expect(clearPicturesBody(0, device: 'this TV'), contains('from this TV.'));
  });
}
