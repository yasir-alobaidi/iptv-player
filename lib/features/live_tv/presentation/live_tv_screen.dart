import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_list_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/live_tv/presentation/preview_pane.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Where the full-screen player lives (step 6); playback carries on
/// there, and stops anywhere else.
const playerRoutePath = '/player';

/// Live TV (canvas `Live TV`): categories, channels and the preview, side
/// by side. ← and → move between the panes; each remembers its place.
class LiveTvScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  final _categories = FocusPaneController();
  final _channels = FocusPaneController();
  final _preview = FocusPaneController();
  final _listFocus = _FocusRequests();
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onLocation);
      _router = router?..routerDelegate.addListener(_onLocation);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onLocation);
    _categories.dispose();
    _channels.dispose();
    _preview.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  /// The shell keeps every destination built, so leaving Live TV doesn't
  /// dispose it: the stream is stopped here instead, unless the player
  /// took over.
  void _onLocation() {
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    if (path == null ||
        path == AppDestination.liveTv.path ||
        path.startsWith(playerRoutePath)) {
      return;
    }
    // Never created means nothing ever played.
    if (!ref.exists(playbackCoordinatorProvider)) return;
    final coordinator = ref.read(playbackCoordinatorProvider);
    if (coordinator.current != null) unawaited(coordinator.stop());
  }

  void _play(ChannelItem channel) {
    ref.read(liveTvControllerProvider.notifier).select(channel);
    final coordinator = ref.read(playbackCoordinatorProvider);
    final playing = coordinator.current;
    if (playing?.id == channel.id && playing?.sourceId == channel.sourceId) {
      return;
    }
    unawaited(coordinator.playLive(channel));
  }

  /// Enter on a row, Watch full screen, or a double-click on the picture.
  void _fullscreen(ChannelItem channel) {
    _play(channel);
    unawaited(context.push(playerRoutePath));
  }

  /// The channel after the one playing, in the list as it shows.
  Future<void> _nextChannel() async {
    final view = ref.read(liveTvControllerProvider);
    final current = ref.read(playbackCoordinatorProvider).current;
    if (view == null || current == null) return;
    final repository = ref.read(channelRepositoryProvider);
    final index = (await repository.indexOf(
      view.query,
      current.id,
    )).valueOrNull;
    final next = (await repository.range(
      view.query,
      (index ?? -1) + 1,
      1,
    )).valueOrNull?.firstOrNull;
    if (next != null && mounted) _play(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final source = ref.watch(currentSourceProvider);
    if (source == null) {
      return FocusPane(
        debugLabel: 'screen-live-tv',
        child: EmptyState(
          icon: AppIcons.liveTv,
          title: 'No channels yet',
          message: 'Add your provider to see its channels here.',
          actionLabel: 'Add a source',
          onAction: () => context.push(addSourceRoutePath),
        ),
      );
    }
    final gap = tokens.spacing.s16;
    return FocusPane(
      debugLabel: 'screen-live-tv',
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: LayoutBuilder(
          builder: (context, constraints) => _panes(constraints.maxWidth, gap),
        ),
      ),
    );
  }

  /// The canvas's widths at 1440 px (248 / flexible / 540); the preview
  /// gives way on a smaller window so the list keeps room for its header.
  Widget _panes(double width, double gap) {
    final shared = width - CategoriesPane.width - gap * 2;
    final preview = (shared * 0.51).clamp(380.0, PreviewPane.width);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: CategoriesPane.width,
          child: CategoriesPane(
            controller: _categories,
            onEnterList: _channels.focusPane,
            onChosen: _listFocus.request,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: ChannelListPane(
            controller: _channels,
            focusRequests: _listFocus,
            onBack: _categories.focusPane,
            onForward: _preview.focusPane,
            onPlay: _play,
            onFullscreen: _fullscreen,
          ),
        ),
        SizedBox(width: gap),
        SizedBox(
          width: preview,
          child: PreviewPane(
            controller: _preview,
            onBack: _channels.focusPane,
            onFullscreen: _fullscreen,
            onNextChannel: () => unawaited(_nextChannel()),
          ),
        ),
      ],
    );
  }
}

/// "The list should take the focus": a category was chosen.
final class _FocusRequests extends ChangeNotifier {
  void request() => notifyListeners();
}
