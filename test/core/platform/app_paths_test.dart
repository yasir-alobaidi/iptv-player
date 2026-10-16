import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/app_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  test('the log is under the app folder, unless given a folder of its own '
      "(Android's, which adb reads: ADR-027)", () {
    final root = Directory('/data/app');
    expect(AppPaths(root).logs.path, p.join('/data/app', 'logs'));
    expect(
      AppPaths(root, logDirectory: Directory('/sdcard/bijou/logs')).logs.path,
      '/sdcard/bijou/logs',
    );
    expect(AppPaths(root).processes.path, p.join('/data/app', 'processes'));
  });
}
