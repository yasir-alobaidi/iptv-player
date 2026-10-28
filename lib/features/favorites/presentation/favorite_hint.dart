import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/components.dart';

/// How to add a favorite, in this device's terms: F on a keyboard; on a
/// TV's remote, holding OK opens the item's menu (docs/07); on a phone,
/// touching and holding does (ADR-068).
String favoriteHint(BuildContext context, {required String on}) =>
    KeyHints.shownIn(context)
    ? 'Press F on $on to add it here.'
    : TvMode.of(context)
    ? 'Hold OK on $on, then choose Add to favorites.'
    : 'Touch and hold $on, then choose Add to favorites.';
