import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';

/// Asks for a group's name: New group, and a group's Rename…. Null when
/// cancelled or left blank.
Future<String?> showGroupNameDialog(
  BuildContext anchor, {
  required String title,
  String initial = '',
  String action = 'Save',
}) => showAppDialog<String>(
  anchor,
  builder: (context) =>
      _GroupNameDialog(title: title, initial: initial, action: action),
);

class _GroupNameDialog extends StatefulWidget {
  const new({required this.title, required this.initial, required this.action});

  final String title;
  final String initial;
  final String action;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    focusButtons: false,
    subtitle: 'Groups keep your favorite channels in the order you set.',
    primaryLabel: widget.action,
    onPrimary: _save,
    secondaryLabel: 'Cancel',
    onSecondary: () => Navigator.of(context).pop(),
    child: AppTextField(
      controller: _controller,
      label: 'Name',
      hint: 'Sports, News, Kids…',
      autofocus: true,
      onSubmitted: (_) => _save(),
    ),
  );
}
