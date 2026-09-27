import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_refresh.dart';

final _now = DateTime.utc(2026, 9, 27, 12);

GuideCoverage _coverage({
  Duration? updatedAgo,
  GuideImportOutcome? last,
  Duration startedAgo = const Duration(hours: 1),
  String? failureCode,
}) => GuideCoverage(
  updatedAt: updatedAgo == null ? null : _now.subtract(updatedAgo),
  lastImport: last == null
      ? null
      : GuideImport(
          id: 1,
          outcome: last,
          startedAt: _now.subtract(startedAgo),
          failureCode: failureCode,
        ),
);

void main() {
  test('a source that never imported is due', () {
    expect(guideRefreshDue(_coverage(), _now), isTrue);
  });

  test('a guide younger than a day is not; a day old, it is', () {
    expect(
      guideRefreshDue(
        _coverage(
          updatedAgo: const Duration(hours: 23, minutes: 59),
          last: GuideImportOutcome.succeeded,
        ),
        _now,
      ),
      isFalse,
    );
    expect(
      guideRefreshDue(
        _coverage(
          updatedAgo: const Duration(hours: 24),
          last: GuideImportOutcome.succeeded,
          startedAgo: const Duration(hours: 24),
        ),
        _now,
      ),
      isTrue,
    );
  });

  test('never while an import runs', () {
    expect(
      guideRefreshDue(_coverage(last: GuideImportOutcome.running), _now),
      isFalse,
    );
  });

  test('a failed or cancelled import waits six hours; one the app was '
      'closed during does not', () {
    for (final outcome in [
      GuideImportOutcome.failed,
      GuideImportOutcome.cancelled,
    ]) {
      expect(
        guideRefreshDue(
          _coverage(
            last: outcome,
            startedAgo: const Duration(hours: 5, minutes: 59),
          ),
          _now,
        ),
        isFalse,
        reason: outcome.name,
      );
      expect(
        guideRefreshDue(
          _coverage(last: outcome, startedAgo: const Duration(hours: 6)),
          _now,
        ),
        isTrue,
        reason: outcome.name,
      );
    }
    expect(
      guideRefreshDue(
        _coverage(
          last: GuideImportOutcome.failed,
          failureCode: interruptedImportCode,
          startedAgo: const Duration(minutes: 5),
        ),
        _now,
      ),
      isTrue,
    );
  });

  test('a fresh guide stays even after a failed refresh', () {
    expect(
      guideRefreshDue(
        _coverage(
          updatedAgo: const Duration(hours: 2),
          last: GuideImportOutcome.failed,
          startedAgo: const Duration(hours: 7),
        ),
        _now,
      ),
      isFalse,
    );
  });
}
