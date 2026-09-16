import 'package:flutter/material.dart';
import 'package:iptv_player/design/tokens.dart';

/// A channel's logo, or a generated monogram tile when there is none
/// (docs/05). The tile color comes from a hash of the name, so the same
/// channel always gets the same color.
///
/// [image] is a plain [ImageProvider] so this stays presentational; the
/// feature layer supplies a cached network provider.
class ChannelLogo extends StatelessWidget {
  const new({
    required this.name,
    this.image,
    this.size = 40,
    this.borderRadius,
    super.key,
  });

  final String name;
  final ImageProvider? image;
  final double size;
  final BorderRadius? borderRadius;

  /// The monogram: up to two initials from the channel name.
  static String monogramOf(String name) {
    final words = name
        .replaceAll(RegExp('[^A-Za-z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.length == 1
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Deterministic tile color for [name], from the canvas palette.
  static Color colorOf(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return monogramPalette[hash % monogramPalette.length];
  }

  /// The monogram colors used on the canvas.
  static const monogramPalette = <Color>[
    Color(0xFF2B4C8C),
    Color(0xFF6B3FA0),
    Color(0xFFA0522D),
    Color(0xFF1E7A6B),
    Color(0xFF7A2E4D),
    Color(0xFF3D6B2E),
    Color(0xFF8C6A1E),
    Color(0xFF2E5E7A),
    Color(0xFF5A2E7A),
    Color(0xFF3D5A8C),
    Color(0xFF1E5E7A),
    Color(0xFF7A3D2E),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = borderRadius ?? tokens.radii.controlAll;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: image != null
            ? Image(
                image: image!,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) =>
                    _Monogram(name: name, size: size),
              )
            : _Monogram(name: name, size: size),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const new({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: ChannelLogo.colorOf(name),
      child: Center(
        child: Text(
          ChannelLogo.monogramOf(name),
          style: tokens.text.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.33,
          ),
        ),
      ),
    );
  }
}
