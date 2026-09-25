import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';

void main() {
  test('where the guide comes from', () {
    expect(
      guideOriginLabel(const GuideOrigin(GuideOriginKind.panel)),
      "From your provider's XMLTV",
    );
    expect(
      guideOriginLabel(const GuideOrigin(GuideOriginKind.sourceUrl)),
      'From the EPG URL set for this source',
    );
    expect(
      guideOriginLabel(
        const GuideOrigin(GuideOriginKind.sourceUrl, isFile: true),
      ),
      'From the guide file set for this source',
    );
    expect(
      guideOriginLabel(const GuideOrigin(GuideOriginKind.playlist)),
      'From the EPG URL your playlist names',
    );
  });

  test('how many channels matched', () {
    expect(matchedLine(const ChannelMatchCounts()), 'No channels to match yet');
    expect(
      matchedLine(const ChannelMatchCounts(channels: 1, matched: 1)),
      'Its one channel is matched',
    );
    expect(
      matchedLine(const ChannelMatchCounts(channels: 1310, matched: 1310)),
      'All 1,310 channels matched',
    );
    expect(
      matchedLine(const ChannelMatchCounts(channels: 1310, matched: 1284)),
      '1,284 of 1,310 channels matched',
    );
    expect(
      matchedLine(const ChannelMatchCounts(channels: 1)),
      '0 of 1 channel matched',
    );
  });

  test('what the guide covers', () {
    expect(coverageLine(const GuideCoverage()), '');
    expect(coverageLine(const GuideCoverage(programmes: 1)), '1 programme');
    expect(
      coverageLine(
        GuideCoverage(
          programmes: 142880,
          lastEnd: DateTime.utc(2026, 9, 28, 12),
        ),
      ),
      '142,880 programmes until Sep 28',
    );
  });

  test('why an import failed', () {
    GuideImport failed(String? code, {int? status}) => GuideImport(
      id: 1,
      outcome: GuideImportOutcome.failed,
      startedAt: DateTime.utc(2026),
      failureCode: code,
      failureStatus: status,
    );
    expect(
      importFailureMessage(failed('interrupted')),
      'The app was closed before it finished.',
    );
    expect(
      importFailureMessage(failed('network')),
      startsWith("Can't reach the server."),
    );
    expect(
      importFailureMessage(failed('network', status: 503)),
      contains('HTTP 503'),
    );
    expect(
      importFailureMessage(failed(null)),
      contains('Something went wrong'),
    );
  });

  test('an import in progress', () {
    expect(importProgressLine(null), 'Importing the guide…');
    expect(
      importProgressLine(const EpgImportProgress()),
      'Importing the guide…',
    );
    expect(
      importProgressLine(
        const EpgImportProgress(bytesRead: 2 * 1024 * 1024, programmes: 1),
      ),
      'Importing the guide · 2.0 MB · 1 programme',
    );
    expect(
      importProgressLine(
        const EpgImportProgress(
          bytesRead: 1024 * 1024,
          totalBytes: 4 * 1024 * 1024,
          programmes: 1204,
        ),
      ),
      'Importing the guide · 1.0 MB of 4.0 MB · 1,204 programmes',
    );
  });

  test('days kept', () {
    expect(keepDaysLabel(1), '1 day');
    expect(keepDaysLabel(7), '7 days');
  });

  test('time offsets, with a real minus sign', () {
    expect(guideOffsetLabel(0), 'None');
    expect(guideOffsetLabel(30), '+30 min');
    expect(guideOffsetLabel(60), '+1 h');
    expect(guideOffsetLabel(90), '+1 h 30 min');
    expect(guideOffsetLabel(-60), '−1 h');
    expect(guideOffsetLabel(-150), '−2 h 30 min');
    expect(guideOffsetLabel(-720), '−12 h');
  });

  test('what a channel is attached to', () {
    ChannelGuideMatch channel({
      String? id,
      GuideMatchRule? rule,
      String? label,
      bool inGuide = true,
    }) => ChannelGuideMatch(
      channelId: 1,
      sourceId: 's',
      remoteKey: '1',
      name: 'Arena Sports 1',
      providerName: 'Arena Sports 1',
      xmltvId: id,
      rule: rule,
      guideLabel: label,
      inGuide: inGuide,
    );
    expect(matchStatus(channel()), 'No guide channel');
    expect(
      matchStatus(
        channel(
          id: 'arena1.uk',
          rule: GuideMatchRule.normalizedName,
          label: 'Arena 1',
        ),
      ),
      '→ Arena 1 · by name',
    );
    expect(
      matchStatus(channel(id: 'arena1.uk', rule: GuideMatchRule.exactId)),
      '→ arena1.uk · by id',
    );
    expect(
      matchStatus(
        channel(id: 'ARENA1.uk', rule: GuideMatchRule.caseInsensitiveId),
      ),
      '→ ARENA1.uk · by id',
    );
    expect(
      matchStatus(
        channel(id: 'arena1.uk', rule: GuideMatchRule.manual, label: 'Arena'),
      ),
      '→ Arena · yours',
    );
    expect(
      matchStatus(
        channel(id: 'gone.uk', rule: GuideMatchRule.manual, inGuide: false),
      ),
      '→ gone.uk · yours, not in this guide',
    );
  });
}
