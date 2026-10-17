import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/sync/guide_scheduler.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:logger/logger.dart';

import '../../features/onboarding/onboarding_fakes.dart';

void main() {
  late DateTime now;
  late _Guide guide;
  late _Imports imports;
  late FakeSourceRepository sources;
  late Set<String> syncing;
  late Set<String> busy;
  late List<AppNotice> notices;

  /// The guide's switch (ADR-031); null: a scheduler made without one.
  bool? enabled;

  /// A TV's "anything plays"; null: a desktop's scheduler, made without.
  bool? playing;

  /// Null: the settings are read. A future must be made inside the fake
  /// clock's zone, or it never completes there.
  Completer<void>? settings;

  setUp(() {
    now = DateTime.utc(2026, 9, 27, 12);
    guide = _Guide();
    imports = _Imports(guide, () => now);
    sources = FakeSourceRepository();
    syncing = {};
    busy = {};
    notices = [];
    settings = null;
    enabled = null;
    playing = null;
  });

  GuideScheduler scheduler() => GuideScheduler(
    guide: guide,
    imports: imports,
    sources: sources,
    log: AppLog(output: _Silent(), secrets: SecretRegistry()),
    settingsLoaded: () => settings?.future ?? Future<void>.value(),
    syncing: syncing.contains,
    enabled: enabled == null ? null : () => enabled!,
    busy: busy.contains,
    playing: playing == null ? null : () => playing!,
    notify: notices.add,
    clock: () => now,
  );

  /// A guide that arrived [hoursAgo] hours ago.
  void fresh(String sourceId, {int hoursAgo = 1}) =>
      guide.coverages[sourceId] = GuideCoverage(
        programmes: 10,
        updatedAt: now.subtract(Duration(hours: hoursAgo)),
        lastImport: GuideImport(
          id: 1,
          outcome: GuideImportOutcome.succeeded,
          startedAt: now.subtract(Duration(hours: hoursAgo)),
        ),
      );

  test('nothing before startUp; then every due source, one at a time, '
      'once the settings are read', () {
    fakeAsync((async) {
      sources
        ..seed()
        ..seed(id: 'src-2', name: 'Second')
        ..seed(id: 'src-3', name: 'Third');
      fresh('src-3');
      settings = Completer<void>();
      imports.gate = Completer<void>();
      final s = scheduler()..synced('src-1');
      async.flushMicrotasks();
      expect(imports.asked, isEmpty, reason: 'the launch syncs come first');

      unawaited(s.startUp());
      async.flushMicrotasks();
      expect(imports.asked, isEmpty, reason: 'waits for the settings');

      settings!.complete();
      async.flushMicrotasks();
      expect(imports.asked, ['src-1'], reason: 'one at a time');
      imports.gate!.complete();
      imports.gate = null;
      async.flushMicrotasks();
      expect(imports.asked, ['src-1', 'src-2'], reason: 'src-3 is fresh');
      unawaited(s.dispose());
    });
  });

  test('a source whose sync runs waits for the sync to end', () {
    fakeAsync((async) {
      sources.seed();
      syncing.add('src-1');
      final s = scheduler();
      unawaited(s.startUp());
      async.flushMicrotasks();
      expect(imports.asked, isEmpty);

      syncing.remove('src-1');
      s.synced('src-1');
      async.flushMicrotasks();
      expect(imports.asked, ['src-1']);
      unawaited(s.dispose());
    });
  });

  test('every hour: a guide that turned a day old is imported', () {
    fakeAsync((async) {
      sources.seed();
      fresh('src-1', hoursAgo: 22);
      final s = scheduler();
      unawaited(s.startUp());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(hours: 1));
      expect(imports.asked, isEmpty, reason: '23 h old');

      now = now.add(const Duration(hours: 2));
      async.elapse(const Duration(hours: 1));
      expect(imports.asked, ['src-1']);
      unawaited(s.dispose());
    });
  });

  test('a source with no guide address is not asked again until it syncs', () {
    fakeAsync((async) {
      sources.seed();
      imports.unrecorded['src-1'] = NotFoundFailure('no guide');
      final s = scheduler();
      unawaited(s.startUp());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(hours: 3));
      expect(imports.asked, ['src-1'], reason: 'once, not hourly');

      imports.unrecorded.remove('src-1');
      s.synced('src-1');
      async.flushMicrotasks();
      expect(imports.asked, ['src-1', 'src-1']);
      unawaited(s.dispose());
    });
  });

  test('an import that failed is tried again after six hours, not hourly', () {
    fakeAsync((async) {
      sources.seed();
      imports.recorded['src-1'] = NetworkFailure('down');
      final s = scheduler();
      unawaited(s.startUp());
      async.flushMicrotasks();
      expect(imports.asked, hasLength(1));

      for (var hour = 1; hour <= 5; hour++) {
        now = now.add(const Duration(hours: 1));
        async.elapse(const Duration(hours: 1));
      }
      expect(imports.asked, hasLength(1));
      now = now.add(const Duration(hours: 1));
      async.elapse(const Duration(hours: 1));
      expect(imports.asked, hasLength(2));
      expect(notices, isEmpty, reason: 'a failure is no pop-up');
      unawaited(s.dispose());
    });
  });

  test('waits while a stream from the source is being set up', () {
    fakeAsync((async) {
      sources.seed();
      busy.add('src-1');
      final s = scheduler();
      unawaited(s.startUp());
      async.elapse(const Duration(seconds: 12));
      expect(imports.asked, isEmpty);

      busy.clear();
      async.elapse(const Duration(seconds: 5));
      expect(imports.asked, ['src-1']);
      unawaited(s.dispose());
    });
  });

  test('a source busy past a minute is left for the next check', () {
    fakeAsync((async) {
      sources.seed();
      busy.add('src-1');
      final s = scheduler();
      unawaited(s.startUp());
      async.elapse(const Duration(minutes: 2));
      expect(imports.asked, isEmpty);

      busy.clear();
      async.elapse(const Duration(hours: 1));
      expect(imports.asked, ['src-1']);
      unawaited(s.dispose());
    });
  });

  test('a finished import says so, with the visible channels matched; the '
      "source's name when there are several", () {
    fakeAsync((async) {
      sources.seed();
      guide.counts['src-1'] = const ChannelMatchCounts(
        channels: 1310,
        matched: 1284,
      );
      final s = scheduler();
      unawaited(s.startUp());
      async.flushMicrotasks();
      expect(notices.single.message, 'Guide updated · 1,284 channels matched');
      expect(notices.single.tone, NoticeTone.success);

      sources.seed(id: 'src-2', name: 'Second');
      guide.counts['src-2'] = const ChannelMatchCounts(channels: 1, matched: 1);
      s.synced('src-2');
      async.flushMicrotasks();
      expect(
        notices.last.message,
        'Guide updated · Second · 1 channel matched',
      );
      unawaited(s.dispose());
    });
  });

  test('never beside an import already running for the source', () {
    fakeAsync((async) {
      sources.seed();
      imports.running.add('src-1');
      final s = scheduler();
      unawaited(s.startUp());
      async.flushMicrotasks();
      expect(imports.asked, isEmpty);
      unawaited(s.dispose());
    });
  });

  group('the switch (ADR-031)', () {
    test('off: nothing is imported, at launch, hourly or after a sync, '
        'and a guide still stored is cleared', () {
      fakeAsync((async) {
        enabled = false;
        sources
          ..seed()
          ..seed(id: 'src-2', name: 'Second');
        fresh('src-1', hoursAgo: 30);
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(guide.cleared, ['src-1'], reason: 'src-2 has none');

        s.synced('src-2');
        now = now.add(const Duration(days: 2));
        async.elapse(const Duration(hours: 3));
        expect(imports.asked, isEmpty);
        expect(guide.cleared, ['src-1'], reason: 'nothing more to clear');
        unawaited(s.dispose());
      });
    });

    test('off waits for the stored choice before it clears '
        'anything', () {
      fakeAsync((async) {
        enabled = false;
        settings = Completer<void>();
        sources.seed();
        fresh('src-1');
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(guide.cleared, isEmpty);

        settings!.complete();
        async.flushMicrotasks();
        expect(guide.cleared, ['src-1']);
        unawaited(s.dispose());
      });
    });

    test('on again: every source is looked at, one that had no guide '
        'address too', () {
      fakeAsync((async) {
        enabled = true;
        sources
          ..seed()
          ..seed(id: 'src-2', name: 'Second');
        imports.unrecorded['src-1'] = NotFoundFailure('no guide');
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1', 'src-2']);

        enabled = false;
        unawaited(s.switchedOff());
        async.flushMicrotasks();
        expect(guide.cleared, ['src-2']);

        imports.unrecorded.remove('src-1');
        enabled = true;
        unawaited(s.switchedOn());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1', 'src-2', 'src-1', 'src-2']);
        unawaited(s.dispose());
      });
    });

    test('off cancels an import that runs, then clears what it put '
        'in', () {
      fakeAsync((async) {
        enabled = true;
        sources.seed();
        imports.gate = Completer<void>();
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1']);

        enabled = false;
        unawaited(s.switchedOff());
        async.flushMicrotasks();
        expect(imports.cancelled, ['src-1']);
        expect(guide.cleared, ['src-1'], reason: 'after the import ended');
        unawaited(s.dispose());
      });
    });

    test('off while a source waits its turn: it is dropped', () {
      fakeAsync((async) {
        enabled = true;
        sources
          ..seed()
          ..seed(id: 'src-2', name: 'Second');
        imports.gate = Completer<void>();
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1']);

        enabled = false;
        imports.gate!.complete();
        imports.gate = null;
        async.flushMicrotasks();
        expect(imports.asked, ['src-1'], reason: 'src-2 never starts');
        unawaited(s.dispose());
      });
    });

    test('off while a source is busy: nothing is imported after the '
        'wait', () {
      fakeAsync((async) {
        enabled = true;
        sources.seed();
        busy.add('src-1');
        final s = scheduler();
        unawaited(s.startUp());
        async.elapse(const Duration(seconds: 12));

        enabled = false;
        busy.clear();
        async.elapse(const Duration(minutes: 2));
        expect(imports.asked, isEmpty);
        unawaited(s.dispose());
      });
    });
  });

  group('while something plays', () {
    test('on a TV, a scheduled import waits for it to end, however long, '
        'and the source is not dropped', () {
      fakeAsync((async) {
        playing = true;
        sources.seed();
        final s = scheduler();
        unawaited(s.startUp());
        async.elapse(const Duration(hours: 3));
        expect(imports.asked, isEmpty);

        playing = false;
        async.elapse(const Duration(minutes: 1));
        expect(imports.asked, ['src-1']);
        unawaited(s.dispose());
      });
    });

    test('on a TV, the moment between two channels is no end', () {
      fakeAsync((async) {
        playing = true;
        sources.seed();
        final s = scheduler();
        unawaited(s.startUp());
        async.elapse(const Duration(minutes: 5));

        // Stopped for one look, then the next channel.
        playing = false;
        async.elapse(s.playPoll);
        playing = true;
        async.elapse(s.playPoll * 4);
        expect(imports.asked, isEmpty);

        playing = false;
        async.elapse(s.playPoll * 2);
        expect(imports.asked, ['src-1']);
        unawaited(s.dispose());
      });
    });

    test('on a TV, a guide refreshed by hand meanwhile is not imported '
        'again', () {
      fakeAsync((async) {
        playing = true;
        sources.seed();
        final s = scheduler();
        unawaited(s.startUp());
        async.elapse(const Duration(minutes: 10));
        fresh('src-1', hoursAgo: 0);

        playing = false;
        async.elapse(const Duration(minutes: 1));
        expect(imports.asked, isEmpty);
        unawaited(s.dispose());
      });
    });

    test('on a TV, nothing plays: the import starts at once', () {
      fakeAsync((async) {
        playing = false;
        sources.seed();
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1']);
        unawaited(s.dispose());
      });
    });

    test('on a desktop (no hold), playing holds nothing', () {
      fakeAsync((async) {
        sources.seed();
        final s = scheduler();
        unawaited(s.startUp());
        async.flushMicrotasks();
        expect(imports.asked, ['src-1']);
        unawaited(s.dispose());
      });
    });
  });

  test('dispose stops the hourly check', () {
    fakeAsync((async) {
      sources.seed();
      fresh('src-1');
      final s = scheduler();
      unawaited(s.startUp());
      async.flushMicrotasks();
      unawaited(s.dispose());
      now = now.add(const Duration(days: 2));
      async.elapse(const Duration(hours: 3));
      expect(imports.asked, isEmpty);
      expect(async.periodicTimerCount, 0);
    });
  });
}

/// Coverage and counts by source, as the test sets them.
final class _Guide implements EpgRepository {
  final coverages = <String, GuideCoverage>{};
  final counts = <String, ChannelMatchCounts>{};
  final cleared = <String>[];

  @override
  Future<Result<void>> clearGuide(String sourceId) async {
    cleared.add(sourceId);
    coverages.remove(sourceId);
    return const Ok(null);
  }

  @override
  Future<Result<GuideCoverage>> coverage(String sourceId) async =>
      Ok(coverages[sourceId] ?? const GuideCoverage());

  @override
  Stream<ChannelMatchCounts> watchChannelMatchCounts(String sourceId) =>
      Stream.value(counts[sourceId] ?? const ChannelMatchCounts());

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An importer that records its imports in [_guide] as the real one does:
/// a success swaps a guide in; a failure it ran is recorded; one that
/// couldn't start leaves nothing.
final class _Imports implements GuideImportService {
  new(this._guide, this._now);

  final _Guide _guide;
  final DateTime Function() _now;
  final asked = <String>[];
  final cancelled = <String>[];
  final running = <String>{};
  final recorded = <String, AppFailure>{};
  final unrecorded = <String, AppFailure>{};
  Completer<void>? gate;
  var _id = 100;

  @override
  bool isImporting(String sourceId) => running.contains(sourceId);

  /// Waits for the import that runs, as the real one does.
  @override
  Future<void> cancel(String sourceId) async {
    cancelled.add(sourceId);
    if (gate case final gate? when !gate.isCompleted) gate.complete();
    await _running;
  }

  Future<void>? _running;

  @override
  Future<Result<EpgImportCounts>> importGuide(String sourceId) {
    final run = _import(sourceId);
    _running = run;
    return run;
  }

  Future<Result<EpgImportCounts>> _import(String sourceId) async {
    asked.add(sourceId);
    await gate?.future;
    if (unrecorded[sourceId] case final failure?) return Err(failure);
    final now = _now();
    final previous = _guide.coverages[sourceId] ?? const GuideCoverage();
    if (recorded[sourceId] case final failure?) {
      _guide.coverages[sourceId] = GuideCoverage(
        updatedAt: previous.updatedAt,
        lastImport: GuideImport(
          id: ++_id,
          outcome: GuideImportOutcome.failed,
          startedAt: now,
          failureCode: failure.code,
        ),
      );
      return Err(failure);
    }
    _guide.coverages[sourceId] = GuideCoverage(
      programmes: 10,
      updatedAt: now,
      lastImport: GuideImport(
        id: ++_id,
        outcome: GuideImportOutcome.succeeded,
        startedAt: now,
      ),
    );
    return const Ok(EpgImportCounts());
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Silent extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
