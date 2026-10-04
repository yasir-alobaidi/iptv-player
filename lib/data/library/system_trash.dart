import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// How putting a file in the trash went.
enum TrashOutcome {
  /// In the system's trash, from where the desktop can put it back.
  trashed,

  /// There is no trash it can go to (a read-only drive, a network
  /// share): docs/09 asks a second time, then deletes for good.
  noTrash,
}

/// The system's trash (Phase 8 decision 10). On Linux, the freedesktop
/// trash spec, done here: a file on the home drive goes to
/// `$XDG_DATA_HOME/Trash`; one on another drive to that drive's own
/// trash (`.Trash/<uid>` when the drive has a safe one, else
/// `.Trash-<uid>`), always by a rename on the same drive, never a copy.
/// Each gets its `.trashinfo`, so the desktop's trash can put it back. On
/// Windows the Recycle Bin, through the shell (untried here).
final class SystemTrash {
  new({
    Map<String, String>? environment,
    String? Function(String path)? mountOf,
    int Function()? uid,
    DateTime Function()? now,
  }) : _environment = environment ?? Platform.environment,
       _mountOf = mountOf ?? _mountPointOf,
       _uid = uid ?? _getuid,
       _now = now ?? DateTime.now;

  final Map<String, String> _environment;
  final String? Function(String path) _mountOf;
  final int Function() _uid;
  final DateTime Function() _now;

  Future<TrashOutcome> trash(String path) async {
    if (Platform.isWindows) return _recycle(path);
    if (!Platform.isLinux) return TrashOutcome.noTrash;
    final file = File(path);
    if (!file.existsSync()) return TrashOutcome.trashed;
    final absolute = p.normalize(p.absolute(path));
    final home = _environment['HOME'];
    final dataHome =
        _environment['XDG_DATA_HOME'] ??
        (home == null ? null : p.join(home, '.local', 'share'));
    final fileMount = _mountOf(absolute);
    final homeTrash = dataHome == null ? null : p.join(dataHome, 'Trash');

    final String trash;
    final String recorded;
    if (homeTrash != null && fileMount == _mountOf(_existing(homeTrash))) {
      trash = homeTrash;
      recorded = absolute;
    } else if (fileMount != null) {
      final drive = _driveTrash(fileMount);
      if (drive == null) return TrashOutcome.noTrash;
      trash = drive;
      recorded = p.relative(absolute, from: fileMount);
    } else {
      return TrashOutcome.noTrash;
    }

    try {
      final files = Directory(p.join(trash, 'files'))
        ..createSync(recursive: true);
      final info = Directory(p.join(trash, 'info'))
        ..createSync(recursive: true);
      final name = _freeName(p.basename(absolute), files, info);
      final record = File(p.join(info.path, '$name.trashinfo'))
        ..writeAsStringSync(
          '[Trash Info]\n'
          'Path=${_escape(recorded)}\n'
          'DeletionDate=${_date(_now())}\n',
          flush: true,
        );
      try {
        await file.rename(p.join(files.path, name));
      } on FileSystemException {
        record.deleteSync();
        return TrashOutcome.noTrash;
      }
      return TrashOutcome.trashed;
    } on FileSystemException {
      return TrashOutcome.noTrash;
    }
  }

  /// A drive's own trash: `.Trash/<uid>` when the drive has a `.Trash`
  /// that is a real folder with the sticky bit, else `.Trash-<uid>`.
  String? _driveTrash(String top) {
    final uid = _uid();
    final shared = Directory(p.join(top, '.Trash'));
    try {
      if (FileSystemEntity.typeSync(shared.path, followLinks: false) ==
              FileSystemEntityType.directory &&
          shared.statSync().mode & 0x200 != 0) {
        return p.join(shared.path, '$uid');
      }
      return p.join(top, '.Trash-$uid');
    } on FileSystemException {
      return null;
    }
  }

  static String _existing(String path) {
    var at = path;
    while (!Directory(at).existsSync() && p.dirname(at) != at) {
      at = p.dirname(at);
    }
    return at;
  }

  static String _freeName(String name, Directory files, Directory info) {
    bool taken(String candidate) =>
        File(p.join(files.path, candidate)).existsSync() ||
        Directory(p.join(files.path, candidate)).existsSync() ||
        File(p.join(info.path, '$candidate.trashinfo')).existsSync();
    if (!taken(name)) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var n = 2; ; n++) {
      final candidate = '$stem.$n$ext';
      if (!taken(candidate)) return candidate;
    }
  }

  /// The spec's `Path`: escaped as in a URL, `/` kept.
  static String _escape(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  /// The spec's `DeletionDate`: local time, `YYYY-MM-DDThh:mm:ss`.
  static String _date(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-'
        '${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// The Recycle Bin: `SHFileOperationW` with undo (Phase 8 decision 10).
  static TrashOutcome _recycle(String path) {
    final units = p.windows.normalize(p.windows.absolute(path)).codeUnits;
    // Two terminating zeros: the field is a list of paths.
    final from = calloc<Uint16>(units.length + 2);
    final operation = calloc<SHFILEOPSTRUCT>();
    try {
      for (var i = 0; i < units.length; i++) {
        from[i] = units[i];
      }
      operation.ref
        ..wFunc = FO_DELETE
        ..pFrom = PWSTR(from.cast())
        ..fFlags =
            FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT | FOF_NOERRORUI;
      final result = SHFileOperation(operation);
      return result.value == 0 ? TrashOutcome.trashed : TrashOutcome.noTrash;
    } on Object {
      return TrashOutcome.noTrash;
    } finally {
      calloc
        ..free(from)
        ..free(operation);
    }
  }
}

/// The mount point holding [path]: the longest mount point in
/// `/proc/self/mountinfo` that it is under.
String? _mountPointOf(String path) {
  try {
    String? best;
    for (final line in File('/proc/self/mountinfo').readAsLinesSync()) {
      final fields = line.split(' ');
      if (fields.length < 5) continue;
      final mount = fields[4].replaceAllMapped(
        RegExp(r'\\(\d{3})'),
        (m) => String.fromCharCode(int.parse(m[1]!, radix: 8)),
      );
      if ((path == mount || p.isWithin(mount, path)) &&
          (best == null || mount.length > best.length)) {
        best = mount;
      }
    }
    return best;
  } on Object {
    return null;
  }
}

typedef _GetuidNative = Uint32 Function();
typedef _Getuid = int Function();

int _getuid() {
  try {
    return DynamicLibrary.process().lookupFunction<_GetuidNative, _Getuid>(
      'getuid',
    )();
  } on Object {
    return 0;
  }
}
