import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/db_ui_preferences.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;

  setUp(() {
    database = AppDatabase.memory();
    settings = SettingsRepository(database);
  });
  tearDown(() => database.close());

  test('the rail starts collapsed when nothing was stored', () async {
    final preferences = await DbUiPreferences.load(settings);

    expect(preferences.railExpanded, isFalse);
  });

  test('the choice survives a reload', () async {
    final first = await DbUiPreferences.load(settings);

    await first.setRailExpanded(expanded: true);
    final second = await DbUiPreferences.load(settings);

    expect(second.railExpanded, isTrue);
  });

  test('the getter changes as soon as it is set, before the write', () async {
    final preferences = await DbUiPreferences.load(settings);

    final write = preferences.setRailExpanded(expanded: true);

    expect(preferences.railExpanded, isTrue);
    await write;
  });

  test('a corrupt row reads as collapsed', () async {
    await settings.writeJsonText(SettingsKeys.railExpanded, 'maybe');

    final preferences = await DbUiPreferences.load(settings);

    expect(preferences.railExpanded, isFalse);
  });
}
