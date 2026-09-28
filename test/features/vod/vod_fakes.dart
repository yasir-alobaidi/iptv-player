import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/sources/data/db_category_repository.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';

import '../onboarding/onboarding_fakes.dart';
import 'vod_test_support.dart';

/// Movies and Series on a real in-memory catalogue, read through the real
/// repositories, with [details] answering for the provider.
final class VodFakes {
  new()
    : fakes = OnboardingFakes(),
      // Widget tests end with no timers pending: drift closes a stream
      // query on a timer unless told to do it at once.
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  final OnboardingFakes fakes;
  final AppDatabase db;
  final details = ScriptedDetails();
  late int drama;
  late int kids;

  DateTime get now => fakes.now;

  /// Source `src-1` with Drama (two movies), Kids (hidden, one movie) and
  /// one uncategorized movie; one series.
  Future<void> seed({bool movies = true}) async {
    fakes.sources.seed();
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(
            id: 'src-1',
            type: SourceType.xtream,
            name: 'Northwind TV',
            url: 'http://northwind.test',
            createdAt: now,
            updatedAt: now,
          ),
        );
    drama = await addCategory(db, 'src-1', CatalogueKind.movie, '10', 'Drama');
    kids = await addCategory(
      db,
      'src-1',
      CatalogueKind.movie,
      '11',
      'Kids',
      hidden: true,
    );
    if (!movies) return;
    await addMovie(
      db,
      '501',
      'The Quiet Harbor',
      source: 'src-1',
      category: drama,
      rating: 7.8,
      added: now.subtract(const Duration(days: 2)),
      year: 2024,
    );
    await addMovie(
      db,
      '502',
      'Copper Hollow',
      source: 'src-1',
      category: drama,
      rating: 7.1,
      added: now.subtract(const Duration(days: 40)),
      year: 2025,
    );
    await addMovie(db, '503', 'Kestrel Point', source: 'src-1', category: kids);
    await addMovie(db, '504', 'Ember Road', source: 'src-1', rating: 6.7);
    await addSeries(db, '77', 'Glass Tide', source: 'src-1', rating: 8.4);
  }

  /// [count] more movies, uncategorized, named "Movie 001"… and each a
  /// day older than the one before.
  Future<void> seedMany(int count) async {
    for (var i = 1; i <= count; i++) {
      await addMovie(
        db,
        'm$i',
        'Movie ${'$i'.padLeft(3, '0')}',
        source: 'src-1',
        rating: 5 + (i % 50) / 10,
        added: now.subtract(Duration(days: 10 + i)),
        year: 2025 - i % 12,
      );
    }
  }

  List<Override> get overrides => [
    sourceRepositoryProvider.overrideWithValue(fakes.sources),
    syncServiceProvider.overrideWithValue(fakes.sync),
    sourceOverviewRepositoryProvider.overrideWithValue(fakes.overviews),
    appClockProvider.overrideWithValue(() => now),
    appDatabaseProvider.overrideWithValue(db),
    categoryRepositoryProvider.overrideWithValue(DbCategoryRepository(db)),
    titleDetailsSourceProvider.overrideWithValue(details),
    movieRepositoryProvider.overrideWithValue(
      DbMovieRepository(db, details, clock: () => now),
    ),
    seriesRepositoryProvider.overrideWithValue(
      DbSeriesRepository(db, details, clock: () => now),
    ),
    watchProgressProvider.overrideWithValue(
      DbWatchProgress(db, clock: () => now),
    ),
  ];
}

/// Lets drift's isolate-free queries and the grid's page reads finish,
/// a frame at a time. Never `pumpAndSettle`: skeletons shimmer.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
