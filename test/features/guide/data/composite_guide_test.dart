import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/data/composite_guide.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';

final _at = DateTime.utc(2026, 9, 20, 20);

void main() {
  late _Guide imported;
  late _Guide short;
  late CompositeGuide guide;

  const arena = ChannelItem(
    id: 1,
    sourceId: 's1',
    remoteKey: '201',
    name: 'Arena Sports 1',
  );
  const velocity = ChannelItem(
    id: 3,
    sourceId: 's1',
    remoteKey: '203',
    name: 'Velocity Motors',
  );

  Programme programme(String title, {int from = -20}) => Programme(
    title: title,
    start: _at.add(Duration(minutes: from)),
    end: _at.add(Duration(minutes: from + 60)),
  );

  setUp(() {
    imported = _Guide();
    short = _Guide();
    guide = CompositeGuide(imported: imported, fallback: short);
  });

  group('nowNext', () {
    test('the imported guide answers when it has a programme on now', () async {
      imported.answers['201'] = NowNext(now: programme('Continental Cup'));

      final found = await guide.nowNext(arena);

      expect(found.valueOrNull!.now!.title, 'Continental Cup');
      expect(short.asked, isEmpty);
    });

    test('and when it has only one to come (a gap)', () async {
      imported.answers['201'] = NowNext(next: programme('Late', from: 20));

      final found = await guide.nowNext(arena);

      expect(found.valueOrNull!.next!.title, 'Late');
      expect(short.asked, isEmpty);
    });

    test('the short EPG answers for an unmatched channel, or one whose '
        'guide has run out', () async {
      short.answers['203'] = NowNext(now: programme('Grand Prix'));

      final found = await guide.nowNext(velocity);

      expect(imported.asked, ['203']);
      expect(short.asked, ['203']);
      expect(found.valueOrNull!.now!.title, 'Grand Prix');
    });

    test('and when the imported guide could not be read', () async {
      imported.failing = true;
      short.answers['201'] = NowNext(now: programme('From the panel'));

      final found = await guide.nowNext(arena);

      expect(found.valueOrNull!.now!.title, 'From the panel');
    });
  });

  group('cached', () {
    test('the imported answer first', () {
      imported.remembered['201'] = NowNext(now: programme('Imported'));
      short.remembered['201'] = NowNext(now: programme('Short'));

      expect(guide.cached(arena)!.now!.title, 'Imported');
    });

    test("then the short EPG's", () {
      imported.remembered['203'] = NowNext.none;
      short.remembered['203'] = NowNext(now: programme('Short'));

      expect(guide.cached(velocity)!.now!.title, 'Short');
    });

    test('then the imported empty answer, so a row can say there is none', () {
      imported.remembered['203'] = NowNext.none;

      expect(guide.cached(velocity), NowNext.none);
    });

    test('and nothing while neither has looked', () {
      expect(guide.cached(velocity), isNull);
    });
  });

  test('warming never reaches the short EPG', () async {
    await guide.warm([arena, velocity]);

    expect(imported.warmed, [
      ['201', '203'],
    ]);
    expect(short.warmed, isEmpty);
  });

  test('says when either guide changed', () async {
    var changes = 0;
    final subscription = guide.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);

    imported.change();
    short.change();
    await Future<void>.delayed(Duration.zero);

    expect(changes, 2);
  });
}

/// A guide that answers from maps and records what it was asked.
final class _Guide implements GuideService {
  /// What [nowNext] answers.
  final answers = <String, NowNext>{};

  /// What [cached] answers.
  final remembered = <String, NowNext>{};
  final asked = <String>[];
  final warmed = <List<String>>[];
  bool failing = false;
  final _changes = StreamController<void>.broadcast();

  @override
  NowNext? cached(ChannelItem channel) => remembered[channel.remoteKey];

  @override
  Future<Result<NowNext>> nowNext(ChannelItem channel) async {
    asked.add(channel.remoteKey);
    if (failing) return Err(StorageFailure('guide: disk I/O error'));
    return Ok(answers[channel.remoteKey] ?? NowNext.none);
  }

  @override
  Future<void> warm(List<ChannelItem> channels) async {
    warmed.add([for (final channel in channels) channel.remoteKey]);
  }

  @override
  Stream<void> get changes => _changes.stream;

  void change() => _changes.add(null);
}
