import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iptv_player/design/tokens.dart';

/// Every icon on the design canvas, extracted to `assets/icons/` by
/// `tools/extract_icons.dart`. The name is the asset's file name, so a
/// typo fails at asset load rather than silently rendering nothing.
enum AppIcons {
  alertCircle('alert-circle'),
  alertTriangle('alert-triangle'),
  arrowDown('arrow-down'),
  arrowLeft('arrow-left'),
  arrowRight('arrow-right'),
  arrowUp('arrow-up'),
  aspectRatio('aspect-ratio'),
  audio('audio'),
  bell('bell'),
  bellFilled('bell-filled'),
  cast('cast'),
  castConnected('cast-connected'),
  catchUp('catch-up'),
  channelList('channel-list'),
  check('check'),
  chevronDown('chevron-down'),
  chevronLeft('chevron-left'),
  chevronRight('chevron-right'),
  chevronUp('chevron-up'),
  clock('clock'),
  close('close'),
  deviceSpeaker('device-speaker'),
  deviceTv('device-tv'),
  download('download'),
  downloadActive('download-active'),
  dragHandle('drag-handle'),
  edit('edit'),
  exitFullscreen('exit-fullscreen'),
  eye('eye'),
  filter('filter'),
  folder('folder'),
  forward10('forward-10'),
  fullscreen('fullscreen'),
  guide('guide'),
  home('home'),
  info('info'),
  lastChannel('last-channel'),
  library('library'),
  liveTv('live-tv'),
  loading('loading'),
  more('more'),
  movies('movies'),
  pause('pause'),
  play('play'),
  plus('plus'),
  replay10('replay-10'),
  rescan('rescan'),
  retry('retry'),
  search('search'),
  series('series'),
  settings('settings'),
  skipNext('skip-next'),
  star('star'),
  starFilled('star-filled'),
  stop('stop'),
  storage('storage'),
  subtitles('subtitles'),
  trash('trash'),
  volumeHigh('volume-high'),
  volumeLow('volume-low'),
  volumeOff('volume-off');

  new(this.asset);

  final String asset;

  String get path => 'assets/icons/$asset.svg';
}

/// Renders a canvas icon, tinted with a token color. The SVGs use
/// `currentColor`, so one file serves every state.
class AppIcon extends StatelessWidget {
  const new(
    this.icon, {
    this.size = 20,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final AppIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.tokens.colors.textSecondary;
    return SvgPicture.asset(
      icon.path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
