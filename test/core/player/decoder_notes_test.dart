import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/diagnostics/data/db_decoder_notes.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 13, 9);

  group('what the player says of a codec, as people say it', () {
    test('mpv’s long names', () {
      expect(shortCodec('H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10'), 'H.264');
      expect(shortCodec('HEVC (High Efficiency Video Coding)'), 'HEVC');
      expect(shortCodec('MPEG-2 video'), 'MPEG-2');
      expect(shortCodec('AV1'), 'AV1');
      expect(shortCodec(''), isNull);
      expect(shortCodec(null), isNull);
    });
  });

  group('a note', () {
    test('says what was decoded and by what', () {
      final hardware = DecoderNote.of(
        const StreamInfo(
          width: 1920,
          height: 1080,
          videoCodec: 'H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10',
          hardwareDecoder: 'vaapi',
        ),
        t0,
      )!;
      final software = DecoderNote.of(
        const StreamInfo(
          height: 576,
          videoCodec: 'MPEG-2 video',
          interlaced: true,
        ),
        t0,
      )!;

      expect(hardware.line, 'H.264 1080p → vaapi');
      expect(software.line, 'MPEG-2 576i → software');
      expect(hardware.kind, isNot(software.kind));
    });

    test('is not made before the player knows the codec and the size', () {
      expect(DecoderNote.of(const StreamInfo(), t0), isNull);
      expect(DecoderNote.of(const StreamInfo(videoCodec: 'HEVC'), t0), isNull);
      expect(DecoderNote.of(const StreamInfo(height: 1080), t0), isNull);
      expect(
        DecoderNote.of(const StreamInfo(height: 0, videoCodec: 'HEVC'), t0),
        isNull,
      );
    });

    test('survives JSON, and anything that isn’t a note reads as none', () {
      final note = DecoderNote(
        codec: 'HEVC',
        height: 2160,
        decoder: 'nvdec',
        at: t0,
      );

      final read = DecoderNote.fromJson(jsonDecode(jsonEncode(note.toJson())))!;

      expect(read.line, 'HEVC 2160p → nvdec');
      expect(read.at, t0);
      for (final junk in [
        null,
        'x',
        7,
        const <String, Object?>{},
        const {'codec': 'HEVC'},
        const {'codec': '', 'height': 1},
      ]) {
        expect(DecoderNote.fromJson(junk), isNull, reason: '$junk');
      }
      // A damaged time or decoder doesn't lose the note.
      expect(
        DecoderNote.fromJson(const {
          'codec': 'HEVC',
          'height': 1080,
          'decoder': 5,
          'at': 'yesterday',
        })!.line,
        'HEVC 1080p → software',
      );
    });
  });

  group('the notes kept in the settings table', () {
    late AppDatabase db;
    late SettingsRepository settings;
    late DateTime now;

    setUp(() {
      db = AppDatabase.memory();
      settings = SettingsRepository(db);
      now = t0;
    });
    tearDown(() => db.close());

    DbDecoderNotes notes({int limit = 20}) =>
        DbDecoderNotes(settings, clock: () => now, limit: limit);

    StreamInfo info(String codec, int height, [String? decoder]) =>
        StreamInfo(height: height, videoCodec: codec, hardwareDecoder: decoder);

    test('the newest first, one per kind of video', () async {
      final kept = notes();
      await kept.note(info('H.264', 1080, 'vaapi'));
      now = now.add(const Duration(minutes: 1));
      await kept.note(info('HEVC', 2160, 'vaapi'));
      now = now.add(const Duration(minutes: 1));
      // The same kind again, decoded another way: it replaces the first.
      await kept.note(info('H.264', 1080));

      expect(
        [for (final note in await kept.recent()) note.line],
        ['H.264 1080p → software', 'HEVC 2160p → vaapi'],
      );
    });

    test('a restart keeps them', () async {
      await notes().note(info('H.264', 1080, 'nvdec'));

      final again = await notes().recent();

      expect(again.single.line, 'H.264 1080p → nvdec');
      expect(again.single.at, t0);
    });

    test(
      'zapping through channels of one kind is one write, not fifty',
      () async {
        final kept = notes();
        await kept.note(info('H.264', 1080, 'vaapi'));
        final written = await db.settingsDao.read(SettingsKeys.decoders);
        now = now.add(const Duration(hours: 1));

        for (var i = 0; i < 50; i++) {
          await kept.note(info('H.264', 1080, 'vaapi'));
        }

        expect(await db.settingsDao.read(SettingsKeys.decoders), written);
      },
    );

    test('twenty at most, the oldest dropped', () async {
      final kept = notes(limit: 3);
      for (final height in [480, 576, 720, 1080]) {
        await kept.note(info('H.264', height));
        now = now.add(const Duration(minutes: 1));
      }

      expect(
        [for (final note in await kept.recent()) note.height],
        [1080, 720, 576],
      );
    });

    test('nothing is noted for a stream the player knows nothing of, and a '
        'damaged list reads as none', () async {
      await settings.writeJsonText(SettingsKeys.decoders, '{"not": "a list"}');
      final kept = notes();

      await kept.note(const StreamInfo());

      expect(await kept.recent(), isEmpty);
      await settings.writeJsonText(
        SettingsKeys.decoders,
        '[1, "x", {"codec": "AV1", "height": 2160}]',
      );
      expect(
        [for (final n in await notes().recent()) n.line],
        ['AV1 2160p → software'],
      );
    });
  });
}
