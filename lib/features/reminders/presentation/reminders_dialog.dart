import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_actions.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminders_dialog.g.dart';

/// The channel a reminder is for, as its source lists it now: the list
/// draws its logo from it. Null once the source no longer has it.
@riverpod
Future<ChannelItem?> reminderChannelItem(
  Ref ref,
  String sourceId,
  String channelKey,
) async =>
    (await ref
            .watch(channelRepositoryProvider)
            .byRemoteKey(sourceId, channelKey))
        .valueOrNull;

/// Opens Reminders (Phase 9 decision 13, sketch H): the one place they
/// are managed, behind the bell in the Guide's toolbar and a row in
/// Settings → Guide.
Future<void> showRemindersDialog(BuildContext context) =>
    showAppDialog<void>(context, builder: (_) => const RemindersDialog());

/// Every reminder, soonest first. The list is one Tab stop: ↑/↓ between
/// rows, Enter opens the Guide on the programme, Delete removes it with
/// Undo; a row's Remove is the mouse's way to the same. Esc closes.
class RemindersDialog extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RemindersDialog> createState() => _RemindersDialogState();
}

class _RemindersDialogState extends ConsumerState<RemindersDialog> {
  /// A row's focus, by its reminder: so removing one can hand the focus
  /// to its neighbour instead of dropping it.
  final _rows = <int, FocusNode>{};
  final _close = FocusNode(debugLabel: 'reminders close');

  @override
  void dispose() {
    for (final node in _rows.values) {
      node.dispose();
    }
    _close.dispose();
    super.dispose();
  }

  FocusNode _nodeOf(Reminder reminder) => _rows.putIfAbsent(
    reminder.id,
    () => FocusNode(debugLabel: 'reminder ${reminder.id}'),
  );

  /// Drops the focus nodes of rows that are gone, once they are out of
  /// the tree.
  void _keepOnly(List<Reminder> reminders) {
    final ids = {for (final reminder in reminders) reminder.id};
    final gone = [
      for (final id in _rows.keys)
        if (!ids.contains(id)) id,
    ];
    if (gone.isEmpty) return;
    final nodes = [for (final id in gone) _rows.remove(id)!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final node in nodes) {
        node.dispose();
      }
    });
  }

  void _remove(List<Reminder> reminders, Reminder reminder) {
    // The focus goes to the row that takes this one's place, else the one
    // before it, else Close: a row that is gone can't hold it.
    final at = reminders.indexOf(reminder);
    final next = at + 1 < reminders.length
        ? reminders[at + 1]
        : at > 0
        ? reminders[at - 1]
        : null;
    if (_rows[reminder.id]?.hasFocus ?? false) {
      (next == null ? _close : _nodeOf(next)).requestFocus();
    }
    unawaited(
      removeReminder(
        ProviderScope.containerOf(context, listen: false),
        reminder,
      ),
    );
  }

  /// The Guide on its programme; the list closes once its channel is
  /// found, and stays for one whose channel is gone (it can be removed
  /// here).
  void _open(Reminder reminder) {
    final navigator = Navigator.of(context);
    unawaited(
      showReminderInGuide(
        ProviderScope.containerOf(context, listen: false),
        reminder,
        beforeLeaving: () {
          if (mounted) navigator.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final reminders = ref.watch(remindersProvider);
    final list = reminders.value;
    if (list != null) _keepOnly(list);
    final hasRows = list != null && list.isNotEmpty;

    return AppDialog(
      title: remindersTitle(list?.length ?? 0),
      width: 640,
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: _body(context, reminders)),
            SizedBox(height: tokens.spacing.s12),
            Text(
              remindersLimit,
              style: tokens.text.caption.copyWith(color: colors.textTertiary),
            ),
            SizedBox(height: tokens.spacing.s16),
            Row(
              children: [
                if (hasRows)
                  Expanded(
                    child: ExcludeSemantics(
                      child: Wrap(
                        spacing: tokens.spacing.s16,
                        runSpacing: tokens.spacing.s8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: const [
                          _KeyHint('Enter', 'Show in the Guide'),
                          _KeyHint('Del', 'Remove'),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  focusNode: _close,
                  autofocus: list != null && list.isEmpty,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const double _rowHeight = 56;

  /// The list, or why there is none. By what the provider holds, not by
  /// its kind: a failed read that is being tried again is still a failed
  /// read, not a loading list.
  Widget _body(BuildContext context, AsyncValue<List<Reminder>> reminders) {
    final tokens = context.tokens;
    final list = reminders.value;
    if (list != null && list.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
        child: const EmptyState(
          compact: true,
          icon: AppIcons.bell,
          title: noRemindersTitle,
          message: noRemindersMessage,
        ),
      );
    }
    if (list != null) return _list(context, list);
    if (reminders.hasError) {
      return ErrorState(
        compact: true,
        title: "Couldn't read your reminders",
        message: 'They are kept on this computer. Try again.',
        details: '${reminders.error}',
        onRetry: () => ref.invalidate(remindersProvider),
        retryLabel: 'Try again',
      );
    }
    return Semantics(
      label: 'Reading your reminders',
      container: true,
      child: SkeletonColumn(
        children: [
          for (var i = 0; i < 3; i++)
            SkeletonRow(height: context.scaled(_rowHeight)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<Reminder> reminders) {
    final tokens = context.tokens;
    final now = ref.watch(appClockProvider)();
    final ring = tokens.focus.ringWidth + tokens.focus.glowWidth;
    return FocusPane(
      debugLabel: 'reminders',
      tabStop: true,
      child: ListView.builder(
        shrinkWrap: true,
        // Room for a row's focus ring, which is drawn outside it.
        padding: EdgeInsets.all(ring),
        itemCount: reminders.length,
        itemExtent: context.scaled(_rowHeight) + 2,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _ReminderRow(
              key: ValueKey(reminder.id),
              reminder: reminder,
              now: now,
              focusNode: _nodeOf(reminder),
              autofocus: index == 0,
              onOpen: () => _open(reminder),
              onRemove: () => _remove(reminders, reminder),
            ),
          );
        },
      ),
    );
  }
}

/// One reminder: its channel's logo, the programme, the channel, when it
/// shows, and Remove.
class _ReminderRow extends ConsumerWidget {
  const new({
    required this.reminder,
    required this.now,
    required this.focusNode,
    required this.autofocus,
    required this.onOpen,
    required this.onRemove,
    super.key,
  });

  final Reminder reminder;
  final DateTime now;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  static const double _logoSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final channel = ref
        .watch(
          reminderChannelItemProvider(reminder.sourceId, reminder.channelKey),
        )
        .value;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.delete): onRemove},
      child: FocusableSurface(
        focusNode: focusNode,
        autofocus: autofocus,
        onPressed: onOpen,
        hoverBackground: colors.surface3,
        borderRadius: tokens.radii.controlAll,
        semanticLabel: reminderRowLabel(reminder, now, tokens.timeStyle),
        builder: (context, states) => Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.s12,
            right: tokens.spacing.s4,
          ),
          child: Row(
            children: [
              ChannelLogo(
                name: reminder.channelName,
                size: _logoSize,
                borderRadius: tokens.radii.smAll,
                image: artworkFor(context, channel?.logoUrl, width: _logoSize),
              ),
              SizedBox(width: tokens.spacing.s12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.s4 - 2),
                    Text(
                      '${reminder.channelName} · '
                      '${reminderWhen(reminder.start, now, tokens.timeStyle)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.small.copyWith(
                        color: states.highlighted
                            ? colors.textSecondary
                            : colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.s8),
              // The mouse's Remove; the keyboard has Delete on the row, so
              // the list stays one stop a row.
              ExcludeFocus(
                child: AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.s,
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Enter  Show in the Guide": a key and what it does here.
class _KeyHint extends StatelessWidget {
  const new(this.keyLabel, this.action);

  final String keyLabel;
  final String action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Kbd(keyLabel),
        SizedBox(width: tokens.spacing.s4 + 2),
        Text(
          action,
          style: tokens.text.small.copyWith(color: tokens.colors.textTertiary),
        ),
      ],
    );
  }
}
