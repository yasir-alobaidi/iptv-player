import 'package:flutter/material.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_screen.dart';

/// Movies: the poster grid (docs/05 §6, canvas `Movies`).
class MoviesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const CatalogueScreen(kind: CatalogueKind.movie);
}
