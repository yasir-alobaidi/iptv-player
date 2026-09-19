import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:logger/logger.dart';

ChannelItem channel(int id, {String source = 'src', int? number}) =>
    ChannelItem(
      id: id,
      sourceId: source,
      remoteKey: 'k$id',
      name: 'Channel $id',
      number: number ?? id,
    );

final class FakeResolver implements StreamResolver {
  int maxConnections = 1;
  AppFailure? failure;
  final List<ChannelItem> resolved = [];

  @override
  Future<Result<ResolvedStream>> live(ChannelItem channel) async {
    resolved.add(channel);
    if (failure case final failure?) return Err(failure);
    return Ok(
      ResolvedStream(
        url: 'http://fake/live/u/p/${channel.remoteKey}.ts',
        maxConnections: maxConnections,
      ),
    );
  }
}

final class FakeProber implements StreamProber {
  PlaybackProblem next = const PlaybackProblem(PlaybackProblemKind.network);
  final List<String?> details = [];

  @override
  Future<PlaybackProblem> diagnose(
    ChannelItem channel,
    ResolvedStream stream, {
    String? detail,
  }) async {
    details.add(detail);
    return next;
  }
}

final class FakeHistory implements PlaybackHistory {
  final List<String> recorded = [];

  @override
  Future<Result<void>> recordLive(ChannelItem channel) async {
    recorded.add(channel.remoteKey);
    return const Ok(null);
  }

  @override
  Future<Result<List<String>>> recentLive(
    String sourceId, {
    int limit = 20,
  }) async => Ok(recorded.reversed.toSet().take(limit).toList());
}

final class FakeChannels implements ChannelRepository {
  final Map<String, ChannelItem> byKey = {};

  @override
  Future<Result<ChannelItem?>> byRemoteKey(String sourceId, String key) async =>
      Ok(byKey[key]);

  @override
  Future<Result<ChannelItem?>> byNumber(String sourceId, int number) async =>
      Ok(byKey.values.where((c) => c.number == number).firstOrNull);

  @override
  Stream<int> watchCount(ChannelQuery query) => Stream.value(byKey.length);

  @override
  Future<Result<List<ChannelItem>>> range(
    ChannelQuery query,
    int offset,
    int limit,
  ) async => Ok(byKey.values.skip(offset).take(limit).toList());

  @override
  Future<Result<int?>> indexOf(ChannelQuery query, int id) async {
    final index = byKey.values.toList().indexWhere((c) => c.id == id);
    return Ok(index < 0 ? null : index);
  }

  @override
  Future<Result<void>> setFavorite(ChannelItem c, {required bool on}) async =>
      const Ok(null);

  @override
  Future<Result<void>> setHidden(int id, {required bool hidden}) async =>
      const Ok(null);

  @override
  Future<Result<void>> rename(int id, String? name) async => const Ok(null);
}

/// A coordinator on fakes, and the states it went through.
final class Rig {
  new({Duration stopDelay = Duration.zero})
    : engine = FakePlayerEngine(stopDelay: stopDelay) {
    coordinator = PlaybackCoordinator(
      engine: engine,
      resolver: resolver,
      prober: prober,
      history: history,
      channels: channels,
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
    );
    coordinator.states.listen(states.add);
  }

  final FakePlayerEngine engine;
  final resolver = FakeResolver();
  final prober = FakeProber();
  final history = FakeHistory();
  final channels = FakeChannels();
  late final PlaybackCoordinator coordinator;
  final List<PlaybackState> states = [];

  PlaybackState get state => coordinator.state;
}
