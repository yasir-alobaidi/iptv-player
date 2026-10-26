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
    hardwareDecoding: false,
    matchFrameRate: true,
    pictureQuality: PictureQuality.standard,
    subtitleSize: SubtitleSize.large,
    timeOnScreen: TimeOnScreen.controls,
    stillWatchingAfter: StillWatchingAfter.oneHour,
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
    expect(request.hardwareDecoding, isFalse);
  });

  test('hardware decoding is Automatic unless Off was stored', () {
    expect(const PlaybackSettings().hardwareDecoding, isTrue);
    expect(const PlaybackSettings().toJson()['hwdec'], 'auto');
    expect(
      PlaybackSettings.fromJson(const {'hwdec': 'off'}).hardwareDecoding,
      isFalse,
    );
    // Settings stored before Phase 9, or damaged: Automatic.
    for (final stored in [
      const <String, Object?>{},
      const {'hwdec': 7},
    ]) {
      expect(PlaybackSettings.fromJson(stored).hardwareDecoding, isTrue);
    }
    expect(
      const PlaybackSettings()
          .request(const ResolvedStream(url: 'u', maxConnections: 1))
          .hardwareDecoding,
      isTrue,
    );
  });

  test("a TV's Match frame rate is Off unless On was chosen (ADR-042)", () {
    expect(const PlaybackSettings().matchFrameRate, isFalse);
    expect(const PlaybackSettings().toJson()['matchRate'], 'off');
    expect(
      const PlaybackSettings(matchFrameRate: true).toJson()['matchRate'],
      'on',
    );
    expect(
      PlaybackSettings.fromJson(const {'matchRate': 'on'}).matchFrameRate,
      isTrue,
    );
    // The old key was written "on" for everyone who saved any playback
    // setting while On was the default: not a choice, so not read.
    expect(const PlaybackSettings().toJson(), isNot(contains('matchFps')));
    for (final stored in [
      const <String, Object?>{},
      const {'matchFps': 'on'},
      const {'matchRate': true},
      const {'matchRate': 'sometimes'},
    ]) {
      expect(PlaybackSettings.fromJson(stored).matchFrameRate, isFalse);
    }
  });

  test("a TV's Match frame rate for channels is On unless Off was chosen "
      '(ADR-044)', () {
    expect(const PlaybackSettings().matchChannelRate, isTrue);
    expect(const PlaybackSettings().toJson()['matchChannels'], 'on');
    expect(
      const PlaybackSettings(matchChannelRate: false).toJson()['matchChannels'],
      'off',
    );
    expect(
      PlaybackSettings.fromJson(const {'matchChannels': 'off'})
          .matchChannelRate,
      isFalse,
    );
    for (final stored in [
      const <String, Object?>{},
      const {'matchChannels': 'on'},
      const {'matchChannels': false},
      const {'matchRate': 'off'},
    ]) {
      expect(PlaybackSettings.fromJson(stored).matchChannelRate, isTrue);
    }
    expect(
      const PlaybackSettings(matchChannelRate: false),
      isNot(const PlaybackSettings()),
    );
  });

  test('Picture quality is High unless Standard was chosen (ADR-055), and '
      'the request carries it', () {
    expect(const PlaybackSettings().pictureQuality, PictureQuality.high);
    expect(const PlaybackSettings().toJson()['picture'], 'high');
    const standard = PlaybackSettings(pictureQuality: PictureQuality.standard);
    expect(standard.toJson()['picture'], 'standard');
    expect(
      PlaybackSettings.fromJson(standard.toJson()).pictureQuality,
      PictureQuality.standard,
    );
    // Stored before it (the old key, written "standard" for anyone who
    // saved a playback setting while Standard was the default), or
    // damaged: High.
    for (final stored in [
      const <String, Object?>{},
      const {'quality': 'standard'},
      const {'picture': 'ultra'},
      const {'picture': 2},
    ]) {
      expect(
        PlaybackSettings.fromJson(stored).pictureQuality,
        PictureQuality.high,
        reason: '$stored',
      );
    }
    const stream = ResolvedStream(url: 'u', maxConnections: 1);
    expect(
      const PlaybackSettings().request(stream).pictureQuality,
      PictureQuality.high,
    );
    expect(standard.request(stream).pictureQuality, PictureQuality.standard);
  });

  test('Subtitle size is Medium unless Small or Large was stored '
      '(ADR-038)', () {
    expect(const PlaybackSettings().subtitleSize, SubtitleSize.medium);
    expect(const PlaybackSettings().toJson()['subtitleSize'], 'medium');
    expect(chosen.toJson()['subtitleSize'], 'large');
    for (final size in SubtitleSize.values) {
      final settings = PlaybackSettings(subtitleSize: size);
      expect(PlaybackSettings.fromJson(settings.toJson()), settings);
    }
    expect(
      PlaybackSettings.fromJson(const {'subtitleSize': 'small'}).subtitleSize,
      SubtitleSize.small,
    );
    // Settings stored before it, or damaged: Medium, and the rest kept.
    for (final stored in [
      const <String, Object?>{},
      const {'subtitleSize': 'huge'},
      const {'subtitleSize': 'Large'},
      const {'subtitleSize': 2},
      const {'subtitleSize': null},
      const {
        'subtitleSize': ['large'],
      },
    ]) {
      expect(
        PlaybackSettings.fromJson(stored).subtitleSize,
        SubtitleSize.medium,
      );
    }
    expect(
      PlaybackSettings.fromJson({...chosen.toJson(), 'subtitleSize': 'giant'}),
      chosen.copyWith(subtitleSize: SubtitleSize.medium),
    );
    expect(
      const PlaybackSettings(subtitleSize: SubtitleSize.small),
      isNot(const PlaybackSettings()),
    );
  });

  test('Time on screen is Always unless With the controls was stored', () {
    expect(const PlaybackSettings().timeOnScreen, TimeOnScreen.always);
    expect(const PlaybackSettings().toJson()['timeOnScreen'], 'always');
    expect(chosen.toJson()['timeOnScreen'], 'controls');
    for (final choice in TimeOnScreen.values) {
      final settings = PlaybackSettings(timeOnScreen: choice);
      expect(PlaybackSettings.fromJson(settings.toJson()), settings);
    }
    expect(
      PlaybackSettings.fromJson(const {'timeOnScreen': 'controls'})
          .timeOnScreen,
      TimeOnScreen.controls,
    );
    // Settings stored before it, or damaged: Always, and the rest kept.
    for (final stored in [
      const <String, Object?>{},
      const {'timeOnScreen': 'never'},
      const {'timeOnScreen': 'Controls'},
      const {'timeOnScreen': 0},
      const {'timeOnScreen': null},
      const {'timeOnScreen': false},
    ]) {
      expect(
        PlaybackSettings.fromJson(stored).timeOnScreen,
        TimeOnScreen.always,
      );
    }
    expect(
      PlaybackSettings.fromJson({...chosen.toJson(), 'timeOnScreen': 'off'}),
      chosen.copyWith(timeOnScreen: TimeOnScreen.always),
    );
    expect(
      const PlaybackSettings(timeOnScreen: TimeOnScreen.controls),
      isNot(const PlaybackSettings()),
    );
  });

  test('Ask if still watching is 4 hours unless another was stored '
      '(ADR-064)', () {
    expect(
      const PlaybackSettings().stillWatchingAfter,
      StillWatchingAfter.fourHours,
    );
    expect(const PlaybackSettings().toJson()['stillWatching'], 'fourHours');
    expect(chosen.toJson()['stillWatching'], 'oneHour');
    expect(
      [for (final choice in StillWatchingAfter.values) choice.after],
      const [
        Duration(minutes: 30),
        Duration(hours: 1),
        Duration(hours: 2),
        Duration(hours: 4),
      ],
    );
    for (final choice in StillWatchingAfter.values) {
      final settings = PlaybackSettings(stillWatchingAfter: choice);
      expect(PlaybackSettings.fromJson(settings.toJson()), settings);
    }
    // Settings stored before it, or damaged: 4 hours, and the rest kept.
    for (final stored in [
      const <String, Object?>{},
      const {'stillWatching': 'never'},
      const {'stillWatching': 'OneHour'},
      const {'stillWatching': 60},
      const {'stillWatching': null},
      const {'stillWatching': false},
    ]) {
      expect(
        PlaybackSettings.fromJson(stored).stillWatchingAfter,
        StillWatchingAfter.fourHours,
      );
    }
    expect(
      PlaybackSettings.fromJson({...chosen.toJson(), 'stillWatching': 'off'}),
      chosen.copyWith(stillWatchingAfter: StillWatchingAfter.fourHours),
    );
    expect(
      const PlaybackSettings(stillWatchingAfter: StillWatchingAfter.halfHour),
      isNot(const PlaybackSettings()),
    );
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
