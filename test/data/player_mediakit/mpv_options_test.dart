import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:path/path.dart' as p;

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

  test('a TV (low memory) reads at most 32 MiB ahead and keeps 16 MiB '
      "behind, a film too; the seconds asked for stay the preset's", () {
    for (final preset in BufferPreset.values) {
      for (final live in [true, false]) {
        final options = mpvOptionsFor(
          PlayRequest(url: 'u', preset: preset, live: live),
          lowMemory: true,
        );
        final reason = '${preset.name}, live: $live';
        expect(options['demuxer-max-bytes'], '32MiB', reason: reason);
        expect(options['demuxer-max-back-bytes'], '16MiB', reason: reason);
        expect(
          options['cache-secs'],
          mpvOptionsFor(PlayRequest(url: 'u', preset: preset))['cache-secs'],
          reason: reason,
        );
      }
    }
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

  test("a library file's subtitle files become its tracks; a path holding "
      "the list's separator is left out, and with none the option is left "
      'out (open clears the list: a newer mpv reads "" as one file)', () {
    final separator = Platform.isWindows ? ';' : ':';
    final english = p.join('films', 'Paper Kites (2019).en.srt');
    final forced = p.join('films', 'Paper Kites (2019).en.forced.srt');
    final options = mpvOptionsFor(
      PlayRequest(
        url: p.join('films', 'Paper Kites (2019).mkv'),
        live: false,
        subtitleFiles: [english, 'odd${separator}name.srt', forced],
      ),
    );
    expect(options['sub-files'], '$english$separator$forced');
    expect(
      mpvOptionsFor(const PlayRequest(url: 'u')),
      isNot(contains('sub-files')),
    );
  });

  group('hardware decoding (Settings → Playback)', () {
    test('Automatic asks mpv for its safe decoders', () {
      expect(mpvOptionsFor(const PlayRequest(url: 'u'))['hwdec'], 'auto-safe');
    });

    test('Off says no, so the next file decodes on the processor', () {
      expect(
        mpvOptionsFor(
          const PlayRequest(url: 'u', hardwareDecoding: false),
        )['hwdec'],
        'no',
      );
    });

    test('with no picture Automatic leaves hwdec alone, and Off still '
        'says no', () {
      expect(
        mpvOptionsFor(
          const PlayRequest(url: 'u'),
          picture: false,
        ).containsKey('hwdec'),
        isFalse,
      );
      expect(
        mpvOptionsFor(
          const PlayRequest(url: 'u', hardwareDecoding: false),
          picture: false,
        )['hwdec'],
        'no',
      );
    });

    test("Android's direct output always asks for MediaCodec itself, the "
        'only decoder it shows; Off waits for the next launch', () {
      for (final hardware in [true, false]) {
        expect(
          mpvOptionsFor(
            PlayRequest(url: 'u', hardwareDecoding: hardware),
            direct: true,
          )['hwdec'],
          'mediacodec',
        );
      }
    });

    test("Android's direct output drops its window when nothing plays (it "
        'spun a core of a TV after every film); other outputs keep theirs', () {
      expect(
        mpvOptionsFor(
          const PlayRequest(url: 'u'),
          direct: true,
        )['force-window'],
        'no',
      );
      expect(
        mpvOptionsFor(const PlayRequest(url: 'u')).containsKey('force-window'),
        isFalse,
      );
    });

    test("Android's direct output skips mpv's scaler, so Fill and Stretch "
        "are the picture widget's fit (a 4:3 channel kept its bars on the "
        "Bedroom TV); the ratios stay mpv's", () {
      expect(directOutputFit(AspectMode.fit), BoxFit.contain);
      expect(directOutputFit(AspectMode.fill), BoxFit.cover);
      expect(directOutputFit(AspectMode.stretch), BoxFit.fill);
      expect(directOutputFit(AspectMode.ratio16x9), BoxFit.contain);
      expect(directOutputFit(AspectMode.ratio4x3), BoxFit.contain);
    });
  });

  group("picture quality (Settings → Playback, the desktop's)", () {
    /// What the running mpv had at the start (0.34.1's own).
    const standard = {
      'scale': 'bilinear',
      'cscale': 'bilinear',
      'dscale': 'bilinear',
      'dither-depth': 'no',
      'correct-downscaling': 'no',
      'linear-downscaling': 'no',
      'sigmoid-upscaling': 'no',
      'deband': 'no',
    };
    const high = PlayRequest(url: 'u', pictureQuality: PictureQuality.high);

    /// The picture's filters among [options].
    Map<String, String> filters(Map<String, String> options) => {
      for (final MapEntry(:key, :value) in options.entries)
        if (highQualityPicture.containsKey(key)) key: value,
    };

    test("High sets mpv 0.34's gpu-hq filters one by one, and only when "
        'the filters are set for Standard', () {
      expect(
        filters(
          mpvOptionsFor(
            high,
            scaling: (now: PictureQuality.standard, standard: standard),
          ),
        ),
        {
          'scale': 'spline36',
          'cscale': 'spline36',
          'dscale': 'mitchell',
          'dither-depth': 'auto',
          'correct-downscaling': 'yes',
          'linear-downscaling': 'yes',
          'sigmoid-upscaling': 'yes',
          'deband': 'yes',
        },
      );
      expect(
        filters(
          mpvOptionsFor(
            high,
            scaling: (now: PictureQuality.high, standard: standard),
          ),
        ),
        isEmpty,
      );
    });

    test("Standard puts back the running mpv's own value of each, and only "
        'after High', () {
      const request = PlayRequest(url: 'u');
      expect(
        filters(
          mpvOptionsFor(
            request,
            scaling: (now: PictureQuality.high, standard: standard),
          ),
        ),
        standard,
      );
      expect(
        filters(
          mpvOptionsFor(
            request,
            scaling: (now: PictureQuality.standard, standard: standard),
          ),
        ),
        isEmpty,
      );
    });

    test('an option the running mpv had no value for at the start is left '
        "alone: High couldn't be undone", () {
      final known = {...standard}..remove('deband');
      final options = filters(
        mpvOptionsFor(
          high,
          scaling: (now: PictureQuality.standard, standard: known),
        ),
      );
      expect(options.keys, unorderedEquals(known.keys));
      expect(options['scale'], 'spline36');
    });

    test("nothing where mpv doesn't scale the picture: Android and no "
        "video output (no scaling), no picture, Android's direct output", () {
      const scaling = (now: PictureQuality.standard, standard: standard);
      expect(filters(mpvOptionsFor(high)), isEmpty);
      expect(
        filters(mpvOptionsFor(high, picture: false, scaling: scaling)),
        isEmpty,
      );
      expect(
        filters(mpvOptionsFor(high, direct: true, scaling: scaling)),
        isEmpty,
      );
    });

    test('a request says it is High, without its URL', () {
      const request = PlayRequest(
        url: 'http://h/live/user/secret/1.ts',
        pictureQuality: PictureQuality.high,
      );
      expect('$request', contains('high quality'));
      expect('$request', isNot(contains('secret')));
      expect('${const PlayRequest(url: 'u')}', isNot(contains('quality')));
    });
  });
}
