import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_client.dart';

/// The client against tools/fake_provider over real HTTP: every action,
/// on a clean panel and on one with every docs/02 quirk on at once. The
/// quirks one at a time, against fixtures, are in `xtream_parse_test.dart`.
Future<FakeProviderServer> _start(FakeProfile profile) async {
  final runDir = await Directory.systemTemp.createTemp('fake_provider');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: profile,
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

XtreamClient _client(FakeProviderServer server, {String password = 'test'}) =>
    XtreamClient(
      server: server.url.toString(),
      username: 'test',
      password: password,
    );

void main() {
  // The Flutter test binding fakes HttpClient with 400s; this needs sockets.
  setUpAll(() => HttpOverrides.global = null);

  test(
    'the default profile: every action, counts as the profile says',
    () async {
      final server = await _start(fakeProfiles['default']!);
      final client = _client(server);

      final account = (await client.account()).valueOrNull!;
      expect(account.status, 'Active');
      expect(account.expiresAt, isNotNull);

      final liveCategories = (await client.liveCategories()).valueOrNull!;
      final channels = (await client.liveStreams()).valueOrNull!;
      final movies = (await client.movies()).valueOrNull!;
      final series = (await client.series()).valueOrNull!;
      expect(liveCategories.items, hasLength(12));
      expect(channels.items, hasLength(240));
      expect(movies.items, hasLength(120));
      expect(series.items, hasLength(24));
      expect(channels.skipped + movies.skipped + series.skipped, 0);

      final firstCategory = liveCategories.items.first.id;
      final filtered = (await client.liveStreams(categoryId: firstCategory))
          .valueOrNull!;
      expect(filtered.items, isNotEmpty);
      expect(
        filtered.items.every((c) => c.categoryId == firstCategory),
        isTrue,
      );

      final info = (await client.movieInfo(movies.items.first.streamId))
          .valueOrNull!;
      expect(info.plot, isNotNull);
      expect(info.ext, isNotNull);

      final episodes = (await client.seriesInfo(series.items.first.seriesId))
          .valueOrNull!;
      expect(episodes.episodes, isNotEmpty);

      final withEpg = channels.items.firstWhere((c) => c.epgChannelId != null);
      final epg = (await client.shortEpg(withEpg.streamId)).valueOrNull!;
      expect(epg.items, isNotEmpty);
      expect(epg.items.first.end.isAfter(epg.items.first.start), isTrue);
    },
  );

  test('wrong credentials are an auth failure, as auth 0 or as an empty '
      '404', () async {
    for (final profile in ['default', 'quirky']) {
      final server = await _start(fakeProfiles[profile]!);

      final result = await _client(server, password: 'wrong').account();

      expect(result.failureOrNull, isA<AuthFailure>(), reason: profile);
    }
  });

  test('the quirky profile: every quirk at once, nothing lost, nothing '
      'thrown', () async {
    final profile = fakeProfiles['quirky']!;
    final server = await _start(profile);
    final client = _client(server);

    final account = (await client.account()).valueOrNull!;
    // exp_date "" means no expiry.
    expect(account.expiresAt, isNull);
    expect(account.maxConnections, isNotNull);

    final categories = (await client.liveCategories()).valueOrNull!;
    final channels = (await client.liveStreams()).valueOrNull!;
    final movies = (await client.movies()).valueOrNull!;
    final series = (await client.series()).valueOrNull!;

    // Numbers as strings, "" for null, invalid UTF-8: no row is lost.
    expect(channels.items, hasLength(profile.liveCount));
    expect(movies.items, hasLength(profile.movieCount));
    expect(series.items, hasLength(profile.seriesCount));
    expect(channels.skipped, 0);

    final names = [
      ...channels.items.map((c) => c.name),
      ...movies.items.map((m) => m.name),
    ];
    for (final name in names) {
      expect(name, isNot(contains('\ufffd')), reason: 'invalid UTF-8');
      expect(name, isNot(contains('&amp;')), reason: 'HTML entities');
      expect(name, isNot(matches(r'^\s|\s$|\s\s')), reason: 'whitespace');
    }

    // Every 11th icon is junk and comes back as no icon, never as junk.
    for (final channel in channels.items) {
      final icon = channel.iconUrl;
      if (icon != null) expect(Uri.parse(icon).host, isNotEmpty);
    }
    expect(channels.items.where((c) => c.iconUrl == null), isNotEmpty);

    // Dangling and missing category ids reach the sync as they are.
    final known = categories.items.map((c) => c.id).toSet();
    expect(channels.items.where((c) => c.categoryId == null), isNotEmpty);
    expect(
      channels.items.where(
        (c) => c.categoryId != null && !known.contains(c.categoryId),
      ),
      isNotEmpty,
    );

    // info: [] and episodes keyed by season.
    final info = await client.movieInfo(movies.items.first.streamId);
    expect(info.isOk, isTrue);
    final episodes = (await client.seriesInfo(series.items.first.seriesId))
        .valueOrNull!;
    expect(episodes.episodes, isNotEmpty);
    expect(episodes.skipped, 0);
  });
}
