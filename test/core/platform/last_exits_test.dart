import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/last_exits.dart';

/// ADR-058: what `bijou/exits` (LastExits.kt) answers becomes the app's
/// last ends, read tolerantly (hard rule 1's spirit); which of them are
/// news, and how they are said.
void main() {
  final crashedAt = DateTime(2026, 10, 25, 6, 3, 44);
  final leftAt = DateTime(2026, 10, 25, 6, 13, 28);

  /// As LastExits.kt answered on the Android 12 emulator after a SIGSEGV
  /// on the raster thread, and Back on Home later.
  Map<String, Object?> answer({int? seenUpTo}) => {
    'exits': [
      {
        'time': leftAt.millisecondsSinceEpoch,
        'reason': 'signaled',
        'status': 9,
        'importance': 400,
        'pssKb': 0,
        'rssKb': 0,
        'byBijou': true,
      },
      {
        'time': crashedAt.millisecondsSinceEpoch,
        'reason': 'crashNative',
        'status': 11,
        'importance': 100,
        'pssKb': 210000,
        'rssKb': 312000,
        'description': null,
        'byBijou': false,
        'signal': 'SIGSEGV SEGV_MAPERR',
        'thread': '1.raster',
        'abort': null,
        'cause': 'null pointer dereference',
        'frames': [
          'pc 00000000000a1c2e libGLES_mali.so',
          'pc 0000000000521385 libflutter.so',
        ],
        'drawing': true,
      },
    ],
    'seenUpTo': seenUpTo ?? 0,
    'drawing': {
      'backend': 'opengles',
      'since': crashedAt.millisecondsSinceEpoch,
      'cause': 'SIGSEGV SEGV_MAPERR on 1.raster in libGLES_mali.so',
    },
  };

  group('reading the answer', () {
    test('a native crash: its signal, thread, cause and frames, newest end '
        'first, and the drawing back end it led to', () {
      final last = lastExitsFrom(answer())!;
      expect(last.exits.map((exit) => exit.reason), [
        ExitReason.signaled,
        ExitReason.crashNative,
      ]);
      final crash = last.exits.last;
      expect(crash.time, crashedAt);
      expect(crash.status, 11);
      expect(crash.importance, 100);
      expect(crash.rssKb, 312000);
      expect(crash.description, isNull);
      expect(crash.signal, 'SIGSEGV SEGV_MAPERR');
      expect(crash.thread, '1.raster');
      expect(crash.cause, 'null pointer dereference');
      expect(crash.frames, hasLength(2));
      expect(crash.drawing, isTrue);
      expect(last.exits.first.byBijou, isTrue);
      expect(last.seenUpTo, isNull);
      expect(last.drawing.openGles, isTrue);
      expect(last.drawing.since, crashedAt);
      expect(last.drawing.cause, contains('libGLES_mali.so'));
    });

    test('the ends are put newest first whatever order they came in', () {
      final reversed = answer();
      reversed['exits'] = (reversed['exits']! as List).reversed.toList();
      expect(lastExitsFrom(reversed)!.exits.first.time, leftAt);
    });

    test('an answer that is not a map is none', () {
      expect(lastExitsFrom(null), isNull);
      expect(lastExitsFrom('exits'), isNull);
      expect(lastExitsFrom(const [1, 2]), isNull);
    });

    test('bad rows are left out and wrong kinds are as if missing, never a '
        'throw', () {
      final last = lastExitsFrom({
        'exits': [
          'not an end',
          {'reason': 'crash'},
          {'time': 0, 'reason': 'crash'},
          {'time': -5, 'reason': 'crash'},
          {'time': '1700000000000', 'reason': 'crash'},
          {
            'time': 1700000000000,
            'reason': 'somethingNew',
            'status': '9',
            'importance': null,
            'frames': ['pc 01 libc.so', 7, null],
            'drawing': 'yes',
            'thread': '   ',
            'trace': 12,
          },
        ],
        'seenUpTo': 'yesterday',
        'drawing': 'opengles',
      })!;
      expect(last.exits, hasLength(1));
      final exit = last.exits.single;
      expect(exit.reason, ExitReason.unknown);
      expect(exit.status, 0);
      expect(exit.importance, 0);
      expect(exit.frames, ['pc 01 libc.so']);
      expect(exit.drawing, isFalse);
      expect(exit.thread, isNull);
      expect(exit.trace, isNull);
      expect(last.seenUpTo, isNull);
      expect(last.drawing.openGles, isFalse);
    });

    test('no exits at all, as before Android 11', () {
      final last = lastExitsFrom({
        'exits': <Object?>[],
        'drawing': {'backend': 'default'},
      })!;
      expect(last.exits, isEmpty);
      expect(last.untold, isEmpty);
      expect(last.drawing.openGles, isFalse);
    });
  });

  group('which ends are news', () {
    AppExit exit(
      ExitReason reason, {
      int importance = 100,
      bool byBijou = false,
    }) => AppExit(
      time: crashedAt,
      reason: reason,
      importance: importance,
      byBijou: byBijou,
    );

    test('a crash, a native crash, an ANR and a failed start always', () {
      for (final reason in [
        ExitReason.crash,
        ExitReason.crashNative,
        ExitReason.anr,
        ExitReason.initializationFailure,
      ]) {
        expect(
          exit(reason, importance: 400).unexpected,
          isTrue,
          reason: '$reason',
        );
      }
    });

    test('a kill only while on the screen: the memory killer taking the app '
        'the TV shows, not a cached one in the background', () {
      expect(exit(ExitReason.lowMemory).unexpected, isTrue);
      expect(exit(ExitReason.signaled, importance: 200).unexpected, isTrue);
      expect(exit(ExitReason.lowMemory, importance: 400).unexpected, isFalse);
      expect(exit(ExitReason.signaled, importance: 0).unexpected, isFalse);
    });

    test('never Back on Home ending the process, nor what the user did', () {
      expect(exit(ExitReason.signaled, byBijou: true).unexpected, isFalse);
      expect(exit(ExitReason.exitSelf, byBijou: true).unexpected, isFalse);
      for (final reason in [
        ExitReason.userRequested,
        ExitReason.userStopped,
        ExitReason.permissionChange,
        ExitReason.packageUpdated,
        ExitReason.dependencyDied,
      ]) {
        expect(exit(reason).unexpected, isFalse, reason: '$reason');
      }
    });

    test('untold: the unexpected ends after the newest told, newest first', () {
      expect(lastExitsFrom(answer())!.untold.map((exit) => exit.time), [
        crashedAt,
      ]);
      expect(
        lastExitsFrom(answer(seenUpTo: crashedAt.millisecondsSinceEpoch))!
            .untold,
        isEmpty,
      );
    });
  });

  group('how an end is said', () {
    test('a sentence for each kind', () {
      String said(ExitReason reason, {bool drawing = false, int status = 0}) =>
          AppExit(
            time: crashedAt,
            reason: reason,
            drawing: drawing,
            status: status,
          ).summary;
      expect(
        said(ExitReason.crashNative, drawing: true),
        'It crashed while drawing the screen.',
      );
      expect(said(ExitReason.crashNative), 'It crashed in its native code.');
      expect(said(ExitReason.crash), 'It crashed on an error nothing caught.');
      expect(
        said(ExitReason.anr),
        'It stopped responding, and Android closed it.',
      );
      expect(said(ExitReason.lowMemory), 'Android closed it to free memory.');
      expect(
        said(ExitReason.signaled, status: 9),
        'Android ended it (signal 9).',
      );
      expect(said(ExitReason.other), 'Android ended it.');
    });

    test('the facts, a line each: kind, signal, thread and memory, then the '
        'cause and the frames numbered', () {
      final crash = lastExitsFrom(answer())!.exits.last;
      expect(crash.details, [
        'crashNative · SIGSEGV SEGV_MAPERR · thread 1.raster · memory 305 MB',
        'cause: null pointer dereference',
        '#00 pc 00000000000a1c2e libGLES_mali.so',
        '#01 pc 0000000000521385 libflutter.so',
      ]);
    });

    test("a Java crash's stack line by line, and not Android's word for it, "
        'which is its kind again', () {
      final crash = AppExit(
        time: crashedAt,
        reason: ExitReason.crash,
        status: 1,
        description: 'crash',
        trace:
            'thread main\n'
            'java.lang.IllegalStateException: no surface\n'
            '\tat io.github.yasiralobaidi.bijou.VideoLayer.show',
      );
      expect(crash.details, [
        'crash · status 1',
        'thread main',
        'java.lang.IllegalStateException: no surface',
        '\tat io.github.yasiralobaidi.bijou.VideoLayer.show',
      ]);
    });
  });
}
