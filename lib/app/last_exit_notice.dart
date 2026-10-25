import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

const _tag = 'exits';

/// What a launch has to tell of the runs before it (ADR-058).
typedef ExitNews = ({
  AppExit newest,
  int count,
  DrawingBackend drawing,

  /// One of these ends made it OpenGL ES (Drawing.kt, this launch).
  bool switched,
});

/// Logs every unexpected end not told yet (oldest first, as errors, so
/// the diagnostics report's recent problems hold them), and how the
/// screen is drawn; marks them told; and gives the newest to show. Marked
/// before it is shown: were showing it to crash the app too, the next
/// launch would tell of that crash, not this one again forever.
Future<ExitNews?> takeExitNews(LastExitsSource source, AppLog log) async {
  if (!source.available) return null;
  final last = await source.read();
  if (last == null) return null;
  final drawing = last.drawing;
  if (drawing.openGles) {
    log.info(
      _tag,
      'Drawing with OpenGL ES since ${drawing.since?.toIso8601String()} '
      '(${drawing.cause ?? 'a crash drawing'})',
    );
  }
  final untold = last.untold;
  if (untold.isEmpty) return null;
  for (final exit in untold.reversed) {
    log.error(
      _tag,
      'The run before ended at ${exit.time.toIso8601String()}: '
      '${exit.summary} ${exit.details.join(' | ')}',
    );
  }
  await source.seen(untold.first.time);
  final since = drawing.since;
  return (
    newest: untold.first,
    count: untold.length,
    drawing: drawing,
    switched:
        drawing.openGles &&
        since != null &&
        untold.any((exit) => exit.time == since),
  );
}

/// On a TV, the first launch after the app closed by itself says so, with
/// what Android kept of why: a crash's thread and where it was, plainly
/// enough to photograph (ADR-058: a TV out of adb's reach is diagnosed
/// from that photo). Once per end; Settings → About & diagnostics keeps
/// them in its report.
class LastExitNotice extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LastExitNotice> createState() => _LastExitNoticeState();
}

class _LastExitNoticeState extends ConsumerState<LastExitNotice> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the router's navigator is there to show it.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_tell()));
  }

  Future<void> _tell() async {
    final news = await takeExitNews(
      ref.read(lastExitsProvider),
      ref.read(appLogProvider),
    );
    if (news == null || !mounted) return;
    final context = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context == null || !context.mounted) return;
    final secrets = ref.read(secretRegistryProvider).values;
    await showAppDialog<void>(
      context,
      builder: (_) => LastExitDialog(news: news, secrets: secrets),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Bijou closed by itself last time": what happened, what the app did
/// about it, and the facts, redacted.
class LastExitDialog extends StatelessWidget {
  const new({required this.news, this.secrets = const [], super.key});

  final ExitNews news;
  final Iterable<String> secrets;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final exit = news.newest;
    // A crash under OpenGL ES already: the photo says so.
    final since = news.drawing.since;
    final underOpenGles =
        news.drawing.openGles && since != null && exit.time.isAfter(since);
    final body = tokens.text.body.copyWith(color: colors.textSecondary);
    final facts = redact(
      [
        '$appName · ${_when(exit.time)}',
        if (underOpenGles) 'drawn with OpenGL ES since ${_when(since)}',
        ...exit.details,
      ].join('\n'),
      secrets: secrets,
    );

    return AppDialog(
      title: '$appName closed by itself last time',
      width: 760,
      primaryLabel: 'OK',
      onPrimary: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              exit.summary,
              if (news.count > 1) 'It happened ${news.count} times.',
              if (news.switched) _switched,
            ].join(' '),
            style: body,
          ),
          SizedBox(height: tokens.spacing.s12),
          Text(
            'If it happens again, a photo of this screen shows where.',
            style: body,
          ),
          SizedBox(height: tokens.spacing.s16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.scaled(260)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: tokens.radii.controlAll,
                border: Border.all(color: colors.border),
              ),
              child: ScrollPane.child(
                semanticLabel: 'What Android kept of it',
                padding: EdgeInsets.all(tokens.spacing.s12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    facts,
                    style: tokens.text.mono.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _switched =
      'From now on it draws the screen another way on this TV (OpenGL ES), '
      'which should keep that from happening again.';

  /// `2026-10-25 06:03`, the TV's own time.
  static String _when(DateTime time) {
    final local = time.toLocal();
    String two(int value) => '$value'.padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
