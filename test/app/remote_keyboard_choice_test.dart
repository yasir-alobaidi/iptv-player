import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/design/components.dart';

/// ADR-027: Bijou's keyboard for the remote opens in the language it last
/// had, across launches.
void main() {
  (ProviderContainer, InMemoryUiPreferences) open({String? stored}) {
    final preferences = InMemoryUiPreferences()..keyboardLanguage = stored;
    final container = ProviderContainer(
      overrides: [uiPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    final kept = container.listen(remoteKeyboardChoiceProvider, (_, _) {});
    addTearDown(kept.close);
    return (container, preferences);
  }

  test('opens in the stored language; a choice is stored', () {
    final (container, preferences) = open(stored: 'ar');
    expect(
      container.read(remoteKeyboardChoiceProvider),
      KeyboardLanguage.arabic,
    );

    container
        .read(remoteKeyboardChoiceProvider.notifier)
        .choose(KeyboardLanguage.english);
    expect(
      container.read(remoteKeyboardChoiceProvider),
      KeyboardLanguage.english,
    );
    expect(preferences.keyboardLanguage, 'en');
  });

  test('nothing stored, or a code it does not know: English', () {
    expect(
      open().$1.read(remoteKeyboardChoiceProvider),
      KeyboardLanguage.english,
    );
    expect(
      open(stored: 'xx').$1.read(remoteKeyboardChoiceProvider),
      KeyboardLanguage.english,
    );
  });
}
