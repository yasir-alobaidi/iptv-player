import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';

/// Settings → Categories → Hidden channels (the plan's sketch B): the
/// channels the user hid, with Show on each and Show all. One Tab stop,
/// ↑/↓ inside it; Enter shows the channel, which leaves the list, and the
/// focus goes to the next one.
class HiddenChannelsView extends ConsumerStatefulWidget {
  const new({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<HiddenChannelsView> createState() => _HiddenChannelsState();
}

class _HiddenChannelsState extends ConsumerState<HiddenChannelsView> {
  var _filter = '';
  List<ChannelItem>? _channels;
  AppFailure? _error;
  final _nodes = <int, FocusNode>{};

  /// The row to focus once the list has read itself again.
  int? _focusIndex;

  ChannelQuery get _query => ChannelQuery(
    sourceId: widget.sourceId,
    filter: const HiddenChannels(),
    text: _filter,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final result = await ref
        .read(channelRepositoryProvider)
        .range(_query, 0, 5000);
    if (!mounted) return;
    setState(() {
      switch (result) {
        case Ok(:final value):
          _channels = value;
          _error = null;
        case Err(:final failure):
          _error = failure;
      }
    });
    final index = _focusIndex;
    final channels = _channels;
    if (index == null || channels == null) return;
    _focusIndex = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || channels.isEmpty) return;
      final next = channels[index.clamp(0, channels.length - 1)];
      _nodes[next.id]?.requestFocus();
    });
  }

  Future<void> _show(ChannelItem channel, int index) async {
    _focusIndex = index;
    await ref
        .read(channelRepositoryProvider)
        .setHidden(channel.id, hidden: false);
  }

  Future<void> _showAll() async {
    final repository = ref.read(channelRepositoryProvider);
    for (final channel in _channels ?? const <ChannelItem>[]) {
      await repository.setHidden(channel.id, hidden: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    ref.listen(channelRevisionProvider(_query), (_, _) => unawaited(_load()));
    final categories = {
      for (final c
          in ref
                  .watch(
                    categoryListProvider(widget.sourceId, CatalogueKind.live),
                  )
                  .value
                  ?.categories ??
              const <CategoryChoice>[])
        c.id: c.name,
    };
    final channels = _channels;

    final Widget list;
    if (_error != null && channels == null) {
      list = ErrorState(
        compact: true,
        title: "Couldn't load the hidden channels",
        message: 'The list could not be read.',
        onRetry: () => unawaited(_load()),
      );
    } else if (channels == null) {
      list = Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.s4),
              child: const SkeletonRow(height: 52),
            ),
        ],
      );
    } else if (channels.isEmpty) {
      list = EmptyState(
        compact: true,
        icon: AppIcons.eye,
        title: _filter.trim().isEmpty
            ? 'No hidden channels'
            : 'No hidden channel matches "${_filter.trim()}"',
        message: _filter.trim().isEmpty
            ? 'Hide a channel from its menu in Live TV, the Guide or Search.'
            : null,
      );
    } else {
      list = FocusPane(
        debugLabel: 'hidden-channels',
        tabStop: true,
        child: ListView.builder(
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return _HiddenRow(
              key: ValueKey(channel.id),
              channel: channel,
              category: categories[channel.categoryId],
              focusNode: _nodes.putIfAbsent(
                channel.id,
                () => FocusNode(debugLabel: 'hidden ${channel.id}'),
              ),
              onShow: () => unawaited(_show(channel, index)),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SearchField(
              hint: 'Filter hidden channels',
              shortcut: null,
              width: 260,
              onChanged: (text) {
                setState(() => _filter = text);
                unawaited(_load());
              },
            ),
            const Spacer(),
            if (channels != null && channels.isNotEmpty)
              AppButton(
                label: 'Show all',
                variant: AppButtonVariant.secondary,
                onPressed: () => unawaited(_showAll()),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.s12),
        Expanded(child: list),
        SizedBox(height: tokens.spacing.s12),
        Text(
          'Hidden channels are left out of Live TV, the Guide, Search and '
          'Home. They stay hidden after a re-sync.',
          style: tokens.text.caption.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// "118 · HC · Harbor City Local · UK | News · Show", as sketch B.
class _HiddenRow extends StatelessWidget {
  const new({
    required this.channel,
    required this.category,
    required this.focusNode,
    required this.onShow,
    super.key,
  });

  final ChannelItem channel;
  final String? category;
  final FocusNode focusNode;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      focusNode: focusNode,
      onPressed: onShow,
      hoverBackground: colors.surface3,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: '${channel.name}, hidden. Show',
      builder: (context, states) => SizedBox(
        height: 52,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  channel.number == null ? '' : '${channel.number}',
                  style: tokens.text.caption
                      .withWeight(600)
                      .copyWith(color: colors.textTertiary),
                ),
              ),
              ChannelLogo(
                name: channel.name,
                size: 32,
                image: artworkFor(context, channel.logoUrl, width: 32),
              ),
              SizedBox(width: tokens.spacing.s12),
              Expanded(
                flex: 3,
                child: Text(
                  channel.name,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  category ?? 'Uncategorized',
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              ExcludeFocus(
                child: AppButton(
                  label: 'Show',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: onShow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
