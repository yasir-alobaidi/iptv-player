import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/domain/guide_refresh.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:meta/meta.dart';

/// Imports guides on its own (ADR-011 decision 5): every source whose
/// guide is missing or a day old ([guideRefreshDue]), checked once the
/// launch's syncs are done and every hour after, and a source again when
/// its sync succeeds — after the sync, never beside it, and one source at
/// a time. A finished import says so in a toast ("Guide updated · 142
/// channels matched"); a failed one keeps the old guide and says so in
/// Settings → Guide only, never in a pop-up.
///
/// The importer does the work (`GuideImportService`): Refresh guide in
/// Settings joins an import this started, and this never starts one while
/// another runs for the same source.
///
/// With the guide switched off (ADR-031) it imports nothing, and clears
/// a guide still stored, at its checks and when the switch goes off; on
/// again, every source is looked at, as at a first launch. On a TV
/// ([_playing]), nothing is imported while anything plays.
final class GuideScheduler {
  new({
    required this._guide,
    required this._imports,
    required this._sources,
    required this._log,
    required this._settingsLoaded,
    required this._syncing,
    this._enabled,
    this._busy,
    this._playing,
    this._notify,
    DateTime Function()? clock,
    this.checkEvery = GuideRefreshPolicy.checkEvery,
    this.busyPoll = const Duration(seconds: 5),
    this.busyLimit = const Duration(minutes: 1),
    this.playPoll = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now;

  final EpgRepository _guide;
  final GuideImportService _imports;
  final SourceRepository _sources;
  final AppLog _log;

  /// Settings → Guide's stored choices: the first import waits for them,
  /// or it would keep the default days.
  final Future<void> Function() _settingsLoaded;

  /// True while the source's catalogue sync runs; its end brings the
  /// source back ([synced]).
  final bool Function(String sourceId) _syncing;

  /// Settings → Guide's switch (ADR-031), read at every step: off, no
  /// import starts. None means on.
  final bool Function()? _enabled;

  /// True while a stream from the source is being set up: the guide's
  /// request waits, so it never competes with the one connection a panel
  /// may allow (hard rule 7).
  final bool Function(String sourceId)? _busy;

  /// A TV's: true while anything plays, from any source. A scheduled
  /// import waits for it to end, however long (a manual Refresh doesn't:
  /// it never comes here). None on a desktop.
  final bool Function()? _playing;
  final void Function(AppNotice notice)? _notify;
  final DateTime Function() _clock;

  /// How often every source is looked at again after [startUp].
  final Duration checkEvery;

  /// How often, and for how long at most, an import waits while [_busy].
  final Duration busyPoll;
  final Duration busyLimit;

  /// How often an import held by [_playing] looks again.
  final Duration playPoll;

  /// Whether imports wait while anything plays: a TV's do.
  @visibleForTesting
  bool get holdsWhilePlaying => _playing != null;

  static const _tag = 'epg';

  /// Sources to look at, in the order asked; each once.
  final _queue = <String>{};

  /// Sources whose import couldn't even start — no guide address, a
  /// locked keyring — and recorded nothing: not asked again this session
  /// until they sync, so a locked keyring isn't prompted every hour.
  final _noGuide = <String>{};
  Future<void>? _draining;
  Timer? _timer;
  var _started = false;
  var _disposed = false;

  /// Once the launch's syncs are done: looks at every source, then every
  /// [checkEvery].
  Future<void> startUp() async {
    if (_started || _disposed) return;
    _started = true;
    _timer = Timer.periodic(checkEvery, (_) => unawaited(checkAll()));
    await checkAll();
  }

  bool get _on => _enabled?.call() ?? true;

  /// Looks at every source; returns once the queue has been worked
  /// through. With the guide off, clears what is still stored instead:
  /// at launch, a guide imported before the switch went off.
  Future<void> checkAll() async {
    if (_disposed) return;
    if (_enabled != null) {
      // The switch is one of the settings.
      await _settingsLoaded();
      if (_disposed) return;
      if (!_on) return await _clearStored();
    }
    switch (await _sources.all()) {
      case Ok(:final value):
        for (final source in value) {
          _enqueue(source.id);
        }
      case Err(:final failure):
        _log.warning(
          _tag,
          'Guide check: the sources could not be read '
          '(${failure.code})',
        );
    }
    await _drain();
  }

  /// A sync of [sourceId] succeeded: its guide may be due (a first sync
  /// has none), and a source that had no guide address may have one now.
  void synced(String sourceId) {
    if (_disposed) return;
    _noGuide.remove(sourceId);
    _enqueue(sourceId);
    unawaited(_drain());
  }

  /// The guide was switched on: every source is looked at, those that
  /// had no guide address too, as at a first launch. Before [startUp],
  /// the launch's check does it.
  Future<void> switchedOn() async {
    if (_disposed) return;
    _noGuide.clear();
    await checkAll();
  }

  /// The guide was switched off: nothing more is imported, a running
  /// import is cancelled, and every stored guide is cleared. The user's
  /// own matches, offsets and reminders stay.
  Future<void> switchedOff() async {
    if (_disposed) return;
    _queue.clear();
    final all = (await _sources.all()).valueOrNull ?? const <Source>[];
    for (final source in all) {
      // Waits for it to end: one already swapping in finishes first, and
      // is cleared after it.
      await _imports.cancel(source.id);
    }
    await _clearStored();
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _queue.clear();
  }

  /// Clears every source's stored guide, if it has one. No VACUUM: the
  /// file shrinks at the launch's compaction.
  Future<void> _clearStored() async {
    final List<Source> all;
    switch (await _sources.all()) {
      case Ok(:final value):
        all = value;
      case Err(:final failure):
        _log.warning(
          _tag,
          'Guide off: the sources could not be read (${failure.code})',
        );
        return;
    }
    for (final source in all) {
      if (_disposed) return;
      final coverage = (await _guide.coverage(source.id)).valueOrNull;
      if (coverage == null || !coverage.hasGuide) continue;
      switch (await _guide.clearGuide(source.id)) {
        case Ok():
          _log.info(
            _tag,
            'Guide off: cleared the stored guide of ${source.id} '
            '(${coverage.programmes} programmes)',
          );
        case Err(:final failure):
          _log.warning(
            _tag,
            'Guide off: could not clear the guide of ${source.id} '
            '(${failure.code})',
          );
      }
    }
  }

  void _enqueue(String sourceId) {
    if (!_noGuide.contains(sourceId)) _queue.add(sourceId);
  }

  /// Works through the queue, one source at a time; a call while that
  /// runs waits for the same run. Nothing runs before [startUp]: the
  /// launch's syncs come first.
  Future<void> _drain() {
    if (!_started || _disposed) return Future.value();
    return _draining ??= _run().whenComplete(() {
      _draining = null;
      // Queued as the run was ending.
      if (_queue.isNotEmpty && !_disposed) unawaited(_drain());
    });
  }

  Future<void> _run() async {
    await _settingsLoaded();
    while (_queue.isNotEmpty && !_disposed) {
      if (!_on) {
        _queue.clear();
        break;
      }
      final sourceId = _queue.first;
      _queue.remove(sourceId);
      try {
        await _refresh(sourceId);
      } on Object catch (error, stackTrace) {
        _log.error(
          _tag,
          'Guide check $sourceId failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _refresh(String sourceId) async {
    if (_syncing(sourceId) || _imports.isImporting(sourceId)) return;
    final GuideCoverage coverage;
    switch (await _guide.coverage(sourceId)) {
      case Ok(:final value):
        coverage = value;
      case Err(:final failure):
        _log.warning(_tag, 'Guide check $sourceId: ${failure.code}');
        return;
    }
    if (!guideRefreshDue(coverage, _clock())) return;
    if (await _holdWhilePlaying()) {
      // Everything again: the wait may have lasted a film, and a Refresh
      // or a sync may have come meanwhile.
      if (_disposed || !_on) return;
      return await _refresh(sourceId);
    }
    if (!await _waitWhileBusy(sourceId)) return;
    // Looked at again: the sync may have started while this waited, or
    // the guide gone off.
    if (_syncing(sourceId) || _disposed || !_on) return;

    _log.info(_tag, 'Guide $sourceId is due: importing it');
    switch (await _imports.importGuide(sourceId)) {
      case Ok():
        await _announce(sourceId);
      case Err(failure: CancelledFailure()):
        break;
      case Err(:final failure):
        // An import that ran recorded its failure for Settings → Guide;
        // one that couldn't start recorded nothing.
        final after = (await _guide.coverage(sourceId)).valueOrNull;
        if (after?.lastImport?.id == coverage.lastImport?.id) {
          _noGuide.add(sourceId);
          _log.info(
            _tag,
            'Guide $sourceId: not imported (${failure.code}); not asked '
            'again until it syncs',
          );
        }
    }
  }

  /// On a TV, while anything plays: waits until nothing has played at
  /// two looks in a row ([playPoll] apart; the moment between two
  /// channels is no end), then says it waited. The source is never
  /// dropped. False at once when nothing plays.
  Future<bool> _holdWhilePlaying() async {
    final playing = _playing;
    if (playing == null || !playing()) return false;
    _log.info(_tag, 'Guide import held: something is playing');
    var quiet = 0;
    while (quiet < 2) {
      await Future<void>.delayed(playPoll);
      if (_disposed || !_on) return true;
      quiet = playing() ? 0 : quiet + 1;
    }
    return true;
  }

  /// False when the source stayed busy past [busyLimit]: the next check
  /// tries again.
  Future<bool> _waitWhileBusy(String sourceId) async {
    final busy = _busy;
    if (busy == null) return true;
    var waited = Duration.zero;
    while (busy(sourceId)) {
      if (_disposed || !_on || waited >= busyLimit) return false;
      await Future<void>.delayed(busyPoll);
      waited += busyPoll;
    }
    return true;
  }

  Future<void> _announce(String sourceId) async {
    final notify = _notify;
    if (notify == null) return;
    try {
      final counts = await _guide.watchChannelMatchCounts(sourceId).first;
      final all = (await _sources.all()).valueOrNull ?? const <Source>[];
      final source = all.length > 1
          ? all.where((s) => s.id == sourceId).firstOrNull?.name
          : null;
      notify(
        AppNotice(
          guideUpdatedMessage(counts.matched, source: source),
          tone: NoticeTone.success,
        ),
      );
    } on Object catch (error) {
      // The guide is in; only the toast is lost.
      _log.warning(_tag, 'Guide $sourceId: no toast (${error.runtimeType})');
    }
  }
}
