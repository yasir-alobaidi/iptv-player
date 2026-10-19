import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/components.dart';

/// Tips for a long wait (the loading stage of a first sync, onboarding's
/// sync): things the app does that are worth knowing, in this device's
/// terms. Each is true of the app as built; a change to what a tip names
/// changes the tip.

/// A computer's: keys may be named (docs/05's shortcuts). The Guide's are
/// left out: it is off until switched on (ADR-031).
const desktopWaitTips = [
  'Press F on a channel or a poster to add it to Favorites.',
  'Press Ctrl+K or / to search from anywhere.',
  'F1 shows every keyboard shortcut.',
  "While watching, type a channel's number to jump to it.",
  'While watching, Backspace goes back to the last channel.',
  'While watching, A and S change the audio and the subtitles.',
  'Press D on a movie or episode to download it.',
  'Press C to cast to a TV.',
  'Hide categories you never watch in Settings → Categories.',
];

/// A TV's: the remote's words only. No keys or keycaps, and nothing a TV
/// hasn't got (casting, windows, downloads; docs/07).
const tvWaitTips = [
  'Hold OK on a channel, then choose Add to favorites.',
  'Rest on an item of the side menu to open its page.',
  'Rest on a channel in Live TV to preview it.',
  'While watching a channel, Up and Down change the channel.',
  'While watching a channel, Left opens the channel list.',
  'In a film, hold Left or Right to skip faster.',
  'Continue watching on Home picks up films where you stopped.',
  'Search can type in Arabic as well as English.',
  'Make subtitles larger in Settings → Playback.',
  'Hide categories you never watch in Settings → Categories.',
];

/// The tips for this device (a TV draws no key hints), from the [from]th
/// on and round again, so screens that wait together don't all open on
/// the same tip.
List<String> waitTips(BuildContext context, {int from = 0}) {
  final tips = KeyHints.shownIn(context) ? desktopWaitTips : tvWaitTips;
  final start = from % tips.length;
  return [...tips.skip(start), ...tips.take(start)];
}
