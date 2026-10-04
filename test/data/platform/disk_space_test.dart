import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/platform/disk_space.dart';

void main() {
  test('the free space of the drive holding a folder, which need not exist '
      'yet', () async {
    final folder = Directory.systemTemp.createTempSync('disk_space_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final free = freeBytes(folder.path);
    expect(free, isNotNull);
    expect(free, greaterThan(0));

    // `df` agrees within what other programs wrote meanwhile.
    final df = await Process.run('df', ['-B1', '--output=avail', folder.path]);
    final reported = int.parse(
      (df.stdout as String).trim().split('\n').last.trim(),
    );
    expect((free! - reported).abs(), lessThan(256 * 1024 * 1024));

    final notYet = '${folder.path}/IPTV Player/Movies/x';
    expect(freeBytes(notYet), closeTo(free, 256 * 1024 * 1024));
  }, skip: Platform.isLinux ? false : 'statvfs and df: Linux');
}
