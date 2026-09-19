import 'package:iptv_player/core/player/player_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_providers.g.dart';

/// The app's one player: `MediaKitPlayerEngine`, created in bootstrap();
/// `FakePlayerEngine` in tests.
@Riverpod(keepAlive: true)
PlayerEngine playerEngine(Ref ref) => throw UnimplementedError(
  'playerEngineProvider is overridden in bootstrap()',
);
