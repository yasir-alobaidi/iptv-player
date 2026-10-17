import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

import 'presentation/guide_settings_fakes.dart';

/// Settings → Guide's switch on, for a test about the Guide: it is off by
/// default (ADR-031). A settings store that holds it on, as the user
/// leaves it; read as the app starts, like the real one.
Override guideSwitchedOn([
  GuideSettings settings = const GuideSettings(enabled: true),
]) => guideSettingsStoreProvider.overrideWithValue(
  FakeGuideSettingsStore()..stored = settings,
);
