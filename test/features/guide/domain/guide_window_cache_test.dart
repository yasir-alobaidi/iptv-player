import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_window_cache.dart';

final _t0 = DateTime.utc(2026, 9, 15, 20);

DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

/// A query for the window of [ids] from [from] to [to] minutes past [_t0].
String _window(List<int> ids, int from, int to) =>
    '$ids ${_at(from).toIso8601String()} ${_at(to).toIso8601String()}';

void main() {
  late _Guide guide;
  late GuideWindowCache cache;
  var notified = 0;

  setUp(() {
    guide = _Guide();
    cache = GuideWindowCache(guide, maxChannels: 4)
      ..addListener(() => notified++);
    notified = 0;
    // Channel 1: back-to-back programmes; 2: one long one; 3: no guide.
    guide
      ..add(1, 1, 'Early', -120, 90)
      ..add(1, 2, 'Now', -30, 60)
      ..add(1, 3, 'Next', 30, 60)
      ..add(1, 4, 'Late', 300, 60)
      ..add(2, 5, 'Marathon', -600, 900)
      ..withGuide.addAll({1, 2});
  });
  tearDown(() => cache.dispose());

  Future<void> settle() => pumpEventQueue();

  test('nothing until the hours asked for are read, then the rows', () async {
    expect(cache.row(1, _t0, _at(120)), isNull);

    cache.request([1, 2, 3], _t0, _at(120));
    expect(cache.row(1, _t0, _at(120)), isNull, reason: 'still loading');
    await settle();

    expect(notified, 1);
    expect(cache.row(1, _t0, _at(120))!.programmes.map((p) => p.title), [
      'Now',
      'Next',
    ]);
    expect(cache.row(2, _t0, _at(120))!.programmes.single.title, 'Marathon');
    final none = cache.row(3, _t0, _at(120))!;
    expect(none.hasGuide, isFalse);
    expect(none.programmes, isEmpty);
    expect(guide.windows, [
      _window([1, 2, 3], 0, 120),
    ]);
    expect(guide.guideAsked, [
      [1, 2, 3],
    ]);
  });

  test('reads only the hours and channels it lacks, whole hours', () async {
    cache.request([1, 2], _at(10), _at(70));
    await settle();
    expect(guide.windows.single, _window([1, 2], 0, 120));

    // Inside what was read: no query.
    cache.request([1, 2], _at(0), _at(120));
    await settle();
    expect(guide.windows, hasLength(1));

    // An hour further: those hours only; nothing asked about the guide
    // again for channels it already knows.
    cache.request([1, 2], _at(60), _at(180));
    await settle();
    expect(guide.windows.last, _window([1, 2], 120, 180));
    expect(guide.guideAsked, hasLength(1));

    // A new channel over the same hours: that channel only.
    cache.request([1, 2, 3], _at(0), _at(180));
    await settle();
    expect(guide.windows.last, _window([3], 0, 180));
    expect(guide.guideAsked.last, [3]);
    expect(cache.known(1).map((p) => p.title), ['Now', 'Next']);
  });

  test('one query at a time: a request made meanwhile waits, and a newer '
      'one replaces it', () async {
    guide.gate = Completer<void>();
    cache.request([1], _t0, _at(60));
    await settle();
    cache
      ..request([2], _t0, _at(60))
      ..request([3], _t0, _at(60));
    expect(guide.guideAsked, hasLength(1));

    guide.gate!.complete();
    guide.gate = null;
    await settle();

    expect(guide.windows, [
      _window([1], 0, 60),
      _window([3], 0, 60),
    ]);
    expect(cache.row(2, _t0, _at(60)), isNull, reason: 'replaced');
    expect(cache.row(3, _t0, _at(60))!.hasGuide, isFalse);
  });

  test('a reset forgets everything, and a load running across it is '
      'dropped', () async {
    cache.request([1], _t0, _at(60));
    await settle();
    expect(cache.row(1, _t0, _at(60)), isNotNull);

    guide.gate = Completer<void>();
    cache.request([1], _at(60), _at(120));
    await settle();
    cache.reset();
    expect(cache.row(1, _t0, _at(60)), isNull);

    guide.add(1, 9, 'Replaced', 60, 60);
    guide.gate!.complete();
    guide.gate = null;
    await settle();
    expect(
      cache.row(1, _at(60), _at(120)),
      isNull,
      reason: 'read from the old guide',
    );

    cache.request([1], _at(60), _at(120));
    await settle();
    expect(cache.row(1, _at(60), _at(120))!.programmes.map((p) => p.title), [
      'Next',
      'Replaced',
    ]);
  });

  test('forgets the channels asked about least recently', () async {
    cache.request([1, 2, 3, 4], _t0, _at(60));
    await settle();
    cache
      ..request([1], _t0, _at(60))
      ..request([5, 6], _t0, _at(60));
    await settle();

    expect(cache.channelCount, 4);
    expect(cache.isRead(1, _t0, _at(60)), isTrue, reason: 'asked again');
    expect(cache.isRead(2, _t0, _at(60)), isFalse);
    expect(cache.isRead(3, _t0, _at(60)), isFalse);
    expect(cache.isRead(4, _t0, _at(60)), isTrue);
    expect(cache.isRead(5, _t0, _at(60)), isTrue);
  });

  test('a failure stops loading until a retry', () async {
    guide.failure = StorageFailure('locked');
    cache.request([1], _t0, _at(60));
    await settle();
    expect(cache.failure, isA<StorageFailure>());
    expect(cache.row(1, _t0, _at(60)), isNull);

    guide.failure = null;
    cache.request([1], _t0, _at(60));
    await settle();
    expect(guide.guideAsked, hasLength(1), reason: 'held until a retry');

    cache
      ..retry()
      ..request([1], _t0, _at(60));
    await settle();
    expect(cache.failure, isNull);
    expect(cache.row(1, _t0, _at(60))!.programmes.map((p) => p.title), [
      'Now',
      'Next',
    ]);
  });

  test("a channel's revision moves when a load for it lands or the cache "
      'resets, not for other channels', () async {
    final before = cache.revisionOf(1);
    cache.request([2], _t0, _at(60));
    await settle();
    expect(cache.revisionOf(1), before, reason: 'another channel');

    cache.request([1], _t0, _at(60));
    await settle();
    final loaded = cache.revisionOf(1);
    expect(loaded, isNot(before));

    cache.reset();
    expect(cache.revisionOf(1), isNot(loaded));
  });

  test('a row between two programmes holds both halves once', () async {
    cache.request([1], _at(-60), _at(60));
    await settle();

    final row = cache.row(1, _at(-40), _at(40))!;
    expect(row.programmes.map((p) => p.title), ['Early', 'Now', 'Next']);
    expect(cache.row(1, _at(0), _at(30))!.programmes.single.title, 'Now');
  });
}

/// A guide over channel ids, answering from what the test put in.
final class _Guide implements EpgRepository {
  final _programmes = <int, List<EpgProgramme>>{};
  final withGuide = <int>{};
  final windows = <String>[];
  final guideAsked = <List<int>>[];
  Completer<void>? gate;
  AppFailure? failure;

  void add(int channel, int id, String title, int from, int minutes) {
    (_programmes[channel] ??= []).add(
      EpgProgramme(
        id: id,
        channelId: 'guide.$channel',
        start: _at(from),
        end: _at(from + minutes),
        title: title,
      ),
    );
  }

  @override
  Future<Result<Set<int>>> channelsWithGuide(List<int> channelIds) async {
    guideAsked.add(channelIds);
    await gate?.future;
    if (failure case final failure?) return Err(failure);
    return Ok(channelIds.where(withGuide.contains).toSet());
  }

  @override
  Future<Result<Map<int, List<EpgProgramme>>>> windowForChannels(
    List<int> channelIds,
    DateTime from,
    DateTime to,
  ) async {
    windows.add(
      '$channelIds ${from.toIso8601String()} ${to.toIso8601String()}',
    );
    await gate?.future;
    if (failure case final failure?) return Err(failure);
    return Ok({
      for (final id in channelIds)
        id: [
          for (final p in _programmes[id] ?? const <EpgProgramme>[])
            if (p.start.isBefore(to) && p.end.isAfter(from)) p,
        ],
    });
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
