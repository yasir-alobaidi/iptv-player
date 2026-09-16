import 'dart:convert';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/models.dart';
import 'package:fake_provider/profile.dart';
import 'package:test/test.dart';

/// The catalogue is what every other test in the app leans on, so the
/// properties checked here are the ones tests depend on: the same profile
/// always yields the same rows, one row can be built without its neighbours,
/// and the docs/02 quirks appear exactly where the profile says.
void main() {
  final defaults = fakeProfiles['default']!;
  final large = fakeProfiles['large']!;
  final quirky = fakeProfiles['quirky']!;

  const shape = JsonShape.clean;

  group('determinism', () {
    test('two catalogues of the same profile are identical', () {
      final a = FakeCatalog(defaults);
      final b = FakeCatalog(defaults);

      expect(
        a.channels().take(40).map((c) => c.toJson(shape)),
        b.channels().take(40).map((c) => c.toJson(shape)),
      );
      expect(
        a.movies().take(20).map((m) => m.toJson(shape)),
        b.movies().take(20).map((m) => m.toJson(shape)),
      );
      expect(
        a.series().take(10).map((s) => s.toJson(shape)),
        b.series().take(10).map((s) => s.toJson(shape)),
      );
      expect(
        a.liveCategories.map((c) => c.toJson(shape)),
        b.liveCategories.map((c) => c.toJson(shape)),
      );

      final series = a.series().first;
      expect(
        a.episodesOf(series).mapValues((e) => e.toJson(shape)),
        b.episodesOf(series).mapValues((e) => e.toJson(shape)),
      );
    });

    test('a different seed gives different data', () {
      final other = FakeCatalog(
        FakeProfile(
          name: 'other',
          seed: defaults.seed + 1,
          liveCount: defaults.liveCount,
          movieCount: defaults.movieCount,
          seriesCount: defaults.seriesCount,
          liveCategoryCount: defaults.liveCategoryCount,
          movieCategoryCount: defaults.movieCategoryCount,
          seriesCategoryCount: defaults.seriesCategoryCount,
        ),
      );
      final mine = FakeCatalog(defaults).channels().take(20).map((c) => c.name);
      expect(other.channels().take(20).map((c) => c.name), isNot(mine));
    });

    test('an item does not depend on its neighbours being built', () {
      final catalog = FakeCatalog(defaults);
      // channelById(120) on its own must equal the 120th of a full walk:
      // that is the whole point of index-addressable draws.
      expect(
        catalog.channelById(120)!.toJson(shape),
        FakeCatalog(defaults).channels().elementAt(119).toJson(shape),
      );
      expect(
        catalog.movieById(movieIdBase + 40)!.toJson(shape),
        catalog.movies().elementAt(40).toJson(shape),
      );
      expect(
        catalog.seriesById(seriesIdBase + 7)!.toJson(shape),
        catalog.series().elementAt(7).toJson(shape),
      );
    });
  });

  group('laziness', () {
    test('the large profile is cheap to open and to sample', () {
      // 50k channels and 30k movies: if anything materialized the range,
      // this would not fit in the budget (docs/06 asks for a 60 s sync of
      // the whole catalogue, so building five rows has to be trivial).
      final watch = Stopwatch()..start();
      final catalog = FakeCatalog(large);
      final first = catalog.channels().take(5).toList();
      final someMovies = catalog.movies().take(5).toList();
      watch.stop();

      expect(first, hasLength(5));
      expect(someMovies, hasLength(5));
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('a category filter stays lazy', () {
      final catalog = FakeCatalog(large);
      final category = catalog.movieCategories.first.id;
      final watch = Stopwatch()..start();
      final page = catalog.movies(categoryId: category).take(3).toList();
      watch.stop();

      expect(page, hasLength(3));
      expect(page.map((m) => m.categoryId), everyElement(category));
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('the last row of the large profile is reachable by id', () {
      final catalog = FakeCatalog(large);
      final watch = Stopwatch()..start();
      final last = catalog.channelById(liveIdBase + large.liveCount - 1);
      watch.stop();

      expect(last, isNotNull);
      expect(last!.number, large.liveCount);
      expect(watch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('counts and ids', () {
    final catalog = FakeCatalog(defaults);

    test('counts follow the profile', () {
      expect(catalog.channels(), hasLength(defaults.liveCount));
      expect(catalog.movies(), hasLength(defaults.movieCount));
      expect(catalog.series(), hasLength(defaults.seriesCount));
      expect(catalog.liveCategories, hasLength(defaults.liveCategoryCount));
      expect(catalog.movieCategories, hasLength(defaults.movieCategoryCount));
      expect(catalog.seriesCategories, hasLength(defaults.seriesCategoryCount));
    });

    test('each kind keeps to its own id range', () {
      expect(catalog.channels().first.streamId, liveIdBase);
      expect(
        catalog.channels().last.streamId,
        liveIdBase + defaults.liveCount - 1,
      );
      expect(catalog.movies().first.streamId, movieIdBase);
      expect(catalog.series().first.seriesId, seriesIdBase);
    });

    test('an id outside the range is null, not an exception', () {
      expect(catalog.channelById(0), isNull);
      expect(catalog.channelById(liveIdBase + defaults.liveCount), isNull);
      expect(catalog.channelById(movieIdBase), isNull);
      expect(catalog.movieById(1), isNull);
      expect(catalog.movieById(movieIdBase + defaults.movieCount), isNull);
      expect(catalog.seriesById(1), isNull);
      expect(catalog.episodeById(1), isNull);
      expect(catalog.episodeById(episodeIdBase - 1), isNull);
    });

    test('categories have unique ids and names', () {
      final ids = catalog.liveCategories.map((c) => c.id).toSet();
      expect(ids, hasLength(defaults.liveCategoryCount));
      final names = catalog.liveCategories.map((c) => c.name).toSet();
      expect(names, hasLength(defaults.liveCategoryCount));
      // The three kinds' ids never collide, so a category_id identifies a
      // list as well as a row.
      final movieIds = catalog.movieCategories.map((c) => c.id).toSet();
      final seriesIds = catalog.seriesCategories.map((c) => c.id).toSet();
      expect(ids.intersection(movieIds), isEmpty);
      expect(ids.intersection(seriesIds), isEmpty);
      expect(movieIds.intersection(seriesIds), isEmpty);
    });

    test('with no quirks every category_id resolves and spreads', () {
      final ids = catalog.liveCategories.map((c) => c.id).toSet();
      final used = <String>{};
      for (final channel in catalog.channels()) {
        expect(channel.categoryId, isNotNull);
        expect(ids, contains(channel.categoryId));
        used.add(channel.categoryId!);
      }
      expect(used, hasLength(ids.length));
    });

    test('samples come from the sample lists and match the extension', () {
      for (final channel in catalog.channels().take(30)) {
        expect(liveSamples, contains(channel.sample));
      }
      for (final movie in catalog.movies().take(30)) {
        expect(vodSamples, contains(movie.sample));
        expect(movie.sample, endsWith('.${movie.containerExtension}'));
      }
    });
  });

  group('episodes', () {
    final catalog = FakeCatalog(defaults);

    test('episodesOf and episodeById agree', () {
      for (final series in catalog.series().take(6)) {
        final bySeason = catalog.episodesOf(series);
        expect(bySeason.keys, series.seasonCount == 0 ? isEmpty : isNotEmpty);
        expect(bySeason.keys.toList(), [
          for (var s = 1; s <= series.seasonCount; s++) s,
        ]);
        for (final entry in bySeason.entries) {
          expect(entry.value.map((e) => e.episode).toList(), [
            for (var i = 1; i <= entry.value.length; i++) i,
          ]);
          for (final episode in entry.value) {
            expect(episode.season, entry.key);
            expect(episode.id, greaterThanOrEqualTo(episodeIdBase));
            expect(
              catalog.episodeById(episode.id)!.toJson(JsonShape.clean),
              episode.toJson(JsonShape.clean),
            );
          }
        }
      }
    });

    test('a season or episode the series does not have is null', () {
      final series = catalog.series().first;
      final seasons = catalog.episodesOf(series);
      final lastSeason = seasons.keys.last;
      final lastEpisode = seasons[lastSeason]!.last;
      expect(catalog.episodeById(lastEpisode.id + 1), isNull);
      expect(
        catalog.episodeById(episodeIdBase + defaults.seriesCount * 1000),
        isNull,
      );
    });
  });

  group('short EPG', () {
    final catalog = FakeCatalog(defaults);
    final now = DateTime.utc(2026, 9, 16, 12, 40);

    test('the first programme covers now and the rest follow it', () {
      final listing = catalog.shortEpg(1, now: now);
      expect(listing, hasLength(4));
      expect(listing.first.start.isAfter(now), isFalse);
      expect(listing.first.end.isAfter(now), isTrue);
      for (var i = 1; i < listing.length; i++) {
        expect(listing[i].start, listing[i - 1].end);
      }
      expect(listing.every((p) => p.start.isUtc), isTrue);
    });

    test('limit is honoured and 0 is empty', () {
      expect(catalog.shortEpg(1, limit: 2, now: now), hasLength(2));
      expect(catalog.shortEpg(1, limit: 0, now: now), isEmpty);
    });

    test('a channel with no epg_channel_id has no listing', () {
      final without = catalog.channels().firstWhere(
        (c) => c.epgChannelId == null,
      );
      expect(catalog.shortEpg(without.streamId, now: now), isEmpty);
      expect(catalog.shortEpg(999999, now: now), isEmpty);
    });

    test('the same channel and clock give the same listing', () {
      expect(
        catalog
            .shortEpg(7, now: now)
            .map((p) => p.toShortEpgJson(shape, now: true)),
        FakeCatalog(defaults)
            .shortEpg(7, now: now)
            .map((p) => p.toShortEpgJson(shape, now: true)),
      );
    });

    test('titles and descriptions are base64 on the wire (docs/02)', () {
      final programme = catalog.shortEpg(1, limit: 1, now: now).single;
      final json = programme.toShortEpgJson(shape, now: true);
      expect(
        utf8.decode(base64.decode(json['title']! as String)),
        programme.title,
      );
      expect(
        utf8.decode(base64.decode(json['description']! as String)),
        programme.description,
      );
      expect(json['start'], '2026-09-16 12:30:00');
      expect(json['channel_id'], programme.epgChannelId);
    });
  });

  group('value quirks', () {
    test('invalid UTF-8 marks every 17th name', () {
      final catalog = FakeCatalog(
        defaults.copyWith(quirks: const FakeQuirks(invalidUtf8Names: true)),
      );
      final names = catalog.channels().map((c) => c.name).toList();
      expect(names[16], contains(invalidUtf8Marker));
      expect(names[33], contains(invalidUtf8Marker));
      expect(names[0], isNot(contains(invalidUtf8Marker)));
      expect(
        names.where((n) => n.contains(invalidUtf8Marker)),
        hasLength(defaults.liveCount ~/ 17),
      );
    });

    test('dangling category ids point outside every category', () {
      final catalog = FakeCatalog(
        defaults.copyWith(quirks: const FakeQuirks(danglingCategoryIds: true)),
      );
      final known = catalog.liveCategories.map((c) => c.id).toSet();
      final ids = catalog.channels().map((c) => c.categoryId).toList();

      // Every 29th has no category at all → "Uncategorized" (docs/02).
      expect(ids[28], isNull);
      // Every 13th points at a category that is not in the list.
      expect(ids[12], isNotNull);
      expect(known, isNot(contains(ids[12])));
      // The rest still resolve.
      expect(known, contains(ids[0]));
    });

    test('junk icons land on every 11th item', () {
      final catalog = FakeCatalog(
        defaults.copyWith(quirks: const FakeQuirks(junkIcons: true)),
      );
      final icons = catalog.channels().map((c) => c.icon).toList();
      final clean = FakeCatalog(defaults).channels().elementAt(10).icon;
      expect(icons[10], isNotNull);
      expect(icons[10], isNot(clean));
      expect(icons[0], startsWith('http'));
      // Junk is a mix: some of it isn't a URL at all, which is the case the
      // placeholder tiles in docs/02 have to survive.
      final notAUrl = icons.whereType<String>().where((url) {
        final parsed = Uri.tryParse(url);
        return parsed == null ||
            (parsed.scheme != 'http' && parsed.scheme != 'https');
      });
      expect(notAUrl, isNotEmpty);
    });

    test('some items have no icon even with no quirks on', () {
      final icons = FakeCatalog(defaults)
          .channels()
          .map((c) => c.icon)
          .toList();
      expect(icons[22], isNull);
      expect(icons.where((i) => i == null), isNotEmpty);
    });

    test('html entities and stray whitespace appear in names', () {
      final names = FakeCatalog(
        defaults.copyWith(quirks: const FakeQuirks(htmlEntities: true)),
      ).channels().take(4).map((c) => c.name).toList();
      expect(names[0], contains('&amp;'));
      expect(names[1], contains('&#39;'));
      expect(names[2], startsWith(' '));
      expect(names[2].trim(), isNot(startsWith(' ')));
    });

    test('the quirky profile turns all of them on at once', () {
      final catalog = FakeCatalog(quirky);
      final channels = catalog.channels().toList();
      expect(
        channels.where((c) => c.name.contains(invalidUtf8Marker)),
        isNotEmpty,
      );
      expect(channels.where((c) => c.categoryId == null), isNotEmpty);
      expect(channels.where((c) => c.name.contains('&')), isNotEmpty);
      expect(quirky.expiresInDays, isNull, reason: 'exp_date null (docs/02)');
    });
  });

  group('JSON shapes', () {
    final catalog = FakeCatalog(defaults);

    test('a live row carries the docs/02 field names', () {
      final json = catalog.channels().first.toJson(shape);
      expect(
        json.keys,
        containsAll(<String>[
          'num',
          'name',
          'stream_id',
          'stream_icon',
          'epg_channel_id',
          'added',
          'category_id',
          'tv_archive',
          'tv_archive_duration',
        ]),
      );
      expect(json['stream_type'], 'live');
      expect(json['num'], isA<int>());
      // Panels send `added` as a string even when nothing else is stringified.
      expect(json['added'], isA<String>());
    });

    test('a vod row and its info carry the docs/02 field names', () {
      final movie = catalog.movies().first;
      expect(movie.toJson(shape)['container_extension'], isIn(['mp4', 'mkv']));
      final info = movie.toInfoJson(shape);
      expect(info.keys, containsAll(<String>['info', 'movie_data']));
      final inner = info['info']! as Map<String, Object?>;
      expect(
        inner.keys,
        containsAll(<String>[
          'plot',
          'cast',
          'director',
          'genre',
          'duration_secs',
          'duration',
          'releasedate',
        ]),
      );
      expect(inner['duration'], matches(RegExp(r'^\d+:\d{2}:\d{2}$')));
    });

    test('a series row and its seasons carry the docs/02 field names', () {
      final series = catalog.series().first;
      final json = series.toJson(shape);
      expect(
        json.keys,
        containsAll(<String>[
          'series_id',
          'name',
          'cover',
          'plot',
          'genre',
          'releaseDate',
          'last_modified',
          'category_id',
        ]),
      );
      final season = series.seasonJson(shape, 1, 8);
      expect(season['season_number'], 1);
      expect(season['episode_count'], 8);
    });

    test('numbers as strings only changes the representation', () {
      const quirked = JsonShape(FakeQuirks(numbersAsStrings: true));
      final channel = catalog.channels().first;
      expect(channel.toJson(quirked)['num'], '${channel.number}');
      expect(channel.toJson(quirked)['stream_id'], '${channel.streamId}');
      expect(channel.toJson(quirked)['tv_archive'], isIn(['0', '1']));
      // The row itself is untouched: the same object still serializes clean.
      expect(channel.toJson(shape)['num'], channel.number);
    });

    test('empty string for null replaces a missing icon', () {
      const quirked = JsonShape(FakeQuirks(emptyStringForNull: true));
      final noIcon = catalog.channels().elementAt(22);
      expect(noIcon.icon, isNull);
      expect(noIcon.toJson(quirked)['stream_icon'], '');
      expect(noIcon.toJson(shape)['stream_icon'], isNull);
    });

    test('info as an empty list replaces the map (docs/02)', () {
      const quirked = JsonShape(FakeQuirks(infoAsEmptyList: true));
      expect(catalog.movies().first.toInfoJson(quirked)['info'], isEmpty);
      expect(
        catalog.movies().first.toInfoJson(quirked)['info'],
        isA<List<Object?>>(),
      );
    });
  });
}

extension on Map<int, List<FakeEpisode>> {
  Map<int, List<Map<String, Object?>>> mapValues(
    Map<String, Object?> Function(FakeEpisode) toJson,
  ) => {
    for (final entry in entries) entry.key: entry.value.map(toJson).toList(),
  };
}
