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

  /// The source the top bar's switcher last picked; null until the user
  /// picks one, which means the first source in their order.
  String? get currentSourceId;

  Future<Result<void>> setCurrentSourceId(String? id);
}

/// Keeps choices for the lifetime of the process only. Used by tests and
/// as the default until `bootstrap()` overrides the provider.
final class InMemoryUiPreferences implements UiPreferences {
  bool _railExpanded = false;
  String? _currentSourceId;

  @override
  bool get railExpanded => _railExpanded;

  @override
  Future<Result<void>> setRailExpanded({required bool expanded}) async {
    _railExpanded = expanded;
    return const Ok(null);
  }

  @override
  String? get currentSourceId => _currentSourceId;

  @override
  Future<Result<void>> setCurrentSourceId(String? id) async {
    _currentSourceId = id;
    return const Ok(null);
  }
}
