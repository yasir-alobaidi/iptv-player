import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';

/// What the user chose in the Match… picker.
sealed class GuideMatchChoice {
  const new();
}

/// Attach the channel to [channel], whatever matched it before.
final class MatchToGuideChannel extends GuideMatchChoice {
  const new(this.channel);

  final GuideChannel channel;
}

/// Drop the user's own mapping and let the matcher decide again.
final class UseAutomaticMatch extends GuideMatchChoice {
  const new();
}

/// Opens the Match… picker for [channel] (the approved sketch): type to
/// filter the guide's channels, ranked by how close their names are to
/// the channel's; ↑/↓ move, Enter matches, Esc cancels. Null when
/// cancelled.
Future<GuideMatchChoice?> showGuideMatchPicker(
  BuildContext context, {
  required ChannelGuideMatch channel,
}) => showAppDialog<GuideMatchChoice>(
  context,
  builder: (_) => GuideMatchPicker(channel: channel),
);

class GuideMatchPicker extends ConsumerStatefulWidget {
  const new({required this.channel, super.key});

  final ChannelGuideMatch channel;

  /// How long typing must pause before the guide is asked again.
  static const debounce = Duration(milliseconds: 120);

  static const rowHeight = 52.0;
  static const listHeight = 320.0;

  @override
  ConsumerState<GuideMatchPicker> createState() => _GuideMatchPickerState();
}

class _GuideMatchPickerState extends ConsumerState<GuideMatchPicker> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  var _generation = 0;
  List<GuideChannelCandidate>? _candidates;
  AppFailure? _error;
  var _highlighted = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(GuideMatchPicker.debounce, () => unawaited(_load()));
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final result = await ref
        .read(epgRepositoryProvider)
        .matchCandidates(
          widget.channel.sourceId,
          channelName: widget.channel.providerName,
          query: _query.text,
        );
    if (!mounted || generation != _generation) return;
    setState(() {
      switch (result) {
        case Ok(:final value):
          _candidates = value;
          _error = null;
          _highlighted = 0;
          if (_scroll.hasClients) _scroll.jumpTo(0);
        case Err(:final failure):
          _error = failure;
      }
    });
  }

  void _move(int by) {
    final candidates = _candidates;
    if (candidates == null || candidates.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + by).clamp(0, candidates.length - 1);
    });
    _reveal(_highlighted);
  }

  /// Scrolls just enough to show row [index].
  void _reveal(int index) {
    if (!_scroll.hasClients) return;
    final top = index * GuideMatchPicker.rowHeight;
    final bottom = top + GuideMatchPicker.rowHeight;
    final view = _scroll.position.viewportDimension;
    final offset = _scroll.offset;
    if (top < offset) {
      _scroll.jumpTo(top);
    } else if (bottom > offset + view) {
      _scroll.jumpTo(bottom - view);
    }
  }

  void _pick([int? index]) {
    final candidates = _candidates;
    final at = index ?? _highlighted;
    if (candidates == null || at < 0 || at >= candidates.length) return;
    Navigator.of(context).pop(MatchToGuideChannel(candidates[at].channel));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final channel = widget.channel;
    final pageRows =
        (GuideMatchPicker.listHeight / GuideMatchPicker.rowHeight).floor() - 1;

    return AppDialog(
      title: 'Match ${channel.name}',
      subtitle: 'Now: ${matchStatus(channel)}',
      width: 560,
      focusButtons: false,
      primaryLabel: 'Match',
      onPrimary: _pick,
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1),
              const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                  _move(pageRows),
              const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                  _move(-pageRows),
            },
            child: AppTextField(
              controller: _query,
              autofocus: true,
              hint: "Search the guide's channels",
              leading: AppIcons.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _pick(),
            ),
          ),
          SizedBox(height: tokens.spacing.s12),
          SizedBox(height: GuideMatchPicker.listHeight, child: _list(context)),
          if (channel.isManual) ...[
            SizedBox(height: tokens.spacing.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Undo my match',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: () =>
                    Navigator.of(context).pop(const UseAutomaticMatch()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final tokens = context.tokens;
    final error = _error;
    final candidates = _candidates;
    if (error != null && candidates == null) {
      return ErrorState(
        compact: true,
        title: "Couldn't read the guide's channels",
        message: failureMessage(error),
        onRetry: () => unawaited(_load()),
      );
    }
    if (candidates == null) {
      return Semantics(
        label: "Loading the guide's channels",
        child: Column(
          children: [
            for (var i = 0; i < 5; i++) ...[
              const SkeletonRow(height: GuideMatchPicker.rowHeight - 8),
              SizedBox(height: tokens.spacing.s8),
            ],
          ],
        ),
      );
    }
    if (candidates.isEmpty) {
      final query = _query.text.trim();
      return EmptyState(
        compact: true,
        icon: query.isEmpty ? AppIcons.guide : AppIcons.search,
        title: query.isEmpty
            ? 'The guide has no channels'
            : 'No guide channel matches "$query"',
        message: query.isEmpty
            ? 'Import the guide first, then match channels to it.'
            : 'Try part of the name, or its id.',
      );
    }
    return Semantics(
      liveRegion: true,
      label:
          '${candidates.length} guide '
          '${candidates.length == 1 ? 'channel' : 'channels'}',
      child: ListView.builder(
        controller: _scroll,
        itemCount: candidates.length,
        itemExtent: GuideMatchPicker.rowHeight,
        itemBuilder: (context, index) => _CandidateRow(
          candidate: candidates[index],
          highlighted: index == _highlighted,
          current: candidates[index].channel.xmltvId == widget.channel.xmltvId,
          onPressed: () => _pick(index),
          onHover: () => setState(() => _highlighted = index),
        ),
      ),
    );
  }
}

/// One guide channel in the picker. Not a focus stop: the search field
/// keeps the focus and ↑/↓ move the highlight, as in a command palette.
class _CandidateRow extends StatelessWidget {
  const new({
    required this.candidate,
    required this.highlighted,
    required this.current,
    required this.onPressed,
    required this.onHover,
  });

  final GuideChannelCandidate candidate;
  final bool highlighted;
  final bool current;
  final VoidCallback onPressed;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final channel = candidate.channel;
    final label = channel.label;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
      child: Semantics(
        button: true,
        selected: highlighted,
        label: [
          label,
          if (label != channel.xmltvId) channel.xmltvId,
          if (candidate.score >= 1) 'best match',
          if (current) 'current',
        ].join(', '),
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(),
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
              decoration: BoxDecoration(
                color: highlighted ? colors.surface3 : colors.surface2,
                borderRadius: tokens.radii.controlAll,
                border: Border.all(
                  color: highlighted ? colors.accentBase : colors.surface3,
                ),
              ),
              child: Row(
                children: [
                  ChannelLogo(
                    name: label,
                    size: 28,
                    image: _logo(channel.iconUrl),
                  ),
                  SizedBox(width: tokens.spacing.s12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.label
                              .withWeight(highlighted ? 700 : 600)
                              .copyWith(color: colors.textPrimary),
                        ),
                        if (label != channel.xmltvId)
                          Text(
                            channel.xmltvId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.text.labelSmall.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (current) ...[
                    SizedBox(width: tokens.spacing.s8),
                    const AppBadge('Current', tone: AppBadgeTone.outline),
                  ],
                  if (candidate.score >= 1) ...[
                    SizedBox(width: tokens.spacing.s8),
                    const AppBadge('Best match', tone: AppBadgeTone.accent),
                  ],
                ],
              ),
            ),
          ),
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
