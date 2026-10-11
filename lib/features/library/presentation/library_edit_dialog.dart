import 'package:flutter/material.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';

/// What Edit details was closed with: the edit to keep, or — with
/// `useFileName` — back to what the file's name says.
typedef EditDetailsAnswer = ({LibraryItemEdit? edit, bool useFileName});

/// What the fields of Edit details make: the edit, or what is wrong with
/// each field, by its name.
({LibraryItemEdit? edit, Map<String, String> errors}) libraryEditFrom({
  required LibraryKind kind,
  required String title,
  String year = '',
  String show = '',
  String season = '',
  String episode = '',
}) {
  final errors = <String, String>{};
  int? number(String field, String text, {int min = 0, int max = 9999}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < min || value > max) {
      errors[field] = min > 0 ? 'A year, like 2019' : 'A number';
      return null;
    }
    return value;
  }

  final name = title.trim();
  final showName = show.trim();
  switch (kind) {
    case LibraryKind.movie:
      if (name.isEmpty) errors['title'] = 'A title is needed';
      final made = LibraryItemEdit(
        kind: kind,
        title: name,
        year: number('year', year, min: 1888, max: 2100),
      );
      return (edit: errors.isEmpty ? made : null, errors: errors);
    case LibraryKind.episode:
      if (showName.isEmpty) errors['show'] = "The show's name is needed";
      final made = LibraryItemEdit(
        kind: kind,
        // With no title of its own an episode is "Episode 4".
        title: name.isEmpty ? showName : name,
        showTitle: showName,
        season: number('season', season),
        episode: number('episode', episode),
      );
      return (edit: errors.isEmpty ? made : null, errors: errors);
    case LibraryKind.unsorted:
      if (name.isEmpty) errors['title'] = 'A title is needed';
      return (
        edit: errors.isEmpty ? LibraryItemEdit(kind: kind, title: name) : null,
        errors: errors,
      );
  }
}

/// Edit details (sketch F): what a file is — a movie, an episode, or a
/// video — and its names and numbers. Null when cancelled. Nothing here
/// touches the file (hard rule 11): the edit is the library's.
Future<EditDetailsAnswer?> showEditDetails(
  BuildContext anchor,
  LibraryItem item,
) => showAppDialog<EditDetailsAnswer>(
  anchor,
  builder: (context) => _EditDetailsDialog(item: item),
);

class _EditDetailsDialog extends StatefulWidget {
  const new({required this.item});

  final LibraryItem item;

  @override
  State<_EditDetailsDialog> createState() => _EditDetailsDialogState();
}

class _EditDetailsDialogState extends State<_EditDetailsDialog> {
  late LibraryKind _kind = widget.item.kind;
  late final _title = TextEditingController(text: _ownTitle(widget.item));
  late final _year = TextEditingController(text: _text(widget.item.year));
  late final _show = TextEditingController(text: widget.item.showTitle ?? '');
  late final _season = TextEditingController(text: _text(widget.item.season));
  late final _episode = TextEditingController(text: _text(widget.item.episode));
  var _errors = const <String, String>{};

  static String _text(int? value) => value == null ? '' : '$value';

  /// An episode with no title of its own has its show's: the field is
  /// empty then.
  static String _ownTitle(LibraryItem item) =>
      item.kind == LibraryKind.episode &&
          item.title.trim().toLowerCase() == item.showTitle?.toLowerCase()
      ? ''
      : item.title;

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    _show.dispose();
    _season.dispose();
    _episode.dispose();
    super.dispose();
  }

  void _save() {
    final made = libraryEditFrom(
      kind: _kind,
      title: _title.text,
      year: _year.text,
      show: _show.text,
      season: _season.text,
      episode: _episode.text,
    );
    final edit = made.edit;
    if (edit == null) {
      setState(() => _errors = made.errors);
      return;
    }
    Navigator.of(context).pop((edit: edit, useFileName: false));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final gap = SizedBox(height: tokens.spacing.s16);
    final between = SizedBox(width: tokens.spacing.s12);
    // Each field has its key: a field keeps the controller it was first
    // built with, and changing the type would otherwise hand Show the
    // title's.

    const narrow = 110.0;

    return AppDialog(
      title: 'Edit details',
      focusButtons: false,
      primaryLabel: 'Save',
      onPrimary: _save,
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            libraryFileName(widget.item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.mono.copyWith(color: colors.textSecondary),
          ),
          gap,
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedControl<LibraryKind>(
              value: _kind,
              onChanged: (kind) => setState(() {
                _kind = kind;
                _errors = const {};
              }),
              options: [
                for (final kind in LibraryKind.values)
                  SegmentOption(value: kind, label: libraryKindWord(kind)),
              ],
            ),
          ),
          gap,
          if (_kind == LibraryKind.episode) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    key: const ValueKey('show'),
                    controller: _show,
                    label: 'Show',
                    errorText: _errors['show'],
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                  ),
                ),
                between,
                SizedBox(
                  width: narrow,
                  child: AppTextField(
                    key: const ValueKey('season'),
                    controller: _season,
                    label: 'Season',
                    errorText: _errors['season'],
                    showClear: false,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _save(),
                  ),
                ),
                between,
                SizedBox(
                  width: narrow,
                  child: AppTextField(
                    key: const ValueKey('episode'),
                    controller: _episode,
                    label: 'Episode',
                    errorText: _errors['episode'],
                    showClear: false,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            gap,
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  key: const ValueKey('title'),
                  controller: _title,
                  label: 'Title',
                  hint: _kind == LibraryKind.episode
                      ? "The episode's own title, if it has one"
                      : null,
                  errorText: _errors['title'],
                  autofocus: _kind != LibraryKind.episode,
                  onSubmitted: (_) => _save(),
                ),
              ),
              if (_kind == LibraryKind.movie) ...[
                between,
                SizedBox(
                  width: narrow,
                  child: AppTextField(
                    key: const ValueKey('year'),
                    controller: _year,
                    label: 'Year',
                    errorText: _errors['year'],
                    showClear: false,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ],
          ),
          if (widget.item.edit != null) ...[
            gap,
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: "Use the file's name",
                icon: AppIcons.retry,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: () =>
                    Navigator.of(context).pop((edit: null, useFileName: true)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
