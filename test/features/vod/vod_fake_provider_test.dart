import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/data/title_details_source.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:logger/logger.dart';

import 'vod_test_support.dart';

/// The details pages' data end to end: a real source and keyring, the
/// Xtream client, and the fake panel in-process, whose `apiCalls` counts
/// what was asked.
final class _Env {
  new _(this.db, this.sources);

  static Future<_Env> open() async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final secrets = SecretRegistry();
    final log = AppLog(output: MemoryOutput(), secrets: secrets);
    addTearDown(log.close);
    return _Env._(
      db,
      DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: secrets,
        log: log,
      ),
    );
  }

  final AppDatabase db;
  final DbSourceRepository sources;

  late final details = XtreamTitleDetails(sources);
  late final movies = DbMovieRepository(db, details);
  late final series = DbSeriesRepository(db, details);

  Future<String> addPanel(Object url) async {
    final added = await sources.add(
      SourceDraft(
        type: SourceType.xtream,
        name: 'Fake panel',
        url: '$url',
        username: 'test',
        password: 'test',
      ),
    );
    return added.valueOrNull!.id;
  }
}

Future<FakeProviderServer> _panel({
  FakeQuirks quirks = const FakeQuirks(),
}) async {
  final runDir = await Directory.systemTemp.createTemp('vod_panel');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: fakeProfiles['default']!.copyWith(quirks: quirks),
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('a movie: the first open asks the panel, the second makes no '
      'request', () async {
    final panel = await _panel();
    final env = await _Env.open();
    final source = await env.addPanel(panel.url);
    await addMovie(env.db, '100000', 'Fake movie', source: source);
    final movie = (await env.movies.byRemoteKey(source, '100000')).valueOrNull!;

    final first = await env.movies.details(movie).last;
    final second = await env.movies.details(movie).toList();

    expect(panel.state.apiCalls['get_vod_info'], 1);
    expect(second.single, isA<DetailsReady<MovieDetails>>());
    final details = (first as DetailsReady<MovieDetails>).value;
    final fake = panel.state.catalog.movieById(100000)!;
    expect(details.plot, fake.plot);
    expect(details.director, fake.director);
    expect(details.videoHeight, 1080);
    expect(details.audioChannels, 2);
    expect(details.backdropUrl, '${panel.url}/art/backdrop/movie/100000.jpg');
  });

  test('a series: the first open asks the panel, the second makes no '
      'request', () async {
    final panel = await _panel();
    final env = await _Env.open();
    final source = await env.addPanel(panel.url);
    await addSeries(env.db, '$seriesIdBase', 'Fake series', source: source);
    final show = (await env.series.byRemoteKey(
      source,
      '$seriesIdBase',
    )).valueOrNull!;

    await env.series.details(show).drain<void>();
    final again = await env.series.details(show).toList();

    expect(panel.state.apiCalls['get_series_info'], 1);
    expect(again.single, isA<DetailsReady<SeriesDetails>>());
  });

  test('episodes as a map keyed by season and as a list read the same, '
      'and match the panel', () async {
    Future<SeriesDetails> read(FakeQuirks quirks) async {
      final panel = await _panel(quirks: quirks);
      final env = await _Env.open();
      final source = await env.addPanel(panel.url);
      await addSeries(env.db, '$seriesIdBase', 'Fake series', source: source);
      final show = (await env.series.byRemoteKey(
        source,
        '$seriesIdBase',
      )).valueOrNull!;
      final last = await env.series.details(show).last;
      return (last as DetailsReady<SeriesDetails>).value;
    }

    final fromList = await read(const FakeQuirks());
    final fromMap = await read(const FakeQuirks(episodesAsMap: true));

    List<(int, int, String, String)> shape(SeriesDetails d) => [
      for (final season in d.seasons)
        for (final e in season.episodes)
          (e.season, e.episode, e.remoteKey, e.title),
    ];
    expect(shape(fromMap), shape(fromList));

    final catalog = FakeCatalog(fakeProfiles['default']!);
    final bySeason = catalog.episodesOf(catalog.seriesById(seriesIdBase)!);
    expect(fromList.seasons.map((s) => s.number), bySeason.keys);
    expect(
      fromList.episodeCount,
      bySeason.values.fold<int>(0, (n, episodes) => n + episodes.length),
    );
    expect(fromList.cast, isNotNull);
  });

  test('an unknown movie ({}) and a panel with no metadata (info: []) are '
      'pages with nothing in them, not errors', () async {
    final panel = await _panel(quirks: const FakeQuirks(infoAsEmptyList: true));
    final env = await _Env.open();
    final source = await env.addPanel(panel.url);
    await addMovie(env.db, '100001', 'No metadata', source: source);
    await addMovie(env.db, '99', 'Gone', source: source);

    for (final key in ['100001', '99']) {
      final movie = (await env.movies.byRemoteKey(source, key)).valueOrNull!;
      final last = await env.movies.details(movie).last;
      expect(last, isA<DetailsReady<MovieDetails>>(), reason: key);
      expect((last as DetailsReady<MovieDetails>).value.plot, isNull);
    }
  });

  test('a panel that answers with a web page: a failure with a reason, '
      'never a throw (hard rule 1)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final account = request.uri.queryParameters['action'] == null;
      request.response
        ..headers.contentType = account ? ContentType.json : ContentType.html
        ..write(
          account
              ? '{"user_info":{"auth":1,"status":"Active"},"server_info":{}}'
              : '<html><body>Maintenance</body></html>',
        );
      await request.response.close();
    });
    final env = await _Env.open();
    final source = await env.addPanel('http://127.0.0.1:${server.port}');
    await addMovie(env.db, '5', 'Harbor', source: source);
    final movie = (await env.movies.byRemoteKey(source, '5')).valueOrNull!;

    final last = await env.movies.details(movie).last;

    expect(last, isA<DetailsFailed<MovieDetails>>());
    expect((last as DetailsFailed<MovieDetails>).failure, isA<ParseFailure>());
  });
}
