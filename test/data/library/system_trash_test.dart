import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/library/system_trash.dart';
import 'package:path/path.dart' as p;

void main() {
  if (!Platform.isLinux) {
    test('the freedesktop trash', () {}, skip: 'Linux');
    return;
  }
  late Directory temp;
  late String home;
  late String usb;
  late SystemTrash trash;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('trash_');
    home = p.join(temp.path, 'home');
    usb = p.join(temp.path, 'media', 'usb');
    Directory(home).createSync(recursive: true);
    Directory(usb).createSync(recursive: true);
    trash = SystemTrash(
      environment: {'HOME': home},
      // Two drives: the USB stick, and everything else.
      mountOf: (path) => p.isWithin(usb, path) || path == usb ? usb : temp.path,
      uid: () => 1000,
      now: () => DateTime(2026, 10, 4, 21, 5, 9),
    );
  });

  tearDown(() {
    Process.runSync('chmod', ['-R', 'u+w', temp.path]);
    temp.deleteSync(recursive: true);
  });

  File make(String path, [String content = 'video']) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  test('a file on the home drive goes to the home trash, with its '
      '.trashinfo', () async {
    final file = make(p.join(home, 'Videos', 'Paper Kites (2019).mkv'));
    expect(await trash.trash(file.path), TrashOutcome.trashed);
    expect(file.existsSync(), isFalse);
    final bin = p.join(home, '.local', 'share', 'Trash');
    expect(
      File(p.join(bin, 'files', 'Paper Kites (2019).mkv')).readAsStringSync(),
      'video',
    );
    expect(
      File(p.join(bin, 'info', 'Paper Kites (2019).mkv.trashinfo'))
          .readAsStringSync(),
      '[Trash Info]\n'
      'Path=${p.join(home, 'Videos', 'Paper%20Kites%20(2019).mkv')}\n'
      'DeletionDate=2026-10-04T21:05:09\n',
    );
  });

  test('a name already in the trash gets a number', () async {
    for (var i = 0; i < 3; i++) {
      final file = make(p.join(home, 'clip.mp4'), 'take $i');
      expect(await trash.trash(file.path), TrashOutcome.trashed);
    }
    final files = p.join(home, '.local', 'share', 'Trash', 'files');
    expect(File(p.join(files, 'clip.mp4')).readAsStringSync(), 'take 0');
    expect(File(p.join(files, 'clip.2.mp4')).readAsStringSync(), 'take 1');
    expect(File(p.join(files, 'clip.3.mp4')).readAsStringSync(), 'take 2');
  });

  test("a file on another drive goes to that drive's own trash, by a "
      'rename, with a path relative to the drive', () async {
    final file = make(p.join(usb, 'Films', 'Ember Road.mkv'));
    expect(await trash.trash(file.path), TrashOutcome.trashed);
    final bin = p.join(usb, '.Trash-1000');
    expect(File(p.join(bin, 'files', 'Ember Road.mkv')).existsSync(), isTrue);
    expect(
      File(p.join(bin, 'info', 'Ember Road.mkv.trashinfo')).readAsStringSync(),
      contains('Path=Films/Ember%20Road.mkv\n'),
    );
    expect(
      Directory(p.join(home, '.local', 'share', 'Trash')).existsSync(),
      isFalse,
    );
  });

  test("a drive's shared .Trash is used only with its sticky bit", () async {
    final shared = Directory(p.join(usb, '.Trash'))..createSync();
    var file = make(p.join(usb, 'a.mkv'));
    await trash.trash(file.path);
    expect(
      File(p.join(usb, '.Trash-1000', 'files', 'a.mkv')).existsSync(),
      isTrue,
    );

    Process.runSync('chmod', ['1777', shared.path]);
    file = make(p.join(usb, 'b.mkv'));
    await trash.trash(file.path);
    expect(
      File(p.join(shared.path, '1000', 'files', 'b.mkv')).existsSync(),
      isTrue,
    );
  });

  test('a drive that takes no trash: no trash, and the file stays', () async {
    final file = make(p.join(usb, 'kept.mkv'));
    Process.runSync('chmod', ['0555', usb]);
    expect(await trash.trash(file.path), TrashOutcome.noTrash);
    expect(file.existsSync(), isTrue);
  });

  test('the real mount table answers for this machine', () async {
    final real = SystemTrash(environment: {'HOME': home});
    final file = make(p.join(home, 'real.mkv'));
    expect(await real.trash(file.path), TrashOutcome.trashed);
    expect(
      File(p.join(home, '.local', 'share', 'Trash', 'files', 'real.mkv'))
          .existsSync(),
      isTrue,
    );
  });
}
