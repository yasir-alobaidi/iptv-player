import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/cast/ffmpeg_video_args.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// What the fake FFmpeg was asked to do.
final class _Call {
  const new(this.arguments, this.environment);

  final List<String> arguments;
  final Map<String, String>? environment;

  bool get isVersion => arguments.contains('-version');

  /// A test picture being made (`-y <file>`).
  String? get makes {
    final at = arguments.indexOf('-y');
    return at < 0 ? null : arguments[at + 1];
  }

  bool get isEncodeTest =>
      arguments.contains('testsrc2=size=1920x1080:rate=25');

  /// The decode test's kind, from its test picture's name.
  HardwareDecode? get decodes {
    if (makes != null || isEncodeTest || isVersion) return null;
    final at = arguments.indexOf('-i');
    if (at < 0) return null;
    final name = p.basenameWithoutExtension(arguments[at + 1]);
    return HardwareDecode.values.asNameMap()[name];
  }

  /// The encoder: the last `-c:v` (Quick Sync's decoder comes first).
  String? get encoder {
    final at = arguments.lastIndexOf('-c:v');
    return at < 0 ? null : arguments[at + 1];
  }

  /// The render node, wherever the arguments name it.
  String? get node {
    for (final argument in arguments) {
      final match = RegExp(r'/dev/dri/renderD\d+').firstMatch(argument);
      if (match != null) return match.group(0);
    }
    return null;
  }

  bool get bundledLibva =>
      environment?['LD_LIBRARY_PATH']?.startsWith('/app/libva') ?? false;
}

/// How the fake FFmpeg answers a call.
final class _Answer {
  const new({
    this.code = 0,
    this.stdout = '',
    this.stderr = '',
    this.hang = false,
  });

  /// A test that ends well and made pictures.
  const new passes() : this(stdout: 'frame=25\nprogress=end\n');

  const new fails([String why = 'Error while opening encoder'])
    : this(code: 1, stderr: '[enc] $why\n');

  final int code;
  final String stdout;
  final String stderr;

  /// Runs until it is stopped.
  final bool hang;
}

final class _FakeProcess implements Process {
  new(this.pid, _Answer answer) {
    if (!answer.hang) {
      scheduleMicrotask(() async {
        _out.add(utf8.encode(answer.stdout));
        _err.add(utf8.encode(answer.stderr));
        await _end(answer.code);
      });
    }
  }

  @override
  final int pid;
  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final _exit = Completer<int>();

  Future<void> _end(int code) async {
    if (_exit.isCompleted) return;
    await Future.wait([_out.close(), _err.close()]);
    _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _out.stream;

  @override
  Stream<List<int>> get stderr => _err.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  IOSink get stdin => throw UnsupportedError('no stdin');

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    unawaited(_end(signal == ProcessSignal.sigkill ? -9 : -15));
    return true;
  }
}

/// A computer like this laptop: NVENC decodes everything; VA-API works
/// only on renderD129 and only with the bundled libva (the system's
/// aborts); Quick Sync fails; libx264 works.
_Answer _laptop(_Call call) {
  switch (call.encoder) {
    case 'h264_nvenc':
      return const _Answer.passes();
    case 'h264_vaapi':
      if (call.node != '/dev/dri/renderD129') {
        return const _Answer.fails('Failed to initialise VAAPI connection');
      }
      return call.bundledLibva
          ? const _Answer.passes()
          : const _Answer(
              code: -6,
              stderr:
                  'implib-gen: libva.so.2: failed to resolve symbol '
                  "'vaMapBuffer2'\n",
            );
    case 'libx264':
      return const _Answer.passes();
    default:
      return const _Answer.fails();
  }
}

void main() {
  late Directory temp;
  late Directory folder;
  late MemoryOutput output;
  late List<_Call> calls;
  late _Answer Function(_Call) script;
  late ProcessSupervisor supervisor;
  late DateTime now;
  var version = 'ffmpeg version n8.1-test Copyright (c) the FFmpeg developers';
  var nextPid = 4000000;

  const withLibva = FfmpegBinaries(
    ffmpeg: '/app/ffmpeg/ffmpeg',
    ffprobe: '/app/ffmpeg/ffprobe',
    libva: '/app/libva',
  );
  const withoutLibva = FfmpegBinaries(
    ffmpeg: '/app/ffmpeg/ffmpeg',
    ffprobe: '/app/ffmpeg/ffprobe',
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('encoder_detector_test_');
    folder = Directory(p.join(temp.path, 'cast'));
    output = MemoryOutput();
    calls = [];
    script = _laptop;
    now = DateTime.utc(2026, 10, 2, 9);
    version = 'ffmpeg version n8.1-test Copyright (c) the FFmpeg developers';
    final log = AppLog(output: output, secrets: SecretRegistry());
    supervisor = ProcessSupervisor(
      folder: Directory(p.join(temp.path, 'processes')),
      log: log,
      grace: const Duration(milliseconds: 50),
      launcher: (executable, arguments, {environment}) async {
        final call = _Call(arguments, environment);
        calls.add(call);
        final _Answer answer;
        if (call.isVersion) {
          answer = _Answer(stdout: '$version\nbuilt with gcc\n');
        } else if (call.makes != null) {
          File(call.makes!).writeAsStringSync('picture');
          answer = const _Answer();
        } else {
          answer = script(call);
        }
        return _FakeProcess(nextPid++, answer);
      },
      // Nothing it is told to sweep is ever real.
      image: (_) => null,
      kill: (_) => false,
    );
  });

  tearDown(() async {
    await supervisor.stopAll();
    temp.deleteSync(recursive: true);
  });

  FfmpegEncoderDetector detector({
    FfmpegBinaries binaries = withLibva,
    bool windows = false,
    List<String> nodes = const ['/dev/dri/renderD128', '/dev/dri/renderD129'],
    Duration testTimeout = const Duration(seconds: 5),
  }) => FfmpegEncoderDetector(
    binaries: binaries,
    folder: folder,
    supervisor: supervisor,
    log: AppLog(output: output, secrets: SecretRegistry()),
    windows: windows,
    renderNodes: () => nodes,
    now: () => now,
    testTimeout: testTimeout,
  );

  List<String> logged() => [for (final event in output.buffer) ...event.lines];

  /// The tests run, as `encoder node bundled` and `decode kind`.
  List<String> tests() => [
    for (final call in calls)
      if (call.isEncodeTest)
        [
          call.encoder,
          if (call.node != null) call.node!.split('/').last,
          if (call.bundledLibva) 'bundled',
        ].join(' ')
      else if (call.decodes != null)
        '${call.encoder} decodes ${call.decodes!.name}',
  ];

  const everything = {
    HardwareDecode.h264,
    HardwareDecode.hevc,
    HardwareDecode.hevc10,
    HardwareDecode.mpeg2,
  };

  group('what it finds', () {
    test('this laptop: NVENC, VA-API on its second node, libx264', () async {
      final found = await detector().encoders();

      expect(found.available, [
        const CastEncoder(CastEncoderKind.nvenc, decodes: everything),
        const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD129',
          decodes: everything,
          bundledLibva: true,
        ),
        const CastEncoder(CastEncoderKind.x264),
      ]);
      expect(found.softwareOnly, isFalse);
      expect(tests(), [
        'h264_nvenc',
        for (final kind in HardwareDecode.values)
          'h264_nvenc decodes ${kind.name}',
        // The bundled libva first, then the system's, node by node.
        'h264_vaapi renderD128 bundled',
        'h264_vaapi renderD128',
        'h264_vaapi renderD129 bundled',
        for (final kind in HardwareDecode.values)
          'h264_vaapi decodes ${kind.name}',
        'h264_qsv renderD128 bundled',
        'h264_qsv renderD128',
        'h264_qsv renderD129 bundled',
        'h264_qsv renderD129',
        'libx264',
      ]);
    });

    test('a system newer than the bundled libva: its own', () async {
      script = (call) => call.encoder == 'h264_vaapi'
          ? (call.bundledLibva
                ? const _Answer.fails('Failed to initialise VAAPI connection')
                : const _Answer.passes())
          : const _Answer.fails();

      final found = await detector(nodes: const ['/dev/dri/renderD128'])
          .encoders();

      expect(found.available, [
        const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD128',
          decodes: everything,
        ),
      ]);
      // Its decode tests run without the bundled libva too.
      expect(
        calls.where((c) => c.decodes != null).map((c) => c.bundledLibva),
        everyElement(isFalse),
      );
    });

    test("no bundled libva: only the system's is tried", () async {
      await detector(binaries: withoutLibva).encoders();

      expect(tests().where((t) => t.startsWith('h264_vaapi')), [
        'h264_vaapi renderD128',
        'h264_vaapi renderD129',
      ]);
      expect(calls.where((c) => c.bundledLibva), isEmpty);
    });

    test('no render nodes: VA-API and Quick Sync are not tried', () async {
      final found = await detector(nodes: const []).encoders();

      expect(
        tests().where((t) => t.contains('vaapi') || t.contains('qsv')),
        isEmpty,
      );
      expect(found.available.map((e) => e.kind), [
        CastEncoderKind.nvenc,
        CastEncoderKind.x264,
      ]);
    });

    test("Windows: docs/04's order, no render nodes, Direct3D 11", () async {
      script = (call) => switch (call.encoder) {
        'h264_qsv' || 'libx264' => const _Answer.passes(),
        _ => const _Answer.fails(),
      };

      final found = await detector(windows: true).encoders();

      expect(tests().where((t) => !t.contains('decodes')), [
        'h264_nvenc',
        'h264_qsv',
        'h264_amf',
        'libx264',
      ]);
      expect(found.available.map((e) => e.kind), [
        CastEncoderKind.qsv,
        CastEncoderKind.x264,
      ]);
      expect(found.best!.device, isNull);
      final qsv = calls.firstWhere(
        (c) => c.isEncodeTest && c.encoder == 'h264_qsv',
      );
      expect(
        qsv.arguments,
        contains('qsv=cast:hw_any,child_device_type=d3d11va'),
      );
      expect(calls.where((c) => c.environment != null), isEmpty);
    });

    test('nothing but the processor: re-encodes capped at 1080p', () async {
      script = (call) => call.encoder == 'libx264'
          ? const _Answer.passes()
          : const _Answer.fails();

      final found = await detector().encoders();

      expect(found.available, [const CastEncoder(CastEncoderKind.x264)]);
      expect(found.softwareOnly, isTrue);
      // No hardware: no test pictures made.
      expect(calls.where((c) => c.makes != null), isEmpty);
    });

    test('nothing works: none', () async {
      script = (_) => const _Answer.fails();

      final found = await detector().encoders();

      expect(found, CastEncoders.none);
      expect(found.canTranscode, isFalse);
    });

    test('a test that ends well but made no pictures fails', () async {
      script = (call) => call.encoder == 'libx264'
          ? const _Answer(stdout: 'frame=0\nprogress=end\n')
          : const _Answer.fails();

      expect(await detector().encoders(), CastEncoders.none);
      expect(
        logged(),
        contains(contains('libx264 encode: no (made no pictures)')),
      );
    });

    test('decodes: only the kinds whose test passed', () async {
      script = (call) {
        if (call.encoder != 'h264_nvenc') return const _Answer.fails();
        return switch (call.decodes) {
          HardwareDecode.hevc10 => const _Answer(
            code: 69,
            stderr: 'Nothing was written into output file\n',
          ),
          HardwareDecode.mpeg2 => const _Answer(stdout: 'frame=0\n'),
          _ => const _Answer.passes(),
        };
      };

      final found = await detector().encoders();

      expect(found.best!.decodes, {HardwareDecode.h264, HardwareDecode.hevc});
    });

    test("decode tests use the re-encode's own arguments", () async {
      await detector().encoders();

      final mpeg2 = calls.firstWhere(
        (c) => c.decodes == HardwareDecode.mpeg2 && c.encoder == 'h264_nvenc',
      );
      final expected = videoTranscodeArgs(
        plan: const CastVideoTranscode(
          height: 288,
          bitRate: 1500000,
          fps: 50,
          deinterlace: true,
          reasons: [TranscodeReason.codecUnsupported],
        ),
        encoder: const CastEncoder(
          CastEncoderKind.nvenc,
          decodes: {HardwareDecode.mpeg2},
        ),
        source: const VideoFacts(
          codec: 'mpeg2video',
          profile: 'Main',
          width: 720,
          height: 576,
          fps: 25,
          interlaced: true,
          bitDepth: 8,
        ),
      );
      expect(mpeg2.arguments, containsAllInOrder(expected.input));
      expect(mpeg2.arguments, containsAllInOrder(expected.output));
      expect(mpeg2.arguments, containsAllInOrder(['-f', 'null', '-']));
      expect(
        mpeg2.arguments,
        containsAllInOrder(['-nostats', '-progress', 'pipe:1']),
      );
    });

    test('a test picture FFmpeg cannot make is not tested', () async {
      // An FFmpeg without libx265.
      final made = <String>[];
      final noHevc = FfmpegEncoderDetector(
        binaries: withLibva,
        folder: folder,
        supervisor: ProcessSupervisor(
          folder: Directory(p.join(temp.path, 'processes2')),
          log: AppLog(output: output, secrets: SecretRegistry()),
          launcher: (executable, arguments, {environment}) async {
            final call = _Call(arguments, environment);
            calls.add(call);
            if (call.isVersion) {
              return _FakeProcess(nextPid++, _Answer(stdout: '$version\n'));
            }
            final file = call.makes;
            if (file != null) {
              if (arguments.contains('libx265')) {
                return _FakeProcess(
                  nextPid++,
                  const _Answer(code: 1, stderr: 'Unknown encoder libx265\n'),
                );
              }
              made.add(p.basename(file));
              File(file).writeAsStringSync('picture');
              return _FakeProcess(nextPid++, const _Answer());
            }
            return _FakeProcess(nextPid++, _laptop(call));
          },
          image: (_) => null,
          kill: (_) => false,
        ),
        log: AppLog(output: output, secrets: SecretRegistry()),
        windows: false,
        renderNodes: () => const [],
        now: () => now,
      );

      final found = await noHevc.encoders();

      expect(made, ['h264.mkv', 'mpeg2.ts']);
      expect(found.best!.decodes, {HardwareDecode.h264, HardwareDecode.mpeg2});
      expect(logged(), contains(contains("Couldn't make a hevc test picture")));
    });

    test('the test pictures are made once and deleted after', () async {
      final stale = Directory(p.join(folder.path, 'encoder-test'))
        ..createSync(recursive: true);
      File(p.join(stale.path, 'old.ts')).writeAsStringSync('left over');

      await detector().encoders();

      // Four pictures, made for NVENC, reused for VA-API.
      expect(calls.where((c) => c.makes != null), hasLength(4));
      expect(stale.existsSync(), isFalse);
    });

    test('the log says what was found and why the rest was not', () async {
      script = (call) =>
          call.encoder == 'h264_vaapi' && call.node!.endsWith('8')
          ? const _Answer(
              code: 251,
              stderr:
                  '[AVHWDeviceContext] Failed to initialise VAAPI connection\n'
                  "Failed to set value 'vaapi=cast:/dev/dri/renderD128' for "
                  "option 'init_hw_device': Input/output error\n"
                  'Error parsing global options: Input/output error\n',
            )
          : _laptop(call);

      await detector().encoders();

      final lines = logged().join('\n');
      // The reason, not the lines FFmpeg ends every failure with.
      expect(
        lines,
        contains(
          'VA-API encode on /dev/dri/renderD128 (bundled libva): no '
          '([AVHWDeviceContext] Failed to initialise VAAPI connection)',
        ),
      );
      expect(
        lines,
        contains(
          'NVENC (decodes h264, hevc, hevc10, mpeg2), VA-API on renderD129 '
          '(bundled libva; decodes h264, hevc, hevc10, mpeg2), libx264',
        ),
      );
    });

    test('a libva too old for FFmpeg is named as the reason', () async {
      await detector(binaries: withoutLibva).encoders();

      expect(
        logged().join('\n'),
        contains(
          'VA-API encode on /dev/dri/renderD129: no '
          "(this system's libva is older than 2.21)",
        ),
      );
    });

    test("FFmpeg that won't start: none, and nothing remembered", () async {
      final broken = FfmpegEncoderDetector(
        binaries: withLibva,
        folder: folder,
        supervisor: ProcessSupervisor(
          folder: Directory(p.join(temp.path, 'processes3')),
          log: AppLog(output: output, secrets: SecretRegistry()),
          launcher: (executable, arguments, {environment}) async =>
              throw const ProcessException('ffmpeg', [], 'No such file'),
        ),
        log: AppLog(output: output, secrets: SecretRegistry()),
        windows: false,
        renderNodes: () => const [],
      );

      expect(await broken.encoders(), CastEncoders.none);
      expect(File(p.join(folder.path, 'encoders.json')).existsSync(), isFalse);
    });

    test('a surprise inside is logged, never thrown', () async {
      final surprising = FfmpegEncoderDetector(
        binaries: withLibva,
        folder: folder,
        supervisor: supervisor,
        log: AppLog(output: output, secrets: SecretRegistry()),
        windows: false,
        renderNodes: () => throw StateError('surprise'),
      );

      expect(await surprising.encoders(), CastEncoders.none);
      expect(logged().join('\n'), contains('Detection failed'));
    });
  });

  group('remembering', () {
    File cache() => File(p.join(folder.path, 'encoders.json'));

    test('the next run asks FFmpeg its version and nothing else', () async {
      final first = await detector().encoders();
      calls.clear();

      final second = await detector().encoders();

      expect(second, first);
      expect(calls, hasLength(1));
      expect(calls.single.isVersion, isTrue);
      expect(logged().join('\n'), contains('Remembered: '));
    });

    test('in this run, not even the version', () async {
      final found = detector();
      await found.encoders();
      calls.clear();

      await found.encoders();

      expect(calls, isEmpty);
    });

    test('what it writes', () async {
      await detector().encoders();

      final json = jsonDecode(cache().readAsStringSync()) as Map;
      expect(json['format'], 1);
      expect(json['ffmpeg'], version);
      expect(json['windows'], false);
      expect(json['libva'], true);
      expect(json['detected_at'], '2026-10-02T09:00:00.000Z');
      expect((json['encoders'] as List).first, {
        'kind': 'nvenc',
        'device': null,
        'decodes': ['h264', 'hevc', 'hevc10', 'mpeg2'],
        'bundled_libva': false,
      });
      expect(File('${cache().path}.tmp').existsSync(), isFalse);
    });

    Future<void> testedAgainWhen(void Function() change) async {
      await detector().encoders();
      change();
      calls.clear();

      await detector().encoders();

      expect(calls.where((c) => c.isEncodeTest), isNotEmpty);
    }

    test('a new FFmpeg: tested again', () async {
      await testedAgainWhen(() => version = 'ffmpeg version n8.2-test');
    });

    test('a week later: tested again', () async {
      await testedAgainWhen(() => now = now.add(const Duration(days: 8)));
    });

    test('six days later: remembered', () async {
      await detector().encoders();
      now = now.add(const Duration(days: 6));
      calls.clear();

      await detector().encoders();

      expect(calls.where((c) => c.isEncodeTest), isEmpty);
    });

    test('a clock that went back: tested again', () async {
      await testedAgainWhen(() => now = now.subtract(const Duration(days: 1)));
    });

    test('a bundled libva added or gone: tested again', () async {
      await detector(binaries: withoutLibva).encoders();
      calls.clear();

      await detector().encoders();

      expect(calls.where((c) => c.isEncodeTest), isNotEmpty);
    });

    test('anything it did not write: tested again', () async {
      String record(Map<String, Object?> changes) => jsonEncode({
        'format': 1,
        'ffmpeg': 'V',
        'windows': false,
        'libva': true,
        'detected_at': '2026-10-02T09:00:00Z',
        'encoders': [
          {
            'kind': 'nvenc',
            'device': null,
            'decodes': ['h264'],
            'bundled_libva': false,
          },
        ],
        ...changes,
      });
      final junk = [
        '',
        'not json',
        '[]',
        '{"format": 2}',
        '{"format": 1, "ffmpeg": 3}',
        record({
          'encoders': [
            {'kind': 'gpu', 'device': null, 'decodes': <String>[]},
          ],
        }),
        record({
          'encoders': [
            {
              'kind': 'nvenc',
              'device': null,
              'decodes': ['av2'],
              'bundled_libva': false,
            },
          ],
        }),
        record({
          'encoders': [
            {'kind': 'nvenc', 'device': 7, 'decodes': 'all'},
          ],
        }),
        record({'detected_at': 'yesterday'}),
        record({'encoders': <String, Object>{}}),
        record({'windows': 'no'}),
      ];
      version = 'V';
      for (final text in junk) {
        folder.createSync(recursive: true);
        cache().writeAsStringSync(text);
        calls.clear();

        await detector().encoders();

        expect(calls.where((c) => c.isEncodeTest), isNotEmpty, reason: text);
      }

      // The record they were made from is read.
      cache().writeAsStringSync(record({}));
      calls.clear();
      expect((await detector().encoders()).available, [
        const CastEncoder(
          CastEncoderKind.nvenc,
          decodes: {HardwareDecode.h264},
        ),
      ]);
      expect(calls.where((c) => c.isEncodeTest), isEmpty);
    });

    test('an empty list it wrote is remembered too', () async {
      script = (_) => const _Answer.fails();
      await detector().encoders();
      calls.clear();

      expect(await detector().encoders(), CastEncoders.none);
      expect(calls.where((c) => c.isEncodeTest), isEmpty);
    });

    test('detectAgain tests, whatever was remembered', () async {
      final found = detector();
      await found.encoders();
      script = (call) => call.encoder == 'libx264'
          ? const _Answer.passes()
          : const _Answer.fails();
      calls.clear();

      final again = await found.detectAgain();

      expect(again.available, [const CastEncoder(CastEncoderKind.x264)]);
      expect(await found.encoders(), again);
      calls.clear();
      expect(await detector().encoders(), again);
      expect(calls.where((c) => c.isEncodeTest), isEmpty);
    });

    test('a test cut short by its timeout: not remembered', () async {
      script = (call) => call.encoder == 'h264_nvenc'
          ? const _Answer(hang: true)
          : _laptop(call);

      final found = await detector(
        testTimeout: const Duration(milliseconds: 200),
      ).encoders();

      expect(found.available.first.kind, CastEncoderKind.vaapi);
      expect(cache().existsSync(), isFalse);
      expect(logged().join('\n'), contains('Not remembered'));
    });

    test('a test stopped as the app quits: not remembered', () async {
      script = (call) => call.encoder == 'h264_nvenc'
          ? const _Answer(hang: true)
          : _laptop(call);
      final detecting = detector().encoders();
      while (!calls.any((c) => c.encoder == 'h264_nvenc')) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      await supervisor.stopAll();
      await detecting;

      expect(cache().existsSync(), isFalse);
    });

    test('a folder it cannot write: found, not remembered, logged', () async {
      folder.parent.createSync(recursive: true);
      File(folder.path).writeAsStringSync('in the way');

      final found = await detector(nodes: const []).encoders();

      expect(found.canTranscode, isTrue);
      expect(logged().join('\n'), contains("Couldn't remember the encoders"));
    });
  });

  group('one at a time', () {
    test('asked twice at once: one detection', () async {
      final found = detector();

      final both = await Future.wait([found.encoders(), found.encoders()]);

      expect(both.first, both.last);
      expect(calls.where((c) => c.isVersion), hasLength(1));
    });

    test('detectAgain while detecting: the same one', () async {
      final found = detector();

      final both = await Future.wait([found.encoders(), found.detectAgain()]);

      expect(both.first, both.last);
      expect(calls.where((c) => c.isVersion), hasLength(1));
    });
  });

  group('with a real FFmpeg', () {
    // The bundled one, else (CI) the system's.
    final bundled = FfmpegBinaries.locate();
    final real =
        bundled ??
        (Platform.isLinux && File('/usr/bin/ffmpeg').existsSync()
            ? const FfmpegBinaries(
                ffmpeg: '/usr/bin/ffmpeg',
                ffprobe: '/usr/bin/ffprobe',
              )
            : null);
    final skip = real == null ? 'needs ffmpeg' : null;

    test('libx264 is found and remembered', () async {
      final realSupervisor = ProcessSupervisor(
        folder: Directory(p.join(temp.path, 'real-processes')),
        log: AppLog(output: output, secrets: SecretRegistry()),
      );
      addTearDown(realSupervisor.stopAll);
      FfmpegEncoderDetector make() => FfmpegEncoderDetector(
        binaries: real!,
        folder: folder,
        supervisor: realSupervisor,
        log: AppLog(output: output, secrets: SecretRegistry()),
        // The processor's only: CI has no GPU, and this laptop's are
        // measured by test/tools/cast_transcode_measure_test.dart.
        kinds: const [CastEncoderKind.x264],
      );

      final found = await make().encoders();

      expect(found.available, [const CastEncoder(CastEncoderKind.x264)]);
      expect(await make().encoders(), found);
      expect(realSupervisor.runningCount, 0);
    }, skip: skip);

    test("libx264's arguments make what the plan says", () async {
      final clip = p.join(temp.path, 'interlaced.ts');
      final made = await Process.run(real!.ffmpeg, [
        ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
        ...['-f', 'lavfi', '-t', '1', '-i', 'testsrc2=size=720x576:rate=25'],
        ...['-vf', 'setfield=tff', '-c:v', 'mpeg2video'],
        ...['-flags', '+ilme+ildct', '-top', '1', '-y', clip],
      ]);
      expect(made.exitCode, 0, reason: '${made.stderr}');
      const plan = CastVideoTranscode(
        height: 288,
        bitRate: 1500000,
        fps: 50,
        deinterlace: true,
        reasons: [TranscodeReason.codecUnsupported],
      );
      final args = videoTranscodeArgs(
        plan: plan,
        encoder: const CastEncoder(CastEncoderKind.x264),
        source: const VideoFacts(
          codec: 'mpeg2video',
          width: 720,
          height: 576,
          fps: 25,
          interlaced: true,
        ),
      );
      final out = p.join(temp.path, 'out.mp4');
      final run = await Process.run(real.ffmpeg, [
        ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
        ...args.input,
        ...['-i', clip, '-map', '0:v:0'],
        ...args.output,
        ...['-y', out],
      ]);
      expect(run.exitCode, 0, reason: '${run.stderr}');

      final probe = await Process.run(real.ffprobe, [
        ...['-v', 'error', '-select_streams', 'v:0'],
        ...['-show_entries', 'stream=codec_name,profile,width,height,'],
        ...['-show_entries', 'stream=r_frame_rate,pix_fmt,field_order'],
        ...['-of', 'json', out],
      ]);
      final stream =
          ((jsonDecode(probe.stdout as String) as Map)['streams'] as List)
                  .single
              as Map;
      expect(stream['codec_name'], 'h264');
      expect(stream['profile'], 'High');
      expect(stream['height'], 288);
      // 720 × 288 keeps the pixels' shape; one picture per field.
      expect(stream['width'], 360);
      expect(stream['r_frame_rate'], '50/1');
      expect(stream['pix_fmt'], 'yuv420p');
    }, skip: skip);
  });
}
