import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/playback/presentation/track_text.dart';

void main() {
  group('namesLanguages: a language is named only when the tags tell the '
      'tracks apart (ADR-065)', () {
    test('one tagged track proves nothing: the encoder\'s "eng"', () {
      expect(
        namesLanguages(const [MediaTrack(id: '1', language: 'eng')]),
        isFalse,
      );
    });

    test('two tracks with the same tag, or "en" and "eng", prove nothing', () {
      expect(
        namesLanguages(const [
          MediaTrack(id: '1', language: 'eng'),
          MediaTrack(id: '2', language: 'eng'),
        ]),
        isFalse,
      );
      expect(
        namesLanguages(const [
          MediaTrack(id: '1', language: 'en'),
          MediaTrack(id: '2', language: 'eng'),
        ]),
        isFalse,
      );
    });

    test('"und" and empty tags are no language', () {
      expect(
        namesLanguages(const [
          MediaTrack(id: '1', language: 'tur'),
          MediaTrack(id: '2', language: 'und'),
          MediaTrack(id: '3', language: ''),
        ]),
        isFalse,
      );
    });

    test("two different languages are someone's tagging", () {
      expect(
        namesLanguages(const [
          MediaTrack(id: '1', language: 'tur'),
          MediaTrack(id: '2', language: 'ara'),
        ]),
        isTrue,
      );
      expect(
        namesLanguages(const [
          MediaTrack(id: '1', language: 'eng'),
          MediaTrack(id: '2', language: 'eng', title: 'Commentary'),
          MediaTrack(id: '3', language: 'ger'),
        ]),
        isTrue,
      );
    });
  });

  group('the Audio control', () {
    test('a Turkish episode\'s one track tagged "eng" is what is heard, not '
        'English', () {
      const tracks = PlayerTracks(
        audio: [
          MediaTrack(
            id: '1',
            language: 'eng',
            codec: 'aac',
            channels: 'stereo',
          ),
        ],
        subtitles: [],
        audioId: '1',
      );
      expect(audioLabel(tracks), 'Audio: Stereo');
    });

    test('names the language when the tracks carry two', () {
      const tracks = PlayerTracks(
        audio: [
          MediaTrack(id: '1', language: 'tur', channels: 'stereo'),
          MediaTrack(id: '2', language: 'ara', channels: '5.1(side)'),
        ],
        subtitles: [],
        audioId: '2',
      );
      expect(audioLabel(tracks), 'Audio: Arabic');
    });

    test('a track the tags don\'t name, with no channels known: "Audio"', () {
      expect(audioLabel(null), 'Audio');
      expect(
        audioLabel(
          const PlayerTracks(
            audio: [MediaTrack(id: '1', language: 'eng')],
            subtitles: [],
            audioId: '1',
          ),
        ),
        'Audio',
      );
    });
  });

  group('the Subtitles control', () {
    test('off, a lone track by its title or "On", a named language', () {
      expect(
        subtitlesLabel(
          const PlayerTracks(
            audio: [],
            subtitles: [MediaTrack(id: '1', language: 'eng')],
          ),
        ),
        'Subtitles: Off',
      );
      expect(
        subtitlesLabel(
          const PlayerTracks(
            audio: [],
            subtitles: [MediaTrack(id: '1', language: 'eng')],
            subtitleId: '1',
          ),
        ),
        'Subtitles: On',
      );
      expect(
        subtitlesLabel(
          const PlayerTracks(
            audio: [],
            subtitles: [MediaTrack(id: '1', language: 'eng', title: 'SDH')],
            subtitleId: '1',
          ),
        ),
        'Subtitles: SDH',
      );
      expect(
        subtitlesLabel(
          const PlayerTracks(
            audio: [],
            subtitles: [
              MediaTrack(id: '1', language: 'eng'),
              MediaTrack(id: '2', language: 'fre'),
            ],
            subtitleId: '2',
          ),
        ),
        'Subtitles: French',
      );
    });
  });

  group("a menu's line", () {
    test('untrusted tags: the title or the number, then the sound', () {
      const t = MediaTrack(
        id: '1',
        language: 'eng',
        codec: 'aac',
        channels: 'stereo',
      );
      expect(trackLine(t, 1, languages: false), 'Track 1 · Stereo · AAC');
      expect(
        trackLine(
          const MediaTrack(id: '2', title: 'Commentary', codec: 'eac3'),
          2,
          languages: false,
        ),
        'Commentary · E-AC3',
      );
    });

    test(
      'named languages: the language, a title that says more, the sound',
      () {
        expect(
          trackLine(
            const MediaTrack(
              id: '1',
              language: 'eng',
              title: 'Commentary',
              codec: 'ac3',
              channels: '5.1(side)',
            ),
            1,
            languages: true,
          ),
          'English · Commentary · 5.1 · AC3',
        );
        expect(
          trackLine(
            const MediaTrack(id: '2', language: 'tur', title: 'Turkish'),
            2,
            languages: true,
          ),
          'Turkish',
        );
        expect(
          trackLine(
            const MediaTrack(id: '3', language: 'und'),
            3,
            languages: true,
          ),
          'Track 3',
        );
      },
    );
  });

  test('channels and codecs as people say them', () {
    expect(channelsLabel('mono'), 'Mono');
    expect(channelsLabel('stereo'), 'Stereo');
    expect(channelsLabel('5.1(side)'), '5.1');
    expect(channelsLabel('7.1'), '7.1');
    expect(channelsLabel('6'), '5.1');
    expect(channelsLabel(''), isNull);
    expect(channelsLabel(null), isNull);
    expect(codecLabel('aac'), 'AAC');
    expect(codecLabel('ac3'), 'AC3');
    expect(codecLabel('pcm_s16le'), 'PCM');
    expect(codecLabel('subrip'), 'SRT');
    expect(codecLabel('hdmv_pgs_subtitle'), 'PGS');
    expect(codecLabel(null), isNull);
  });
}
