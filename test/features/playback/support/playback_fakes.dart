import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:logger/logger.dart';

ChannelItem channel(int id, {String source = 'src', int? number}) =>
    ChannelItem(
      id: id,
      sourceId: source,
      remoteKey: 'k$id',
      name: 'Channel $id',
      number: number ?? id,
    );

MovieItem movie(int id, {String source = 'src', Duration? runtime}) =>
    MovieItem(
      id: id,
      sourceId: source,
      remoteKey: 'm$id',
      name: 'Movie $id',
      ext: 'mkv',
      runtime: runtime,
    );

const series = SeriesItem(
  id: 1,
  sourceId: 'src',
  remoteKey: 's1',
  name: 'Glass Tide',
);

EpisodeItem episode(int season, int number, {Duration? duration}) =>
    EpisodeItem(
      id: season * 100 + number,
      sourceId: 'src',
      seriesKey: 's1',
      remoteKey: 'e$season$number',
      season: season,
      episode: number,
      title: 'Episode $number',
      ext: 'mp4',
      duration: duration,
    );

final class FakeResolver implements StreamResolver {
  int maxConnections = 1;
  AppFailure? failure;

  /// Live channels as the provider's own HLS (`.m3u8`).
  bool hls = false;

  /// The source sets a User-Agent of its own.
  bool customUserAgent = false;
  final List<ChannelItem> resolved = [];

  /// Every movie's and episode's remote key resolved, in order.
  final List<String> resolvedFiles = [];

  Future<Result<ResolvedStream>> _answer(
    String path, {
    bool hls = false,
  }) async {
    if (failure case final failure?) return Err(failure);
    return Ok(
      ResolvedStream(
        url: 'http://fake/$path',
        maxConnections: maxConnections,
        hls: hls,
        customUserAgent: customUserAgent,
      ),
    );
  }

  @override
  Future<Result<ResolvedStream>> live(ChannelItem channel) {
    resolved.add(channel);
    return _answer(
      'live/u/p/${channel.remoteKey}.${hls ? 'm3u8' : 'ts'}',
      hls: hls,
    );
  }

  @override
  Future<Result<ResolvedStream>> movie(MovieItem movie) {
    resolvedFiles.add(movie.remoteKey);
    return _answer('movie/u/p/${movie.remoteKey}.${movie.ext}');
  }

  @override
  Future<Result<ResolvedStream>> episode(EpisodeItem episode) {
    resolvedFiles.add(episode.remoteKey);
    return _answer('series/u/p/${episode.remoteKey}.${episode.ext}');
  }
}

final class FakeProber implements StreamProber {
  PlaybackProblem next = const PlaybackProblem(PlaybackProblemKind.network);
  final List<String?> details = [];

  @override
  Future<PlaybackProblem> diagnose(
    String sourceId,
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

/// [WatchProgress] in memory: every save, in order.
final class FakeWatchProgress implements WatchProgress {
  final List<({VodRef ref, Duration position, Duration? duration})> saves = [];

  Duration? get lastPosition => saves.lastOrNull?.position;

  @override
  Future<Result<void>> save(
    VodRef ref, {
    required Duration position,
    Duration? duration,
  }) async {
    saves.add((ref: ref, position: position, duration: duration));
    return const Ok(null);
  }

  @override
  Future<Result<void>> setWatched(VodRef ref, {required bool watched}) async =>
      const Ok(null);

  /// What [watch] answers, by title.
  final Map<VodRef, WatchMark> marks = {};

  @override
  Stream<WatchMark?> watch(VodRef ref) => Stream.value(marks[ref]);

  @override
  Stream<Map<String, WatchMark>> watchSeries(
    String sourceId,
    String seriesKey,
  ) => Stream.value(const {});

  @override
  Stream<List<ContinueItem>> continueWatching({int limit = 20}) =>
      Stream.value(const []);

  @override
  Future<Result<void>> dismiss(ContinueItem item) async => const Ok(null);
}

/// A coordinator on fakes, and the states it went through.
final class Rig {
  /// [watchProgress] saves where files were left in place of [progress]
  /// (a real database's, for screens that read it back).
  new({Duration stopDelay = Duration.zero, WatchProgress? watchProgress})
    : engine = FakePlayerEngine(stopDelay: stopDelay) {
    coordinator = PlaybackCoordinator(
      engine: engine,
      resolver: resolver,
      prober: prober,
      history: history,
      channels: channels,
      progress: watchProgress ?? progress,
      log: AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
    );
    coordinator.states.listen(states.add);
    coordinator.timelines.listen(timelines.add);
  }

  final FakePlayerEngine engine;
  final resolver = FakeResolver();
  final prober = FakeProber();
  final history = FakeHistory();
  final channels = FakeChannels();
  final progress = FakeWatchProgress();
  late final PlaybackCoordinator coordinator;
  final List<PlaybackState> states = [];
  final List<VodTimeline> timelines = [];

  PlaybackState get state => coordinator.state;
}
