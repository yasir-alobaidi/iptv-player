import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_state.g.dart';

/// The source chip in the top bar. Null while no provider is configured,
/// which is every run until Phase 2 adds sources.
@immutable
class ShellSource {
  const new({required this.name, required this.connected});

  final String name;

  /// Drives the status dot: green when the last request succeeded.
  final bool connected;
}

/// The top bar's sync slot, e.g. "Syncing channels · 12,340" or
/// "Guide updated 12 min ago" (docs/05). Phase 2 and Phase 4 fill it.
@immutable
class ShellSyncStatus {
  const new({required this.message, this.busy = false});

  final String message;

  /// Shows the spinner instead of plain text.
  final bool busy;
}

/// The top bar's download slot: "↓ 2 · 34 %" while downloads run
/// (docs/05, docs/09). Phase 8 fills it.
@immutable
class ShellDownloads {
  const new({required this.active, required this.progress});

  final int active;

  /// 0..1 across the active downloads.
  final double progress;
}

/// What the casting bar shows while a cast is running (docs/05). Phase 7
/// fills it; null keeps the bar out of the tree.
@immutable
class ShellCastSession {
  const new({
    required this.title,
    required this.deviceName,
    this.subtitle,
    this.isPlaying = true,
    this.progress,
    this.reconnecting = false,
  });

  final String title;
  final String deviceName;
  final String? subtitle;
  final bool isPlaying;
  final double? progress;
  final bool reconnecting;
}

// The shell's slots. Each is empty until the phase that owns it
// overrides the provider, so the shell can be built and tested now
// without inventing domain state.

@riverpod
ShellSource? shellSource(Ref ref) => null;

@riverpod
ShellSyncStatus? shellSyncStatus(Ref ref) => null;

@riverpod
ShellDownloads? shellDownloads(Ref ref) => null;

@riverpod
ShellCastSession? shellCastSession(Ref ref) => null;

/// Whether the nav rail is expanded to 240 px. The shell still collapses
/// it on a narrow window; this is what the user asked for.
///
/// Step 5 persists it in the `settings` table.
@riverpod
class RailExpanded extends _$RailExpanded {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Non-fatal errors the global handlers caught, shown as toasts by the
/// shell (step 2's `ErrorReporter`).
@riverpod
Stream<AppFailure> nonFatalErrors(Ref ref) =>
    ref.watch(errorReporterProvider).nonFatalErrors;

/// Where the window's size and position are kept. Step 5 overrides this
/// with the settings-table implementation.
@Riverpod(keepAlive: true)
WindowBoundsStore windowBoundsStore(Ref ref) => InMemoryWindowBoundsStore();
