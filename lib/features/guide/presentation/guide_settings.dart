import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_request.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// Settings → Guide (the approved sketch, ADR-011 step 5): where a
/// source's guide comes from and how much of it matched, Refresh, the
/// days kept, the source's time offset, and its channels without a guide
/// with a Match… picker for each.
class GuideSettingsSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).value;
    final wanted = ref.watch(settingsLocationProvider).guideSourceId;
    final current = ref.watch(currentSourceProvider);
    final source = sources?.where((s) => s.id == wanted).firstOrNull ?? current;

    if (sources == null) {
      return const SettingsPanel(title: 'Guide', body: _Loading());
    }
    if (source == null) {
      return SettingsPanel(
        title: 'Guide',
        body: EmptyState(
          icon: AppIcons.guide,
          title: 'No guide yet',
          message: 'Add a source first; its guide is set up here.',
          actionLabel: 'Add a source',
          onAction: () => _addSource(context, ref),
        ),
      );
    }

    final many = sources.length > 1;
    return SettingsPanel(
      title: 'Guide',
      subtitle: many
          ? 'Per source: where the guide comes from and which channels it '
                'covers.'
          : '${source.name}: where the guide comes from and which channels '
                'it covers.',
      actions: [
        if (many)
          Builder(
            builder: (anchor) => AppButton(
              label: source.name,
              trailingIcon: AppIcons.chevronDown,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(
                showAppMenu(
                  anchor,
                  width: 260,
                  items: [
                    for (final s in sources)
                      AppMenuItem(
                        label: s.name,
                        checked: s.id == source.id,
                        onPressed: () => ref
                            .read(settingsLocationProvider.notifier)
                            .showGuide(s.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
      // Keyed by source: the list, its filter and anything pending belong
      // to one source.
      body: _GuideBody(key: ValueKey(source.id), source: source),
    );
  }

  static void _addSource(BuildContext context, WidgetRef ref) {
    ref.read(pendingSourceDraftProvider.notifier).draft = null;
    ref.read(onboardingReturnPathProvider.notifier).path = GoRouterState.of(
      context,
    ).uri.path;
    unawaited(context.push<void>(addSourceRoutePath));
  }
}

class _GuideBody extends ConsumerStatefulWidget {
  const new({required this.source, super.key});

  final Source source;

  @override
  ConsumerState<_GuideBody> createState() => _GuideBodyState();
}

class _GuideBodyState extends ConsumerState<_GuideBody> {
  /// How long the offset must stay put before it is saved: each save
  /// re-imports the guide, so stepping from 0 to +2 h is one import.
  static const _offsetSettle = Duration(milliseconds: 1200);

  late final GuideSettingsController _settings = ref.read(
    guideSettingsControllerProvider.notifier,
  );

  String? _error;

  /// Refresh was pressed and the import hasn't answered yet.
  var _starting = false;

  int? _pendingOffset;
  Timer? _offsetTimer;
  Timer? _clock;

  ChannelMatchFilter _filter = ChannelMatchFilter.unmatched;
  var _query = '';

  /// Matches the user just made, shown at once until the list has been
  /// read again after the rematch (docs/05: optimistic updates).
  final _overrides = <int, ({ChannelGuideMatch row, bool settled})>{};
  var _listRevision = 0;

  String get _sourceId => widget.source.id;

  @override
  void initState() {
    super.initState();
    // "Updated 12 min ago" moves on by itself.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_takeMatchRequest()),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _offsetTimer?.cancel();
    // Leaving the page doesn't lose a step that hadn't settled yet.
    if (_pendingOffset case final minutes?
        when minutes != widget.source.epgOffsetMinutes) {
      unawaited(_settings.setOffset(widget.source, minutes));
    }
    super.dispose();
  }

  /// The Live TV preview's "Match to a guide channel" asked for a
  /// channel's picker.
  Future<void> _takeMatchRequest() async {
    if (!mounted) return;
    final channelId = ref.read(guideMatchRequestProvider.notifier).take();
    if (channelId == null) return;
    final found = await ref.read(epgRepositoryProvider).channelMatch(channelId);
    if (!mounted) return;
    switch (found) {
      case Ok(value: final channel?) when channel.sourceId == _sourceId:
        await _match(channel);
      case Ok():
        break;
      case Err(:final failure):
        setState(
          () => _error =
              "Couldn't open that channel's match. "
              '${failureMessage(failure)}',
        );
    }
  }

  Future<void> _import() async {
    final imports = ref.read(guideImportServiceProvider);
    final guide = ref.read(epgRepositoryProvider);
    final before = ref.read(guideCoverageProvider(_sourceId)).value;
    ref.invalidate(guideImportProgressProvider(_sourceId));
    setState(() {
      _starting = true;
      _error = null;
    });
    final result = await imports.importGuide(_sourceId);
    String? error;
    if (result case Err(:final failure) when failure is! CancelledFailure) {
      // A failure the import recorded shows in the Guide data row; one it
      // couldn't record (no guide address, a locked keyring) shows here.
      final after = (await guide.coverage(_sourceId)).valueOrNull;
      if (after?.lastImport?.id == before?.lastImport?.id) {
        error = "Couldn't import the guide. ${failureWithAnswer(failure)}";
      }
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = error;
    });
  }

  Future<void> _setKeepDays(int days) async {
    final result = await _settings.setKeepDays(days);
    if (!mounted) return;
    setState(() {
      _error = switch (result) {
        Err(:final failure) =>
          "Couldn't save that change. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
  }

  void _stepOffset(int minutes) {
    setState(() => _pendingOffset = minutes);
    _offsetTimer?.cancel();
    _offsetTimer = Timer(_offsetSettle, () => unawaited(_saveOffset()));
  }

  Future<void> _saveOffset() async {
    final minutes = _pendingOffset;
    if (minutes == null) return;
    if (minutes == widget.source.epgOffsetMinutes) {
      setState(() => _pendingOffset = null);
      return;
    }
    final result = await _settings.setOffset(widget.source, minutes);
    if (!mounted) return;
    if (result case Err(:final failure)) {
      setState(() {
        _pendingOffset = null;
        _error = "Couldn't change the offset. ${failureMessage(failure)}";
      });
    }
    // On success the pending value shows until the source reports it.
  }

  Future<void> _match(ChannelGuideMatch channel) async {
    final repository = ref.read(epgRepositoryProvider);
    final matching = ref.read(guideMatchingProvider);
    final choice = await showGuideMatchPicker(context, channel: channel);
    if (choice == null || !mounted) return;

    final shown = switch (choice) {
      MatchToGuideChannel(channel: final target) => ChannelGuideMatch(
        channelId: channel.channelId,
        sourceId: channel.sourceId,
        remoteKey: channel.remoteKey,
        name: channel.name,
        providerName: channel.providerName,
        number: channel.number,
        logoUrl: channel.logoUrl,
        epgKey: channel.epgKey,
        xmltvId: target.xmltvId,
        rule: GuideMatchRule.manual,
        guideLabel: target.label,
        inGuide: true,
      ),
      UseAutomaticMatch() => ChannelGuideMatch(
        channelId: channel.channelId,
        sourceId: channel.sourceId,
        remoteKey: channel.remoteKey,
        name: channel.name,
        providerName: channel.providerName,
        number: channel.number,
        logoUrl: channel.logoUrl,
        epgKey: channel.epgKey,
      ),
    };
    setState(() {
      _overrides[channel.channelId] = (row: shown, settled: false);
      _error = null;
    });

    final written = switch (choice) {
      MatchToGuideChannel(channel: final target) => await repository.setMapping(
        sourceId: channel.sourceId,
        channelRemoteKey: channel.remoteKey,
        xmltvId: target.xmltvId,
      ),
      UseAutomaticMatch() => await repository.removeMapping(
        sourceId: channel.sourceId,
        channelRemoteKey: channel.remoteKey,
      ),
    };
    if (written case Err(:final failure)) {
      if (!mounted) return;
      setState(() {
        _overrides.remove(channel.channelId);
        _error = "Couldn't save that match. ${failureMessage(failure)}";
      });
      return;
    }
    // The rest of the app (Live TV's rows, the player) follows the
    // matches, not the mappings: match again now.
    final matched = await matching.rematch(channel.sourceId);
    if (!mounted) return;
    setState(() {
      _overrides[channel.channelId] = (row: shown, settled: true);
      _listRevision++;
      if (matched case Err(:final failure) when failure is! CancelledFailure) {
        _error =
            "Your match is saved, but the channels couldn't be matched "
            'again. ${failureMessage(failure)}';
      }
    });
  }

  /// The list has been read again: matches that were settled by then are
  /// in what it read.
  void _onListReloaded() {
    if (!_overrides.values.any((o) => o.settled)) return;
    setState(() => _overrides.removeWhere((_, o) => o.settled));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final source = widget.source;
    if (_pendingOffset == source.epgOffsetMinutes &&
        !(_offsetTimer?.isActive ?? false)) {
      _pendingOffset = null;
    }
    // Settings can stay built behind Live TV, so a request can arrive
    // while this page already shows.
    ref.listen(guideMatchRequestProvider, (_, channelId) {
      if (channelId == null) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_takeMatchRequest()),
      );
    });
    final coverage = ref.watch(guideCoverageProvider(_sourceId));
    final counts = ref.watch(channelMatchCountsProvider(_sourceId)).value;
    final hasGuide = coverage.value?.hasGuide ?? false;
    final importing =
        _starting ||
        (coverage.value?.isImporting ?? false) ||
        ref.watch(guideImportServiceProvider).isImporting(_sourceId);
    final keepDays = ref.watch(guideSettingsControllerProvider).keepDays;

    final rows = [
      if (_error case final error?) ...[
        AppBanner(
          message: error,
          tone: BannerTone.error,
          onDismiss: () => setState(() => _error = null),
        ),
        SizedBox(height: tokens.spacing.s8),
      ],
      _GuideDataRow(
        source: source,
        counts: counts,
        importing: importing,
        onImport: () => unawaited(_import()),
        onCancel: () =>
            unawaited(ref.read(guideImportServiceProvider).cancel(_sourceId)),
      ),
      _Setting(
        title: 'Keep',
        description: Text(
          "Days of programmes to keep ahead, plus yesterday's, for every "
          'source. More days take longer to import.',
          style: _descriptionStyle(context),
        ),
        control: Builder(
          builder: (anchor) => AppButton(
            label: keepDaysLabel(keepDays),
            trailingIcon: AppIcons.chevronDown,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.s,
            onPressed: () => unawaited(
              showAppMenu(
                anchor,
                width: 160,
                items: [
                  for (final days in GuideSettings.keepDaysOptions)
                    AppMenuItem(
                      label: keepDaysLabel(days),
                      checked: days == keepDays,
                      onPressed: () => unawaited(_setKeepDays(days)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      _Setting(
        title: 'Time offset · ${source.name}',
        description: Text(
          'Moves every programme of this source by the same amount. Use it '
          'when they look an hour early or late; a change imports the '
          'guide again.',
          style: _descriptionStyle(context),
        ),
        control: _OffsetStepper(
          value: _pendingOffset ?? source.epgOffsetMinutes,
          onChanged: _stepOffset,
        ),
      ),
    ];

    final Widget list;
    if (!hasGuide) {
      list = coverage.hasError
          ? const SizedBox.shrink()
          : EmptyState(
              icon: AppIcons.guide,
              title: importing
                  ? 'Importing the guide…'
                  : 'No guide to match against yet',
              message: importing
                  ? 'Channels without a guide are listed here once it is in.'
                  : "Import the guide first. Channels it doesn't cover are "
                        'listed here, ready to match by hand.',
            );
    } else {
      list = _ChannelList(
        sourceId: _sourceId,
        filter: _filter,
        query: _query,
        revision: _listRevision,
        overrides: {
          for (final MapEntry(:key, :value) in _overrides.entries)
            key: value.row,
        },
        onMatch: (channel) => unawaited(_match(channel)),
        onReloaded: _onListReloaded,
      );
    }

    final channels = [
      if (hasGuide) ...[
        _ChannelsToolbar(
          filter: _filter,
          counts: counts,
          onFilter: (filter) => setState(() => _filter = filter),
          onQuery: (query) => setState(() => _query = query),
        ),
        SizedBox(height: tokens.spacing.s8),
      ],
    ];
    final footer = Text(
      "Channels you've hidden aren't listed or counted. Your matches stay "
      'through every refresh and sync.',
      style: tokens.text.caption.copyWith(color: tokens.colors.textTertiary),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tall enough: the settings on top, the list takes the rest. A
        // short window scrolls the whole page with the list at a fixed
        // height instead.
        if (constraints.maxHeight >= 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...rows,
              SizedBox(height: tokens.spacing.s16),
              ...channels,
              Expanded(child: list),
              SizedBox(height: tokens.spacing.s12),
              footer,
            ],
          );
        }
        return ListView(
          children: [
            ...rows,
            SizedBox(height: tokens.spacing.s16),
            ...channels,
            SizedBox(height: 320, child: list),
            SizedBox(height: tokens.spacing.s12),
            footer,
          ],
        );
      },
    );
  }
}

TextStyle _descriptionStyle(BuildContext context) => context.tokens.text.caption
    .copyWith(color: context.tokens.colors.textTertiary);

/// "Guide data": where the guide comes from, when it was updated and how
/// much of it matched, or why there is none — with Refresh, Cancel or the
/// way out of the problem beside it.
class _GuideDataRow extends ConsumerWidget {
  const new({
    required this.source,
    required this.counts,
    required this.importing,
    required this.onImport,
    required this.onCancel,
  });

  final Source source;
  final ChannelMatchCounts? counts;
  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = _descriptionStyle(context);
    final origin = ref.watch(guideOriginProvider(source.id));
    final coverage = ref.watch(guideCoverageProvider(source.id));
    final now = ref.watch(appClockProvider)();

    Widget line(String text, {Color? color}) =>
        Text(text, style: color == null ? style : style.copyWith(color: color));
    Widget button(
      String label,
      VoidCallback onPressed, {
      AppButtonVariant variant = AppButtonVariant.secondary,
    }) => AppButton(
      label: label,
      variant: variant,
      size: AppButtonSize.s,
      onPressed: onPressed,
    );
    void editSource() => unawaited(context.push(editSourcePath(source.id)));

    final List<Widget> lines;
    final Widget control;
    switch ((origin, coverage)) {
      case (AsyncValue(error: final error?), _) ||
          (_, AsyncValue(error: final error?)):
        final failure = error is AppFailure
            ? error
            : AppFailure.fromError(error);
        lines = [
          line(
            "Couldn't read this source's guide. ${failureMessage(failure)}",
            color: colors.danger,
          ),
        ];
        control = button('Try again', () {
          ref
            ..invalidate(guideOriginProvider(source.id))
            ..invalidate(guideCoverageProvider(source.id));
        });
      case (AsyncValue(value: null), _) || (_, AsyncValue(value: null)):
        lines = [
          const Skeleton.text(width: 280, height: 12),
          SizedBox(height: tokens.spacing.s8),
          const Skeleton.text(width: 200, height: 12),
        ];
        control = const SizedBox.shrink();
      case (AsyncValue(value: Err(failure: NotFoundFailure())), _):
        lines = [
          line(
            source.type == SourceType.xtream
                ? 'This source has no guide address. Set an EPG URL for it '
                      'to get one.'
                : "This playlist doesn't name a guide. Set an EPG URL for the "
                      'source to get one.',
          ),
        ];
        control = button('Edit source', editSource);
      case (AsyncValue(value: Err(failure: SecureStorageFailure())), _):
        lines = [
          line(
            "Couldn't read this source's details from the keyring, so its "
            "guide can't be fetched. Unlock the keyring, then try again.",
            color: colors.warning,
          ),
        ];
        control = button(
          'Try again',
          () => ref.invalidate(guideOriginProvider(source.id)),
        );
      case (AsyncValue(value: Err(:final failure)), _):
        lines = [line(failureMessage(failure), color: colors.danger)];
        control = button('Edit source', editSource);
      case (
        AsyncValue(value: Ok(value: final from)),
        AsyncValue(value: final guide?),
      ):
        (lines, control) = _describe(context, ref, from, guide, now);
    }

    return _Setting(
      title: 'Guide data',
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, widget) in lines.indexed) ...[
            if (index > 0 && widget is! SizedBox)
              SizedBox(height: tokens.spacing.s4),
            widget,
          ],
        ],
      ),
      control: control,
    );
  }

  (List<Widget>, Widget) _describe(
    BuildContext context,
    WidgetRef ref,
    GuideOrigin origin,
    GuideCoverage coverage,
    DateTime now,
  ) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = _descriptionStyle(context);
    Text line(String text, {Color? color}) =>
        Text(text, style: color == null ? style : style.copyWith(color: color));
    final last = coverage.lastImport;
    final from = guideOriginLabel(origin);

    if (importing) {
      final progress = ref.watch(guideImportProgressProvider(source.id)).value;
      return (
        [
          Semantics(
            liveRegion: true,
            child: line(importProgressLine(progress)),
          ),
          SizedBox(height: tokens.spacing.s8),
          SizedBox(
            width: 280,
            child: ProgressBar(
              value: progress?.fraction,
              semanticLabel: 'Guide import progress',
            ),
          ),
          if (coverage.hasGuide) ...[
            SizedBox(height: tokens.spacing.s8),
            line('The guide in use stays until the new one is in.'),
          ],
        ],
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.s,
          onPressed: onCancel,
        ),
      );
    }

    if (!coverage.hasGuide) {
      final failed = last?.outcome == GuideImportOutcome.failed;
      return (
        [
          if (failed)
            line(
              "The guide couldn't be imported. ${importFailureMessage(last!)}",
              color: colors.danger,
            )
          else if (last?.outcome == GuideImportOutcome.cancelled)
            line('The last import was cancelled. $from.')
          else
            line('No guide imported yet. $from.'),
        ],
        AppButton(
          label: failed ? 'Try again' : 'Import guide',
          variant: failed
              ? AppButtonVariant.secondary
              : AppButtonVariant.primary,
          size: AppButtonSize.s,
          onPressed: onImport,
        ),
      );
    }

    final updated = coverage.updatedAt;
    final covered = [
      if (counts case final counts?) matchedLine(counts),
      coverageLine(coverage),
    ].where((part) => part.isNotEmpty).join(' · ');
    return (
      [
        line(
          updated == null ? from : '$from · updated ${formatAgo(updated, now)}',
          color: colors.textSecondary,
        ),
        if (covered.isNotEmpty) line(covered),
        if (last != null && last.outcome == GuideImportOutcome.failed)
          line(
            'The last refresh failed '
            '${formatAgo(last.finishedAt ?? last.startedAt, now)}: '
            '${importFailureMessage(last)} The guide above stays in use.',
            color: colors.warning,
          ),
      ],
      AppButton(
        label: 'Refresh guide',
        icon: AppIcons.retry,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.s,
        onPressed: onImport,
      ),
    );
  }
}

/// One setting: its name and what it does on the left, the control on
/// the right (Settings → Playback's layout).
class _Setting extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final Widget description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s12 + 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: tokens.spacing.s4),
                description,
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s24),
          control,
        ],
      ),
    );
  }
}

/// The time offset: one focus stop, ←/→ (or −/+) by half an hour, the
/// arrows beside the value for the mouse. A slider to assistive tech.
class _OffsetStepper extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _width = 176.0;
  static const _height = 36.0;

  int _stepped(int by) => (value + by * guideOffsetStepMinutes).clamp(
    -guideOffsetLimitMinutes,
    guideOffsetLimitMinutes,
  );

  void _step(int by) {
    final next = _stepped(by);
    if (next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final canEarlier = value > -guideOffsetLimitMinutes;
    final canLater = value < guideOffsetLimitMinutes;

    Widget arrow(AppIcons icon, String tooltip, int by, {required bool on}) =>
        ExcludeFocus(
          child: AppTooltip(
            message: tooltip,
            child: MouseRegion(
              cursor: on ? SystemMouseCursors.click : MouseCursor.defer,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: on ? () => _step(by) : null,
                child: SizedBox(
                  width: _height,
                  height: _height,
                  child: Center(
                    child: AppIcon(
                      icon,
                      size: 16,
                      color: on ? colors.textSecondary : colors.textDisabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.minus): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): () =>
            _step(-1),
        const SingleActivator(LogicalKeyboardKey.equal): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): () => _step(1),
      },
      child: Semantics(
        slider: true,
        label: 'Time offset',
        value: guideOffsetLabel(value),
        increasedValue: guideOffsetLabel(_stepped(1)),
        decreasedValue: guideOffsetLabel(_stepped(-1)),
        onIncrease: canLater ? () => _step(1) : null,
        onDecrease: canEarlier ? () => _step(-1) : null,
        child: FocusableSurface(
          // Enter goes back to no offset; the arrows do the rest.
          onPressed: () {
            if (value != 0) onChanged(0);
          },
          semanticButton: false,
          borderRadius: tokens.radii.controlAll,
          background: colors.surface2,
          hoverBackground: colors.surface3,
          builder: (context, states) => SizedBox(
            width: _width,
            height: _height,
            child: Row(
              children: [
                arrow(
                  AppIcons.chevronLeft,
                  '30 minutes earlier',
                  -1,
                  on: canEarlier,
                ),
                Expanded(
                  child: Text(
                    guideOffsetLabel(value),
                    textAlign: TextAlign.center,
                    style: tokens.text.label
                        .withWeight(states.focused ? 700 : 600)
                        .copyWith(
                          color: value == 0
                              ? colors.textSecondary
                              : colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                arrow(
                  AppIcons.chevronRight,
                  '30 minutes later',
                  1,
                  on: canLater,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelsToolbar extends StatelessWidget {
  const new({
    required this.filter,
    required this.counts,
    required this.onFilter,
    required this.onQuery,
  });

  final ChannelMatchFilter filter;
  final ChannelMatchCounts? counts;
  final ValueChanged<ChannelMatchFilter> onFilter;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    String? count(ChannelMatchFilter f) =>
        counts == null ? null : formatCount(counts!.of(f));
    return Wrap(
      spacing: spacing.s12,
      runSpacing: spacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        SegmentedControl<ChannelMatchFilter>(
          options: [
            SegmentOption(
              value: ChannelMatchFilter.unmatched,
              label: 'Unmatched',
              count: count(ChannelMatchFilter.unmatched),
            ),
            SegmentOption(
              value: ChannelMatchFilter.manual,
              label: 'Matched by you',
              count: count(ChannelMatchFilter.manual),
            ),
            SegmentOption(
              value: ChannelMatchFilter.all,
              label: 'All',
              count: count(ChannelMatchFilter.all),
            ),
          ],
          value: filter,
          onChanged: onFilter,
        ),
        SearchField(
          hint: 'Filter channels',
          shortcut: null,
          width: 240,
          onChanged: onQuery,
        ),
      ],
    );
  }
}

/// The source's channels for [filter] and [query], a page at a time (hard
/// rule 2: a count, then pages on demand). One Tab stop with the arrows
/// inside; Enter opens the Match… picker.
///
/// When the matches change the list is read again and swapped in whole,
/// never cleared first, and its rows aren't keyed by channel: so the
/// focused row keeps the focus, and matching a channel under Unmatched
/// leaves the focus on the next one.
class _ChannelList extends ConsumerStatefulWidget {
  const new({
    required this.sourceId,
    required this.filter,
    required this.query,
    required this.revision,
    required this.overrides,
    required this.onMatch,
    required this.onReloaded,
  });

  final String sourceId;
  final ChannelMatchFilter filter;
  final String query;

  /// Bumped by the page when the list must be read again.
  final int revision;
  final Map<int, ChannelGuideMatch> overrides;
  final ValueChanged<ChannelGuideMatch> onMatch;
  final VoidCallback onReloaded;

  /// The repository's page, which is its default `limit`.
  static const pageSize = 100;
  static const rowHeight = 56.0;

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  final _scroll = ScrollController();
  final _pages = <int, List<ChannelGuideMatch>>{};
  final _loading = <int>{};
  int? _total;
  AppFailure? _error;

  /// Bumped on every reset and reload: an answer for an older one is
  /// dropped.
  var _generation = 0;
  StreamSubscription<void>? _changes;
  Timer? _reloadSoon;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _changes = ref
        .read(epgRepositoryProvider)
        .watchChanges()
        .listen((_) => _scheduleReload());
  }

  @override
  void didUpdateWidget(_ChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter || oldWidget.query != widget.query) {
      _pages.clear();
      _loading.clear();
      _total = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      unawaited(_reload());
    } else if (oldWidget.revision != widget.revision) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _reloadSoon?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// A rematch writes in one go, but an import's swap and its rematch come
  /// close together: read once for both.
  void _scheduleReload() {
    _reloadSoon?.cancel();
    _reloadSoon = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_reload()),
    );
  }

  /// Reads the count and every page already loaded, then swaps them in.
  Future<void> _reload() async {
    final generation = ++_generation;
    final repository = ref.read(epgRepositoryProvider);
    final (filter, query) = (widget.filter, widget.query);
    final pages = _pages.keys.isEmpty ? [0] : _pages.keys.toList();
    final count = repository.countChannelMatches(
      widget.sourceId,
      filter: filter,
      query: query,
    );
    final read = await Future.wait([
      for (final page in pages)
        repository.channelMatches(
          widget.sourceId,
          filter: filter,
          query: query,
          offset: page * _ChannelList.pageSize,
        ),
    ]);
    final total = await count;
    if (!mounted || generation != _generation) return;
    setState(() {
      switch (total) {
        case Ok(:final value):
          _total = value;
          _error = null;
        case Err(:final failure):
          _error = failure;
      }
      _pages.clear();
      _loading.clear();
      for (final (index, page) in pages.indexed) {
        switch (read[index]) {
          case Ok(:final value):
            _pages[page] = value;
          case Err(:final failure):
            _error = failure;
        }
      }
    });
    widget.onReloaded();
  }

  Future<void> _load(int page) async {
    if (!_loading.add(page)) return;
    final generation = _generation;
    final result = await ref
        .read(epgRepositoryProvider)
        .channelMatches(
          widget.sourceId,
          filter: widget.filter,
          query: widget.query,
          offset: page * _ChannelList.pageSize,
        );
    if (!mounted || generation != _generation) return;
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

  ChannelGuideMatch? _at(int index) {
    final page = index ~/ _ChannelList.pageSize;
    final rows = _pages[page];
    if (rows == null) {
      unawaited(_load(page));
      return null;
    }
    final offset = index % _ChannelList.pageSize;
    if (offset >= rows.length) return null;
    final row = rows[offset];
    return widget.overrides[row.channelId] ?? row;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final error = _error;
    final total = _total;
    if (error != null && total == null) {
      return ErrorState(
        compact: true,
        title: "Couldn't load the channels",
        message: failureMessage(error),
        onRetry: () => unawaited(_reload()),
      );
    }
    if (total == null) {
      return Semantics(
        label: 'Loading the channels',
        child: Column(
          children: [
            for (var i = 0; i < 4; i++) ...[
              const SkeletonRow(height: _ChannelList.rowHeight - 8),
              SizedBox(height: tokens.spacing.s8),
            ],
          ],
        ),
      );
    }
    if (total == 0) return _empty();
    return FocusPane(
      debugLabel: 'guide-channels',
      tabStop: true,
      child: ListView.builder(
        controller: _scroll,
        itemCount: total,
        itemExtent: _ChannelList.rowHeight,
        itemBuilder: (context, index) {
          final channel = _at(index);
          if (channel == null) {
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.s4),
              child: const SkeletonRow(),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.s4),
            child: _ChannelRow(
              channel: channel,
              onMatch: () => widget.onMatch(channel),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    final query = widget.query.trim();
    if (query.isNotEmpty) {
      return EmptyState(
        compact: true,
        icon: AppIcons.search,
        title: 'No channels match "$query"',
      );
    }
    return switch (widget.filter) {
      ChannelMatchFilter.unmatched => const EmptyState(
        compact: true,
        icon: AppIcons.check,
        title: 'Every channel has a guide',
        message: 'Nothing is left to match by hand.',
      ),
      ChannelMatchFilter.manual => const EmptyState(
        compact: true,
        icon: AppIcons.guide,
        title: "You haven't matched any channels",
        message: 'Pick one under Unmatched or All and press Enter.',
      ),
      ChannelMatchFilter.all => const EmptyState(
        compact: true,
        icon: AppIcons.liveTv,
        title: 'No channels yet',
        message: 'They appear after the source syncs.',
      ),
    };
  }
}

/// A channel and what it is attached to: number, logo, name, the match,
/// and Match… or Change (which the whole row does too).
class _ChannelRow extends StatelessWidget {
  const new({required this.channel, required this.onMatch});

  final ChannelGuideMatch channel;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final status = matchStatus(channel);
    final number = channel.number;
    return FocusableSurface(
      onPressed: onMatch,
      borderRadius: tokens.radii.controlAll,
      background: colors.surface2,
      hoverBackground: colors.surface3,
      semanticLabel: [
        if (number != null) '$number',
        channel.name,
        status,
      ].join(', '),
      builder: (context, states) => Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                number == null ? '' : '$number',
                textAlign: TextAlign.right,
                style: tokens.text.labelSmall.copyWith(
                  color: colors.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.s12),
            ChannelLogo(
              name: channel.name,
              size: 32,
              image: _logo(channel.logoUrl),
            ),
            SizedBox(width: tokens.spacing.s12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.label
                        .withWeight(states.focused ? 700 : 600)
                        .copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.labelSmall.copyWith(
                      color: channel.isMatched
                          ? colors.textSecondary
                          : colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.s12),
            // For the mouse; the keyboard presses Enter on the row.
            ExcludeFocus(
              child: AppButton(
                label: channel.isMatched ? 'Change' : 'Match…',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: onMatch,
              ),
            ),
          ],
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

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final spacing = context.tokens.spacing;
    return Semantics(
      label: 'Loading the guide settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            const Skeleton(height: 56),
            SizedBox(height: spacing.s8),
          ],
          SizedBox(height: spacing.s16),
          for (var i = 0; i < 4; i++) ...[
            const Skeleton(height: 48),
            SizedBox(height: spacing.s8),
          ],
        ],
      ),
    );
  }
}
