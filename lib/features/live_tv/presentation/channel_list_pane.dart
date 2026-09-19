import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// The channel list: a header (the category, its count, the filter, No. /
/// A–Z) and a virtualized list of `ChannelRow`s that can hold 50,000
/// channels (hard rule 2: a count, then pages of [pageSize] on demand).
/// One Tab stop; ↑↓ move and select (the preview follows after a moment),
/// Enter plays at once, F toggles the favorite, the menu key opens the
/// row's menu, ← goes back to the categories, → to the preview.
class ChannelListPane extends ConsumerStatefulWidget {
  const new({
    required this.controller,
    this.focusRequests,
    this.onBack,
    this.onForward,
    this.onPlay,
    super.key,
  });

  final FocusPaneController controller;

  /// Each notification asks for the first row to take the focus, as soon
  /// as the list shows rows (a category was just chosen).
  final Listenable? focusRequests;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  /// Enter or a double click: play this channel now (full screen from
  /// step 6).
  final void Function(ChannelItem channel)? onPlay;

  static const pageSize = 100;

  @override
  ConsumerState<ChannelListPane> createState() => _ChannelListPaneState();
}

class _ChannelListPaneState extends ConsumerState<ChannelListPane> {
  final _scroll = ScrollController();
  final _pages = <int, List<ChannelItem>>{};
  final _loading = <int>{};
  ChannelQuery? _query;
  AppFailure? _error;
  bool _wantFocus = false;

  @override
  void initState() {
    super.initState();
    widget.focusRequests?.addListener(_onFocusRequest);
  }

  @override
  void didUpdateWidget(ChannelListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequests != widget.focusRequests) {
      oldWidget.focusRequests?.removeListener(_onFocusRequest);
      widget.focusRequests?.addListener(_onFocusRequest);
    }
  }

  @override
  void dispose() {
    widget.focusRequests?.removeListener(_onFocusRequest);
    _scroll.dispose();
    super.dispose();
  }

  void _onFocusRequest() => setState(() => _wantFocus = true);

  /// Hands the focus to the first row once one is on screen.
  void _focusFirstWhenReady() {
    if (!_wantFocus || _pages[0] == null) return;
    _wantFocus = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.focusFirst();
    });
  }

  void _reset(ChannelQuery query) {
    _query = query;
    _pages.clear();
    _loading.clear();
    _error = null;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  ChannelItem? _itemAt(int index) {
    final page = index ~/ ChannelListPane.pageSize;
    final rows = _pages[page];
    if (rows == null) {
      unawaited(_load(page));
      return null;
    }
    final offset = index % ChannelListPane.pageSize;
    return offset < rows.length ? rows[offset] : null;
  }

  Future<void> _load(int page) async {
    final query = _query;
    if (query == null || !_loading.add(page)) return;
    final result = await ref
        .read(channelRepositoryProvider)
        .range(
          query,
          page * ChannelListPane.pageSize,
          ChannelListPane.pageSize,
        );
    if (!mounted || query != _query) return;
    setState(() {
      _loading.remove(page);
      switch (result) {
        case Ok(:final value):
          _pages[page] = value;
        case Err(:final failure):
          _error = failure;
      }
    });
  }

  /// Something changed (a favorite, a rename, a sync): reload what shows.
  void _refresh() {
    if (!mounted) return;
    setState(() {
      _pages.clear();
      _loading.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final view = ref.watch(liveTvControllerProvider);
    if (view == null) return const SizedBox.shrink();
    final query = view.query;
    if (query != _query) _reset(query);
    ref.listen(channelCountProvider(query), (_, _) => _refresh());
    final count = ref.watch(channelCountProvider(query));
    ref.watch(guideRevisionProvider);
    final title = _title(query.filter);
    final notifier = ref.read(liveTvControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(tokens.spacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.s4 + 2,
              tokens.spacing.s4,
              tokens.spacing.s4 + 2,
              tokens.spacing.s12,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.h3
                          .withWeight(700)
                          .copyWith(color: colors.textPrimary),
                    ),
                    SizedBox(height: tokens.spacing.s4 - 2),
                    Text(
                      switch (count.value) {
                        null => ' ',
                        1 => '1 channel',
                        final n => '${formatCount(n)} channels',
                      },
                      style: tokens.text.labelSmall.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                );
                final sort = SegmentedControl<ChannelSort>(
                  options: const [
                    SegmentOption(value: ChannelSort.number, label: 'No.'),
                    SegmentOption(value: ChannelSort.name, label: 'A–Z'),
                  ],
                  value: query.sort,
                  onChanged: notifier.setSort,
                );
                SearchField filter({double? width}) => SearchField(
                  key: ValueKey('live-filter-${query.filter.hashCode}'),
                  hint: 'Filter $title',
                  shortcut: null,
                  width: width,
                  onChanged: notifier.setText,
                );
                // Narrow: the filter and the sort go under the title.
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      SizedBox(height: tokens.spacing.s12),
                      Row(
                        children: [
                          Expanded(child: filter()),
                          SizedBox(width: tokens.spacing.s8),
                          sort,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    SizedBox(width: tokens.spacing.s12),
                    filter(width: 200),
                    SizedBox(width: tokens.spacing.s12),
                    sort,
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft):
                    ?widget.onBack,
                const SingleActivator(LogicalKeyboardKey.arrowRight):
                    ?widget.onForward,
                const SingleActivator(LogicalKeyboardKey.keyF): () {
                  final channel = ref.read(liveTvControllerProvider)?.selected;
                  if (channel != null) unawaited(_toggleFavorite(channel));
                },
              },
              child: FocusPane(
                debugLabel: 'live-channels',
                controller: widget.controller,
                tabStop: true,
                child: _body(context, view, count),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, LiveTvView view, AsyncValue<int> count) {
    final tokens = context.tokens;
    final query = view.query;
    final error = _error;
    if (count.hasError || error != null) {
      return ErrorState(
        compact: true,
        title: "Couldn't load the channels",
        message: 'The channel list could not be read.',
        details: '${error ?? count.error}',
        onRetry: () {
          ref.invalidate(channelCountProvider(query));
          _refresh();
          setState(() => _error = null);
        },
      );
    }
    final total = count.value;
    if (total == null) return _skeletons(tokens);
    if (total == 0) {
      _wantFocus = false;
      return _empty(context, query);
    }
    final rowHeight = tokens.density.rowHeight + 4;
    _focusFirstWhenReady();
    return ListView.builder(
      controller: _scroll,
      itemCount: total,
      itemExtent: rowHeight,
      itemBuilder: (context, index) {
        final channel = _itemAt(index);
        if (channel == null) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SkeletonRow(),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _Row(
            channel: channel,
            selected: view.selected?.id == channel.id,
            onSelect: () =>
                ref.read(liveTvControllerProvider.notifier).select(channel),
            onPlay: () => widget.onPlay?.call(channel),
            onFavorite: () => unawaited(_toggleFavorite(channel)),
            onMenu: (anchor) => unawaited(_menu(anchor, channel)),
          ),
        );
      },
    );
  }

  Widget _skeletons(AppTokens tokens) => Column(
    children: [
      for (var i = 0; i < 8; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SkeletonRow(height: tokens.density.rowHeight),
        ),
    ],
  );

  Widget _empty(BuildContext context, ChannelQuery query) {
    final notifier = ref.read(liveTvControllerProvider.notifier);
    if (query.text.trim().isNotEmpty) {
      return EmptyState(
        compact: true,
        icon: AppIcons.search,
        title: 'No channels match "${query.text.trim()}"',
      );
    }
    final syncing = ref.watch(syncStatusProvider(query.sourceId)).value;
    if (syncing is SyncRunning) {
      return const EmptyState(
        compact: true,
        icon: AppIcons.loading,
        title: 'Getting your channels…',
        message: 'They show here as soon as the sync has them.',
      );
    }
    return switch (query.filter) {
      FavoriteChannels() => const EmptyState(
        compact: true,
        icon: AppIcons.star,
        title: 'No favorites yet',
        message: 'Press F on a channel, or use its menu, to add it here.',
      ),
      _ when !query.showHidden => EmptyState(
        compact: true,
        icon: AppIcons.liveTv,
        title: 'No channels in this category.',
        actionLabel: 'Show hidden channels',
        onAction: () => notifier.setShowHidden(show: true),
      ),
      _ => const EmptyState(
        compact: true,
        icon: AppIcons.liveTv,
        title: 'No channels in this category.',
      ),
    };
  }

  String _title(ChannelFilter filter) => switch (filter) {
    AllChannels() => 'All channels',
    FavoriteChannels() => 'Favorites',
    UncategorizedChannels() => 'Uncategorized',
    CategoryChannels(:final categoryId) => _categoryName(categoryId),
  };

  String _categoryName(int id) {
    final sourceId = ref.read(liveTvControllerProvider)?.query.sourceId;
    if (sourceId == null) return 'Channels';
    final list = ref
        .watch(categoryListProvider(sourceId, CatalogueKind.live))
        .value;
    return list?.categories.where((c) => c.id == id).firstOrNull?.name ??
        'Channels';
  }

  Future<void> _toggleFavorite(ChannelItem channel) async {
    await ref
        .read(channelRepositoryProvider)
        .setFavorite(channel, on: !channel.isFavorite);
  }

  Future<void> _menu(BuildContext anchor, ChannelItem channel) {
    final repository = ref.read(channelRepositoryProvider);
    return showAppMenu(
      anchor,
      items: [
        AppMenuItem(
          label: 'Watch',
          icon: AppIcons.play,
          onPressed: () => widget.onPlay?.call(channel),
        ),
        AppMenuItem(
          label: channel.isFavorite
              ? 'Remove from favorites'
              : 'Add to favorites',
          icon: channel.isFavorite ? AppIcons.starFilled : AppIcons.star,
          shortcut: 'F',
          onPressed: () => unawaited(_toggleFavorite(channel)),
        ),
        AppMenuItem(
          label: 'Rename…',
          icon: AppIcons.edit,
          onPressed: () => unawaited(_rename(anchor, channel)),
        ),
        const AppMenuItem.separator(),
        AppMenuItem(
          label: channel.isHidden ? 'Show channel' : 'Hide channel',
          icon: AppIcons.eye,
          onPressed: () => unawaited(
            repository.setHidden(channel.id, hidden: !channel.isHidden),
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext anchor, ChannelItem channel) async {
    final result = await showAppDialog<_RenameResult>(
      anchor,
      builder: (context) => _RenameDialog(channel: channel),
    );
    if (result == null) return;
    await ref.read(channelRepositoryProvider).rename(channel.id, result.name);
  }
}

class _Row extends ConsumerStatefulWidget {
  const new({
    required this.channel,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
    required this.onFavorite,
    required this.onMenu,
  });

  final ChannelItem channel;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;
  final void Function(BuildContext anchor) onMenu;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  final _focus = FocusNode(debugLabel: 'channel row');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final guide = ref.watch(guideServiceProvider).cached(channel);
    final now = ref.watch(appClockProvider)();
    final programme = guide?.now;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) widget.onSelect();
      },
      // No double-click here: it would hold every single click back by the
      // double-click timeout. Enter opens full screen instead.
      child: Builder(
        builder: (context) => ChannelRow(
          name: channel.name,
          number: channel.number,
          image: _logo(channel.logoUrl),
          nowTitle: programme?.title,
          guideKnown: guide != null,
          progress: programme?.progressAt(now),
          isFavorite: channel.isFavorite,
          selected: widget.selected,
          focusNode: _focus,
          // A click takes the keyboard's place too, so the arrows go on
          // from the row that was clicked.
          onPressed: () {
            _focus.requestFocus();
            widget.onPlay();
          },
          onToggleFavorite: widget.onFavorite,
          onMenu: () => widget.onMenu(context),
        ),
      ),
    );
  }

  static ImageProvider? _logo(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return null;
    }
    return NetworkImage(url!);
  }
}

final class _RenameResult {
  const new(this.name);

  /// Null or blank: the provider's name.
  final String? name;
}

class _RenameDialog extends StatefulWidget {
  const new({required this.channel});

  final ChannelItem channel;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.channel.name)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.channel.name.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_RenameResult(_controller.text));

  @override
  Widget build(BuildContext context) {
    final original = widget.channel.providerName;
    return AppDialog(
      title: 'Rename channel',
      focusButtons: false,
      subtitle: original == null
          ? 'Only this app sees the new name.'
          : 'Your provider calls it "$original".',
      primaryLabel: 'Save',
      onPrimary: _save,
      secondaryLabel: original == null ? 'Cancel' : "Use provider's name",
      onSecondary: () =>
          Navigator.of(context)
              .pop(original == null ? null : const _RenameResult(null)),
      child: AppTextField(
        controller: _controller,
        label: 'Name',
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
