import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/casting/presentation/cast_plan_text.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';
import 'package:iptv_player/features/casting/presentation/casting_view.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cast_shell_slots.g.dart';

/// The shell's casting slots (Phase 7 step 7): the bar under the content,
/// the top bar's Cast button, and the casting view in place of the
/// screen. `bootstrap()` applies them; an integration test must too.
final List<Override> castShellOverrides = [
  shellCastSessionProvider.overrideWith(_session),
  shellCastButtonProvider.overrideWith(_button),
  shellContentOverlayProvider.overrideWith(_overlay),
];

ShellCastSession? _session(Ref ref) {
  final state = ref.watch(castingStateProvider).value;
  if (state == null || !state.active) return null;
  // Read before building callbacks: they outlive this build.
  final cast = ref.read(castCoordinatorProvider);
  final playback = ref.read(playbackCoordinatorProvider);
  final view = ref.read(castingViewOpenProvider.notifier);
  final item = state.item;
  final device = state.device?.name ?? 'the TV';
  final title = switch (item) {
    null => 'Nothing playing',
    PlayableChannel(:final channel) =>
      ref.watch(nowNextProvider(channel)).value?.now?.title ?? channel.name,
    PlayableMovie(:final movie) => movie.name,
    PlayableEpisode(:final series, :final episode) =>
      '${series.name} · S${episode.season} E${episode.episode}',
    PlayableLibraryItem(:final item) => item.title,
  };
  final imageUrl = switch (item) {
    null => null,
    PlayableChannel(:final channel) => channel.logoUrl,
    PlayableMovie(:final movie) => movie.posterUrl,
    PlayableEpisode(:final series, :final episode) =>
      episode.stillUrl ?? series.posterUrl,
    PlayableLibraryItem() => null,
  };
  final playing = state.phase == CastPhase.playing;
  final plan = state.plan;
  final imageName = switch (item) {
    null => null,
    PlayableChannel(:final channel) => channel.name,
    PlayableMovie(:final movie) => movie.name,
    PlayableEpisode(:final series) => series.name,
    PlayableLibraryItem(:final item) => item.showTitle ?? item.title,
  };
  return ShellCastSession(
    title: title,
    deviceName: device,
    imageName: imageName,
    imageUrl: imageUrl,
    quality: playing && plan != null ? castBadge(plan) : null,
    status: castPhaseLine(state),
    isPlaying: !state.paused,
    reconnecting: state.reconnecting,
    onOpen: view.open,
    onPlayPause: item != null && !item.live && playing
        ? () => unawaited(playback.setPaused(paused: !state.paused))
        : null,
    onStop: () => unawaited(cast.disconnect()),
  );
}

ShellCastButton _button(Ref ref) {
  final active = ref.watch(castingStateProvider).value?.active ?? false;
  return ShellCastButton(
    connected: active,
    onPressed: (context) => unawaited(castFrom(context)),
  );
}

Widget? _overlay(Ref ref) {
  final open = ref.watch(castingViewOpenProvider);
  final active = ref.watch(castingStateProvider).value?.active ?? false;
  return open && active ? const CastingView() : null;
}

/// The cast's notices as toasts (docs/05: "Automatic fallbacks are quiet:
/// badge change + small toast"). `bootstrap()` reads it once.
@Riverpod(keepAlive: true)
void castNoticeToasts(Ref ref) {
  final cast = ref.watch(castCoordinatorProvider);
  final notices = ref.watch(appNoticesProvider);
  final listening = cast.notices.listen(
    (notice) => notices.show(
      AppNotice(
        castNoticeText(notice),
        tone: notice is CastSessionClosed && notice.end == CastEnd.lost
            ? NoticeTone.error
            : NoticeTone.neutral,
      ),
    ),
  );
  ref.onDispose(listening.cancel);
}

/// What a notice's toast says.
String castNoticeText(CastNotice notice) => switch (notice) {
  CastSessionClosed() => castClosedText(notice),
  CastStoppedOnDevice(:final deviceName) => 'Stopped on $deviceName',
  CastPlanChanged(:final deviceName, :final before, :final after) =>
    castPlanChangedText(before, after, deviceName),
};

/// "Now converting the audio for Living Room TV": what a quiet fallback
/// changed.
String castPlanChangedText(CastPlan before, CastPlan after, String device) {
  if (before.delivery.direct && !after.delivery.direct) {
    return "$device couldn't fetch it directly, so this computer sends it";
  }
  if (after.video is CastVideoTranscode &&
      before.video is! CastVideoTranscode) {
    return 'Now re-encoding the video for $device';
  }
  if (after.audio is CastAudioToAac && before.audio is! CastAudioToAac) {
    return 'Now converting the audio for $device';
  }
  if (after.output.height != before.output.height) {
    return 'Now sending ${after.output.height}p to $device';
  }
  return 'Changed how this plays on $device';
}

/// Before the first relay start on Windows: the firewall will ask about
/// the app, so say why first (once). `bootstrap()` gives it to
/// `relayFirewallNoticeProvider` on Windows; [navigatorContext] finds the
/// app's navigator.
Future<void> Function() windowsFirewallNotice(
  CastFirewallNoticeStore store,
  BuildContext? Function() navigatorContext,
) => () async {
  if (await store.explained()) return;
  final context = navigatorContext();
  if (context == null || !context.mounted) return;
  await showAppDialog<void>(
    context,
    builder: (dialog) => AppDialog(
      title: 'Windows will ask about the firewall',
      subtitle:
          'Your TV fetches the stream from this computer, on ports '
          '$castPortRange.',
      primaryLabel: 'Got it',
      onPrimary: () => Navigator.of(dialog).pop(),
      child: Text(
        'Windows asks whether IPTV Player may accept connections on your '
        "network. Allow it on private networks, or your TV won't be able "
        'to play what you cast.',
        style: dialog.tokens.text.body.copyWith(
          color: dialog.tokens.colors.textSecondary,
        ),
      ),
    ),
  );
  await store.markExplained();
};
