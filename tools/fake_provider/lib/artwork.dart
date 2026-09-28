/// Posters, logos, backdrops and episode stills: the panel's own URLs
/// (Phase 5 step 1), so an app pointed at this server loads, caches and
/// decodes real images the size real panels serve.
///
/// The generator writes every artwork URL under [artworkRoot], a host that
/// resolves nowhere; each response rewrites it with [artworkFor] to the
/// origin the client reached this server on, as `server_info` does. A few
/// images per kind are drawn once in Dart (no ffmpeg, no image package: the
/// fake provider also runs where neither is installed) and served under
/// every item's name.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Where the generator puts artwork. [artworkFor] turns it into this
/// server's `/art/…`; anything else (a junk icon, an outside URL) is left
/// as it is.
const artworkRoot = 'https://images.northwind.invalid/art';

/// [url] as a client of [origin] should see it.
String? artworkFor(String? url, String origin) =>
    url != null && url.startsWith('$artworkRoot/')
    ? '$origin/art/${url.substring(artworkRoot.length + 1)}'
    : url;

/// The sizes real panels link to: square channel logos, TMDB's 600 × 900
/// posters, its 1280 backdrops and 500 px episode stills.
enum ArtworkKind {
  live(256, 256),
  movie(600, 900),
  series(600, 900),
  episode(500, 281),
  backdrop(1280, 720);

  new(this.width, this.height);

  final int width;
  final int height;
}

/// Distinct pictures per kind; an item's id picks one.
const artworkVariants = 8;

/// `GET /art/<kind>/<id>.<ext>` and `/art/backdrop/<movie|series>/<id>.<ext>`.
/// An id the catalogue doesn't have is a 404, like a panel's missing file.
Handler artworkHandler(FakeServerState state) {
  final store = ArtworkStore();
  Response serve(Request request, ArtworkKind kind, String owner, String file) {
    final dot = file.lastIndexOf('.');
    final id = int.tryParse(dot < 0 ? file : file.substring(0, dot));
    if (id == null) return Response.notFound('no artwork $file\n');
    final catalog = state.catalog;
    final known = switch (owner) {
      'live' => catalog.channelById(id) != null,
      'movie' => catalog.movieById(id) != null,
      'series' => catalog.seriesById(id) != null,
      'episode' => catalog.episodeById(id) != null,
      _ => false,
    };
    if (!known) return Response.notFound('no artwork $file\n');
    final variant = id % artworkVariants;
    final image = store.image(kind, variant);
    final tag = '"art-${kind.name}-$variant-${image.length}"';
    final headers = {
      'content-type': 'image/png',
      'etag': tag,
      'cache-control': 'public, max-age=604800',
    };
    if (request.headers['if-none-match'] == tag) {
      return Response.notModified(headers: headers);
    }
    return Response.ok(image, headers: headers);
  }

  ArtworkKind? kindOf(String name) => switch (name) {
    'live' => ArtworkKind.live,
    'movie' => ArtworkKind.movie,
    'series' => ArtworkKind.series,
    'episode' => ArtworkKind.episode,
    _ => null,
  };

  return (Router(notFoundHandler: (_) => Response.notFound('no artwork\n'))
        ..get('/art/backdrop/<owner>/<file>', (
          Request request,
          String owner,
          String file,
        ) {
          if (owner != 'movie' && owner != 'series') {
            return Response.notFound('no artwork\n');
          }
          return serve(request, ArtworkKind.backdrop, owner, file);
        })
        ..get('/art/<kind>/<file>', (
          Request request,
          String kind,
          String file,
        ) {
          final artwork = kindOf(kind);
          if (artwork == null) return Response.notFound('no artwork\n');
          return serve(request, artwork, kind, file);
        }))
      .call;
}

/// Draws each (kind, variant) once and keeps the PNG.
class ArtworkStore {
  final _images = <(ArtworkKind, int), Uint8List>{};

  Uint8List image(ArtworkKind kind, int variant) =>
      _images[(kind, variant)] ??= _draw(kind, variant % artworkVariants);
}

/// Colours in the canvas's poster style: a light top, a dark foot, a glow.
const _palettes = <(int, int, int)>[
  (0xB8683F, 0x151A33, 0xFFD6A0),
  (0x8FD3DD, 0x0B1422, 0xE6FAFF),
  (0xA9C48A, 0x16200F, 0xF4FBEA),
  (0x2B5F8A, 0x0A1624, 0xAAE6FF),
  (0x9AA7B8, 0x1A2030, 0xF1F4F8),
  (0x5B2A6E, 0x0E0A18, 0xFF78C8),
  (0x6E2418, 0x2A1216, 0xFFAA5A),
  (0x243A4A, 0x121E28, 0xFFC878),
];

Uint8List _draw(ArtworkKind kind, int variant) {
  final (top, bottom, glow) = _palettes[variant];
  final w = kind.width;
  final h = kind.height;
  final pixels = Uint8List(w * h * 3);
  final glowX = w * (0.35 + variant * 0.05);
  final glowY = h * 0.3;
  final radius = math.min(w, h) * 0.45;
  // A cheap xorshift: a little grain, so an image weighs what a real one
  // does on the wire instead of compressing to nothing.
  var seed = 0x9E3779B9 ^ (kind.index << 8) ^ variant;
  int grain() {
    seed ^= seed << 13;
    seed ^= seed >>> 17;
    seed ^= seed << 5;
    seed &= 0xFFFFFFFF;
    // One pixel in sixteen, ±1: enough entropy for a realistic size.
    return (seed & 15) != 0 ? 0 : ((seed >>> 4) & 2) - 1;
  }

  int channel(int colour, int shift) => (colour >> shift) & 0xFF;
  var i = 0;
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    // Stripes over the lower half, as the canvas draws its posters.
    final stripe = t > 0.55 && (y ~/ math.max(2, h ~/ 90)).isEven;
    for (var x = 0; x < w; x++) {
      final dx = x - glowX;
      final dy = y - glowY;
      final g = math.max(0, 1 - math.sqrt(dx * dx + dy * dy) / radius);
      final glowAmount = g * g * 0.8;
      final noise = grain();
      for (final shift in const [16, 8, 0]) {
        final base =
            channel(top, shift) +
            (channel(bottom, shift) - channel(top, shift)) * t;
        var value = base + (channel(glow, shift) - base) * glowAmount + noise;
        if (stripe) value += 10;
        pixels[i++] = value.round().clamp(0, 255);
      }
    }
  }
  return encodePng(w, h, pixels);
}

/// An 8-bit RGB PNG of [rgb] (`width * height * 3` bytes, rows top down).
Uint8List encodePng(int width, int height, Uint8List rgb) {
  final stride = width * 3;
  final raw = Uint8List(height * (stride + 1));
  for (var y = 0; y < height; y++) {
    // Filter type 2 (Up): each byte less the one above it, which is what
    // makes a gradient compress like a real encoder's output.
    final row = y * (stride + 1);
    raw[row] = 2;
    for (var x = 0; x < stride; x++) {
      final above = y == 0 ? 0 : rgb[(y - 1) * stride + x];
      raw[row + 1 + x] = (rgb[y * stride + x] - above) & 0xFF;
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // colour type: RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typed = [...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List());
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibCodec().encode(raw));
  chunk('IEND', const []);
  return out.takeBytes();
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return c ^ 0xFFFFFFFF;
}
