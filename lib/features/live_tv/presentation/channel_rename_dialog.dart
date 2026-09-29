import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// Rename… for a channel, wherever its menu is (Live TV, Favorites): the
/// name shown, the provider's own under it, and "Use provider's name"
/// once renamed.
Future<void> renameChannel(
  BuildContext anchor,
  ChannelRepository channels,
  ChannelItem channel,
) async {
  final result = await showAppDialog<_RenameResult>(
    anchor,
    builder: (context) => _RenameDialog(channel: channel),
  );
  if (result == null) return;
  await channels.rename(channel.id, result.name);
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

  /// The name typed, unless it is the name already shown and not the
  /// user's: saving that would pin today's cleaned name as a rename, and
  /// the provider's later changes would stop showing.
  void _save() {
    final channel = widget.channel;
    final typed = _controller.text.trim();
    final unchanged = !channel.isRenamed && typed == channel.name;
    Navigator.of(context).pop(unchanged ? null : _RenameResult(typed));
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final original = channel.providerName;
    return AppDialog(
      title: 'Rename channel',
      focusButtons: false,
      subtitle: 'Only this app sees the new name.',
      primaryLabel: 'Save',
      onPrimary: _save,
      // Back to the provider's name as the app shows it: cleaned, with
      // its badge.
      secondaryLabel: channel.isRenamed ? "Use provider's name" : 'Cancel',
      onSecondary: () =>
          Navigator.of(context)
              .pop(channel.isRenamed ? const _RenameResult(null) : null),
      child: AppTextField(
        controller: _controller,
        label: 'Name',
        helperText: original == null ? null : "Provider's name: $original",
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
