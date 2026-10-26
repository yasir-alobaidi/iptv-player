import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_facts.g.dart';

/// A graphics card, as the system names it, and the driver it runs on.
@immutable
final class GraphicsCard {
  const new({required this.name, this.driver});

  /// `Intel UHD Graphics 630`, `NVIDIA GeForce GTX 1650 Ti Mobile`.
  final String name;

  /// `i915`, `nvidia`; null where the system doesn't say.
  final String? driver;

  /// `Intel UHD Graphics 630 (i915)`.
  String get line => driver == null ? name : '$name ($driver)';

  @override
  bool operator ==(Object other) =>
      other is GraphicsCard && other.name == name && other.driver == driver;

  @override
  int get hashCode => Object.hash(name, driver);

  @override
  String toString() => line;
}

/// What the diagnostics report says about this computer (Phase 9
/// decision 9): nothing that names the user, the network or the
/// provider.
@immutable
final class SystemFacts {
  const new({
    this.os,
    this.kernel,
    this.session,
    this.desktop,
    this.graphics = const [],
    this.device,
    this.memory,
  });

  /// `Ubuntu 22.04.5 LTS`, `Windows 11 Pro 10.0 (Build 22631)`.
  final String? os;

  /// `Linux 6.8.0-138-generic`; null on Windows, where [os] has it.
  final String? kernel;

  /// `Wayland` or `X11`; null on Windows.
  final String? session;

  /// `GNOME`, `KDE`; null on Windows.
  final String? desktop;
  final List<GraphicsCard> graphics;

  /// A TV's make, model and chip: `TCL 43V8C · board m7332 · …` (ADR-059);
  /// null on a computer.
  final String? device;

  /// A TV's memory and what the app may use of it; null on a computer.
  final String? memory;
}

/// Reads [SystemFacts]. Never throws: what can't be read is left out.
abstract interface class SystemFactsReader {
  Future<SystemFacts> read();
}

/// Knows nothing: tests, and a system this app has no reader for.
final class NoSystemFacts implements SystemFactsReader {
  const new();

  @override
  Future<SystemFacts> read() async => const SystemFacts();
}

/// `bootstrap()` gives the system's.
@Riverpod(keepAlive: true)
SystemFactsReader systemFactsReader(Ref ref) => const NoSystemFacts();
