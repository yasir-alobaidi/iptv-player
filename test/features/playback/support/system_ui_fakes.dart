import 'package:iptv_player/features/playback/presentation/player_system_ui.dart';

/// What the player asked of a phone's or a tablet's screen, in order:
/// `enter landscape`, `enter` (a tablet: as it is held), `leave`.
final class RecordedPlayerSystemUi implements PlayerSystemUi {
  final calls = <String>[];

  @override
  Future<void> enter({required bool landscape}) async =>
      calls.add(landscape ? 'enter landscape' : 'enter');

  @override
  Future<void> leave() async => calls.add('leave');
}
