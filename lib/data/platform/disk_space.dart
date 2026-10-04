import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// The bytes the user can still write on the drive holding [path] (a file
/// or folder, which need not exist yet: its nearest existing parent is
/// asked); null when the system won't say. docs/09: a download checks it
/// before it starts and every 256 MB.
int? freeBytes(String path) {
  final existing = _nearestExisting(path);
  if (existing == null) return null;
  try {
    if (Platform.isWindows) return _windowsFree(existing);
    if (Platform.isLinux) return _linuxFree(existing);
  } on Object {
    // A call the system refused: unknown, not zero.
  }
  return null;
}

String? _nearestExisting(String path) {
  var at = p.absolute(path);
  while (true) {
    if (FileSystemEntity.typeSync(at) != FileSystemEntityType.notFound) {
      return at;
    }
    final parent = p.dirname(at);
    if (parent == at) return null;
    at = parent;
  }
}

typedef _StatvfsNative = Int32 Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _Statvfs = int Function(Pointer<Utf8>, Pointer<Uint8>);

final _Statvfs _statvfs = DynamicLibrary.process()
    .lookupFunction<_StatvfsNative, _Statvfs>('statvfs');

/// `statvfs`: `f_bavail` (blocks free to an unprivileged user) ×
/// `f_frsize`. glibc's struct on 64-bit Linux is eleven 8-byte fields
/// then six ints; the two read here are the 2nd and the 5th.
int? _linuxFree(String path) {
  final name = path.toNativeUtf8();
  final buffer = calloc<Uint8>(256);
  try {
    if (_statvfs(name, buffer) != 0) return null;
    final fields = buffer.cast<Uint64>();
    final fragment = fields[1];
    final available = fields[4];
    return fragment * available;
  } finally {
    calloc
      ..free(name)
      ..free(buffer);
  }
}

int? _windowsFree(String path) {
  final name = path.toNativeUtf16();
  final available = calloc<Uint64>();
  try {
    final answered = GetDiskFreeSpaceEx(PCWSTR(name), available, null, null);
    return answered.value ? available.value : null;
  } finally {
    calloc
      ..free(name)
      ..free(available);
  }
}
