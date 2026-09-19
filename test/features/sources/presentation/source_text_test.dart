import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/source_text.dart';

void main() {
  final now = DateTime(2026, 9, 14, 12);

  Source source() => Source(
    id: 's1',
    type: SourceType.xtream,
    name: 'Northwind',
    displayUrl: 'http://line.test',
    liveFormat: LiveFormat.ts,
    epgOffsetMinutes: 0,
    refreshHours: 12,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );

  group('accountSummary', () {
    test('status, trial and expiry', () {
      expect(
        accountSummary(
          ProviderAccount(status: 'active', expiresAt: DateTime(2026, 11, 3)),
          now,
        ),
        'Active · exp Nov 3',
      );
      expect(
        accountSummary(
          ProviderAccount(
            status: 'Active',
            isTrial: true,
            expiresAt: DateTime(2027, 2),
          ),
          now,
        ),
        'Active · Trial · exp Feb 1, 2027',
      );
      expect(
        accountSummary(const ProviderAccount(status: 'Banned'), now),
        'Banned',
      );
    });

    test('an expired account says when', () {
      expect(
        accountSummary(
          ProviderAccount(status: 'Active', expiresAt: DateTime(2026, 9)),
          now,
        ),
        'Expired Sep 1, 2026',
      );
    });
  });

  test('countsSummary leaves empty lists out', () {
    expect(
      countsSummary(const SourceCounts(channels: 12340, series: 1)),
      '12,340 channels · 1 series',
    );
    expect(countsSummary(const SourceCounts(movies: 1)), '1 movie');
    expect(
      countsSummary(const SourceCounts()),
      'No channels, movies or series',
    );
  });

  test('syncFailureMessage phrases stored codes, never raw text', () {
    expect(
      syncFailureMessage('timeout'),
      'The server took too long to answer.',
    );
    expect(
      syncFailureMessage(interruptedSyncCode),
      'The app was closed before it finished.',
    );
    expect(syncFailureMessage('something new'), contains('went wrong'));
    expect(syncFailureMessage(null), contains('went wrong'));
  });

  test('syncProgressLine counts what the stage writes', () {
    expect(
      syncProgressLine(const SyncProgress(stage: SyncStage.account)),
      'Signing in',
    );
    expect(
      syncProgressLine(const SyncProgress(stage: SyncStage.live)),
      'Syncing channels',
    );
    expect(
      syncProgressLine(
        const SyncProgress(stage: SyncStage.live, channels: 12340),
      ),
      'Syncing channels · 12,340',
    );
    expect(
      syncProgressLine(
        const SyncProgress(stage: SyncStage.playlist, channels: 10, movies: 5),
      ),
      'Reading the playlist · 15',
    );
  });

  group('sourceNotice', () {
    SourceOverview ending(DateTime at, [String status = 'Active']) =>
        SourceOverview(
          account: ProviderAccount(status: status, expiresAt: at),
        );

    test('nothing for a healthy or unknown account', () {
      expect(sourceNotice(source(), const SourceOverview(), now), isNull);
      expect(sourceNotice(source(), ending(DateTime(2026, 12)), now), isNull);
    });

    test('expiring: today, tomorrow, in N days', () {
      String? message(Duration left) =>
          sourceNotice(source(), ending(now.add(left)), now)?.message;

      expect(message(const Duration(hours: 5)), contains('ends today'));
      expect(message(const Duration(days: 1, hours: 1)), contains('tomorrow'));
      expect(message(const Duration(days: 6, hours: 1)), contains('in 6 days'));
      expect(message(const Duration(days: 7, hours: 1)), isNull);
    });

    test('most urgent first: refused sign-in, expired, not active', () {
      final refused = SourceOverview(
        account: ProviderAccount(
          status: 'Expired',
          expiresAt: DateTime(2026, 9),
        ),
        lastSync: LastSync(
          outcome: LastSyncOutcome.failed,
          startedAt: now,
          failureCode: 'auth',
        ),
      );
      expect(
        sourceNotice(source(), refused, now)!.kind,
        SourceNoticeKind.signInRefused,
      );
      expect(
        sourceNotice(source(), refused.copyWith(lastSync: null), now)!.kind,
        SourceNoticeKind.expired,
      );
      expect(
        sourceNotice(source(), ending(DateTime(2027), 'Disabled'), now)!.kind,
        SourceNoticeKind.notActive,
      );
      // A failed sync for any other reason is the Sources page's to show.
      expect(
        sourceNotice(
          source(),
          SourceOverview(
            lastSync: LastSync(
              outcome: LastSyncOutcome.failed,
              startedAt: now,
              failureCode: 'network',
            ),
          ),
          now,
        ),
        isNull,
      );
    });
  });
}
