import 'package:flutter/foundation.dart';

/// The Component Gallery ships in debug builds, and in a release build
/// only when it was compiled with `--dart-define=GALLERY=true`.
bool get galleryEnabled => kDebugMode || const bool.fromEnvironment('GALLERY');
