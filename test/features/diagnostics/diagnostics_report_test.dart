// The report's lines are long, and are split here where they are too
// wide for the page: each list entry is one line of the report.
// ignore_for_file: no_adjacent_strings_in_list

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/features/diagnostics/domain/diagnostics_report.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);

  test('the whole report, as sketch D reads', () {
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        appVersion: '0.1.0+1',
        system: const SystemFacts(
          os: 'Ubuntu 22.04.5 LTS',
          kernel: 'Linux 6.8.0-138-generic',
          session: 'Wayland',
          desktop: 'GNOME',
          graphics: [
            GraphicsCard(name: 'Intel UHD Graphics 630', driver: 'i915'),
            GraphicsCard(name: 'NVIDIA GeForce GTX 1650 Ti', driver: 'nvidia'),
          ],
        ),
        player: 'mpv 0.34.1',
        decoders: [
          DecoderNote(codec: 'H.264', height: 1080, decoder: 'vaapi', at: now),
          DecoderNote(codec: 'HEVC', height: 2160, decoder: 'vaapi', at: now),
          DecoderNote(codec: 'MPEG-2', height: 576, interlaced: true, at: now),
        ],
        ffmpeg: 'ffmpeg version n8.1.2',
        encoders: const ['h264_nvenc', 'h264_vaapi', 'libx264'],
        sources: [
          SourceFacts(
            type: 'Xtream',
            accountStatus: 'Active',
            maxConnections: 1,
            channels: 12610,
            movies: 20072,
            series: 8262,
            sync: RunFacts(
              outcome: 'succeeded',
              startedAt: now.subtract(const Duration(hours: 2)),
              duration: const Duration(milliseconds: 8700),
            ),
            guide: RunFacts(
              outcome: 'succeeded',
              startedAt: now.subtract(const Duration(hours: 3)),
              duration: const Duration(seconds: 41),
              skipped: 12,
            ),
            guideProgrammes: 142880,
          ),
        ],
        settings: const {'buffering': 'balanced', 'hardware decoding': 'auto'},
        libraryFolders: 3,
        libraryItems: 412,
        downloadsWaiting: 2,
        downloadsFinished: 14,
        problems: const [
          '2026-10-13T11:14:07.530Z WARN [watchdog] Stalled for 4 s',
          '2026-10-13T11:20:00.000Z ERROR [sync] The sync failed',
          '  error: TimeoutException',
        ],
      ),
    );

    expect(report.split('\n'), [
      'Bijou 0.1.0+1 · Ubuntu 22.04.5 LTS · Linux 6.8.0-138-generic · '
          'Wayland · GNOME',
      'Graphics: Intel UHD Graphics 630 (i915) · NVIDIA GeForce GTX 1650 Ti '
          '(nvidia)',
      'Player: mpv 0.34.1',
      'Decoding: H.264 1080p → vaapi · HEVC 2160p → vaapi · MPEG-2 576i → '
          'software',
      'Casting: ffmpeg version n8.1.2 · encoders h264_nvenc · h264_vaapi · '
          'libx264',
      'Source 1: Xtream · Active · 1 connection · 12,610 channels · 20,072 '
          'movies · 8,262 series',
      '  last sync: 2 h ago, 8 s, 0 rows skipped',
      '  guide: 142,880 programmes, last import 3 h ago, 41 s, 12 rows '
          'skipped',
      'Settings: buffering balanced · hardware decoding auto',
      'Library: 3 folders · 412 items',
      'Downloads: 2 waiting or running · 14 finished',
      'Recent warnings and errors (3):',
      '  2026-10-13T11:14:07.530Z WARN [watchdog] Stalled for 4 s',
      '  2026-10-13T11:20:00.000Z ERROR [sync] The sync failed',
      '    error: TimeoutException',
    ]);
  });

  test('a computer that has done nothing yet: every line still says '
      'something', () {
    final report = buildDiagnosticsReport(DiagnosticsFacts(now: now));

    expect(report.split('\n'), [
      'Bijou unknown',
      'Graphics: not known',
      'Player: not available',
      'Decoding: nothing played yet',
      'Casting: FFmpeg not looked at yet · encoders not looked for yet',
      'Sources: none',
      'Library: 0 folders · 0 items',
      'Downloads: 0 waiting or running · 0 finished',
      'Recent warnings and errors: none',
    ]);
  });

  group("a TV's drawing and its last ends (ADR-058)", () {
    final crashed = now.subtract(const Duration(hours: 2));

    test('drawn with OpenGL ES after a crash drawing: said on the Graphics '
        'line; the unexpected ends listed with their facts, addresses '
        'hidden, a kill in the background left out', () {
      final report = buildDiagnosticsReport(
        DiagnosticsFacts(
          now: now,
          drawing: DrawingBackend(
            openGles: true,
            since: crashed,
            cause: 'SIGSEGV SEGV_MAPERR on 1.raster in libGLES_mali.so',
          ),
          exits: [
            AppExit(
              time: now.subtract(const Duration(hours: 1)),
              reason: ExitReason.signaled,
              status: 9,
              importance: 400,
            ),
            AppExit(
              time: crashed,
              reason: ExitReason.crashNative,
              importance: 100,
              signal: 'SIGSEGV SEGV_MAPERR',
              thread: '1.raster',
              abort: 'stream http://203.0.113.7:8080/live/1.ts',
              frames: const ['pc 00000000000a1c2e libGLES_mali.so'],
              drawing: true,
            ),
          ],
        ),
      );
      final lines = report.split('\n');
      expect(
        lines,
        contains(
          'Graphics: not known · drawn with OpenGL ES · since 2 h ago · '
          'SIGSEGV SEGV_MAPERR on 1.raster in libGLES_mali.so',
        ),
      );
      final at = lines.indexOf('Unexpected ends (1):');
      expect(at, isNot(-1));
      expect(lines.sublist(at + 1, at + 5), [
        '  2 h ago: It crashed while drawing the screen.',
        '    crashNative · SIGSEGV SEGV_MAPERR · thread 1.raster',
        '    abort: stream http://<address>/live/1.ts',
        '    #00 pc 00000000000a1c2e libGLES_mali.so',
      ]);
      expect(report, isNot(contains('203.0.113.7')));
    });

    test("Flutter's own drawing and no unexpected end: the Graphics line as "
        'it is, and a line that says none', () {
      final report = buildDiagnosticsReport(
        DiagnosticsFacts(
          now: now,
          drawing: const DrawingBackend(),
          exits: const [],
        ),
      );
      expect(report, contains('Graphics: not known\n'));
      expect(report, contains('Unexpected ends: none kept'));
    });
  });

  group("a TV's own lines and each run's log (ADR-059)", () {
    test('the TV, its chip and its memory under the first line, the other '
        'ends on one line after the unexpected ones', () {
      final report = buildDiagnosticsReport(
        DiagnosticsFacts(
          now: now,
          system: const SystemFacts(
            os: 'Android 12 (API 31, 2024-05-05)',
            kernel: 'Linux 5.4.274+',
            device: 'TCL 43V8C · board m7332 · platform m7332',
            memory: '1.9 GB, 0.6 GB free, low at 0.2 GB · a low-RAM device',
            graphics: [
              GraphicsCard(
                name: 'EGL mali · Vulkan 1.1 (mali) · OpenGL ES 3.2',
              ),
            ],
          ),
          exits: [
            AppExit(
              time: now.subtract(const Duration(minutes: 5)),
              reason: ExitReason.exitSelf,
              importance: 400,
              byBijou: true,
            ),
            AppExit(
              time: now.subtract(const Duration(hours: 1)),
              reason: ExitReason.lowMemory,
              importance: 400,
              description: 'cached kill from 192.168.1.20',
            ),
          ],
        ),
      );
      final lines = report.split('\n');
      expect(lines.sublist(0, 4), [
        'Bijou unknown · Android 12 (API 31, 2024-05-05) · Linux 5.4.274+',
        'Device: TCL 43V8C · board m7332 · platform m7332',
        'Memory: 1.9 GB, 0.6 GB free, low at 0.2 GB · a low-RAM device',
        'Graphics: EGL mali · Vulkan 1.1 (mali) · OpenGL ES 3.2',
      ]);
      expect(
        lines,
        containsAllInOrder([
          'Unexpected ends: none kept',
          'Other ends: 5 min ago exitSelf, Back on Home, importance 400 · '
              '1 h ago lowMemory, importance 400, cached kill from <address>',
        ]),
      );
    });

    test("the report a phone takes ends with each run's log, addresses "
        'hidden and secrets redacted; one with nothing kept says so', () {
      final report = buildDiagnosticsReport(
        DiagnosticsFacts(
          now: now,
          runLogs: const RunLogs(
            previous: [
              '10-26 14:03:01.120  4120  4120 I Bijou   : Key DPAD_LEFT down',
              '10-26 14:03:01.410  4120  4161 F libc    : Fatal signal 11 '
                  '(SIGSEGV) in tid 4161 (1.raster)',
              '10-26 14:03:01.200  4120  4150 I flutter : open '
                  'http://203.0.113.7:8080/live/u/hunter2/1.ts',
            ],
          ),
        ),
        secrets: ['hunter2'],
      );
      final lines = report.split('\n');
      final at = lines.indexOf(
        'The run before, as Android logged it (3 lines):',
      );
      expect(at, isNot(-1));
      expect(lines.sublist(at + 1), [
        '  10-26 14:03:01.120  4120  4120 I Bijou   : Key DPAD_LEFT down',
        '  10-26 14:03:01.410  4120  4161 F libc    : Fatal signal 11 '
            '(SIGSEGV) in tid 4161 (1.raster)',
        '  10-26 14:03:01.200  4120  4150 I flutter : open '
            'http://<address>/live/***/***/1.ts',
        'This run so far: nothing kept',
      ]);
      expect(report, isNot(contains('hunter2')));
      expect(report, isNot(contains('203.0.113.7')));
    });

    test('the report on the screen has no run log and no TV lines', () {
      final report = buildDiagnosticsReport(DiagnosticsFacts(now: now));
      expect(report, isNot(contains('Device:')));
      expect(report, isNot(contains('Memory:')));
      expect(report, isNot(contains('The run before')));
      expect(report, isNot(contains('Other ends')));
    });
  });

  test('a sync that failed, one still running, one cancelled, and a source '
      'never synced', () {
    RunFacts run(String outcome, {String? failure, int? status}) => RunFacts(
      outcome: outcome,
      startedAt: now.subtract(const Duration(minutes: 12)),
      failure: failure,
      failureStatus: status,
    );
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        sources: [
          SourceFacts(
            type: 'Xtream',
            sync: run('failed', failure: 'network', status: 503),
            guide: run('failed', failure: 'parse'),
          ),
          SourceFacts(type: 'M3U URL', sync: run('running')),
          SourceFacts(type: 'M3U file', sync: run('cancelled')),
          const SourceFacts(type: 'Xtream'),
          SourceFacts(type: 'Xtream', sync: run('failed')),
        ],
      ),
    );

    expect(
      report,
      allOf(
        contains('  last sync: failed 12 min ago: network HTTP 503'),
        contains('  guide: 0 programmes, last import failed 12 min ago: parse'),
        contains('  last sync: running, started 12 min ago'),
        contains('  last sync: cancelled 12 min ago'),
        contains(
          'Source 4: Xtream · 0 channels · 0 movies · 0 series\n'
          '  last sync: never\n  guide: never imported',
        ),
        contains('  last sync: failed 12 min ago: unknown'),
      ),
    );
  });

  test('no encoder that works is said, as is one connection or several', () {
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        ffmpeg: 'ffmpeg version 4.4.2',
        encoders: const [],
        sources: const [
          SourceFacts(
            type: 'Xtream',
            accountStatus: 'Expired',
            maxConnections: 3,
          ),
        ],
      ),
    );

    expect(
      report,
      contains('Casting: ffmpeg version 4.4.2 · no encoder works here'),
    );
    expect(report, contains('Source 1: Xtream · Expired · 3 connections · '));
  });

  test('the home folder is written ~, wherever it appears', () {
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        homeFolder: '/home/mariam',
        problems: const [
          '2026-10-13T11:00:00.000Z WARN [library] Unreadable: '
              '/home/mariam/Videos/Film (2019).mkv',
        ],
      ),
    );

    expect(report, isNot(contains('mariam')));
    expect(report, contains('Unreadable: ~/Videos/Film (2019).mkv'));
  });

  test('the whole text is redacted once more on its way out: a secret or a '
      'credential-bearing URL that reached a log line never leaves', () {
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        problems: const [
          '2026-10-13T11:00:00.000Z WARN [player] Failed: '
              'http://tv.example.test:8080/live/viewerQX19/pw-J4vK9/147.ts',
          '2026-10-13T11:00:01.000Z WARN [sync] bad answer from '
              'http://tv.example.test/player_api.php?username=viewerQX19'
              '&password=pw-J4vK9',
          '2026-10-13T11:00:02.000Z WARN [odd] the token zz-token-71 leaked',
        ],
      ),
      secrets: const ['zz-token-71'],
    );

    expect(report, isNot(contains('viewerQX19')));
    expect(report, isNot(contains('pw-J4vK9')));
    expect(report, isNot(contains('zz-token-71')));
    expect(report, contains('/live/'));
  });

  test('a source is a number, never a name', () {
    final report = buildDiagnosticsReport(
      DiagnosticsFacts(
        now: now,
        sources: const [
          SourceFacts(type: 'Xtream'),
          SourceFacts(type: 'M3U URL'),
        ],
      ),
    );

    expect(report, contains('Source 1: Xtream'));
    expect(report, contains('Source 2: M3U URL'));
  });

  group('what a log line may say and the report may not', () {
    test('a server’s or a device’s address becomes <address>; this '
        'computer’s own stays', () {
      expect(
        withoutAddresses('GET http://tv.example.test:8080/a/b?x=1 failed'),
        'GET http://<address>/a/b?x=1 failed',
      );
      expect(
        withoutAddresses('Living Room TV at 192.168.1.155:8009 went quiet'),
        'Living Room TV at <address> went quiet',
      );
      expect(withoutAddresses('rtmp://10.0.0.7/live'), 'rtmp://<address>/live');
      for (final own in [
        'http://127.0.0.1:38412/p/abc/stream.mp4',
        'http://localhost:8899/player_api.php',
        'listening on 0.0.0.0:38400',
        'http://[::1]:8080/x',
      ]) {
        expect(withoutAddresses(own), own);
      }
      // A version isn't an address.
      expect(
        withoutAddresses('ffmpeg n8.1.2 on 6.8.0'),
        'ffmpeg n8.1.2 on 6.8.0',
      );
    });

    test('a source’s server and name are replaced wherever they appear, the '
        'longer name first; short ones are left, so ordinary words stay', () {
      final report = buildDiagnosticsReport(
        DiagnosticsFacts(
          now: now,
          problems: const [
            '2026-10-13T11:00:00.000Z WARN [guide] Northwind TV Plus at '
                'tv.northwind.test gave nothing',
            '2026-10-13T11:00:01.000Z WARN [guide] Northwind TV is slow, '
                'and so is TV',
          ],
          named: const {
            'tv.northwind.test': '<server>',
            'Northwind TV': 'Source 1',
            'Northwind TV Plus': 'Source 2',
            'TV': 'Source 3',
          },
        ),
      );

      expect(report, contains('Source 2 at <server> gave nothing'));
      expect(report, contains('Source 1 is slow, and so is TV'));
      expect(report, isNot(contains('Northwind')));
    });
  });
}
