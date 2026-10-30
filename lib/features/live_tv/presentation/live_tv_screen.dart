import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_list_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/live_tv/presentation/preview_pane.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Where the full-screen player lives (step 6); playback carries on
/// there, and stops anywhere else.
const playerRoutePath = '/player';

/// Live TV (canvas `Live TV`): categories, channels and the preview, side
/// by side. ← and → move between the panes; each remembers its place.
///
/// By the screen's width (ADR-068): narrower than a phone held upright
/// ([WindowSizes.phoneWidth]) the list alone, its title the button that
/// opens the categories in a sheet; wider, the categories beside it, and
/// the preview too where it has its narrowest. With no preview a press
/// on a channel plays it full screen, and back here the stream stops.
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

  /// The list keeps its place (its pages, its scroll) when the screen
  /// turns and its layout changes.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'live channel list');
  GoRouter? _router;

  /// Whether the layout drawn last has the preview pane: without it a
  /// press on a channel plays it full screen.
  bool _previewShown = true;

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
    // The top route's path: a push (the player, from here or from the
    // Guide) leaves the delegate's own configuration on the page under it.
    final path = _router?.state.uri.path;
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

  /// A click: the preview plays it. While casting it is only chosen
  /// (Phase 7 decision 2: the preview opens no stream; Enter plays on the
  /// TV).
  void _play(ChannelItem channel) {
    ref.read(liveTvControllerProvider.notifier).select(channel);
    final coordinator = ref.read(playbackCoordinatorProvider);
    if (coordinator.casting) return;
    _playNow(channel);
  }

  void _playNow(ChannelItem channel) {
    final coordinator = ref.read(playbackCoordinatorProvider);
    final playing = coordinator.current;
    if (playing?.id == channel.id && playing?.sourceId == channel.sourceId) {
      return;
    }
    unawaited(coordinator.playLive(channel));
  }

  /// Enter on a row, Watch full screen, or a double-click on the picture.
  /// While casting: the TV plays it, and the casting view opens.
  void _fullscreen(ChannelItem channel) {
    if (ref.read(playbackCoordinatorProvider).casting) {
      ref.read(liveTvControllerProvider.notifier).select(channel);
      unawaited(
        playOnTv(
          ProviderScope.containerOf(context, listen: false),
          PlayableChannel(channel),
        ),
      );
      return;
    }
    _play(channel);
    final back = context.push<void>(playerRoutePath);
    // Back from the player with no preview to go on playing in: the
    // stream stops, as it does back on Home.
    unawaited(
      back.then((_) {
        if (!mounted || _previewShown) return;
        final coordinator = ref.read(playbackCoordinatorProvider);
        if (coordinator.current != null && !coordinator.casting) {
          unawaited(coordinator.stop());
        }
      }),
    );
  }

  /// A phone's categories (ADR-068): a sheet with the categories pane and
  /// a filter over it; a choice closes it, and the list takes the focus.
  Future<void> _pickCategory() => showAppBottomSheet<void>(
    context,
    builder: (sheet) => _CategorySheet(
      controller: _categories,
      onChosen: () {
        Navigator.of(sheet).pop();
        _listFocus.request();
      },
      onLeaving: () => Navigator.of(sheet).pop(),
    ),
  );

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
    if (next != null && mounted) {
      ref.read(liveTvControllerProvider.notifier).select(next);
      _playNow(next);
    }
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
      child: LayoutBuilder(
        builder: (context, screen) {
          if (screen.maxWidth < WindowSizes.phoneWidth) {
            _previewShown = false;
            return ChannelListPane(
              key: _listKey,
              controller: _channels,
              focusRequests: _listFocus,
              compact: true,
              onPickCategory: () => unawaited(_pickCategory()),
              onPlay: _fullscreen,
              onFullscreen: _fullscreen,
            );
          }
          return Padding(
            padding: EdgeInsets.all(gap),
            child: LayoutBuilder(
              builder: (context, constraints) => _panes(constraints, gap),
            ),
          );
        },
      ),
    );
  }

  /// The canvas's widths at 1440 px (248 / flexible / 540), and what each
  /// pane does in another window (ADR-017):
  ///
  /// - **smaller:** the categories and the preview give way, so the list
  ///   keeps the width at which a channel's name can be read;
  /// - **larger:** the preview grows with the window, as far as its
  ///   picture leaves room under it for what is on; the list stops at the
  ///   width past which a row's name and its star are far apart, and what
  ///   is left stays empty at the right.
  ///
  /// Narrower than the three at their narrowest (a tablet, a phone on its
  /// side; ADR-068): the categories and the list, which takes the rest.
  Widget _panes(BoxConstraints constraints, double gap) {
    final layout = context.tokens.layout;
    final width = constraints.maxWidth;
    final categories = (width * layout.categoriesShare).clamp(
      layout.categoriesMinWidth,
      layout.categoriesWidth,
    );
    final categoriesPane = SizedBox(
      width: categories,
      child: CategoriesPane(
        controller: _categories,
        onEnterList: _channels.focusPane,
        onChosen: _listFocus.request,
      ),
    );
    if (width <
        categories + layout.channelListMin + layout.previewMin + gap * 2) {
      _previewShown = false;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          categoriesPane,
          SizedBox(width: gap),
          Expanded(
            child: ChannelListPane(
              key: _listKey,
              controller: _channels,
              focusRequests: _listFocus,
              onBack: _categories.focusPane,
              onPlay: _fullscreen,
              onFullscreen: _fullscreen,
            ),
          ),
        ],
      );
    }
    _previewShown = true;
    final shared = width - categories - gap * 2;
    final previewMax = math.max(
      PreviewPane.width,
      (constraints.maxHeight - layout.previewDetailsRoom) * 16 / 9,
    );
    var preview = (shared * layout.previewShare).clamp(
      layout.previewMin,
      previewMax,
    );
    preview = math.min(
      preview,
      math.max(layout.previewMin, shared - layout.channelListMin),
    );
    var list = shared - preview;
    if (list > layout.channelListMax) {
      preview = math.min(shared - layout.channelListMax, previewMax);
      list = math.min(shared - preview, layout.channelListMax);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoriesPane,
        SizedBox(width: gap),
        SizedBox(
          width: list,
          child: ChannelListPane(
            key: _listKey,
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

/// A phone's categories (ADR-068), in a sheet: a filter, for a provider's
/// 146 of them, over the categories pane's list (Favorites and its groups,
/// All channels, the categories with their counts, the hidden ones' foot
/// and its Manage), each with its menu on a long press.
class _CategorySheet extends StatefulWidget {
  const new({
    required this.controller,
    required this.onChosen,
    required this.onLeaving,
  });

  final FocusPaneController controller;
  final VoidCallback onChosen;
  final VoidCallback onLeaving;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppBottomSheet(
      title: 'Categories',
      tall: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s4),
              child: SearchField(
                controller: _filter,
                hint: 'Filter categories',
                shortcut: null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(height: tokens.spacing.s8),
            Expanded(
              child: CategoriesPane(
                controller: widget.controller,
                framed: false,
                nameFilter: _filter.text,
                onChosen: widget.onChosen,
                onLeaving: widget.onLeaving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
