import 'dart:async';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/guide/data/composite_guide.dart';
import 'package:iptv_player/features/guide/data/db_guide.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/data/short_epg_guide.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_tv_providers.g.dart';

@Riverpod(keepAlive: true)
ChannelRepository channelRepository(Ref ref) =>
    DbChannelRepository(ref.watch(appDatabaseProvider));

/// How many channels [query] matches, live.
@riverpod
Stream<int> channelCount(Ref ref, ChannelQuery query) =>
    ref.watch(channelRepositoryProvider).watchCount(query);

/// The provider's short EPG (ADR-010 decision 2), behind the imported
/// guide for the channels it has nothing for.
@Riverpod(keepAlive: true)
GuideService shortEpgGuide(Ref ref) =>
    ShortEpgGuide(ref.watch(sourceRepositoryProvider));

/// Now and next for the channels on screen: the imported guide first, the
/// short EPG behind it (Phase 4 decision 1).
@Riverpod(keepAlive: true)
GuideService guideService(Ref ref) {
  final imported = DbGuide(
    ref.watch(epgRepositoryProvider),
    clock: ref.watch(appClockProvider),
  );
  ref.onDispose(() => unawaited(imported.dispose()));
  return CompositeGuide(
    imported: imported,
    fallback: ref.watch(shortEpgGuideProvider),
  );
}

/// What's on [channel] now and next; [NowNext.none] when unknown. Asks
/// again when the guide changes, and when the answer changes shape (the
/// programme on now ends, or the next one starts), so the preview and the
/// player's OSD move on by themselves.
@riverpod
Future<NowNext> nowNext(Ref ref, ChannelItem channel) async {
  // Not [guideRevisionProvider]: this bumps it, and would ask again for
  // every lookup anywhere.
  ref.watch(guideChangesProvider);
  final clock = ref.watch(appClockProvider);
  final result = await ref.watch(guideServiceProvider).nowNext(channel);
  final found = result.valueOrNull ?? NowNext.none;
  if (!ref.mounted) return found;
  ref.read(guideRevisionProvider.notifier).bump();
  final at = clock();
  final turns = [found.now?.end, found.next?.start].nonNulls
      .where((moment) => moment.isAfter(at))
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  if (turns != null) {
    final timer = Timer(turns.difference(at), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return found;
}

/// Counts guide lookups, so rows showing only what is already cached
/// redraw when a lookup lands.
@Riverpod(keepAlive: true)
class GuideRevision extends _$GuideRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Counts the times the guide said its answers may be stale (an import,
/// the matcher): [nowNext] asks again, and a list looks its rows up again.
/// Each one also bumps [GuideRevision], so what is on screen redraws.
@Riverpod(keepAlive: true)
class GuideChanges extends _$GuideChanges {
  @override
  int build() {
    final subscription = ref.watch(guideServiceProvider).changes.listen((_) {
      state++;
      ref.read(guideRevisionProvider.notifier).bump();
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return 0;
  }
}

/// [channel] as the database has it now (a favorite toggled, a rename).
@riverpod
Stream<ChannelItem?> freshChannel(Ref ref, ChannelItem channel) async* {
  final repository = ref.watch(channelRepositoryProvider);
  // A count query runs again on every change to channels or favorites.
  await for (final _ in repository.watchCount(
    ChannelQuery(sourceId: channel.sourceId, showHidden: true),
  )) {
    yield (await repository.byRemoteKey(
      channel.sourceId,
      channel.remoteKey,
    )).valueOrNull;
  }
}
