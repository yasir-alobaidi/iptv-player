import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/platform/file_reveals.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// A file manager's `org.freedesktop.FileManager1`.
final class _FileManager extends DBusObject {
  new() : super(DBusObjectPath('/org/freedesktop/FileManager1'));

  final calls = <String>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.freedesktop.FileManager1' &&
        (call.name == 'ShowItems' || call.name == 'ShowFolders')) {
      calls.add('${call.name} ${call.values.first.asStringArray().join(' ')}');
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

void main() {
  late Directory temp;
  final closing = <Future<void> Function()>[];
  final started = <String>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('file_reveal');
    started.clear();
  });

  tearDown(() async {
    for (final close in closing.reversed) {
      await close();
    }
    closing.clear();
    await temp.delete(recursive: true);
  });

  AppLog log() => AppLog(output: MemoryOutput(), secrets: SecretRegistry());

  Future<void> start(String executable, List<String> arguments) async =>
      started.add([executable, ...arguments].join(' | '));

  Future<void> fail(String executable, List<String> arguments) async =>
      throw ProcessException(executable, arguments, 'not found');

  /// A file of [rel] under the temporary folder; its path.
  String make(String rel) {
    final file = File(p.join(temp.path, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    return file.path;
  }

  group('Linux', () {
    /// A session bus with a file manager on it, or nothing.
    Future<DBusAddress> bus({_FileManager? manager}) async {
      final server = DBusServer();
      final address = await server.listenAddress(
        DBusAddress.unix(dir: Directory((await temp.createTemp()).path)),
      );
      closing.add(server.close);
      if (manager != null) {
        final owner = DBusClient(address);
        await owner.requestName('org.freedesktop.FileManager1');
        await owner.registerObject(manager);
        closing.add(owner.close);
      }
      return address;
    }

    test('the file manager selects the file; a file gone opens the '
        'nearest folder still there', () async {
      final manager = _FileManager();
      final address = await bus(manager: manager);
      final reveal = DbusFileReveal(
        log: log(),
        session: () => DBusClient(address),
        start: start,
      );
      final video = make('Movies HDD/Paper Kites (2019)/Paper Kites.mkv');

      expect(await reveal.showInFolder(video), isTrue);
      final gone = p.join(temp.path, 'Movies HDD', 'Gone (2020)', 'Gone.mkv');
      expect(await reveal.showInFolder(gone), isTrue);

      expect(manager.calls, [
        'ShowItems ${Uri.file(video)}',
        'ShowFolders ${Uri.file(p.join(temp.path, 'Movies HDD'))}',
      ]);
      expect(
        manager.calls.first,
        contains('Paper%20Kites%20(2019)'),
        reason: 'a URI, spaces escaped',
      );
      expect(started, isEmpty);
    });

    test('no file manager on the bus: xdg-open on the folder', () async {
      final address = await bus();
      final video = make('Videos/clip.mp4');
      final reveal = DbusFileReveal(
        log: log(),
        session: () => DBusClient(address),
        start: start,
      );
      expect(await reveal.showInFolder(video), isTrue);
      expect(started, ['xdg-open | ${p.dirname(video)}']);
    });

    test('no bus and no xdg-open: false, never a throw', () async {
      final reveal = DbusFileReveal(
        log: log(),
        session: () =>
            DBusClient(DBusAddress.unix(path: p.join(temp.path, 'none'))),
        start: fail,
      );
      expect(await reveal.showInFolder(make('clip.mp4')), isFalse);
    });
  }, skip: Platform.isLinux ? null : 'the session bus is a Linux thing');

  group('Windows', () {
    test('Explorer selects the file, or opens the nearest folder', () async {
      final reveal = WindowsFileReveal(log: log(), start: start);
      final video = make('Movies/Paper Kites.mkv');
      expect(await reveal.showInFolder(video), isTrue);
      expect(
        await reveal.showInFolder(p.join(temp.path, 'Movies', 'Gone', 'x.mkv')),
        isTrue,
      );
      expect(started, [
        'explorer.exe | /select,$video',
        'explorer.exe | ${p.join(temp.path, 'Movies')}',
      ]);
    });

    test("Explorer that can't start: false", () async {
      final reveal = WindowsFileReveal(log: log(), start: fail);
      expect(await reveal.showInFolder(make('clip.mp4')), isFalse);
    });
  });

  test('the nearest folder: itself when there, else up to the root', () async {
    final deep = p.join(temp.path, 'a', 'b', 'c.mkv');
    expect(await nearestFolder(deep), temp.path);
    make(p.join('a', 'b', 'd.mkv'));
    expect(await nearestFolder(deep), p.join(temp.path, 'a', 'b'));
  });
}
