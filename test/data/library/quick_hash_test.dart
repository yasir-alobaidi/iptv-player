import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/library/quick_hash.dart';

void main() {
  late Directory folder;
  setUp(() => folder = Directory.systemTemp.createTempSync('quick_hash_'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('FNV-1a 64 over the bytes, behind the size', () {
    // The published FNV-1a 64-bit test vectors.
    expect(quickHashOf(0, const [], const []), '0-cbf29ce484222325');
    expect(quickHashOf(1, utf8.encode('a'), const []), '1-af63dc4c8601ec8c');
    expect(
      quickHashOf(6, utf8.encode('foo'), utf8.encode('bar')),
      '6-${quickHashOf(6, utf8.encode('foobar'), const []).split('-').last}',
    );
  });

  File write(String name, Uint8List bytes) =>
      File('${folder.path}/$name')..writeAsBytesSync(bytes);

  Uint8List bytes(int length, {int seed = 0}) => Uint8List.fromList(
    List<int>.generate(length, (i) => (i * 7 + seed) & 0xff),
  );

  test('a small file is read whole', () async {
    final data = bytes(1000);
    expect(
      await quickHash(write('small', data)),
      quickHashOf(1000, data, const []),
    );
  });

  test('a big file: its first and last 64 KB and its size', () async {
    final data = bytes(1 << 20);
    final file = write('big', data);
    expect(
      await quickHash(file),
      quickHashOf(
        data.length,
        data.sublist(0, quickHashEdge),
        data.sublist(data.length - quickHashEdge),
      ),
    );

    // The middle doesn't count; the ends and the size do.
    final middle = Uint8List.fromList(data)..[500000] ^= 0xff;
    expect(await quickHash(write('middle', middle)), await quickHash(file));
    final end = Uint8List.fromList(data)..[data.length - 1] ^= 0xff;
    expect(await quickHash(write('end', end)), isNot(await quickHash(file)));
    final longer = Uint8List.fromList([...data, 0]);
    expect(
      await quickHash(write('longer', longer)),
      isNot(await quickHash(file)),
    );
  });

  test('between 64 and 128 KB the ends do not overlap', () async {
    final data = bytes(100 * 1024);
    expect(
      await quickHash(write('mid', data)),
      quickHashOf(
        data.length,
        data.sublist(0, quickHashEdge),
        data.sublist(quickHashEdge),
      ),
    );
  });

  test('a file that is gone throws', () async {
    await expectLater(
      quickHash(File('${folder.path}/missing')),
      throwsA(isA<FileSystemException>()),
    );
  });
}
