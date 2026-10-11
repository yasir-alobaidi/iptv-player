import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/downloads/presentation/download_text.dart';

import '../../library/presentation/library_ui_support.dart';

void main() {
  // Local, as the screen reads the day.
  final now = DateTime(2026, 10, 11, 15);

  test('a download is listed by what it is doing; one finished on an '
      'earlier day is not listed', () {
    DownloadSection? of(
      DownloadTaskState state, {
      DownloadProblem? problem,
      DateTime? at,
    }) => downloadSectionOf(
      download(1, 'A', state: state, problem: problem, completedAt: at),
      now,
    );
    for (final state in [
      DownloadTaskState.queued,
      DownloadTaskState.connecting,
      DownloadTaskState.downloading,
      DownloadTaskState.waitingForConnection,
      DownloadTaskState.retrying,
      DownloadTaskState.verifying,
      DownloadTaskState.paused,
    ]) {
      expect(of(state), DownloadSection.inProgress, reason: '$state');
    }
    expect(of(DownloadTaskState.failed), DownloadSection.needsAttention);
    for (final problem in [DownloadProblem.auth, DownloadProblem.noSpace]) {
      expect(
        of(DownloadTaskState.paused, problem: problem),
        DownloadSection.needsAttention,
        reason: 'only the user can put $problem right',
      );
    }
    expect(of(DownloadTaskState.canceled), isNull);
    expect(
      of(DownloadTaskState.completed, at: DateTime(2026, 10, 11, 0, 5)),
      DownloadSection.finished,
    );
    expect(
      of(DownloadTaskState.completed, at: DateTime(2026, 10, 10, 23, 55)),
      isNull,
    );
    expect(of(DownloadTaskState.completed), isNull);
  });

  test('the sections keep the queue order; finished are newest first', () {
    final sections = downloadSections([
      download(1, 'A', state: DownloadTaskState.downloading),
      download(
        2,
        'B',
        state: DownloadTaskState.completed,
        completedAt: DateTime(2026, 10, 11, 13),
      ),
      download(3, 'C'),
      download(4, 'D', state: DownloadTaskState.failed),
      download(
        5,
        'E',
        state: DownloadTaskState.completed,
        completedAt: DateTime(2026, 10, 11, 14),
      ),
    ], now);
    expect([for (final t in sections.inProgress) t.id], [1, 3]);
    expect([for (final t in sections.needsAttention) t.id], [4]);
    expect([for (final t in sections.finished) t.id], [5, 2]);
  });

  test('a movie and an episode, as the canvas names them', () {
    final movie = download(1, 'Copper Hollow', year: 2025);
    final episode = download(
      2,
      'Northbound',
      type: VodType.episode,
      show: 'Glass Tide',
      season: 2,
      episode: 5,
    );
    expect(downloadTitle(movie), 'Copper Hollow');
    expect(downloadSubtitle(movie), 'Movie · 2025');
    expect(downloadSubtitle(download(1, 'Copper Hollow')), 'Movie');
    expect(downloadTitle(episode), 'Glass Tide');
    expect(downloadSubtitle(episode), 'S2 · E5 · Northbound');
    expect(downloadName(episode), 'Glass Tide · S2 · E5 · Northbound');
    expect(downloadName(movie), 'Copper Hollow');
  });

  test('what a download is doing, in words', () {
    const gb = 1024 * 1024 * 1024;
    final running = download(
      1,
      'Copper Hollow',
      state: DownloadTaskState.downloading,
      downloaded: (1.03 * gb).round(),
      total: (2.1 * gb).round(),
      speed: 8.4 * 1024 * 1024,
    );
    expect(downloadStateWord(running), '49%');
    expect(downloadStateDetails(running), [
      '1.0 GB of 2.1 GB',
      '8.4 MB/s',
      'about 2 min left',
    ]);
    expect(
      downloadStateWord(download(1, 'A', state: DownloadTaskState.downloading)),
      'Downloading',
      reason: 'no size from the server',
    );

    final queued = download(2, 'Northbound', total: (0.9 * gb).round());
    expect(downloadStateWord(queued), 'Queued');
    expect(downloadStateDetails(queued, before: running), [
      'starts after Copper Hollow',
      '922 MB',
    ]);
    expect(downloadStateDetails(download(2, 'B')), isEmpty);

    expect(
      downloadStateDetails(
        running.copyWith(state: DownloadTaskState.paused, speed: null),
      ),
      ['1.0 GB of 2.1 GB'],
    );
    expect(
      downloadStateDetails(
        download(3, 'C', state: DownloadTaskState.waitingForConnection),
      ),
      ["your provider's connection is in use"],
    );
    expect(
      downloadStateWord(download(3, 'C', state: DownloadTaskState.retrying)),
      'Trying again',
    );
    expect(downloadSpeed(640 * 1024), '640 KB/s');
    expect(
      downloadTimeLeft(const Duration(seconds: 20)),
      'less than a minute left',
    );
    expect(
      downloadTimeLeft(const Duration(minutes: 80)),
      'about 1 h 20 min left',
    );
  });

  test('every problem has its own words, and none is a raw error', () {
    final texts = {
      for (final problem in [...DownloadProblem.values, null])
        downloadProblemText(
          download(
            1,
            'A',
            state: DownloadTaskState.failed,
            problem: problem,
          ).copyWith(problemDetail: 'SocketException: errno 104'),
        ),
    };
    expect(texts, hasLength(DownloadProblem.values.length + 1));
    expect(texts.where((text) => text.contains('Exception')), isEmpty);
    expect(
      downloadProblemText(
        download(
          1,
          'A',
          type: VodType.episode,
          state: DownloadTaskState.failed,
          problem: DownloadProblem.notFound,
        ),
      ),
      'This episode is no longer available from your provider.',
    );
  });

  test('the finished line and the meter', () {
    expect(
      downloadFinishedLine(
        download(
          1,
          'Northwind Hotel',
          state: DownloadTaskState.completed,
          total: (3.4 * 1024 * 1024 * 1024).round(),
          completedAt: DateTime(2026, 10, 11, 14, 14),
        ),
      ),
      '3.4 GB · finished at 2:14 PM',
    );
    expect(downloadsUsedLabel(45419225907), 'Downloads 42.3 GB');
    expect(
      downloadsFreeLabel((free: 118 * 1073741824, total: 512 * 1073741824)),
      '118 GB free of 512 GB',
    );
    expect(downloadsFreeLabel(null), '');
  });
}
