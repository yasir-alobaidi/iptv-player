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
  });

  GuideScheduler scheduler() => GuideScheduler(
    guide: guide,
    imports: imports,
    sources: sources,
    log: AppLog(output: _Silent(), secrets: SecretRegistry()),
    settingsLoaded: () => settings?.future ?? Future<void>.value(),
    syncing: syncing.contains,
    busy: busy.contains,
    notify: notices.add,
    clock: () => now,
  );

  /// A guide that arrived [hoursAgo] hours ago.
  void fresh(String sourceId, {int hoursAgo = 1}) =>
      guide.coverages[sourceId] = GuideCoverage(
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
  final running = <String>{};
  final recorded = <String, AppFailure>{};
  final unrecorded = <String, AppFailure>{};
  Completer<void>? gate;
  var _id = 100;

  @override
  bool isImporting(String sourceId) => running.contains(sourceId);

  @override
  Future<Result<EpgImportCounts>> importGuide(String sourceId) async {
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
