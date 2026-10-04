import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_reveal.g.dart';

/// Shows a file in the system's file manager: docs/09's Show in folder,
/// on the player's failure card for a library file (Phase 8 decision 8)
/// and in a library item's menu.
abstract interface class FileReveal {
  /// Opens the folder holding [path] with the file selected, where the
  /// file manager can; when the file is gone, the nearest folder above it
  /// that is still there. Never throws: false when nothing could be
  /// opened.
  Future<bool> showInFolder(String path);
}

/// No file manager to ask: tests, and systems without a way.
final class NoFileReveal implements FileReveal {
  const new();

  @override
  Future<bool> showInFolder(String path) async => false;
}

/// Show in folder. Nothing here; `bootstrap()` gives it the system's
/// (`platformFileReveal`).
@Riverpod(keepAlive: true)
FileReveal fileReveal(Ref ref) => const NoFileReveal();
