import 'dart:convert';
import 'dart:typed_data';

/// Fragmented MP4s made by hand, the shape FFmpeg's `frag_keyframe+
/// empty_moov+default_base_moof` writes: `ftyp`, a `moov` whose length is
/// 0, then `moof` + `mdat` pairs, and `mfra` at the end.

Uint8List mp4Box(String type, List<int> body) {
  final head = ByteData(8)
    ..setUint32(0, 8 + body.length)
    ..setUint32(4, _fourcc(type));
  return Uint8List.fromList([...head.buffer.asUint8List(), ...body]);
}

/// A box with a 64-bit size.
Uint8List mp4WideBox(String type, List<int> body) {
  final head = ByteData(16)
    ..setUint32(0, 1)
    ..setUint32(4, _fourcc(type))
    ..setUint64(8, 16 + body.length);
  return Uint8List.fromList([...head.buffer.asUint8List(), ...body]);
}

/// A full box's body: its version and flags, then [fields].
List<int> fullBody(int version, int flags, List<int> fields) => [
  version,
  (flags >> 16) & 0xff,
  (flags >> 8) & 0xff,
  flags & 0xff,
  ...fields,
];

List<int> u32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

List<int> u64(int value) =>
    (ByteData(8)..setUint64(0, value)).buffer.asUint8List();

/// A track: its id, timescale, and whether its header boxes are version 1.
typedef SampleTrack = ({int id, int timescale, bool v1});

const sampleTracks = <SampleTrack>[
  (id: 1, timescale: 16000, v1: false),
  (id: 2, timescale: 48000, v1: true),
];

Uint8List sampleFtyp() => mp4Box('ftyp', [
  ...ascii.encode('isom'),
  ...u32(512),
  ...'isomiso6'.codeUnits,
]);

/// `moov` with a length of 0 throughout, as FFmpeg writes it, at a movie
/// timescale of 1000; [mehd] adds one (version 0) with [mehdLength].
Uint8List sampleMoov({
  List<SampleTrack> tracks = sampleTracks,
  bool mvhdV1 = false,
  bool mehd = false,
  int mehdLength = 0,
}) {
  final mvhd = mp4Box(
    'mvhd',
    fullBody(mvhdV1 ? 1 : 0, 0, [
      ...mvhdV1 ? [...u64(0), ...u64(0)] : [...u32(0), ...u32(0)],
      ...u32(1000),
      ...mvhdV1 ? u64(0) : u32(0),
      ...List.filled(80, 0),
    ]),
  );
  final traks = [
    for (final track in tracks)
      mp4Box('trak', [
        ...mp4Box(
          'tkhd',
          fullBody(track.v1 ? 1 : 0, 3, [
            ...track.v1 ? [...u64(0), ...u64(0)] : [...u32(0), ...u32(0)],
            ...u32(track.id),
            ...u32(0),
            ...track.v1 ? u64(0) : u32(0),
            ...List.filled(60, 0),
          ]),
        ),
        ...mp4Box('mdia', [
          ...mp4Box(
            'mdhd',
            fullBody(track.v1 ? 1 : 0, 0, [
              ...track.v1 ? [...u64(0), ...u64(0)] : [...u32(0), ...u32(0)],
              ...u32(track.timescale),
              ...track.v1 ? u64(0) : u32(0),
              ...u32(0x55c40000),
            ]),
          ),
          ...mp4Box('hdlr', fullBody(0, 0, List.filled(21, 0))),
        ]),
      ]),
  ];
  final mvex = mp4Box('mvex', [
    if (mehd) ...mp4Box('mehd', fullBody(0, 0, u32(mehdLength))),
    for (final track in tracks)
      ...mp4Box(
        'trex',
        fullBody(0, 0, [...u32(track.id), ...List.filled(16, 0)]),
      ),
  ]);
  return mp4Box('moov', [
    ...mvhd,
    for (final trak in traks) ...trak,
    ...mvex,
    ...mp4Box('udta', ascii.encode('made by hand')),
  ]);
}

/// One fragment: for each track its `tfdt` ([decode] ticks, version 1
/// unless the track's [v0Fragments]), and [baseDataOffset] in `tfhd`
/// when given (FFmpeg without `default_base_moof`).
Uint8List sampleMoof({
  required int sequence,
  required Map<int, int> decode,
  Set<int> v0Fragments = const {2},
  int? baseDataOffset,
}) => mp4Box('moof', [
  ...mp4Box('mfhd', fullBody(0, 0, u32(sequence))),
  for (final MapEntry(key: id, value: ticks) in decode.entries)
    ...mp4Box('traf', [
      ...mp4Box(
        'tfhd',
        baseDataOffset == null
            ? fullBody(0, 0x020000, u32(id))
            : fullBody(0, 0x000001, [...u32(id), ...u64(baseDataOffset)]),
      ),
      ...mp4Box(
        'tfdt',
        v0Fragments.contains(id)
            ? fullBody(0, 0, u32(ticks))
            : fullBody(1, 0, u64(ticks)),
      ),
      ...mp4Box('trun', fullBody(0, 0x000001, [...u32(0), ...u32(8)])),
    ]),
]);

Uint8List sampleMdat(int length, {int seed = 0}) =>
    mp4Box('mdat', [for (var i = 0; i < length; i++) (i + seed) & 0xff]);

Uint8List sampleMfra() => mp4Box('mfra', [
  ...mp4Box('tfra', fullBody(1, 0, [...u32(1), ...u32(0), ...u32(0)])),
  ...mp4Box('mfro', fullBody(0, 0, u32(8 + 20 + 16))),
]);

/// A whole stream: header, two fragments 2 s apart, the index.
Uint8List sampleStream({bool mehd = false, int? baseDataOffset}) =>
    Uint8List.fromList([
      ...sampleFtyp(),
      ...sampleMoov(mehd: mehd),
      ...sampleMoof(
        sequence: 1,
        decode: {1: 0, 2: 0},
        baseDataOffset: baseDataOffset,
      ),
      ...sampleMdat(300),
      ...sampleMoof(
        sequence: 2,
        decode: {1: 32000, 2: 96000},
        baseDataOffset: baseDataOffset,
      ),
      ...sampleMdat(300, seed: 7),
      ...sampleMfra(),
    ]);

/// Where the [nth] box at [path] is in [file]: its body's first byte and
/// its end. Null when there is none.
({int body, int end})? findBox(
  Uint8List file,
  List<String> path, {
  int nth = 0,
}) {
  final data = ByteData.sublistView(file);
  var found = 0;
  ({int body, int end})? search(int from, int to, int depth) {
    var at = from;
    while (at + 8 <= to) {
      var size = data.getUint32(at);
      var head = 8;
      if (size == 1) {
        size = data.getUint64(at + 8);
        head = 16;
      }
      final type = String.fromCharCodes(file.sublist(at + 4, at + 8));
      if (size < head || at + size > to) return null;
      if (type == path[depth]) {
        if (depth == path.length - 1) {
          if (found++ == nth) return (body: at + head, end: at + size);
        } else {
          final inner = search(at + head, at + size, depth + 1);
          if (inner != null) return inner;
        }
      }
      at += size;
    }
    return null;
  }

  return search(0, file.length, 0);
}

/// The size field of the [nth] box at [path].
int boxSize(Uint8List file, List<String> path, {int nth = 0}) {
  final box = findBox(file, path, nth: nth)!;
  return box.end - box.body + 8;
}

/// A full box's version-dependent time field: [v0] bytes into the body
/// for version 0 (32 bits), [v1] for version 1 (64 bits).
int timeField(
  Uint8List file,
  List<String> path, {
  required int v0,
  required int v1,
  int nth = 0,
}) {
  final box = findBox(file, path, nth: nth)!;
  final data = ByteData.sublistView(file);
  return file[box.body] == 1
      ? data.getUint64(box.body + v1)
      : data.getUint32(box.body + v0);
}

int _fourcc(String type) =>
    ByteData.sublistView(Uint8List.fromList(ascii.encode(type))).getUint32(0);
