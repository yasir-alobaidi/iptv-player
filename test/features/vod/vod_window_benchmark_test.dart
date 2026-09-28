import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';

import 'vod_test_support.dart';

/// The Movies grid's window query over the `large` profile's 30,000
/// movies in 90 categories, on a file database opened the way the app
/// opens it (Phase 5 step 2: an index only where this asks for one).
/// Skipped unless asked for:
///
///     flutter test --tags benchmark --run-skipped \
///       test/features/vod/vod_window_benchmark_test.dart
void main() {
  test('benchmark: a window of 120 movies out of 30,000', () async {
    final directory = await Directory.systemTemp.createTemp('vod_bench');
    addTearDown(() => directory.delete(recursive: true));
    final db = AppDatabase(await openAppDatabase(directory));
    addTearDown(db.close);
    await addSource(db, 'src');
    final random = Random(7);
    final categories = <int>[
      for (var i = 0; i < 90; i++)
        await addCategory(
          db,
          'src',
          CatalogueKind.movie,
          '$i',
          'Category $i',
          hidden: i % 9 == 0,
        ),
    ];
    for (var start = 0; start < 30000; start += 5000) {
      await db.moviesDao.upsertAll([
        for (var i = start; i < start + 5000; i++)
          MoviesCompanion.insert(
            sourceId: 'src',
            remoteKey: '$i',
            name: 'Movie ${random.nextInt(1 << 30).toRadixString(36)}',
            categoryId: Value(categories[i % 90]),
            rating: Value(i % 11 == 0 ? null : random.nextInt(70) / 10 + 3),
            addedAt: Value(
              DateTime.utc(2024)
                  .add(Duration(minutes: random.nextInt(1 << 20))),
            ),
            position: Value(i),
          ),
      ]);
    }
    for (var i = 0; i < 200; i++) {
      await db.favoritesDao.add(UserItemType.movie, 'src', '${i * 97}', t0);
      await db.watchHistoryDao.touch(
        UserItemType.movie,
        'src',
        '${i * 89}',
        t0,
        positionMs: 600000,
        durationMs: 6000000,
        completed: false,
      );
    }
    final repo = DbMovieRepository(db, ScriptedDetails());

    Future<double> median(Future<void> Function() body) async {
      final times = <int>[];
      for (var i = 0; i < 7; i++) {
        final clock = Stopwatch()..start();
        await body();
        times.add(clock.elapsedMicroseconds);
      }
      times.sort();
      return times[times.length ~/ 2] / 1000;
    }

    const query = TitleQuery(sourceId: 'src');
    final lines = <String>[];
    final count = await median(
      () => db
          .customSelect(
            'SELECT COUNT(*) FROM movies m '
            'LEFT JOIN categories k ON k.id = m.category_id '
            'WHERE m.source_id = ? AND (k.id IS NULL OR k.is_hidden = 0)',
            variables: [Variable.withString('src')],
          )
          .get(),
    );
    lines.add('count: ${count.toStringAsFixed(1)} ms');
    for (final sort in TitleSort.values) {
      for (final offset in [0, 13000, 26500]) {
        final ms = await median(
          () => repo.range(query.copyWith(sort: sort), offset, 120),
        );
        lines.add('${sort.name} @$offset: ${ms.toStringAsFixed(1)} ms');
      }
    }
    final filtered = await median(
      () => repo.range(query.copyWith(text: 'mo'), 0, 120),
    );
    lines.add('filter "mo": ${filtered.toStringAsFixed(1)} ms');
    final category = await median(
      () => repo.range(
        query.copyWith(filter: CategoryTitles(categories[5])),
        0,
        120,
      ),
    );
    lines.add('one category: ${category.toStringAsFixed(1)} ms');
    final favorites = await median(
      () => repo.range(query.copyWith(filter: const FavoriteTitles()), 0, 120),
    );
    lines.add('favorites: ${favorites.toStringAsFixed(1)} ms');
    // A benchmark reports its numbers; there is nothing to assert.
    // ignore: avoid_print
    print(lines.join('\n'));
  }, tags: 'benchmark');
}
