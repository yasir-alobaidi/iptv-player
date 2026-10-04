import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';

void main() {
  DownloadTask task({int done = 0, int? total, double? speed}) => DownloadTask(
    id: 1,
    sourceId: 'src-1',
    type: VodType.movie,
    remoteKey: '100000',
    title: 'Copper Hollow',
    targetPath: '/v/Movies/Copper Hollow (2025)/Copper Hollow (2025).mkv',
    state: DownloadTaskState.downloading,
    downloadedBytes: done,
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 10, 4),
    totalBytes: total,
    speed: speed,
  );

  test('progress and time left need the size, and time left the speed', () {
    expect(task(done: 50).progress, isNull);
    expect(task(done: 50, total: 200).progress, 0.25);
    expect(task(done: 300, total: 200).progress, 1.0);
    expect(task(done: 50, total: 200).timeLeft, isNull);
    expect(
      task(done: 1000000, total: 9400000, speed: 8400000).timeLeft,
      const Duration(seconds: 1),
    );
    expect(task(done: 200, total: 200, speed: 10).timeLeft, Duration.zero);
    expect(task(done: 50, total: 200, speed: 0).timeLeft, isNull);
  });

  test("the states' groups", () {
    expect(
      [
        for (final s in DownloadTaskState.values)
          if (s.isActive) s,
      ],
      [
        DownloadTaskState.connecting,
        DownloadTaskState.downloading,
        DownloadTaskState.verifying,
      ],
    );
    expect(
      [
        for (final s in DownloadTaskState.values)
          if (s.isPending) s,
      ],
      [
        DownloadTaskState.queued,
        DownloadTaskState.waitingForConnection,
        DownloadTaskState.retrying,
      ],
    );
    expect(
      [
        for (final s in DownloadTaskState.values)
          if (s.isFinished) s,
      ],
      [
        DownloadTaskState.completed,
        DownloadTaskState.failed,
        DownloadTaskState.canceled,
      ],
    );
  });

  group('download settings', () {
    test('round-trip through JSON', () {
      const settings = DownloadSettings(
        folder: '/media/films',
        atATime: 2,
        speedLimit: DownloadSpeedLimit.mbps20,
        resumeOnLaunch: false,
        keepAwake: false,
      );
      expect(DownloadSettings.fromJson(settings.toJson()), settings);
      expect(
        DownloadSettings.fromJson(const DownloadSettings().toJson()),
        const DownloadSettings(),
      );
    });

    test('anything odd reads as the default (hard rule 1)', () {
      for (final json in <Object?>[
        null,
        'yes',
        42,
        <Object?>[],
        {
          'folder': '  ',
          'at_a_time': '3',
          'speed_limit_mbps': 33,
          'resume_on_launch': 'no',
          'keep_awake': null,
        },
      ]) {
        expect(
          DownloadSettings.fromJson(json),
          const DownloadSettings(),
          reason: '$json',
        );
      }
      expect(DownloadSettings.fromJson(const {'at_a_time': 9}).atATime, 3);
      expect(DownloadSettings.fromJson(const {'at_a_time': 0}).atATime, 1);
    });

    test('a speed limit in bytes a second', () {
      expect(DownloadSpeedLimit.unlimited.bytesPerSecond, isNull);
      expect(DownloadSpeedLimit.mbps10.bytesPerSecond, 1250000);
      expect(DownloadSpeedLimit.mbps50.bytesPerSecond, 6250000);
    });
  });
}
