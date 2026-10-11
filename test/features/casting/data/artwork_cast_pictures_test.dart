import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/features/casting/data/artwork_cast_pictures.dart';
import 'package:path/path.dart' as p;

/// The picture the TV shows for a library item is a file already (its
/// poster, or the frame the app grabbed): handed over as it is, never
/// fetched.
void main() {
  late Directory temp;
  late ArtworkCastPictures pictures;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cast_pictures_');
    pictures = ArtworkCastPictures(
      ArtworkCache(directory: Directory(p.join(temp.path, 'cache'))),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('a file URL is its path, when the file is there', () async {
    final poster = File(p.join(temp.path, 'Paper Kites (2019)', 'poster.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    expect(
      await pictures.fileFor(Uri.file(poster.path).toString()),
      poster.path,
    );
    expect(Directory(p.join(temp.path, 'cache')).existsSync(), isFalse);

    poster.deleteSync();
    expect(await pictures.fileFor(Uri.file(poster.path).toString()), isNull);
  });
}
