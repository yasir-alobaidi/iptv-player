import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Folders the app owns, all under the platform's application support
/// directory.
final class AppPaths {
  const new(this.root);

  final Directory root;

  static Future<AppPaths> resolve() async =>
      AppPaths(await getApplicationSupportDirectory());

  Directory get logs => Directory(p.join(root.path, 'logs'));
}
