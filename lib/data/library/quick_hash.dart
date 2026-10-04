import 'dart:io';
import 'dart:typed_data';

/// How much of each end of a file the quick hash reads (docs/09).
const int quickHashEdge = 64 * 1024;

/// A file's quick hash (docs/09 "Identity"): its size, and FNV-1a over its
/// first and last 64 KB. History, favorites and edits follow a file across
/// renames and moves by it; reading 128 KB is what keeps a scan of
/// thousands of files fast. Throws a [FileSystemException] when the file
/// can't be read.
Future<String> quickHash(File file) async {
  final handle = await file.open();
  try {
    final size = await handle.length();
    final head = await handle.read(size < quickHashEdge ? size : quickHashEdge);
    Uint8List tail;
    if (size > quickHashEdge) {
      final from = size - quickHashEdge < quickHashEdge
          ? quickHashEdge
          : size - quickHashEdge;
      await handle.setPosition(from);
      tail = await handle.read(size - from);
    } else {
      tail = Uint8List(0);
    }
    return quickHashOf(size, head, tail);
  } finally {
    await handle.close();
  }
}

/// The quick hash of a file of [size] bytes whose first bytes are [head]
/// and whose last bytes (past [head]) are [tail].
String quickHashOf(int size, List<int> head, List<int> tail) {
  // FNV-1a, 64 bits, as two 32-bit halves: wraps the same on the VM and
  // the web.
  var high = 0xcbf29ce4;
  var low = 0x84222325;
  void add(List<int> bytes) {
    for (final byte in bytes) {
      low ^= byte;
      // × 0x100000001b3 (the FNV prime) in halves.
      final lowProduct = low * 0x1b3;
      final carry = lowProduct ~/ 0x100000000;
      high = (high * 0x1b3 + low * 0x100 + carry) & 0xffffffff;
      low = lowProduct & 0xffffffff;
    }
  }

  add(head);
  add(tail);
  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return '${size.toRadixString(16)}-${hex(high)}${hex(low)}';
}
