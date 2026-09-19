import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/playback/data/db_playback_settings_store.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';

void main() {
  const chosen = PlaybackSettings(
    preset: BufferPreset.stable,
    audioLanguages: ['ar', 'en'],
    subtitleLanguages: ['en'],
    deinterlace: false,
  );

  test('round-trips through JSON', () {
    expect(PlaybackSettings.fromJson(chosen.toJson()), chosen);
    expect(
      PlaybackSettings.fromJson(const PlaybackSettings().toJson()),
      const PlaybackSettings(),
    );
  });

  test('anything damaged reads as the default, field by field', () {
    expect(PlaybackSettings.fromJson('nonsense'), const PlaybackSettings());
    expect(
      PlaybackSettings.fromJson(const {
        'preset': 'turbo',
        'audio': ['  AR ', 7, ''],
        'subtitles': 'en',
        'deinterlace': 'maybe',
      }),
      const PlaybackSettings(audioLanguages: ['ar']),
    );
  });

  test('the settings shape the request the player gets', () {
    final request = chosen.request(
      const ResolvedStream(url: 'u', maxConnections: 1, userAgent: 'Box/1'),
    );

    expect(request.preset, BufferPreset.stable);
    expect(request.audioLanguages, ['ar', 'en']);
    expect(request.subtitleLanguages, ['en']);
    expect(request.deinterlace, isFalse);
    expect(request.userAgent, 'Box/1');
  });

  test('the store keeps them in the settings table', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final store = DbPlaybackSettingsStore(SettingsRepository(db));

    expect((await store.load()).valueOrNull, const PlaybackSettings());
    await store.save(chosen);
    expect((await store.load()).valueOrNull, chosen);
  });
}
