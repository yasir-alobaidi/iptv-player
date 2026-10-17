// Settings → Guide's switch on, for the walks and measurements that use
// the Guide: it is off by default (ADR-031). As `bootstrap()` reads it
// before the first frame for a user who switched it on.

import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

Override guideSwitchedOn() => launchGuideSettingsProvider.overrideWithValue(
  const GuideSettings(enabled: true),
);
