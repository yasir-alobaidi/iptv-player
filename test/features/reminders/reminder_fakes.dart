import 'dart:async';

import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';

/// Reminders kept in memory.
final class FakeReminders implements ReminderRepository {
  final _held = <int, Reminder>{};
  final _changes = StreamController<List<Reminder>>.broadcast();
  int _nextId = 1;

  /// Makes every read fail with this.
  AppFailure? readFailure;

  /// Makes [remove] fail with this.
  AppFailure? removeFailure;

  /// Makes [set] fail with this.
  AppFailure? setFailure;

  /// Makes [watchAll] fail with this instead of listing anything.
  AppFailure? watchFailure;

  /// Ids removed, in order.
  final removed = <int>[];

  List<Reminder> get sorted => _held.values.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });

  void _changed() => _changes.add(sorted);

  /// Sets one without going through a draft.
  Reminder add({
    required DateTime start,
    Duration length = const Duration(hours: 1),
    String title = 'The Harbor Pilot',
    String channelName = 'Blue Water',
    String channelKey = '212',
    String sourceId = 'src-1',
    String xmltvId = 'bluewater.uk',
  }) {
    final reminder = Reminder(
      id: _nextId++,
      sourceId: sourceId,
      channelKey: channelKey,
      xmltvId: xmltvId,
      channelName: channelName,
      title: title,
      start: start,
      end: start.add(length),
    );
    _held[reminder.id] = reminder;
    _changed();
    return reminder;
  }

  @override
  Stream<List<Reminder>> watchAll() async* {
    if (watchFailure case final failure?) throw failure;
    yield sorted;
    yield* _changes.stream;
  }

  @override
  Future<Result<List<Reminder>>> all() async =>
      readFailure == null ? Ok(sorted) : Err(readFailure!);

  @override
  Future<Result<List<Reminder>>> forSource(String sourceId) async =>
      readFailure == null
      ? Ok([
          for (final reminder in sorted)
            if (reminder.sourceId == sourceId) reminder,
        ])
      : Err(readFailure!);

  @override
  Future<Result<Reminder>> set(ReminderDraft draft) async {
    if (setFailure case final failure?) return Err(failure);
    for (final held in _held.values) {
      if (held.isFor(
        sourceId: draft.sourceId,
        channelKey: draft.channelKey,
        start: draft.start,
      )) {
        return Ok(held);
      }
    }
    return Ok(
      add(
        start: draft.start,
        length: draft.end.difference(draft.start),
        title: draft.title,
        channelName: draft.channelName,
        channelKey: draft.channelKey,
        sourceId: draft.sourceId,
        xmltvId: draft.xmltvId,
      ),
    );
  }

  @override
  Future<Result<bool>> remove(int id) async {
    if (removeFailure case final failure?) return Err(failure);
    final was = _held.remove(id) != null;
    if (was) {
      removed.add(id);
      _changed();
    }
    return Ok(was);
  }

  @override
  Future<Result<void>> move(int id, DateTime start, DateTime end) async {
    final held = _held[id];
    if (held == null) return Err(StorageFailure('no reminder $id'));
    for (final other in _held.values) {
      if (other.id != id &&
          other.isFor(
            sourceId: held.sourceId,
            channelKey: held.channelKey,
            start: start,
          )) {
        return Err(StorageFailure('reminder $id: another is there'));
      }
    }
    _held[id] = held.movedTo(start, end);
    _changed();
    return const Ok(null);
  }
}

/// A guide that answers what a test set for each title.
final class FakeReminderGuide implements ReminderGuide {
  final answers = <String, GuideAnswer>{};
  AppFailure? failure;
  final asked = <String>[];

  @override
  Future<Result<GuideAnswer>> lookUp({
    required String sourceId,
    required String xmltvId,
    required String title,
    required DateTime around,
    required Duration within,
  }) async {
    asked.add('$sourceId/$xmltvId/$title');
    if (failure case final failure?) return Err(failure);
    return Ok(answers[title] ?? const GuideAnswer());
  }
}

/// The desktop's notifications, recorded.
final class FakeNotifier implements SystemNotifier {
  /// False: this system has no notifications.
  bool works = true;
  final shown = <SystemNotice>[];
  final _responses = StreamController<NoticeResponse>.broadcast();

  @override
  Future<bool> show(SystemNotice notice) async {
    if (!works) return false;
    shown.add(notice);
    return true;
  }

  @override
  Stream<NoticeResponse> get responses => _responses.stream;

  /// The user did this with a notice.
  void answer(NoticeResponse response) => _responses.add(response);

  @override
  Future<void> dispose() => _responses.close();
}
