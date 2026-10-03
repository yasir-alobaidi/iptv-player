import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/design/components/quality_badge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_state.g.dart';

/// The source chip in the top bar, and each entry of its switcher. Null
/// while no provider is configured.
@immutable
class ShellSource {
  const new({required this.name, required this.connected, this.id = ''});

  final String id;
  final String name;

  /// Drives the status dot: green when the last request succeeded.
  final bool connected;
}

/// What the source switcher offers: every source, in the user's order,
/// and what choosing one does. With fewer than two, the chip opens
/// Settings → Sources instead of a menu.
@immutable
class ShellSourceChoices {
  const new({required this.sources, required this.onSelect});

  final List<ShellSource> sources;
  final ValueChanged<String> onSelect;
}

/// A message across the top of every screen, under the top bar: the
/// subscription is about to end, has ended, or the provider refused the
/// saved details (docs/08 Phase 2). One at a time.
@immutable
class ShellNotice {
  const new({
    required this.message,
    this.tone = ShellNoticeTone.warning,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final ShellNoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Null: the notice can't be closed.
  final VoidCallback? onDismiss;
}

enum ShellNoticeTone { info, warning, error }

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

/// What the casting bar shows while a cast is on (canvas `Casting`,
/// docs/05). The casting feature fills it; null keeps the bar out of the
/// tree.
@immutable
class ShellCastSession {
  const new({
    required this.title,
    required this.deviceName,
    this.imageName,
    this.imageUrl,
    this.quality,
    this.status,
    this.isPlaying = true,
    this.reconnecting = false,
    this.onOpen,
    this.onPlayPause,
    this.onStop,
  });

  final String title;
  final String deviceName;

  /// Whose monogram stands in for a missing picture (the channel's).
  final String? imageName;

  /// The logo or poster, as the provider names it.
  final String? imageUrl;
  final StreamQuality? quality;

  /// "Connecting…", "Preparing…", what failed: said instead of the
  /// quality.
  final String? status;
  final bool isPlaying;
  final bool reconnecting;

  /// Opens the casting view.
  final VoidCallback? onOpen;

  /// Null for live.
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
}

/// The top bar's Cast button (and C): the device picker, with the
/// connected icon while casting.
@immutable
class ShellCastButton {
  const new({required this.connected, required this.onPressed});

  final bool connected;

  /// Called with a context under the app's navigator, for the dialog.
  final void Function(BuildContext context) onPressed;
}

// The shell's slots. Each is empty until the phase that owns it
// overrides the provider, so the shell can be built and tested now
// without inventing domain state.

@riverpod
ShellSource? shellSource(Ref ref) => null;

@riverpod
ShellSourceChoices? shellSourceChoices(Ref ref) => null;

@riverpod
ShellSyncStatus? shellSyncStatus(Ref ref) => null;

@riverpod
ShellNotice? shellNotice(Ref ref) => null;

@riverpod
ShellDownloads? shellDownloads(Ref ref) => null;

@riverpod
ShellCastSession? shellCastSession(Ref ref) => null;

@riverpod
ShellCastButton? shellCastButton(Ref ref) => null;

/// Drawn in place of the screen (the casting view, which the canvas draws
/// inside the shell); null shows the screen.
@riverpod
Widget? shellContentOverlay(Ref ref) => null;

/// Whether the nav rail is expanded to 240 px. The shell still collapses
/// it on a narrow window; this is what the user asked for.
@riverpod
class RailExpanded extends _$RailExpanded {
  @override
  bool build() => ref.read(uiPreferencesProvider).railExpanded;

  void toggle() {
    state = !state;
    // The rail moves now; the write is not worth waiting for, and a
    // failed one only costs the choice on the next launch.
    unawaited(ref.read(uiPreferencesProvider).setRailExpanded(expanded: state));
  }
}

/// Non-fatal errors the global handlers caught, shown as toasts by the
/// shell (step 2's `ErrorReporter`).
@riverpod
Stream<AppFailure> nonFatalErrors(Ref ref) =>
    ref.watch(errorReporterProvider).nonFatalErrors;

/// What background work did ("Guide updated · 142 channels matched"),
/// shown as toasts by the shell.
@riverpod
Stream<AppNotice> backgroundNotices(Ref ref) =>
    ref.watch(appNoticesProvider).stream;

/// Where the window's size and position are kept. `bootstrap()`
/// overrides this with the settings-table implementation; the in-memory
/// default keeps widget tests free of a database.
@Riverpod(keepAlive: true)
WindowBoundsStore windowBoundsStore(Ref ref) => InMemoryWindowBoundsStore();

/// Small UI choices that survive a restart. Overridden in `bootstrap()`
/// with the settings-table implementation, for the same reason.
@Riverpod(keepAlive: true)
UiPreferences uiPreferences(Ref ref) => InMemoryUiPreferences();
