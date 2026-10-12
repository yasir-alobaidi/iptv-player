import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/ffmpeg_cast_subtitles.dart';
import 'package:iptv_player/data/cast/webvtt.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'relay/relay_rig.dart' show relayBinaries;

/// docs/04 "Subtitles": a file's text subtitles made into WebVTT for the
/// TV, and where a relayed stream of it really starts.
void main() {
  group('the first packet FFmpeg prints', () {
    test("its time, in its stream's own time base", () {
      expect(
        firstPacketTime(
          '#software: Lavf62.12.102\n#tb 0: 1/1000\n#media_type 0: video\n'
          '0,      -7580,      -7500,       40,    19289, 0xe2d395fc\n',
        ),
        const Duration(milliseconds: -7580),
      );
      expect(
        firstPacketTime(
          '#tb 0: 1/48000\n0,    -364608,    -364608,     1024,  93, 0xf9c\n',
        ),
        const Duration(milliseconds: -7596),
      );
      expect(
        firstPacketTime('#tb 0: 1001/30000\n0, 30, 30, 1, 5, 0x1\n'),
        const Duration(milliseconds: 1001),
      );
    });

    test('nothing printed, no time base, a packet with no time: null', () {
      expect(firstPacketTime(''), isNull);
      expect(firstPacketTime('#tb 0: 1/1000\n'), isNull);
      expect(firstPacketTime('0, -7580, -7500, 40, 19289, 0xe2\n'), isNull);
      expect(firstPacketTime('#tb 0: 1/0\n0, 5, 5, 1, 1, 0x1\n'), isNull);
      expect(
        firstPacketTime(
          '#tb 0: 1/1000\n0, -9223372036854775808, 0, 1, 1, 0x1\n',
        ),
        isNull,
      );
    });
  });

  group("an older subtitle file's code page", () {
    final latin = latin1.encode('Café olé');

    test('Unicode is read as it is', () {
      expect(subtitleCodePage(utf8.encode('Café مرحبا')), isNull);
      expect(subtitleCodePage(const [0xEF, 0xBB, 0xBF, 0x31]), isNull);
      expect(subtitleCodePage(const [0xFF, 0xFE, 0x31, 0x00]), isNull);
      expect(subtitleCodePage(const [0xFE, 0xFF, 0x00, 0x31]), isNull);
      expect(subtitleCodePage(const []), isNull);
    });

    test("by the file's own language, two letters or three", () {
      expect(subtitleCodePage(latin, language: 'ar'), 'CP1256');
      expect(subtitleCodePage(latin, language: 'ara'), 'CP1256');
      expect(subtitleCodePage(latin, language: 'rus'), 'CP1251');
      expect(subtitleCodePage(latin, language: 'el'), 'CP1253');
      expect(subtitleCodePage(latin, language: 'tr'), 'CP1254');
      expect(subtitleCodePage(latin, language: 'pol'), 'CP1250');
      expect(subtitleCodePage(latin, language: 'en'), 'CP1252');
      expect(subtitleCodePage(latin, language: 'xx'), 'CP1252');
    });

    test('a file that names none: the most wanted subtitle language, else '
        'Western', () {
      expect(subtitleCodePage(latin, hints: ['ar', 'en']), 'CP1256');
      expect(subtitleCodePage(latin, hints: ['en', 'ar']), 'CP1252');
      expect(subtitleCodePage(latin), 'CP1252');
      // Its own name wins over what is wanted.
      expect(subtitleCodePage(latin, language: 'fr', hints: ['ar']), 'CP1252');
    });
  });

  final binaries = relayBinaries();
  if (binaries == null || Platform.isWindows) {
    test('subtitles as WebVTT', () {}, skip: 'needs FFmpeg (Linux)');
    return;
  }

  group('with the real FFmpeg', () {
    late Directory temp;
    late Directory folder;
    late ProcessSupervisor supervisor;
    late MemoryOutput logged;
    late FfmpegCastSubtitles subtitles;

    FfmpegCastSubtitles maker({List<String> languages = const []}) =>
        FfmpegCastSubtitles(
          supervisor: supervisor,
          binaries: binaries,
          folder: folder,
          log: AppLog(output: logged, secrets: SecretRegistry()),
          languages: () => languages,
        );

    setUp(() {
      temp = Directory.systemTemp.createTempSync('cast_subtitles_');
      folder = Directory(p.join(temp.path, 'relay', 'run'));
      logged = MemoryOutput();
      supervisor = ProcessSupervisor(
        folder: Directory(p.join(temp.path, 'processes')),
        log: AppLog(output: logged, secrets: SecretRegistry()),
      );
      subtitles = maker();
    });
    tearDown(() async {
      await supervisor.stopAll();
      temp.deleteSync(recursive: true);
    });

    String srt(String name, List<(int, int, String)> cues, {Encoding? as}) {
      String time(int seconds) => '00:00:${'$seconds'.padLeft(2, '0')},000';
      final text = [
        for (final (index, (from, to, words)) in cues.indexed)
          '${index + 1}\n${time(from)} --> ${time(to)}\n$words\n',
      ].join('\n');
      final file = File(p.join(temp.path, name))
        ..writeAsBytesSync((as ?? utf8).encode(text));
      return file.path;
    }

    Future<void> ffmpeg(List<String> arguments) async {
      final made = await Process.run(binaries.ffmpeg, [
        ...['-hide_banner', '-v', 'error', '-nostdin', '-y'],
        ...arguments,
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');
    }

    /// A Matroska clip of [seconds], with [tracks] as its own SubRip
    /// tracks (each a language and maybe a title), a key frame every
    /// [keyEvery] frames at 25 a second.
    Future<String> video(
      String name, {
      int seconds = 6,
      int keyEvery = 25,
      String audio = 'ac3',
      List<(String, String?)> tracks = const [],
    }) async {
      final path = p.join(temp.path, name);
      final sources = [
        for (final (index, (language, _)) in tracks.indexed)
          srt('own$index.srt', [
            (1, 3, 'Own $language one'),
            (4, 5, 'Own $language two'),
          ]),
      ];
      await ffmpeg([
        ...['-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=25:d=$seconds'],
        ...['-f', 'lavfi', '-i', 'sine=frequency=440:duration=$seconds'],
        for (final source in sources) ...['-i', source],
        ...['-map', '0:v', '-map', '1:a'],
        for (var i = 0; i < sources.length; i++) ...['-map', '${i + 2}:s'],
        ...['-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p'],
        ...['-g', '$keyEvery', '-keyint_min', '$keyEvery'],
        ...['-sc_threshold', '0', '-bf', '2'],
        ...['-c:a', audio, '-c:s', 'subrip'],
        for (final (index, (language, title)) in tracks.indexed) ...[
          ...['-metadata:s:s:$index', 'language=$language'],
          if (title != null) ...['-metadata:s:s:$index', 'title=$title'],
        ],
        path,
      ]);
      return path;
    }

    Iterable<String> lines() => logged.buffer.expand((e) => e.lines);

    test('the files beside the video first, then its own text tracks, '
        'each a WebVTT file', () async {
      final film = await video(
        'Film.mkv',
        tracks: [('eng', null), ('ger', 'SDH')],
      );
      final english = srt('Film.en.srt', [
        (1, 2, 'Beside one'),
        (3, 5, 'Beside <i>two</i>'),
      ]);
      final forced = srt('Film.fr.forced.srt', [(2, 3, 'Forcé')]);
      final set = subtitles.prepare(film, beside: [english, forced]);
      await set.done;
      expect(set.subtitles, const [
        CastSubtitle(language: 'en', beside: true),
        CastSubtitle(language: 'fr', forced: true, beside: true),
        CastSubtitle(language: 'eng'),
        CastSubtitle(language: 'ger', title: 'SDH'),
      ]);
      final files = await set.files();
      expect(files, hasLength(4));
      final texts = [for (final file in files) File(file).readAsStringSync()];
      expect(texts.every((text) => text.startsWith('WEBVTT')), isTrue);
      expect([for (final text in texts) webVttCues(text)], [2, 1, 2, 2]);
      expect(texts[0], contains('00:01.000 --> 00:02.000\nBeside one'));
      expect(texts[1], contains('Forcé'));
      expect(texts[2], contains('Own eng one'));
      expect(texts[3], contains('00:04.000 --> 00:05.000\nOwn ger two'));
      // In the folder it was given, which goes with the relay's.
      expect(files.every((file) => p.isWithin(folder.path, file)), isTrue);
      expect(lines().join('\n'), contains('2 beside the file, 2 of its own'));
      expect(supervisor.folder.listSync(), isEmpty, reason: 'no FFmpeg left');
    });

    test('moved back for a relayed stream: new files each time, the last '
        "call's gone", () async {
      final film = await video('Film.mkv', tracks: [('eng', null)]);
      final beside = srt('Film.srt', [(1, 2, 'Early'), (3, 5, 'Late')]);
      final set = subtitles.prepare(film, beside: [beside]);
      await set.done;
      expect(set.subtitles.first, const CastSubtitle(beside: true));

      final moved = await set.files(by: const Duration(seconds: 2));
      expect(moved, hasLength(2));
      expect(
        File(moved[0]).readAsStringSync(),
        'WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nLate\n',
      );
      expect(
        File(moved[1]).readAsStringSync(),
        'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nOwn eng one\n\n'
        '00:00:02.000 --> 00:00:03.000\nOwn eng two\n',
      );

      final again = await set.files(by: const Duration(seconds: 4));
      expect(File(moved[0]).existsSync(), isFalse);
      expect(webVttCues(File(again[0]).readAsStringSync()), 1);
      // Unmoved: the files as they were made.
      final whole = await set.files();
      expect(File(again[0]).existsSync(), isFalse);
      expect(webVttCues(File(whole[0]).readAsStringSync()), 2);
    });

    test('an older code page is read by its language: Western, Arabic '
        'by its name, and by what Settings prefers', () async {
      final film = await video('Film.mkv');
      final french = srt('Film.fr.srt', [(1, 2, 'Café olé')], as: latin1);
      // «مرحبا» in Windows-1256.
      const hello = [0xE3, 0xD1, 0xCD, 0xC8, 0xC7];
      List<int> arabic() => [
        ...ascii.encode('1\n00:00:01,000 --> 00:00:02,000\n'),
        ...hello,
        ...ascii.encode('\n'),
      ];
      final named = File(p.join(temp.path, 'Film.ar.srt'))
        ..writeAsBytesSync(arabic());
      final unnamed = File(p.join(temp.path, 'Film.srt'))
        ..writeAsBytesSync(arabic());

      final set = subtitles.prepare(film, beside: [french, named.path]);
      await set.done;
      final files = await set.files();
      expect(File(files[0]).readAsStringSync(), contains('Café olé'));
      expect(File(files[1]).readAsStringSync(), contains('مرحبا'));

      final preferred = maker(languages: ['ar'])
          .prepare(film, beside: [unnamed.path]);
      await preferred.done;
      expect(
        File((await preferred.files()).single).readAsStringSync(),
        contains('مرحبا'),
      );
    });

    test("what can't be read is left out, and the rest still come", () async {
      final film = await video('Film.mkv', tracks: [('eng', null)]);
      final good = srt('Film.en.srt', [(1, 2, 'Good')]);
      final junk = File(p.join(temp.path, 'Film.de.srt'))
        ..writeAsBytesSync(List.generate(4096, (i) => (i * 37) % 256));
      final empty = File(p.join(temp.path, 'Film.es.srt'))
        ..writeAsStringSync('');
      final missing = p.join(temp.path, 'Film.it.srt');
      final set = subtitles.prepare(
        film,
        beside: [junk.path, good, empty.path, missing],
      );
      await set.done;
      expect(set.subtitles, const [
        CastSubtitle(language: 'en', beside: true),
        CastSubtitle(language: 'eng'),
      ]);
      expect(await set.files(), hasLength(2));
    });

    test('a video with none, and one that is not there: none, never '
        'thrown', () async {
      final none = subtitles.prepare(await video('Plain.mkv'));
      await none.done;
      expect(none.subtitles, isEmpty);
      expect(await none.files(), isEmpty);

      final gone = subtitles.prepare(p.join(temp.path, 'Gone.mkv'));
      await gone.done;
      expect(gone.subtitles, isEmpty);
      expect(await gone.files(by: const Duration(seconds: 3)), isEmpty);
    });

    test('deleted: its files and folder gone, nothing more made', () async {
      final film = await video('Film.mkv', tracks: [('eng', null)]);
      final set = subtitles.prepare(film);
      await set.done;
      final files = await set.files(by: const Duration(seconds: 1));
      await set.delete();
      expect(File(files.single).existsSync(), isFalse);
      expect(folder.listSync(), isEmpty);
      expect(await set.files(), isEmpty);
      await set.delete();

      // Deleted while it is being made: stopped, and nothing left.
      final stopped = subtitles.prepare(film);
      await stopped.delete();
      expect(stopped.subtitles, isEmpty);
      expect(folder.listSync(), isEmpty);
      expect(supervisor.folder.listSync(), isEmpty);
    });

    test('where a relayed stream starts: the key frame before the place '
        'asked for when the picture is copied', () async {
      // A key frame every 10 s: 0, 10, 20, …
      final film = await video('Long.mkv', seconds: 40, keyEvery: 250);
      const at = Duration(seconds: 27, milliseconds: 500);
      // The key frame at 20 s, less the two frames it is decoded ahead.
      final copied = await subtitles.startOf(
        film,
        at: at,
        copied: (video: true, audioTrack: null),
      );
      expect(copied.inMilliseconds, closeTo(19920, 60));

      // Nothing copied: FFmpeg cuts where it was asked.
      expect(
        await subtitles.startOf(
          film,
          at: at,
          copied: (video: false, audioTrack: null),
        ),
        at,
      );
      // From the beginning there is nothing to ask.
      expect(
        await subtitles.startOf(
          film,
          at: Duration.zero,
          copied: (video: true, audioTrack: 0),
        ),
        Duration.zero,
      );
      // Past the end: the last key frame.
      final past = await subtitles.startOf(
        film,
        at: const Duration(minutes: 5),
        copied: (video: true, audioTrack: null),
      );
      expect(past.inMilliseconds, closeTo(29920, 60));
    });

    test('where it starts with only the sound copied: where the sound '
        "begins, at the picture's key frame", () async {
      final film = await video(
        'Long.mkv',
        seconds: 40,
        keyEvery: 250,
        audio: 'aac',
      );
      final start = await subtitles.startOf(
        film,
        at: const Duration(seconds: 27, milliseconds: 500),
        copied: (video: false, audioTrack: 0),
      );
      expect(start.inMilliseconds, closeTo(19920, 120));
      // A sound track that isn't there: the place asked for.
      expect(
        await subtitles.startOf(
          film,
          at: const Duration(seconds: 27),
          copied: (video: false, audioTrack: 4),
        ),
        const Duration(seconds: 27),
      );
    });

    test("a file FFmpeg can't open: the place asked for", () async {
      const at = Duration(seconds: 12);
      expect(
        await subtitles.startOf(
          p.join(temp.path, 'Gone.mkv'),
          at: at,
          copied: (video: true, audioTrack: null),
        ),
        at,
      );
    });
  });
}
