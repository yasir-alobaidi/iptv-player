import 'package:flutter/widgets.dart';

/// Whether the app is on a TV, driven by a remote (docs/07, ADR-025): the
/// design system's components that a remote uses differently ask this,
/// e.g. a text field opens `RemoteKeyboard` in place of Android's.
/// Above everything the router draws, so dialogs see it too; with none
/// above, the desktop.
class TvMode extends InheritedWidget {
  const new({required this.on, required super.child, super.key});

  final bool on;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvMode>()?.on ?? false;

  @override
  bool updateShouldNotify(TvMode oldWidget) => oldWidget.on != on;
}
