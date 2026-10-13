import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/features/playback/presentation/player_sound.dart';

void main() {
  late FakePlayerEngine engine;
  late InMemoryUiPreferences preferences;
  late ProviderContainer container;

  ProviderContainer open({PlayerSound stored = const PlayerSound()}) {
    engine = FakePlayerEngine();
    preferences = InMemoryUiPreferences()..playerSound = stored;
    container = ProviderContainer(
      overrides: [
        playerEngineProvider.overrideWithValue(engine),
        uiPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  PlayerSound sound() => container.read(playerSoundControllerProvider);
  PlayerSoundController controller() =>
      container.read(playerSoundControllerProvider.notifier);

  test('a new engine is left alone when nothing was stored', () async {
    open();

    expect(sound(), const PlayerSound());
    await pumpEventQueue();
    expect(engine.calls, isEmpty);
  });

  test(
    'the engine is told the stored level and mute once, at the start',
    () async {
      open(stored: const PlayerSound(volume: 35, muted: true));

      expect(sound(), const PlayerSound(volume: 35, muted: true));
      await pumpEventQueue();
      expect(engine.calls, ['volume:35.0', 'muted:true']);
    },
  );

  test('a level is set, told to the engine and kept', () async {
    open();

    controller().setVolume(42);
    await pumpEventQueue();

    expect(sound(), const PlayerSound(volume: 42));
    expect(engine.calls, ['volume:42.0']);
    expect(preferences.playerSound, const PlayerSound(volume: 42));
  });

  test('a level is kept within 0 and 100', () async {
    open();

    controller().setVolume(140);
    expect(sound().volume, 100);
    controller().setVolume(-3);
    expect(sound().volume, 0);
    expect(sound().silent, isTrue);
  });

  test('a key steps by 5 to the nearest step, and stops at the ends', () async {
    open(stored: const PlayerSound(volume: 92));

    controller().nudge(1);
    expect(sound().volume, 95);
    controller()
      ..nudge(1)
      ..nudge(1);
    expect(sound().volume, 100);
    controller().nudge(-1);
    expect(sound().volume, 95);
  });

  test('Mute keeps the level; Unmute goes back to it', () async {
    open(stored: const PlayerSound(volume: 60));
    expect(sound().muted, isFalse);
    await pumpEventQueue();
    engine.calls.clear();

    controller().toggleMute();
    expect(sound(), const PlayerSound(volume: 60, muted: true));
    controller().toggleMute();
    await pumpEventQueue();

    expect(sound(), const PlayerSound(volume: 60));
    expect(engine.calls, ['muted:true', 'muted:false']);
    expect(preferences.playerSound, const PlayerSound(volume: 60));
  });

  test('turning it up while muted is also Unmute', () async {
    open(stored: const PlayerSound(volume: 60, muted: true));

    controller().nudge(1);

    expect(sound(), const PlayerSound(volume: 65));
  });

  test('turning it down while muted changes nothing', () async {
    open(stored: const PlayerSound(volume: 60, muted: true));

    controller().nudge(-1);

    expect(sound(), const PlayerSound(volume: 60, muted: true));
  });

  test('Unmute from a level dragged to nothing is audible again', () async {
    open();

    controller().setVolume(0);
    expect(sound().silent, isTrue);
    controller().toggleMute();

    expect(sound(), const PlayerSound(volume: 50));
  });

  test('a drag writes its last level', () async {
    open();

    for (var level = 99.0; level >= 20; level -= 1) {
      controller().setVolume(level);
    }
    await pumpEventQueue();

    expect(preferences.playerSound, const PlayerSound(volume: 20));
  });

  group('PlayerSound.fromJson', () {
    test('reads what toJson wrote', () {
      const sound = PlayerSound(volume: 35, muted: true);
      expect(PlayerSound.fromJson(sound.toJson()), sound);
    });

    test('anything damaged reads as full volume, unmuted', () {
      expect(PlayerSound.fromJson(null), const PlayerSound());
      expect(PlayerSound.fromJson('loud'), const PlayerSound());
      expect(PlayerSound.fromJson(const {'volume': 'x'}), const PlayerSound());
      expect(
        PlayerSound.fromJson(const {'volume': 900, 'muted': 1}),
        const PlayerSound(),
      );
      expect(
        PlayerSound.fromJson(const {'volume': double.nan}),
        const PlayerSound(),
      );
    });
  });
}
