import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/player/player_engine.dart';

void main() {
  group("the laptop's player's facts (decision 4's first source)", () {
    test("mpv's names read as ffprobe's", () {
      // What mpv 0.34.1 reports for the 1080i sample (checked by hand).
      const info = StreamInfo(
        width: 1920,
        height: 1080,
        fps: 25,
        videoCodec: 'h264 (H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10)',
        audioCodec: 'mp2',
        audioChannels: 2,
        videoBitrate: 8000000,
        interlaced: true,
      );
      final facts = streamFactsFromPlayer(info)!;
      expect(facts.origin, StreamFactsOrigin.player);
      expect(facts.container, isNull);
      expect(
        facts.video,
        const VideoFacts(
          codec: 'h264',
          width: 1920,
          height: 1080,
          fps: 25,
          interlaced: true,
          bitRate: 8000000,
        ),
      );
      expect(facts.audio, const [
        AudioFacts(index: 0, codec: 'mp2', channels: 2),
      ]);
    });

    test("the player's track list, when it has one, gives every track", () {
      const tracks = PlayerTracks(
        audio: [
          MediaTrack(
            id: '1',
            codec: 'ac3',
            channels: '5.1(side)',
            language: 'eng',
          ),
          MediaTrack(
            id: '2',
            codec: 'aac',
            channels: 'stereo',
            language: 'GER',
            title: 'Deutsch',
          ),
          MediaTrack(id: '3', language: 'und'),
        ],
        subtitles: [],
        audioId: '2',
      );
      const info = StreamInfo(
        videoCodec: 'hevc (HEVC (High Efficiency Video Coding))',
        audioCodec: 'aac',
      );
      final facts = streamFactsFromPlayer(info, tracks: tracks)!;
      expect(facts.video?.codec, 'hevc');
      expect(facts.audio, const [
        AudioFacts(index: 0, codec: 'ac3', channels: 6, language: 'eng'),
        AudioFacts(
          index: 1,
          codec: 'aac',
          channels: 2,
          language: 'ger',
          title: 'Deutsch',
        ),
        AudioFacts(index: 2),
      ]);
      expect(playerAudioIndex(tracks), 1);
    });

    test('a radio channel: sound, no picture', () {
      final facts = streamFactsFromPlayer(
        const StreamInfo(audioCodec: 'aac', audioChannels: 2),
      )!;
      expect(facts.video, isNull);
      expect(facts.audio.single.codec, 'aac');
    });

    test('nothing read yet is too little to plan with', () {
      expect(streamFactsFromPlayer(const StreamInfo()), isNull);
      expect(
        streamFactsFromPlayer(
          const StreamInfo(width: 1920, height: 1080, videoCodec: '  '),
        ),
        isNull,
      );
      expect(
        streamFactsFromPlayer(
          const StreamInfo(),
          tracks: const PlayerTracks(
            audio: [MediaTrack(id: '1')],
            subtitles: [],
          ),
        ),
        isNull,
      );
    });

    test('which track is on', () {
      const audio = [MediaTrack(id: '1'), MediaTrack(id: '2')];
      expect(
        playerAudioIndex(const PlayerTracks(audio: audio, subtitles: [])),
        isNull,
      );
      expect(
        playerAudioIndex(
          const PlayerTracks(audio: audio, subtitles: [], audioId: '7'),
        ),
        isNull,
      );
      expect(
        playerAudioIndex(
          const PlayerTracks(audio: audio, subtitles: [], audioId: '1'),
        ),
        0,
      );
    });
  });

  test('channels from layouts as mpv and ffprobe write them', () {
    const counts = {
      'mono': 1,
      'stereo': 2,
      'downmix': 2,
      '2.1': 3,
      'quad': 4,
      '5.0': 5,
      '5.1': 6,
      '5.1(side)': 6,
      ' 7.1 ': 8,
      '6 channels': 6,
      '8ch': 8,
      '3': 3,
    };
    for (final MapEntry(key: layout, value: n) in counts.entries) {
      expect(channelCount(layout), n, reason: layout);
    }
    for (final odd in [null, '', 'unknown', 'hexadecagonal?', '5.x']) {
      expect(channelCount(odd), isNull, reason: odd);
    }
  });
}
