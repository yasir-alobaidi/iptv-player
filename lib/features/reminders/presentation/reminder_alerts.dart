import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/domain/reminder_scheduler.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';

const _tag = 'reminders';

/// The user chose Watch on a reminder.
final class ReminderWatch {
  const new(this.reminder, {this.activationToken});

  final Reminder reminder;

  /// What the desktop handed out with the click, for bringing the window
  /// forward; null from a toast (the window is in front already) and
  /// from desktops that hand out none.
  final String? activationToken;
}

/// Says a reminder when it is due (Phase 9 decision 10, sketch I): by
/// the desktop when the window is covered or minimized, inside the app
/// when it is in front — a notification on top of the app you are
/// looking at is noise — and inside the app whenever the desktop can't.
final class ReminderAlerts {
  new({
    required this._notifier,
    required this._window,
    required this._notices,
    required this._timeStyle,
    required this._log,
    DateTime Function()? clock,
    this.focusWait = const Duration(seconds: 1),
  }) : _clock = clock ?? DateTime.now {
    _answers = _notifier.responses.listen(
      (response) => unawaited(_onResponse(response)),
      onError: (Object _) {},
    );
  }

  final SystemNotifier _notifier;
  final WindowControls _window;
  final AppNotices _notices;
  final TimeStyle Function() _timeStyle;
  final AppLog _log;
  final DateTime Function() _clock;

  /// How long a closed notice is given to turn out to have been a click
  /// (GNOME brings the window forward and tells the app only that the
  /// notice is gone).
  final Duration focusWait;

  /// The notices the desktop still shows, by our id, oldest first.
  final _shown = <int, Reminder>{};
  static const _keep = 32;
  int _nextId = 1;

  final _watches = StreamController<ReminderWatch>.broadcast();
  late final StreamSubscription<NoticeResponse> _answers;
  bool _disposed = false;

  /// Each Watch the user chose, on a notice or a toast. Whoever plays
  /// the channel listens.
  Stream<ReminderWatch> get watches => _watches.stream;

  /// Shows [due]: the scheduler's `onDue`.
  Future<void> show(DueReminder due) async {
    if (_disposed) return;
    final style = _timeStyle();
    final reminder = due.reminder;
    var focused = true;
    try {
      focused = await _window.isFocused();
    } on Object {
      // Not known: inside the app, which is never wrong.
    }
    if (!focused) {
      final id = _nextId++;
      _shown[id] = reminder;
      if (_shown.length > _keep) _shown.remove(_shown.keys.first);
      final shown = await _notifier.show(
        SystemNotice(
          id: id,
          title: reminder.title,
          body: reminderNoticeBody(due, style),
          action: 'Watch',
        ),
      );
      if (shown) return;
      _shown.remove(id);
      _log.info(_tag, 'No system notification: shown inside the app');
    }
    _notices.show(
      AppNotice(
        reminderToast(due, style),
        actionLabel: 'Watch',
        onAction: () => _watch(ReminderWatch(reminder)),
      ),
    );
  }

  Future<void> _onResponse(NoticeResponse response) async {
    final reminder = _shown.remove(response.id);
    if (reminder == null || _disposed) return;
    if (response.chosen) {
      _watch(
        ReminderWatch(reminder, activationToken: response.activationToken),
      );
      return;
    }
    // Closed, on a desktop where a click on the notice itself brings the
    // window forward: if the window is in front a moment later, that was
    // the click, and the user wants the channel.
    final until = DateTime.now().add(focusWait);
    while (!_disposed) {
      var focused = false;
      try {
        focused = await _window.isFocused();
      } on Object {
        focused = false;
      }
      if (focused) {
        _watch(ReminderWatch(reminder));
        return;
      }
      if (!DateTime.now().isBefore(until)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _watch(ReminderWatch watch) {
    if (!_disposed) _watches.add(watch);
  }

  /// Says what a guide refresh did to the reminders: one that moved by
  /// five minutes or more, and one whose programme is gone (decision
  /// 12). A small move says nothing.
  void sayFollowed(List<FollowedReminder> changed) {
    if (_disposed) return;
    final style = _timeStyle();
    final now = _clock();
    for (final followed in changed) {
      switch (followed.outcome) {
        case ReminderMoved(:final start, :final worthSaying):
          if (!worthSaying) continue;
          _notices.show(
            AppNotice(reminderMovedText(followed.before, start, now, style)),
          );
        case ReminderGone():
          _notices.show(AppNotice(reminderGoneText(followed.before)));
        case ReminderKept():
          break;
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _answers.cancel();
    await _watches.close();
  }
}
