import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// The executable process [pid] runs, on Windows; null when it isn't
/// running or can't be asked.
String? windowsProcessImage(int pid) {
  final handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
  if (!handle.value.isValid) return null;
  const capacity = 4096;
  final buffer = calloc<Uint16>(capacity);
  final size = calloc<Uint32>()..value = capacity;
  try {
    final answered = QueryFullProcessImageName(
      handle.value,
      PROCESS_NAME_WIN32,
      PWSTR(buffer.cast()),
      size,
    );
    if (!answered.value) return null;
    return buffer.cast<Utf16>().toDartString(length: size.value);
  } finally {
    calloc
      ..free(buffer)
      ..free(size);
    handle.value.close();
  }
}
