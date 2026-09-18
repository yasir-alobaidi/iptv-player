import 'package:flutter/material.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_check.dart';

/// Where "Test connection" is.
sealed class ConnectCheck {
  const new();
}

final class CheckIdle extends ConnectCheck {
  const new();
}

final class CheckRunning extends ConnectCheck {
  const new(this.where);

  /// The host or file being tried, for "Connecting to …".
  final String where;
}

final class CheckPassed extends ConnectCheck {
  const new(this.result, this.draft);

  final SourceCheck result;

  /// What was tested; an edit that changes it makes the result stale.
  final SourceDraft draft;
}

final class CheckFailed extends ConnectCheck {
  const new(this.failure);

  final AppFailure failure;
}

/// The card to the right of the Connect form (canvas): what the test
/// will do, the test running, what it found, or why it failed.
class ConnectResultCard extends StatelessWidget {
  const new({
    required this.type,
    required this.check,
    required this.now,
    super.key,
  });

  final SourceType type;
  final ConnectCheck check;

  /// For "in 50 days"; the screen passes the clock so tests can pin it.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.s24 + 4),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: tokens.radii.lgAll,
          border: Border.all(color: colors.surface3),
        ),
        child: AnimatedSize(
          duration: tokens.motion.base,
          curve: tokens.motion.baseCurve,
          alignment: Alignment.topCenter,
          child: switch (check) {
            CheckIdle() => _Idle(type: type),
            CheckRunning(:final where) => _Running(where: where),
            CheckPassed(:final result) => _Passed(
              type: type,
              result: result,
              now: now,
            ),
            CheckFailed(:final failure) => _Failed(
              type: type,
              failure: failure,
            ),
          },
        ),
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const new({required this.type});

  final SourceType type;

  @override
  Widget build(BuildContext context) => _CardBody(
    badge: const _Badge(icon: AppIcons.info, tone: _Tone.neutral),
    title: 'Test the connection',
    subtitle: switch (type) {
      SourceType.xtream =>
        "We'll sign in and show your account: its status, when it "
            'expires and how many connections it allows.',
      SourceType.m3uUrl =>
        "We'll read the start of your playlist to make sure it "
            'works.',
      SourceType.m3uFile =>
        "We'll read the start of the file to make sure it's a "
            'playlist.',
    },
    note: _nextNote,
  );
}

class _Running extends StatelessWidget {
  const new({required this.where});

  final String where;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _CardBody(
      badge: const _Badge(tone: _Tone.accent, spinning: true),
      title: 'Connecting…',
      subtitle: where.isEmpty ? 'Trying your details' : 'Trying $where',
      rows: [
        for (final width in const [0.55, 0.4, 0.5])
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.s4),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: width,
              child: const Skeleton(height: 14),
            ),
          ),
      ],
    );
  }
}

class _Passed extends StatelessWidget {
  const new({required this.type, required this.result, required this.now});

  final SourceType type;
  final SourceCheck result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final account = result.account;
    final playlist = result.playlist;
    final ms = result.responseTime.inMilliseconds;
    final answered = switch (type) {
      SourceType.m3uFile => '${result.where} opened in $ms ms',
      _ => '${result.where} responded in $ms ms',
    };

    final rows = <(String, Widget)>[];
    String? warning;
    if (account != null) {
      final status = account.status ?? 'Unknown';
      final active = status.toLowerCase() == 'active';
      if (!active) {
        warning =
            'This account is ${status.toLowerCase()}. Channels may not play '
            'until you renew it with your provider.';
      }
      rows
        ..add((
          'Account',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.success : colors.danger,
                ),
              ),
              SizedBox(width: tokens.spacing.s8),
              _value(context, account.isTrial ? '$status · Trial' : status),
            ],
          ),
        ))
        ..add(('Expires', _expiry(context, account)));
      if (account.maxConnections != null) {
        rows.add((
          'Connections',
          _value(
            context,
            '${account.maxConnections} allowed',
            after: account.activeConnections == null
                ? null
                : '${account.activeConnections} in use',
          ),
        ));
      }
      if (account.allowedFormats.isNotEmpty) {
        rows.add((
          'Formats',
          _value(context, account.allowedFormats.map(_formatName).join(', ')),
        ));
      }
      if (account.serverTimezone case final zone?) {
        rows.add(('Time zone', _value(context, zone)));
      }
    }
    if (playlist != null) {
      rows.add((
        'Entries',
        playlist.complete
            ? _value(context, formatCount(playlist.entries))
            : _value(
                context,
                'At least ${formatCount(playlist.entries)}',
                after: 'the rest loads next',
              ),
      ));
      final kinds = [
        if (playlist.live > 0) '${formatCount(playlist.live)} channels',
        if (playlist.movies > 0) '${formatCount(playlist.movies)} movies',
        if (playlist.episodes > 0) '${formatCount(playlist.episodes)} episodes',
      ];
      if (kinds.isNotEmpty) {
        rows.add((
          playlist.complete ? 'Holds' : 'Starts with',
          _value(context, kinds.join(' · ')),
        ));
      }
      if (playlist.bytes case final bytes?) {
        rows.add(('Size', _value(context, formatBytes(bytes))));
      }
    }

    return _CardBody(
      badge: const _Badge(icon: AppIcons.check, tone: _Tone.success),
      title: type == SourceType.xtream ? 'Connected' : 'Playlist found',
      subtitle: answered,
      table: rows,
      warning: warning,
      note: _nextNote,
    );
  }

  Widget _expiry(BuildContext context, ProviderAccount account) {
    final expires = account.expiresAt;
    if (expires == null) return _value(context, 'Never');
    final days = expires.difference(now).inDays;
    final date = formatDate(expires);
    if (expires.isBefore(now)) {
      return _value(context, date, after: 'expired', warn: true);
    }
    return _value(
      context,
      date,
      after: switch (days) {
        0 => 'today',
        1 => 'tomorrow',
        _ => 'in $days days',
      },
      warn: days < 7,
    );
  }

  static String _formatName(String format) => switch (format.toLowerCase()) {
    'm3u8' => 'HLS',
    final other => other.toUpperCase(),
  };
}

class _Failed extends StatelessWidget {
  const new({required this.type, required this.failure});

  final SourceType type;
  final AppFailure failure;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (failure) {
      AuthFailure() when type == SourceType.xtream => (
        'Sign-in refused',
        failureMessage(failure),
      ),
      AuthFailure() => (
        'Access refused',
        'The server refused this playlist link. Check it with your '
            'provider.',
      ),
      NetworkFailure() ||
      TimeoutFailure() => ("Can't reach the server", failureMessage(failure)),
      ParseFailure() => (
        type == SourceType.xtream ? 'Not an Xtream panel' : 'Not a playlist',
        type == SourceType.xtream
            ? 'The server answered, but not as an Xtream Codes panel '
                  'does. Check the address.'
            : "This doesn't look like an M3U playlist.",
      ),
      NotFoundFailure() when type == SourceType.m3uFile => (
        'File not found',
        "That file isn't there any more. Choose it again.",
      ),
      NotFoundFailure() => (
        'Not found',
        'The server has nothing at that address. Check it with your '
            'provider.',
      ),
      _ => ("Couldn't connect", failureMessage(failure)),
    };
    return _CardBody(
      badge: const _Badge(icon: AppIcons.alertCircle, tone: _Tone.danger),
      title: title,
      subtitle: message,
      details: failure.detail,
    );
  }
}

const _nextNote =
    "Next, we'll download your channel, movie and series lists. It "
    'takes about a minute the first time.';

Widget _value(
  BuildContext context,
  String text, {
  String? after,
  bool warn = false,
}) {
  final tokens = context.tokens;
  final colors = tokens.colors;
  final strong = tokens.text.body.withWeight(700);
  return Text.rich(
    TextSpan(
      text: text,
      style: strong.copyWith(color: warn ? colors.warning : colors.textPrimary),
      children: [
        if (after != null)
          TextSpan(
            text: ' · $after',
            style: tokens.text.body
                .withWeight(500)
                .copyWith(color: warn ? colors.warning : colors.textSecondary),
          ),
      ],
    ),
  );
}

enum _Tone { neutral, accent, success, danger }

class _Badge extends StatelessWidget {
  const new({required this.tone, this.icon, this.spinning = false});

  final AppIcons? icon;
  final _Tone tone;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final color = switch (tone) {
      _Tone.neutral => colors.textSecondary,
      _Tone.accent => colors.accentBase,
      _Tone.success => colors.success,
      _Tone.danger => colors.danger,
    };
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: spinning
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
            )
          : AppIcon(icon!, size: 22, color: color),
    );
  }
}

class _CardBody extends StatefulWidget {
  const new({
    required this.badge,
    required this.title,
    required this.subtitle,
    this.rows = const [],
    this.table = const [],
    this.warning,
    this.note,
    this.details,
  });

  final Widget badge;
  final String title;
  final String subtitle;
  final List<Widget> rows;
  final List<(String, Widget)> table;
  final String? warning;
  final String? note;

  /// A failure's redacted detail, behind a Details button.
  final String? details;

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final gap = SizedBox(height: spacing.s20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            widget.badge,
            SizedBox(width: spacing.s12 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: tokens.text.titleLarge.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: spacing.s4 / 2),
                  Text(
                    widget.subtitle,
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.rows.isNotEmpty || widget.table.isNotEmpty) ...[
          gap,
          Container(height: 1, color: colors.surface3),
          gap,
          ...widget.rows,
          for (final (label, value) in widget.table)
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.s4 + 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(
                      label,
                      style: tokens.text.body
                          .withWeight(600)
                          .copyWith(color: colors.textTertiary),
                    ),
                  ),
                  Expanded(child: value),
                ],
              ),
            ),
        ],
        if (widget.warning != null) ...[
          gap,
          AppBanner(message: widget.warning!, tone: BannerTone.warning),
        ],
        if (widget.note != null) ...[
          gap,
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.s12 + 2,
              vertical: spacing.s12,
            ),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: tokens.radii.controlAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.info, size: 18, color: colors.textTertiary),
                SizedBox(width: spacing.s8 + 2),
                Expanded(
                  child: Text(
                    widget.note!,
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.details != null) ...[
          SizedBox(height: spacing.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: _showDetails ? 'Hide details' : 'Details',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.s,
              onPressed: () => setState(() => _showDetails = !_showDetails),
            ),
          ),
          if (_showDetails) ...[
            SizedBox(height: spacing.s8),
            SelectableText(
              widget.details!,
              style: tokens.text.mono.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ],
    );
  }
}
