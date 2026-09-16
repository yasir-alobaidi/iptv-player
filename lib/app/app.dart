import 'package:flutter/material.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/design/theme.dart';

/// Root widget. Phase 1 step 4 replaces the home with the desktop shell
/// and moves the gallery to the `/dev/gallery` route; until then the
/// gallery is the app's only screen, so the design system can be used and
/// checked by hand.
class IptvPlayerApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: galleryEnabled ? const GalleryScreen() : const Scaffold(),
    );
  }
}
