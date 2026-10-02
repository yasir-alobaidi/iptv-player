import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('ffmpeg_binaries'));
  tearDown(() => root.deleteSync(recursive: true));

  void put(String folder, List<String> names, {bool executable = true}) {
    Directory(folder).createSync(recursive: true);
    for (final name in names) {
      final file = File(p.join(folder, name))..writeAsStringSync('#!/bin/sh');
      if (executable && !Platform.isWindows) {
        Process.runSync('chmod', ['+x', file.path]);
      }
    }
  }

  String app(String folder) => p.join(root.path, folder, 'iptv_player');

  // The two that find something run as the platform they are on: the
  // execute bits they check exist only off Windows.
  final windows = Platform.isWindows;
  final exe = windows ? '.exe' : '';

  test('beside the executable, where the builds put them', () {
    put(p.join(root.path, 'bundle', 'ffmpeg'), ['ffmpeg$exe', 'ffprobe$exe']);

    final found = FfmpegBinaries.locate(
      executable: app('bundle'),
      workingDirectory: root.path,
      windows: windows,
    );

    final folder = p.join(root.path, 'bundle', 'ffmpeg');
    expect(found!.ffmpeg, p.join(folder, 'ffmpeg$exe'));
    expect(found.ffprobe, p.join(folder, 'ffprobe$exe'));
  });

  test("else in a checkout's third_party, from a folder inside it", () {
    final third = p.join(
      root.path,
      'third_party',
      'ffmpeg',
      windows ? 'windows-x64' : 'linux-x64',
    );
    put(third, ['ffmpeg$exe', 'ffprobe$exe']);

    final found = FfmpegBinaries.locate(
      executable: app('elsewhere'),
      workingDirectory: p.join(root.path, 'tools', 'deep'),
      windows: windows,
    );

    expect(found!.ffmpeg, p.join(third, 'ffmpeg$exe'));
  });

  test('the Windows names on Windows', () {
    put(p.join(root.path, 'bundle', 'ffmpeg'), ['ffmpeg.exe', 'ffprobe.exe']);

    final found = FfmpegBinaries.locate(
      executable: app('bundle'),
      workingDirectory: root.path,
      windows: true,
    );

    expect(p.basename(found!.ffmpeg), 'ffmpeg.exe');
    expect(p.basename(found.ffprobe), 'ffprobe.exe');
  });

  test('one of the two missing: none', () {
    put(p.join(root.path, 'bundle', 'ffmpeg'), ['ffmpeg']);

    expect(
      FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      ),
      isNull,
    );
  });

  test('nothing anywhere: none', () {
    expect(
      FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      ),
      isNull,
    );
  });

  test('not executable on Linux: none', () {
    put(p.join(root.path, 'bundle', 'ffmpeg'), [
      'ffmpeg',
      'ffprobe',
    ], executable: false);

    expect(
      FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      ),
      isNull,
    );
  }, skip: Platform.isWindows ? 'no execute bits on Windows' : null);

  test('a folder where the file should be: none', () {
    Directory(p.join(root.path, 'bundle', 'ffmpeg', 'ffmpeg'))
        .createSync(recursive: true);
    put(p.join(root.path, 'bundle', 'ffmpeg'), ['ffprobe']);

    expect(
      FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      ),
      isNull,
    );
  });

  group('the bundled libva (Linux)', () {
    const linuxOnly = 'execute bits and libva: Linux';
    final skip = Platform.isWindows ? linuxOnly : null;

    test("beside FFmpeg in a build's ffmpeg/libva/", () {
      final folder = p.join(root.path, 'bundle', 'ffmpeg');
      put(folder, ['ffmpeg', 'ffprobe']);
      put(p.join(folder, 'libva'), ['libva.so.2', 'libva-drm.so.2']);

      final found = FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      );

      expect(found!.libva, p.join(folder, 'libva'));
    }, skip: skip);

    test("in a checkout's third_party/libva/linux-x64/", () {
      final third = p.join(root.path, 'third_party');
      put(p.join(third, 'ffmpeg', 'linux-x64'), ['ffmpeg', 'ffprobe']);
      put(p.join(third, 'libva', 'linux-x64'), ['libva.so.2']);

      final found = FfmpegBinaries.locate(
        executable: app('elsewhere'),
        workingDirectory: p.join(root.path, 'lib'),
        windows: false,
      );

      expect(found!.libva, p.join(third, 'libva', 'linux-x64'));
    }, skip: skip);

    test('none fetched: FFmpeg without it', () {
      put(p.join(root.path, 'bundle', 'ffmpeg'), ['ffmpeg', 'ffprobe']);

      final found = FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: false,
      );

      expect(found, isNotNull);
      expect(found!.libva, isNull);
      expect(found.libvaEnvironment(), isEmpty);
    }, skip: skip);

    test('never on Windows', () {
      final folder = p.join(root.path, 'bundle', 'ffmpeg');
      put(folder, ['ffmpeg.exe', 'ffprobe.exe']);
      put(p.join(folder, 'libva'), ['libva.so.2']);

      final found = FfmpegBinaries.locate(
        executable: app('bundle'),
        workingDirectory: root.path,
        windows: true,
      );

      expect(found!.libva, isNull);
    });

    test('found before the system libraries, keeping any already set', () {
      const binaries = FfmpegBinaries(
        ffmpeg: '/app/ffmpeg/ffmpeg',
        ffprobe: '/app/ffmpeg/ffprobe',
        libva: '/app/ffmpeg/libva',
      );

      expect(binaries.libvaEnvironment(const {}), {
        'LD_LIBRARY_PATH': '/app/ffmpeg/libva',
      });
      expect(binaries.libvaEnvironment(const {'LD_LIBRARY_PATH': ''}), {
        'LD_LIBRARY_PATH': '/app/ffmpeg/libva',
      });
      expect(binaries.libvaEnvironment(const {'LD_LIBRARY_PATH': '/opt/lib'}), {
        'LD_LIBRARY_PATH': '/app/ffmpeg/libva:/opt/lib',
      });
    });
  });
}
