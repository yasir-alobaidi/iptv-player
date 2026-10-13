import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/data/platform/dbus_notifier.dart';
import 'package:logger/logger.dart';

/// A desktop's `org.freedesktop.Notifications`, as much of it as the app
/// speaks: it records what it is told to show and lets a test do what a
/// user would.
final class _Desktop extends DBusObject {
  new({this.server = 'kwin-notifications', this.version = '6.1'})
    : super(DBusObjectPath('/org/freedesktop/Notifications'));

  static const _interface = 'org.freedesktop.Notifications';

  final String server;
  final String version;

  /// Each Notify, whole.
  final shown = <List<DBusValue>>[];
  int _nextId = 41;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (call.name) {
      case 'GetServerInformation':
        return DBusMethodSuccessResponse([
          DBusString(server),
          const DBusString('Test'),
          DBusString(version),
          const DBusString('1.2'),
        ]);
      case 'Notify':
        shown.add(call.values);
        return DBusMethodSuccessResponse([DBusUint32(++_nextId)]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  int get lastId => _nextId;

  /// The user pressed [action] on notice [id].
  Future<void> press(int id, String action, {String? token}) async {
    if (token != null) {
      await emitSignal(_interface, 'ActivationToken', [
        DBusUint32(id),
        DBusString(token),
      ]);
    }
    await emitSignal(_interface, 'ActionInvoked', [
      DBusUint32(id),
      DBusString(action),
    ]);
  }

  /// Notice [id] went away: 1 expired, 2 dismissed by the user, 3 closed
  /// by the app.
  Future<void> close(int id, int reason) => emitSignal(
    _interface,
    'NotificationClosed',
    [DBusUint32(id), DBusUint32(reason)],
  );
}

void main() {
  late Directory temp;
  final closing = <Future<void> Function()>[];

  setUp(() async => temp = await Directory.systemTemp.createTemp('notifier'));
  tearDown(() async {
    for (final close in closing.reversed) {
      await close();
    }
    closing.clear();
    await temp.delete(recursive: true);
  });

  /// A session bus with [desktop]'s notification service on it, or with
  /// none.
  Future<DBusAddress> bus({_Desktop? desktop}) async {
    final server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(dir: Directory((await temp.createTemp()).path)),
    );
    closing.add(server.close);
    if (desktop != null) {
      final owner = DBusClient(address);
      await owner.requestName('org.freedesktop.Notifications');
      await owner.registerObject(desktop);
      closing.add(owner.close);
    }
    return address;
  }

  Future<(DbusNotifier, List<NoticeResponse>)> notifier(
    DBusAddress address,
  ) async {
    final made = DbusNotifier(
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      session: () => DBusClient(address),
      timeout: const Duration(seconds: 2),
    );
    closing.add(made.dispose);
    final responses = <NoticeResponse>[];
    made.responses.listen(responses.add);
    return (made, responses);
  }

  const notice = SystemNotice(
    id: 7,
    title: 'The Harbor Pilot',
    body: 'Starting now on Blue Water',
    action: 'Watch',
  );

  /// Lets signals cross the bus.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  test('what is sent: the app, the title, the line under it, a Watch button, '
      'and a click on the notice meaning the same', () async {
    final desktop = _Desktop();
    final (made, _) = await notifier(await bus(desktop: desktop));

    expect(await made.show(notice), isTrue);

    final sent = desktop.shown.single;
    expect(sent[0].asString(), 'IPTV Player');
    expect(sent[1].asUint32(), 0, reason: 'replaces nothing');
    expect(sent[3].asString(), 'The Harbor Pilot');
    expect(sent[4].asString(), 'Starting now on Blue Water');
    expect(sent[5].asStringArray(), ['default', 'Watch', 'watch', 'Watch']);
    final hints = sent[6].asStringVariantDict();
    expect(
      hints['desktop-entry']!.asString(),
      'io.github.yasiralobaidi.iptvplayer',
    );
    expect(hints['urgency']!.asByte(), 1);
    expect(sent[7].asInt32(), -1, reason: "the desktop's own time on screen");
  });

  test('nothing but the title and the line is in it: no address, no '
      'sign-in could be', () async {
    final desktop = _Desktop();
    final (made, _) = await notifier(await bus(desktop: desktop));
    await made.show(notice);

    final text = desktop.shown.single.map((v) => v.toString()).join(' ');
    for (final secretish in ['http', '://', 'password', 'username', '@']) {
      expect(text, isNot(contains(secretish)), reason: secretish);
    }
  });

  test('Watch: the app is told which notice, once', () async {
    final desktop = _Desktop();
    final (made, responses) = await notifier(await bus(desktop: desktop));
    await made.show(notice);

    await desktop.press(desktop.lastId, 'watch');
    await settle();
    // The desktop then closes the notice it was pressed on.
    await desktop.close(desktop.lastId, 2);
    await settle();

    expect(responses, hasLength(1));
    expect(responses.single.id, 7);
    expect(responses.single.chosen, isTrue);
    expect(responses.single.activationToken, isNull);
  });

  test('a click on the notice itself is the same as Watch', () async {
    final desktop = _Desktop();
    final (made, responses) = await notifier(await bus(desktop: desktop));
    await made.show(notice);

    await desktop.press(desktop.lastId, 'default');
    await settle();

    expect(responses.single.chosen, isTrue);
  });

  test('a desktop that hands out an activation token with the click: the '
      'app gets it, to bring its window forward', () async {
    final desktop = _Desktop();
    final (made, responses) = await notifier(await bus(desktop: desktop));
    await made.show(notice);

    await desktop.press(desktop.lastId, 'watch', token: 'token-9f2');
    await settle();

    expect(responses.single.activationToken, 'token-9f2');
  });

  test(
    'closed unread, expired or closed by the app: nothing is told',
    () async {
      final desktop = _Desktop();
      final (made, responses) = await notifier(await bus(desktop: desktop));
      for (final reason in [1, 2, 3]) {
        await made.show(notice);
        await desktop.close(desktop.lastId, reason);
      }
      await settle();

      expect(responses, isEmpty);
    },
  );

  test(
    'an action or a token for a notice that isn’t ours is ignored',
    () async {
      final desktop = _Desktop();
      final (made, responses) = await notifier(await bus(desktop: desktop));
      await made.show(notice);

      await desktop.press(9999, 'watch', token: 'someone-elses');
      await desktop.press(desktop.lastId, 'another-action');
      await settle();

      expect(responses, isEmpty);
    },
  );

  test('two notices: each answer names its own', () async {
    final desktop = _Desktop();
    final (made, responses) = await notifier(await bus(desktop: desktop));
    await made.show(notice);
    final first = desktop.lastId;
    await made.show(
      const SystemNotice(
        id: 8,
        title: 'Late Scores',
        body: 'b',
        action: 'Watch',
      ),
    );

    await desktop.press(desktop.lastId, 'watch');
    await desktop.press(first, 'watch');
    await settle();

    expect([for (final r in responses) r.id], [8, 7]);
  });

  group('GNOME Shell', () {
    test('is told of no default action: there a click on the notice brings '
        'the window forward by itself', () async {
      final desktop = _Desktop(server: 'gnome-shell', version: '42.9');
      final (made, _) = await notifier(await bus(desktop: desktop));

      await made.show(notice);

      expect(desktop.shown.single[5].asStringArray(), ['watch', 'Watch']);
    });

    test('a notice the user closed is told as closed, not chosen: the '
        'caller looks at the window', () async {
      final desktop = _Desktop(server: 'gnome-shell', version: '42.9');
      final (made, responses) = await notifier(await bus(desktop: desktop));
      await made.show(notice);

      await desktop.close(desktop.lastId, 2);
      await settle();

      expect(responses.single.id, 7);
      expect(responses.single.chosen, isFalse);
    });

    test('one that only expired is told to nobody; Watch is told as chosen '
        'and not again as closed', () async {
      final desktop = _Desktop(server: 'gnome-shell', version: '42.9');
      final (made, responses) = await notifier(await bus(desktop: desktop));
      await made.show(notice);
      await desktop.close(desktop.lastId, 1);
      await made.show(notice);
      await desktop.press(desktop.lastId, 'watch');
      await settle();
      await desktop.close(desktop.lastId, 2);
      await settle();

      expect([for (final r in responses) r.chosen], [true]);
    });
  });

  test('a notice with no button has no actions at all', () async {
    final desktop = _Desktop();
    final (made, _) = await notifier(await bus(desktop: desktop));

    await made.show(const SystemNotice(id: 1, title: 't', body: 'b'));

    expect(desktop.shown.single[5].asStringArray(), isEmpty);
  });

  test('no notification service at all: false, so the reminder is said '
      'inside the app; and asked again the next time', () async {
    final address = await bus();
    final (made, responses) = await notifier(address);

    expect(await made.show(notice), isFalse);
    expect(await made.show(notice), isFalse);
    expect(responses, isEmpty);
  });

  test('no session bus at all: false, never a throw', () async {
    final made = DbusNotifier(
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
      session: () =>
          DBusClient(DBusAddress.unix(path: '${temp.path}/no-such-bus')),
      timeout: const Duration(seconds: 2),
    );
    closing.add(made.dispose);

    expect(await made.show(notice), isFalse);
  });

  test('once disposed it shows nothing', () async {
    final desktop = _Desktop();
    final (made, _) = await notifier(await bus(desktop: desktop));
    await made.show(notice);

    await made.dispose();

    expect(await made.show(notice), isFalse);
    expect(desktop.shown, hasLength(1));
  });
}
