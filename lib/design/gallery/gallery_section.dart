import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// A titled block of specimens in the gallery.
class GallerySection extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      margin: EdgeInsets.only(bottom: tokens.spacing.s24),
      padding: EdgeInsets.all(tokens.spacing.s20),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tokens.text.titleSmall.copyWith(color: colors.textPrimary),
          ),
          if (description != null) ...[
            SizedBox(height: tokens.spacing.s4),
            Text(
              description!,
              style: tokens.text.caption.copyWith(color: colors.textTertiary),
            ),
          ],
          SizedBox(height: tokens.spacing.s16),
          ...children,
        ],
      ),
    );
  }
}

/// A labelled specimen. [states] forces the interaction state so a sheet
/// can show default / hover / focused / pressed next to each other.
class Specimen extends StatelessWidget {
  const new({required this.label, required this.child, this.states, super.key});

  final String label;
  final Widget child;
  final SurfaceStates? states;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final body = states == null
        ? child
        : SurfaceStateOverride(states: states!, child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tokens.text.micro.copyWith(color: tokens.colors.textTertiary),
        ),
        SizedBox(height: tokens.spacing.s8),
        // Flexible so a specimen given a fixed height (the empty and
        // error sheets) shrinks instead of overflowing.
        Flexible(child: body),
      ],
    );
  }
}

/// Lays specimens out in a wrap with the standard gaps.
class SpecimenRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s16),
      child: Wrap(
        spacing: tokens.spacing.s16,
        runSpacing: tokens.spacing.s16,
        children: children,
      ),
    );
  }
}

/// The five interaction states every interactive specimen is shown in.
const gallerySurfaceStates = <String, SurfaceStates>{
  'Default': SurfaceStates(),
  'Hover': SurfaceStates(hovered: true),
  'Focused': SurfaceStates(focused: true),
  'Pressed': SurfaceStates(pressed: true, hovered: true),
};
