import 'dart:async';

/// How a notice reads: news, good news, or a problem.
enum NoticeTone { neutral, success, error }

/// A short message about something that happened in the background
/// ("Guide updated · 142 channels matched", docs/05). The shell shows it
/// as a toast.
///
/// Neither const nor `==`: the same message twice (tomorrow's "Guide
/// updated") is two notices, and a listener that compares values would
/// drop the second.
final class AppNotice {
  new(
    this.message, {
    this.tone = NoticeTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final NoticeTone tone;

  /// One action on the toast: "Undo" after a remove or a hide (docs/05:
  /// optimistic updates).
  final String? actionLabel;
  final void Function()? onAction;

  @override
  String toString() => 'AppNotice($message)';
}

/// Background work tells the user what it did through this, without
/// knowing where or how it is shown (the shell's toast area).
final class AppNotices {
  final _notices = StreamController<AppNotice>.broadcast();

  Stream<AppNotice> get stream => _notices.stream;

  void show(AppNotice notice) {
    if (!_notices.isClosed) _notices.add(notice);
  }

  Future<void> dispose() => _notices.close();
}
