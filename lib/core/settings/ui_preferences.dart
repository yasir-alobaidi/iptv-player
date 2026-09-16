import 'package:iptv_player/core/result.dart';

/// Small UI choices that survive a restart.
///
/// The shell sees only this interface; the settings-table implementation
/// lives in `lib/data` (hard rule 6). [railExpanded] is a plain getter
/// rather than a future because the first frame needs it — `bootstrap()`
/// reads the stored value before `runApp`.
abstract interface class UiPreferences {
  bool get railExpanded;

  Future<Result<void>> setRailExpanded({required bool expanded});
}

/// Keeps choices for the lifetime of the process only. Used by tests and
/// as the default until `bootstrap()` overrides the provider.
final class InMemoryUiPreferences implements UiPreferences {
  bool _railExpanded = false;

  @override
  bool get railExpanded => _railExpanded;

  @override
  Future<Result<void>> setRailExpanded({required bool expanded}) async {
    _railExpanded = expanded;
    return const Ok(null);
  }
}
