import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folders the app owns: its data under the platform's application
/// support directory, and what can be fetched again under its cache
/// directory ([cacheRoot]; under [root] when none is given).
final class AppPaths {
  const new(this.root, {this.cacheDirectory});

  final Directory root;

  /// The platform's cache directory, when it gave one.
  final Directory? cacheDirectory;

  static Future<AppPaths> resolve() async => AppPaths(
    await getApplicationSupportDirectory(),
    cacheDirectory: await getApplicationCacheDirectory(),
  );

  Directory get cacheRoot =>
      cacheDirectory ?? Directory(p.join(root.path, 'cache'));

  Directory get logs => Directory(p.join(root.path, 'logs'));

  /// Posters, logos, backdrops and stills (Phase 5 decision 6).
  Directory get artwork => Directory(p.join(cacheRoot.path, 'artwork'));
}
