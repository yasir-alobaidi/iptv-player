import 'package:flutter/material.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_screen.dart';

/// Series: the same grid as Movies (docs/05 §7).
class SeriesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const CatalogueScreen(kind: CatalogueKind.series);
}
