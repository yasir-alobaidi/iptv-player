import 'dart:async';

import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_source.g.dart';

/// The source the user last picked in the top bar's switcher, remembered
/// across restarts. Null means "the first one".
@Riverpod(keepAlive: true)
class ChosenSourceId extends _$ChosenSourceId {
  @override
  String? build() => ref.read(uiPreferencesProvider).currentSourceId;

  void choose(String id) {
    if (state == id) return;
    state = id;
    // The switch happens now; a failed write only costs the choice on the
    // next launch.
    unawaited(ref.read(uiPreferencesProvider).setCurrentSourceId(id));
  }

  /// A removed source stops being the choice; the first one takes over.
  void forget(String id) {
    if (state != id) return;
    state = null;
    unawaited(ref.read(uiPreferencesProvider).setCurrentSourceId(null));
  }
}

/// The source the app browses: the one the user picked, or the first in
/// their order when they haven't picked one or it was removed. Null while
/// there is no source.
@Riverpod(keepAlive: true)
Source? currentSource(Ref ref) {
  final sources = ref.watch(sourcesProvider).value;
  if (sources == null || sources.isEmpty) return null;
  final chosen = ref.watch(chosenSourceIdProvider);
  return sources.where((s) => s.id == chosen).firstOrNull ?? sources.first;
}
