import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import '../../playback/support/playback_fakes.dart';

final class _Guide implements GuideService {
  NowNext answer = NowNext.none;
  bool fail = false;

  @override
  NowNext? cached(ChannelItem channel) => null;

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    if (fail) throw StateError('the guide broke');
    return Ok(answer);
  }

  @override
  Future<void> warm(List<ChannelItem> channels) async {}

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  late FakeResolver resolver;
  late _Guide guide;
  late CastItems items;

  setUp(() {
    resolver = FakeResolver()..maxConnections = 2;
    guide = _Guide();
    items = CastItems(resolver: resolver, guide: guide);
  });

  test(
    "a channel: its key, the source's facts, a fresh URL each time",
    () async {
      resolver.hls = true;
      final item = PlayableChannel(channel(4));
      final resolved = (await items.resolve(item)).valueOrNull!;
      expect(
        resolved.key,
        const CastStreamKey(
          sourceId: 'src',
          kind: CastStreamKind.live,
          id: 'k4',
        ),
      );
      expect(resolved.info.live, isTrue);
      expect(resolved.info.hls, isTrue);
      expect(resolved.info.customUserAgent, isFalse);
      expect(resolved.stream.maxConnections, 2);
      expect(resolver.resolved, hasLength(1));
      final upstream = (await resolved.upstream.resolve()).valueOrNull!;
      expect(upstream.url, 'http://fake/live/u/p/k4.m3u8');
      expect(upstream.hls, isTrue);
      expect(upstream.maxConnections, 2);
      await resolved.upstream.resolve();
      expect(resolver.resolved, hasLength(3), reason: 'built every time');
    },
  );

  test(
    "a movie and an episode: files, with the provider's extension",
    () async {
      final film = (await items.resolve(PlayableMovie(movie(3)))).valueOrNull!;
      expect(film.info.live, isFalse);
      expect(film.info.fileExtension, 'mkv');
      expect(film.key.kind, CastStreamKind.movie);
      final show = (await items.resolve(PlayableEpisode(series, episode(1, 2))))
          .valueOrNull!;
      expect(show.info.fileExtension, 'mp4');
      expect(show.key.kind, CastStreamKind.episode);
      expect(show.key.id, 'e12');
    },
  );

  test('a source with its own User-Agent says so', () async {
    resolver.customUserAgent = true;
    final resolved = (await items.resolve(PlayableChannel(channel(1))))
        .valueOrNull!;
    expect(resolved.info.customUserAgent, isTrue);
  });

  test('a stream that cannot be built: the failure', () async {
    resolver.failure = AuthFailure('locked');
    final result = await items.resolve(PlayableChannel(channel(1)));
    expect(result.failureOrNull, isA<AuthFailure>());
  });

  group('metadata', () {
    test('a channel: its number and name, the programme, the logo', () async {
      guide.answer = NowNext(
        now: Programme(
          title: 'Continental Cup · Semi-final',
          start: DateTime(2026, 10, 3, 20),
          end: DateTime(2026, 10, 3, 22),
        ),
      );
      const item = PlayableChannel(
        ChannelItem(
          id: 1,
          sourceId: 'src',
          remoteKey: 'k1',
          name: 'Arena Sports 1',
          number: 201,
          logoUrl: 'http://panel/logo.png',
        ),
      );
      final metadata = await items.metadataFor(item);
      expect(metadata.title, '201 · Arena Sports 1');
      expect(metadata.subtitle, 'Continental Cup · Semi-final');
      expect(metadata.imageUrl, 'http://panel/logo.png');
    });

    test('no number, no guide: the name alone', () async {
      guide.fail = true;
      const item = PlayableChannel(
        ChannelItem(id: 1, sourceId: 'src', remoteKey: 'k1', name: 'News'),
      );
      final metadata = await items.metadataFor(item);
      expect(metadata.title, 'News');
      expect(metadata.subtitle, isNull);
    });

    test('a movie: its year and poster', () async {
      final metadata = await items.metadataFor(
        PlayableMovie(
          movie(1).copyWith(year: 2024, posterUrl: 'http://panel/p.jpg'),
        ),
      );
      expect(metadata.title, 'Movie 1');
      expect(metadata.subtitle, '2024');
      expect(metadata.imageUrl, 'http://panel/p.jpg');
    });

    test(
      'an episode: its series and number, its still or the poster',
      () async {
        final show = series.copyWith(posterUrl: 'http://panel/s.jpg');
        final metadata = await items.metadataFor(
          PlayableEpisode(show, episode(2, 5)),
        );
        expect(metadata.title, 'Episode 5');
        expect(metadata.subtitle, 'Glass Tide · S2 E5');
        expect(metadata.imageUrl, 'http://panel/s.jpg');
        final still = await items.metadataFor(
          PlayableEpisode(
            show,
            episode(2, 5).copyWith(stillUrl: 'http://panel/e.jpg'),
          ),
        );
        expect(still.imageUrl, 'http://panel/e.jpg');
      },
    );
  });

  test('keyOf matches what resolve keys by', () async {
    final item = PlayableMovie(movie(9));
    final resolved = (await items.resolve(item)).valueOrNull!;
    expect(keyOf(item), resolved.key);
    expect(movie(9), isA<MovieItem>());
  });
}
