import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

void main() {
  test("each preset sets docs/03's buffer options", () {
    final expected = {
      BufferPreset.lowLatency: ('2', '32MiB', '2', '500000', '0.5'),
      BufferPreset.balanced: ('8', '64MiB', '8', '1000000', '1'),
      BufferPreset.stable: ('20', '128MiB', '20', '2000000', '2'),
    };
    for (final MapEntry(key: preset, value: values) in expected.entries) {
      final options = mpvOptionsFor(PlayRequest(url: 'u', preset: preset));

      expect(options['cache-secs'], values.$1, reason: preset.name);
      expect(options['demuxer-max-bytes'], values.$2, reason: preset.name);
      expect(options['demuxer-readahead-secs'], values.$3, reason: preset.name);
      expect(options['demuxer-lavf-probesize'], values.$4, reason: preset.name);
      expect(
        options['demuxer-lavf-analyzeduration'],
        values.$5,
        reason: preset.name,
      );
    }
  });

  test('live keeps little behind the live edge; VOD keeps more', () {
    expect(
      mpvOptionsFor(const PlayRequest(url: 'u'))['demuxer-max-back-bytes'],
      '16MiB',
    );
    expect(
      mpvOptionsFor(
        const PlayRequest(url: 'u', live: false),
      )['demuxer-max-back-bytes'],
      '64MiB',
    );
  });

  test('the source User-Agent, languages and deinterlace ride along', () {
    final options = mpvOptionsFor(
      const PlayRequest(
        url: 'u',
        userAgent: 'MyBox/1.0',
        audioLanguages: ['ar', 'en'],
        subtitleLanguages: ['en'],
        deinterlace: true,
      ),
    );

    expect(options['user-agent'], 'MyBox/1.0');
    expect(options['alang'], 'ar,en');
    expect(options['slang'], 'en');
    expect(options['deinterlace'], 'yes');
  });

  test('Auto deinterlace sets nothing up front (the engine follows the '
      'stream)', () {
    expect(
      mpvOptionsFor(const PlayRequest(url: 'u')).containsKey('deinterlace'),
      isFalse,
    );
  });

  test('a request prints without its URL', () {
    const request = PlayRequest(url: 'http://h/live/user/secret/1.ts');

    expect('$request', isNot(contains('secret')));
  });
}
