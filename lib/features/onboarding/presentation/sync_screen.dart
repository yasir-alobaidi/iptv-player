import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_frame.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// Onboarding step 3 (canvas `Onboarding · Sync`): the first sync of the
/// source just added, stage by stage with live counts.
///
/// It follows `syncStatusProvider`, so it shows whatever the engine is
/// doing, and starts the sync itself if nothing is running (after a
/// restart of the flow, say). Cancel and "Change details" remove the
/// half-added source and return to the filled-in form; nothing of it is
/// left behind.
class SyncScreen extends ConsumerStatefulWidget {
  const new({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  /// The last progress seen, so a failure can say which stage it hit.
  SyncProgress? _last;
  var _leaving = false;
  final _nextNode = FocusNode(debugLabel: 'sync next');
  final _retryNode = FocusNode(debugLabel: 'sync retry');

  @override
  void initState() {
    super.initState();
    final service = ref.read(syncServiceProvider);
    if (service.statusOf(widget.sourceId) is SyncIdle) {
      unawaited(service.sync(widget.sourceId));
    }
  }

  @override
  void dispose() {
    _nextNode.dispose();
    _retryNode.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    // Stops the sync, then removes the source with whatever it wrote.
    await ref.read(syncServiceProvider).removeSource(widget.sourceId);
    if (!mounted) return;
    context.go(addSourceRoutePath);
  }

  void _retry() =>
      unawaited(ref.read(syncServiceProvider).sync(widget.sourceId));

  @override
  Widget build(BuildContext context) {
    ref.listen(syncStatusProvider(widget.sourceId), (previous, next) {
      switch (next.value) {
        case SyncSucceeded():
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _nextNode.requestFocus(),
          );
        case SyncFailed() || SyncCancelled():
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _retryNode.requestFocus(),
          );
        default:
      }
    });

    final status =
        ref.watch(syncStatusProvider(widget.sourceId)).value ??
        ref.read(syncServiceProvider).statusOf(widget.sourceId);
    if (status case SyncRunning(:final progress)) _last = progress;
    final source = ref.watch(sourceByIdProvider(widget.sourceId)).value;
    final type = source?.type ?? _typeFrom(_last);

    final done = status is SyncSucceeded;
    final stopped = status is SyncFailed || status is SyncCancelled;

    return OnboardingFrame(
      step: 2,
      title: 'Getting your lists',
      subtitle:
          'This takes about a minute the first time. After that, updates '
          'run quietly in the background.',
      maxWidth: 640,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Progress(status: status, last: _last),
            SizedBox(height: context.tokens.spacing.s20 + 2),
            if (stopped) ...[
              AppBanner(
                message: switch (status) {
                  SyncFailed(:final failure) => _failureText(failure),
                  _ => 'The sync stopped before it finished.',
                },
                tone: BannerTone.error,
              ),
              SizedBox(height: context.tokens.spacing.s12),
            ],
            ..._rows(context, type, status),
          ],
        ),
      ),
      footer: OnboardingFooter(
        leading: done
            ? null
            : AppButton(
                label: stopped ? 'Change details' : 'Cancel',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.l,
                loading: _leaving,
                onPressed: () => unawaited(_leave()),
              ),
        note: switch (status) {
          SyncSucceeded(:final report) =>
            'Done in ${formatDuration(report.duration)}.',
          SyncRunning() || SyncIdle() =>
            'Next step unlocks when the lists '
                'are in.',
          _ => null,
        },
        actions: [
          if (stopped)
            AppButton(
              label: 'Retry',
              icon: AppIcons.retry,
              size: AppButtonSize.l,
              focusNode: _retryNode,
              onPressed: _leaving ? null : _retry,
            )
          else
            AppButton(
              label: 'Pick categories',
              trailingIcon: AppIcons.arrowRight,
              size: AppButtonSize.l,
              focusNode: _nextNode,
              autofocus: done,
              onPressed: done
                  ? () => context.go(pickCategoriesPath(widget.sourceId))
                  : null,
            ),
        ],
      ),
    );
  }

  String _failureText(AppFailure failure) => switch (failure) {
    AuthFailure() =>
      'Your provider rejected these details. Change them and try again.',
    _ => '${failureMessage(failure)} Nothing was saved yet; try again.',
  };

  static SourceType _typeFrom(SyncProgress? progress) =>
      progress?.stage == SyncStage.playlist
      ? SourceType.m3uUrl
      : SourceType.xtream;

  List<Widget> _rows(BuildContext context, SourceType type, SyncStatus status) {
    final spacing = context.tokens.spacing;
    final progress = switch (status) {
      SyncRunning(:final progress) => progress,
      _ => _last,
    };
    final report = status is SyncSucceeded ? status.report : null;
    final failed = status is SyncFailed || status is SyncCancelled;
    final stage = progress?.stage;

    _RowState stateOf(List<SyncStage> own) {
      if (report != null) return _RowState.done;
      if (stage == null) {
        return own.first == SyncStage.account || own.first == SyncStage.playlist
            ? (failed ? _RowState.failed : _RowState.active)
            : _RowState.waiting;
      }
      const order = SyncStage.values;
      final current = order.indexOf(stage);
      if (own.contains(stage)) {
        return failed ? _RowState.failed : _RowState.active;
      }
      return order.indexOf(own.last) < current
          ? _RowState.done
          : _RowState.waiting;
    }

    String counted(int value, {int? total}) => total == null
        ? formatCount(value)
        : '${formatCount(value)} of about ${formatCount(total)}';

    final rows = <_StageRow>[];
    if (type == SourceType.xtream) {
      final account = progress?.account;
      final expires = account?.expiresAt;
      rows.addAll([
        _StageRow(
          label: 'Account',
          state: stateOf(const [SyncStage.account]),
          detail: account == null
              ? null
              : [
                  account.status ?? 'Signed in',
                  if (expires != null) 'expires ${formatDate(expires)}',
                ].join(' · '),
        ),
        _StageRow(
          label: 'Categories',
          state: stateOf(const [SyncStage.categories]),
          detail: _count(report?.categories ?? progress?.categories),
        ),
        for (final (label, own, value) in [
          ('Channels', SyncStage.live, report?.channels ?? progress?.channels),
          ('Movies', SyncStage.movies, report?.movies ?? progress?.movies),
          ('Series', SyncStage.series, report?.series ?? progress?.series),
        ])
          _StageRow(
            label: label,
            state: stateOf([own]),
            detail: stage == own && report == null
                ? (progress!.stageTotal == null && (value ?? 0) == 0
                      ? 'Downloading…'
                      : counted(value ?? 0, total: progress.stageTotal))
                : _count(value),
          ),
      ]);
    } else {
      final playing = stateOf(const [SyncStage.playlist]);
      // A playlist is one stage: its counts all grow at once.
      final countState = playing == _RowState.active
          ? _RowState.counting
          : playing;
      final series = report?.series ?? progress?.series ?? 0;
      final episodes = report?.episodes ?? progress?.episodes ?? 0;
      rows.addAll([
        _StageRow(
          label: 'Playlist',
          state: stateOf(const [SyncStage.playlist, SyncStage.finishing]),
          detail: switch (playing) {
            _RowState.active => 'Reading…',
            _RowState.done => 'Read',
            _ => null,
          },
        ),
        _StageRow(
          label: 'Channels',
          state: countState,
          detail: _count(report?.channels ?? progress?.channels),
        ),
        _StageRow(
          label: 'Movies',
          state: countState,
          detail: _count(report?.movies ?? progress?.movies),
        ),
        _StageRow(
          label: 'Series',
          state: countState,
          detail: series == 0 && episodes == 0
              ? _count(series)
              : '${formatCount(series)} · '
                    '${formatCount(episodes)} episodes',
        ),
      ]);
    }
    return [
      for (final (index, row) in rows.indexed) ...[
        if (index > 0) SizedBox(height: spacing.s8),
        row,
      ],
    ];
  }

  static String? _count(int? value) =>
      value == null ? null : formatCount(value);
}

/// The bar above the rows: what is happening now, and how far along.
class _Progress extends StatelessWidget {
  const new({required this.status, required this.last});

  final SyncStatus status;
  final SyncProgress? last;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final (label, value) = switch (status) {
      SyncSucceeded() => ('All lists are in', 1.0),
      SyncFailed() || SyncCancelled() => ('Stopped', null),
      SyncRunning(:final progress) => _describe(progress),
      SyncIdle() => ('Starting', null),
    };
    final stopped = status is SyncFailed || status is SyncCancelled;
    return Semantics(
      liveRegion: true,
      label: value == null ? label : '$label, ${(value * 100).round()}%',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tokens.text.caption
                      .withWeight(700)
                      .copyWith(color: colors.textSecondary),
                ),
              ),
              if (value != null)
                Text(
                  '${(value * 100).round()}%',
                  style: tokens.text.caption
                      .withWeight(700)
                      .copyWith(color: colors.textSecondary),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.s8),
          ProgressBar(
            value: stopped ? 0 : value,
            height: 6,
            color: status is SyncSucceeded ? colors.success : null,
          ),
        ],
      ),
    );
  }

  static (String, double?) _describe(SyncProgress progress) {
    final total = progress.stageTotal;
    (String, double?) items(String noun, int done) => total == null
        ? ('Downloading $noun', null)
        : ('Saving $noun', total == 0 ? 1 : (done / total).clamp(0, 1));
    return switch (progress.stage) {
      SyncStage.account => ('Signing in', null),
      SyncStage.categories => ('Downloading categories', null),
      SyncStage.live => items('channels', progress.channels),
      SyncStage.movies => items('movies', progress.movies),
      SyncStage.series => items('series', progress.series),
      SyncStage.playlist => ('Reading your playlist', null),
      SyncStage.finishing => ('Finishing up', null),
    };
  }
}

enum _RowState { waiting, active, counting, done, failed }

/// One stage (canvas): a status mark, the stage's name and its count.
class _StageRow extends StatelessWidget {
  const new({required this.label, required this.state, this.detail});

  final String label;
  final _RowState state;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final active = state == _RowState.active;
    final waiting = state == _RowState.waiting;

    final mark = switch (state) {
      _RowState.done => _Mark(
        tint: colors.success,
        child: AppIcon(AppIcons.check, size: 15, color: colors.success),
      ),
      _RowState.active || _RowState.counting => _Mark(
        tint: colors.accentBase,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: colors.accentBase,
          ),
        ),
      ),
      _RowState.failed => _Mark(
        tint: colors.danger,
        child: AppIcon(AppIcons.alertCircle, size: 16, color: colors.danger),
      ),
      _RowState.waiting => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.border, width: 2),
        ),
      ),
    };

    final text = waiting ? 'Waiting' : detail;
    return Semantics(
      label: '$label: ${text ?? state.name}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: tokens.motion.base,
        curve: tokens.motion.baseCurve,
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s16 + 2),
        decoration: BoxDecoration(
          color: active ? colors.surface2 : colors.surface1,
          borderRadius: tokens.radii.mdAll,
          border: Border.all(
            color: active ? colors.accentSoftBorder : colors.surface3,
          ),
        ),
        child: Row(
          children: [
            mark,
            SizedBox(width: tokens.spacing.s12 + 2),
            Expanded(
              child: Text(
                label,
                style: tokens.text.body
                    .withWeight(active ? 800 : 700)
                    .copyWith(
                      color: waiting
                          ? colors.textSecondary
                          : colors.textPrimary,
                    ),
              ),
            ),
            if (text != null)
              Text(
                text,
                style: tokens.text.label
                    .withWeight(waiting ? 500 : 700)
                    .copyWith(
                      color: waiting
                          ? colors.textTertiary
                          : active
                          ? colors.textPrimary
                          : colors.textEmphasis,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const new({required this.tint, required this.child});

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tint.withValues(alpha: 0.14),
    ),
    child: child,
  );
}
