import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';

/// "Device not showing?" → Troubleshoot, and Settings → Casting's
/// firewall help: the network, the firewall's ports, VPNs.
Future<void> showCastHelp(BuildContext context) => showAppDialog<void>(
  context,
  builder: (dialog) => AppDialog(
    title: 'Casting troubleshooting',
    subtitle: 'What keeps a TV from finding or reaching this computer.',
    primaryLabel: 'Done',
    onPrimary: () => Navigator.of(dialog).pop(),
    onClose: () => Navigator.of(dialog).pop(),
    child: SingleChildScrollView(
      child: CastTroubleshooting(
        style: dialog.tokens.text.caption
            .withWeight(400)
            .copyWith(color: dialog.tokens.colors.textSecondary),
      ),
    ),
  ),
);

/// The troubleshooting points, each with its heading.
class CastTroubleshooting extends StatelessWidget {
  const new({required this.style, super.key});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, (heading, text)) in castTroubleshooting.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.s8 + 2),
          Text(
            heading,
            style: style.withWeight(700).copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: tokens.spacing.s4 / 2),
          SelectableText(text, style: style),
        ],
      ],
    );
  }
}
