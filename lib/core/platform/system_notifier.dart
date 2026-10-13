import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_notifier.g.dart';

/// Something to tell the user through the desktop's own notifications:
/// a title, a line under it, and one thing they can do about it.
///
/// Whoever makes one keeps secrets out of it (hard rule 3): it leaves
/// the app, and the desktop may keep it.
@immutable
final class SystemNotice {
  const new({
    required this.id,
    required this.title,
    required this.body,
    this.action,
  });

  /// Ours, to tell which notice the user answered.
  final int id;
  final String title;
  final String body;

  /// The label of its one button ("Watch"); null for none.
  final String? action;
}

/// The user did something with a notice.
@immutable
final class NoticeResponse {
  const new(this.id, {required this.chosen, this.activationToken});

  final int id;

  /// True when they pressed its button, or clicked it where a click
  /// means the same. False when all that is known is that they closed
  /// it: on some desktops (GNOME) a click on the notice's own body
  /// brings the app's window forward and tells the app only that the
  /// notice is gone, so the caller checks whether the window came to the
  /// front.
  final bool chosen;

  /// What the desktop handed out with the click, which lets the app
  /// bring its own window forward (Wayland refuses a window that raises
  /// itself without it); null where the desktop gives none.
  final String? activationToken;

  @override
  String toString() =>
      'NoticeResponse($id, chosen: $chosen'
      '${activationToken == null ? '' : ', with a token'})';
}

/// The desktop's notifications (Phase 9 decision 11): our own D-Bus
/// client on Linux, a package on Windows, and nothing where there is no
/// notification service — the caller then says it inside the app.
abstract interface class SystemNotifier {
  /// Shows [notice]. False when this system can't, for any reason: the
  /// caller falls back. Never throws.
  Future<bool> show(SystemNotice notice);

  /// What users did with the notices shown.
  Stream<NoticeResponse> get responses;

  Future<void> dispose();
}

/// A system with no notifications: every notice is the caller's to show.
final class NoSystemNotifier implements SystemNotifier {
  const new();

  @override
  Future<bool> show(SystemNotice notice) async => false;

  @override
  Stream<NoticeResponse> get responses => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// `bootstrap()` gives the system's. (Not named `systemNotifier`: the
/// generator drops a trailing "Notifier" from a provider's name.)
@Riverpod(keepAlive: true)
SystemNotifier systemNotifications(Ref ref) => const NoSystemNotifier();
