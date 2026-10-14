import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One row of the keyboard shortcuts list: what happens, and the keys
/// that do it.
@immutable
final class ShortcutEntry {
  const new(
    this.action,
    this.keys, {
    this.between = 'or',
    this.binds = const [],
  });

  /// "Previous or next channel".
  final String action;

  /// Each way to do it, as the keycaps to press together: `[['Ctrl',
  /// 'K'], ['/']]`.
  final List<List<String>> keys;

  /// The word between two ways: "or"; "…" for a range (Ctrl 1 … Ctrl 7);
  /// "then" for keys pressed one after the other.
  final String between;

  /// The activators of the app's global layer this row documents. A test
  /// checks that every one the layer binds is in some row.
  final List<SingleActivator> binds;

  /// "Ctrl K or /": the row's keys as one line of text, for assistive
  /// technology and for docs/05's table.
  String get keysText =>
      [for (final combo in keys) combo.join(' ')]
          .join(between.isEmpty ? ' ' : ' $between ');
}

/// A heading and the rows under it: where those keys work.
@immutable
final class ShortcutGroup {
  const new(this.title, this.entries);

  final String title;
  final List<ShortcutEntry> entries;
}

/// Every keyboard shortcut, grouped by where it works (Phase 9 decision
/// 5). The one list: Settings → Keyboard shortcuts and the F1 panel draw
/// it, and docs/05's table is written from it (a test compares them).
///
/// A new shortcut goes here in the commit that binds it.
const shortcutTable = <ShortcutGroup>[
  ShortcutGroup('Anywhere', [
    ShortcutEntry('Move around', [
      ['↑'],
      ['↓'],
      ['←'],
      ['→'],
    ], between: ''),
    ShortcutEntry('The next or the previous part of the screen', [
      ['Tab'],
      ['Shift', 'Tab'],
    ]),
    ShortcutEntry('Choose what has the focus', [
      ['Enter'],
      ['Space'],
    ]),
    ShortcutEntry("The focused item's menu", [
      ['Menu'],
      ['Shift', 'F10'],
    ]),
    ShortcutEntry(
      'Back, close, or leave full screen',
      [
        ['Esc'],
      ],
      binds: [SingleActivator(LogicalKeyboardKey.escape)],
    ),
    ShortcutEntry(
      'Search',
      [
        ['Ctrl', 'K'],
        ['/'],
      ],
      binds: [
        SingleActivator(LogicalKeyboardKey.keyK, control: true),
        SingleActivator(LogicalKeyboardKey.slash),
      ],
    ),
    ShortcutEntry(
      'Home, Live TV, Guide, Movies, Series, Favorites, Library',
      [
        ['Ctrl', '1'],
        ['Ctrl', '7'],
      ],
      between: '…',
      binds: [
        SingleActivator(LogicalKeyboardKey.digit1, control: true),
        SingleActivator(LogicalKeyboardKey.digit2, control: true),
        SingleActivator(LogicalKeyboardKey.digit3, control: true),
        SingleActivator(LogicalKeyboardKey.digit4, control: true),
        SingleActivator(LogicalKeyboardKey.digit5, control: true),
        SingleActivator(LogicalKeyboardKey.digit6, control: true),
        SingleActivator(LogicalKeyboardKey.digit7, control: true),
      ],
    ),
    ShortcutEntry(
      'Settings',
      [
        ['Ctrl', ','],
      ],
      binds: [SingleActivator(LogicalKeyboardKey.comma, control: true)],
    ),
    ShortcutEntry(
      'The Guide',
      [
        ['G'],
      ],
      binds: [SingleActivator(LogicalKeyboardKey.keyG)],
    ),
    ShortcutEntry(
      'Cast, or choose a TV',
      [
        ['C'],
      ],
      binds: [SingleActivator(LogicalKeyboardKey.keyC)],
    ),
    ShortcutEntry(
      'This list',
      [
        ['F1'],
      ],
      binds: [SingleActivator(LogicalKeyboardKey.f1)],
    ),
    ShortcutEntry('Move the focused item up or down its list', [
      ['Alt', '↑'],
      ['Alt', '↓'],
    ]),
    ShortcutEntry('Undo, while a message offers it', [
      ['Ctrl', 'Z'],
    ]),
  ]),
  ShortcutGroup('Live TV and the player', [
    ShortcutEntry('Watch the focused channel full screen', [
      ['Enter'],
    ]),
    ShortcutEntry('Add the channel to favorites, or take it out', [
      ['F'],
    ]),
    ShortcutEntry('The previous or the next channel', [
      ['↑'],
      ['↓'],
      ['PageUp'],
      ['PageDown'],
    ], between: ''),
    ShortcutEntry('The channel list, over the picture', [
      ['←'],
    ]),
    ShortcutEntry('Go to a channel by its number', [
      ['0–9'],
      ['Enter'],
    ], between: 'then'),
    ShortcutEntry('The last channel', [
      ['Backspace'],
    ]),
    ShortcutEntry('The volume up or down (while playing)', [
      ['+'],
      ['−'],
    ]),
    ShortcutEntry('Mute', [
      ['M'],
    ]),
    ShortcutEntry('The next audio track', [
      ['A'],
    ]),
    ShortcutEntry('The next subtitle, then off', [
      ['S'],
    ]),
    ShortcutEntry('Stream info', [
      ['I'],
    ]),
    ShortcutEntry('The window full screen, or back (while playing)', [
      ['F'],
    ]),
  ]),
  ShortcutGroup('Movies and episodes', [
    ShortcutEntry('Add to favorites, or take out', [
      ['F'],
    ]),
    ShortcutEntry('Download', [
      ['D'],
    ]),
    ShortcutEntry('The first or the last title of a grid', [
      ['Home'],
      ['End'],
    ]),
    ShortcutEntry('A screen up or down a grid', [
      ['PageUp'],
      ['PageDown'],
    ]),
    ShortcutEntry('Play or pause', [
      ['Space'],
    ]),
    ShortcutEntry('Back or forward 10 seconds', [
      ['←'],
      ['→'],
    ]),
    ShortcutEntry('Back or forward a minute', [
      ['Shift', '←'],
      ['Shift', '→'],
    ]),
    ShortcutEntry('Start over, from the beginning (while playing)', [
      ['Home'],
    ]),
    ShortcutEntry('The volume up or down (while playing)', [
      ['↑'],
      ['↓'],
      ['+'],
      ['−'],
    ], between: ''),
  ]),
  ShortcutGroup('The Guide', [
    ShortcutEntry('From programme to programme, channel to channel', [
      ['←'],
      ['→'],
      ['↑'],
      ['↓'],
    ], between: ''),
    ShortcutEntry('A screen of channels up or down', [
      ['PageUp'],
      ['PageDown'],
    ]),
    ShortcutEntry('Back to now', [
      ['Home'],
    ]),
    ShortcutEntry("A programme's details", [
      ['Enter'],
    ]),
    ShortcutEntry("Set the programme's reminder, or remove it", [
      ['R'],
    ]),
  ]),
  ShortcutGroup('Search', [
    ShortcutEntry('Through the results', [
      ['↑'],
      ['↓'],
    ], between: ''),
    ShortcutEntry('The next or the previous group of results', [
      ['Tab'],
      ['Shift', 'Tab'],
    ]),
    ShortcutEntry('Open the result', [
      ['Enter'],
    ]),
    ShortcutEntry('Download the result', [
      ['Ctrl', 'D'],
    ]),
    ShortcutEntry("Set an upcoming programme's reminder, or remove it", [
      ['Ctrl', 'R'],
    ]),
    ShortcutEntry('Forget a recent search', [
      ['Delete'],
    ]),
  ]),
  ShortcutGroup('Casting', [
    ShortcutEntry('The previous or the next channel on the TV', [
      ['↑'],
      ['↓'],
    ], between: ''),
    ShortcutEntry('Play or pause on the TV', [
      ['Space'],
    ]),
    ShortcutEntry('Back or forward 10 seconds on the TV', [
      ['←'],
      ['→'],
    ]),
    ShortcutEntry('Start over on the TV, from the beginning', [
      ['Home'],
    ]),
    ShortcutEntry('The next subtitle on the TV, then off', [
      ['S'],
    ]),
    ShortcutEntry('Mute the TV', [
      ['M'],
    ]),
  ]),
  ShortcutGroup('Favorites, downloads and settings', [
    ShortcutEntry('Fold or open a group of favorites', [
      ['←'],
      ['→'],
    ]),
    ShortcutEntry('Cancel a download, or clear a finished one', [
      ['Delete'],
    ]),
    ShortcutEntry('Remove a reminder from the list', [
      ['Delete'],
    ]),
    ShortcutEntry("Step the Guide's time offset", [
      ['←'],
      ['→'],
      ['−'],
      ['+'],
    ], between: ''),
  ]),
];
