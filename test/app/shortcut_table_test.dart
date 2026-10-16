import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/shortcut_table.dart';
import 'package:iptv_player/app/shortcuts.dart';

/// docs/05's "Keyboard shortcuts" section, written from [shortcutTable]:
/// a heading and a table per group.
String shortcutTableMarkdown() {
  final out = StringBuffer();
  for (final group in shortcutTable) {
    out
      ..writeln('**${group.title}**')
      ..writeln()
      ..writeln('| Keys | What they do |')
      ..writeln('|---|---|');
    for (final entry in group.entries) {
      out.writeln('| ${entry.keysText} | ${entry.action} |');
    }
    out.writeln();
  }
  return out.toString().trimRight();
}

const _docs = 'docs/05-design-system.md';
const _start = '<!-- shortcuts: written from lib/app/shortcut_table.dart -->';
const _end = '<!-- shortcuts: end -->';

String _describe(SingleActivator key) => [
  if (key.control) 'Ctrl',
  if (key.shift) 'Shift',
  if (key.alt) 'Alt',
  key.trigger.keyLabel,
].join('+');

bool _same(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.shift == b.shift &&
    a.alt == b.alt &&
    a.meta == b.meta;

void main() {
  final documented = [
    for (final group in shortcutTable)
      for (final entry in group.entries) ...entry.binds,
  ];
  final bound = AppGlobalShortcuts.shortcuts.keys
      .cast<SingleActivator>()
      .toList();

  test('every shortcut the global layer binds has a row in the list', () {
    for (final key in bound) {
      expect(
        documented.any((row) => _same(row, key)),
        isTrue,
        reason:
            '${_describe(key)} is bound in AppGlobalShortcuts but '
            'no row of shortcutTable names it',
      );
    }
  });

  test('every key a row says the global layer binds, it binds', () {
    for (final key in documented) {
      expect(
        bound.any((activator) => _same(activator, key)),
        isTrue,
        reason: '${_describe(key)} is in shortcutTable but not bound',
      );
    }
  });

  test('F1 is bound, and is in the list', () {
    expect(bound.any((key) => key.trigger == LogicalKeyboardKey.f1), isTrue);
    expect(
      shortcutTable.first.entries.any(
        (entry) => entry.action == 'This list' && entry.keysText == 'F1',
      ),
      isTrue,
    );
  });

  test('no group is empty, no row lacks its words or its keys, and no two '
      'rows of a group say the same thing', () {
    for (final group in shortcutTable) {
      expect(group.title.trim(), isNotEmpty);
      expect(group.entries, isNotEmpty, reason: group.title);
      final actions = <String>{};
      for (final entry in group.entries) {
        expect(entry.action.trim(), isNotEmpty, reason: group.title);
        expect(entry.keys, isNotEmpty, reason: entry.action);
        for (final combo in entry.keys) {
          expect(combo, isNotEmpty, reason: entry.action);
          expect(combo.every((key) => key.trim().isNotEmpty), isTrue);
        }
        expect(actions.add(entry.action), isTrue, reason: entry.action);
      }
    }
  });

  test('the keys read as one line', () {
    ShortcutEntry row(String action) =>
        [for (final group in shortcutTable) ...group.entries]
            .firstWhere((entry) => entry.action == action);

    expect(row('Search').keysText, 'Ctrl K or /');
    expect(
      row('Home, Live TV, Movies, Series, Favorites, Library, Guide').keysText,
      'Ctrl 1 … Ctrl 7',
    );
    expect(row('Go to a channel by its number').keysText, '0–9 then Enter');
    expect(row('Move around').keysText, '↑ ↓ ← →');
  });

  // The page, the F1 panel and docs/05 say the same, for good: the doc's
  // section is this text. After changing the list, run this test with
  // UPDATE_SHORTCUT_DOCS=1 to write it.
  test("docs/05's shortcut tables are the list, word for word", () {
    final file = File(_docs);
    final text = file.readAsStringSync();
    final start = text.indexOf(_start);
    final end = text.indexOf(_end);
    expect(start, greaterThanOrEqualTo(0), reason: 'no start marker in $_docs');
    expect(end, greaterThan(start), reason: 'no end marker in $_docs');
    final wanted = '$_start\n${shortcutTableMarkdown()}\n';

    if (Platform.environment['UPDATE_SHORTCUT_DOCS'] == '1') {
      file.writeAsStringSync(text.replaceRange(start, end, wanted));
      return;
    }
    expect(
      text.substring(start, end),
      wanted,
      reason:
          'docs/05 and lib/app/shortcut_table.dart differ: run this test '
          'with UPDATE_SHORTCUT_DOCS=1',
    );
  });
}
