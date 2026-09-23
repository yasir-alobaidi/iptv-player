/// Byte streams as providers send them, shared by the M3U and XMLTV
/// parsers.
library;

import 'dart:async';
import 'dart:io';

/// [source], gunzipped when it starts with gzip's magic number (a
/// `.m3u.gz` or `.xml.gz`, or a server that gzips without saying so). A
/// body sent with `Content-Encoding: gzip` is already unpacked by the HTTP
/// client.
///
/// A listener that stops early — a parser that refused an error page at
/// its first tag — lets go of [source] too, so the connection under it
/// closes rather than waiting, paused, for the rest of the body.
Stream<List<int>> gunzipIfNeeded(Stream<List<int>> source) async* {
  final iterator = StreamIterator(source);
  try {
    final head = <int>[];
    while (head.length < 2 && await iterator.moveNext()) {
      head.addAll(iterator.current);
    }
    if (head.isEmpty) return;

    Stream<List<int>> rest() async* {
      yield head;
      while (await iterator.moveNext()) {
        yield iterator.current;
      }
    }

    final gzipped = head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b;
    yield* gzipped ? gzip.decoder.bind(rest()) : rest();
  } finally {
    await iterator.cancel();
  }
}
