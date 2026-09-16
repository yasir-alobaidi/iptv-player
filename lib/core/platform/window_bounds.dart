import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// Where the desktop window was when the app last closed.
///
/// [position] is null when it was never known or can't be restored: on
/// Wayland an application cannot place its own window, so only the size
/// survives a restart (ADR-008).
@immutable
class WindowBounds {
  const new({required this.size, this.position, this.maximized = false});

  /// Reads a stored value tolerantly: anything unexpected gives null
  /// rather than throwing, so a corrupt setting can't stop the app from
  /// opening (hard rule 1).
  static WindowBounds? fromJson(Map<String, Object?> json) {
    final width = _asDouble(json['width']);
    final height = _asDouble(json['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    final x = _asDouble(json['x']);
    final y = _asDouble(json['y']);
    return WindowBounds(
      size: Size(width, height),
      position: x == null || y == null ? null : Offset(x, y),
      maximized: json['maximized'] == true,
    );
  }

  /// Parses the JSON text a settings row holds; null when it is unusable.
  static WindowBounds? decode(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, Object?> ? fromJson(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  final Size size;
  final Offset? position;
  final bool maximized;

  Map<String, Object?> toJson() => {
    'width': size.width,
    'height': size.height,
    if (position != null) 'x': position!.dx,
    if (position != null) 'y': position!.dy,
    'maximized': maximized,
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is WindowBounds &&
      other.size == size &&
      other.position == position &&
      other.maximized == maximized;

  @override
  int get hashCode => Object.hash(size, position, maximized);

  @override
  String toString() =>
      'WindowBounds(${size.width}x${size.height}, $position, '
      'maximized: $maximized)';

  static double? _asDouble(Object? value) => switch (value) {
    final num n when n.isFinite => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}

/// Remembers the window's size and position between runs. Phase 1 step 5
/// backs this with the `settings` table; until then the app uses
/// [InMemoryWindowBoundsStore] and opens at its default size every time.
abstract interface class WindowBoundsStore {
  /// The stored bounds, or `Ok(null)` when nothing was stored yet.
  Future<Result<WindowBounds?>> load();

  Future<Result<void>> save(WindowBounds bounds);
}

/// Keeps bounds for the lifetime of the process only.
final class InMemoryWindowBoundsStore implements WindowBoundsStore {
  new([this._bounds]);

  WindowBounds? _bounds;

  @override
  Future<Result<WindowBounds?>> load() async => Ok(_bounds);

  @override
  Future<Result<void>> save(WindowBounds bounds) async {
    _bounds = bounds;
    return const Ok(null);
  }
}

/// Window geometry the app enforces (docs/05: minimum 1024 × 640).
abstract final class WindowSizes {
  static const minimum = Size(1024, 640);

  /// First run: the size the design canvas is drawn at, shrunk to fit a
  /// smaller screen by the window manager.
  static const initial = Size(1440, 900);

  /// Below this the nav rail collapses (docs/05).
  static const railCollapseWidth = 1280.0;
}

/// True in a native Wayland session, where a window cannot position
/// itself. `GDK_BACKEND=x11` forces XWayland, and there positioning works
/// again.
bool isWaylandSession([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  if (env['GDK_BACKEND'] == 'x11') return false;
  if (env['XDG_SESSION_TYPE'] == 'wayland') return true;
  return (env['WAYLAND_DISPLAY'] ?? '').isNotEmpty;
}

/// Decides how the window should open: the saved size clamped to the
/// minimum, and the saved position only when this session can restore it
/// and the window would still be reachable.
WindowBounds resolveStartupBounds(
  WindowBounds? saved, {
  required bool canRestorePosition,
  Size minimum = WindowSizes.minimum,
  Size initial = WindowSizes.initial,
}) {
  if (saved == null) {
    return WindowBounds(size: initial);
  }
  final size = Size(
    saved.size.width < minimum.width ? minimum.width : saved.size.width,
    saved.size.height < minimum.height ? minimum.height : saved.size.height,
  );
  final position = canRestorePosition ? saved.position : null;
  return WindowBounds(
    size: size,
    position: position != null && _isPlausible(position) ? position : null,
    maximized: saved.maximized,
  );
}

/// A sanity check only. Negative coordinates are normal with a second
/// monitor placed left of or above the primary one, so this rejects just
/// the absurd values a corrupt setting could hold.
bool _isPlausible(Offset position) =>
    position.dx.abs() < 32000 && position.dy.abs() < 32000;
