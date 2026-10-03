import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/cast_picker.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

// What the Cast buttons, C and the menus do (Phase 7 decision 2).

/// Cast [item] (a details page's, a channel's menu), or what plays here
/// when there is none: the picker, or, with a session already on, the TV
/// at once.
Future<void> castFrom(
  BuildContext context, {
  Playable? item,
  Duration? from,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final cast = container.read(castCoordinatorProvider);
  if (cast.state.active && item != null) {
    await playOnTv(container, item, from: from);
    return;
  }
  await showCastPicker(context, item: item, from: from);
}

/// Starts a session on [device]: what plays here moves to it (the
/// coordinator's hand-over), then [item] plays there if it isn't what
/// moved. The casting view opens once something plays.
Future<void> castTo(
  ProviderContainer container,
  CastDevice device, {
  Playable? item,
  Duration? from,
}) async {
  final cast = container.read(castCoordinatorProvider);
  await cast.connect(device);
  final moved = cast.state.item;
  if (item != null && moved != item) {
    await playOnTv(container, item, from: from);
  } else if (moved != null) {
    container.read(castingViewOpenProvider.notifier).open();
  }
}

/// Plays [item] on the TV (a session is on), and shows the casting view.
Future<void> playOnTv(
  ProviderContainer container,
  Playable item, {
  Duration? from,
}) async {
  container.read(castingViewOpenProvider.notifier).open();
  final playback = container.read(playbackCoordinatorProvider);
  switch (item) {
    case PlayableChannel(:final channel):
      unawaited(playback.playLive(channel));
    case final Playable file:
      unawaited(playback.playVod(file, from: from));
  }
}
