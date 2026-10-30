import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'privacy_policy.g.dart';

/// The policy the app shows is docs/privacy-policy.md itself, bundled:
/// the page Google Play links to and the app's words can't drift apart
/// (ADR-068).
const privacyPolicyAsset = 'docs/privacy-policy.md';

/// Where the same policy is published, for Google Play's listing.
const privacyPolicyAddress =
    'https://github.com/yasir-alobaidi/iptv-player/blob/main/docs/'
    'privacy-policy.md';

/// A stretch of a paragraph: **bold** in the source is [strong].
@immutable
final class PolicyRun {
  const new(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  bool operator ==(Object other) =>
      other is PolicyRun && other.text == text && other.strong == strong;

  @override
  int get hashCode => Object.hash(text, strong);

  @override
  String toString() => strong ? '**$text**' : text;
}

/// One block of the policy, in its order.
sealed class PolicyBlock {
  const new(this.runs);

  final List<PolicyRun> runs;

  /// The words without their emphasis.
  String get text => runs.map((run) => run.text).join();
}

/// A `## ` heading.
final class PolicyHeading extends PolicyBlock {
  const new(super.runs);
}

/// A paragraph.
final class PolicyParagraph extends PolicyBlock {
  const new(super.runs);
}

/// A `- ` list item.
final class PolicyBullet extends PolicyBlock {
  const new(super.runs);
}

/// A line in *italics* alone: "Effective 27 October 2026."
final class PolicyNote extends PolicyBlock {
  const new(super.runs);
}

/// The blocks of [markdown], as much of Markdown as the policy uses:
/// `## ` headings, `- ` items (their next lines indented), paragraphs,
/// **bold**, a paragraph that is all *italics*, and `code` shown as its
/// words. The `# ` title is the dialog's own. Anything else is kept as
/// text: a stray `**` shows rather than hides the words after it.
List<PolicyBlock> parsePrivacyPolicy(String markdown) {
  final blocks = <PolicyBlock>[];
  final lines = <String>[];
  var bullet = false;

  void flush() {
    if (lines.isEmpty) {
      bullet = false;
      return;
    }
    final joined = lines.join(' ');
    lines.clear();
    final note = bullet ? null : _italicLine.firstMatch(joined);
    if (note != null) {
      blocks.add(PolicyNote(_runs(note[1]!)));
    } else if (bullet) {
      blocks.add(PolicyBullet(_runs(joined)));
    } else {
      blocks.add(PolicyParagraph(_runs(joined)));
    }
    bullet = false;
  }

  for (final raw in markdown.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    final bare = line.trimLeft();
    if (bare.isEmpty) {
      flush();
    } else if (bare.startsWith('#')) {
      flush();
      final level = bare.length - bare.replaceFirst(RegExp('^#+'), '').length;
      final words = bare.substring(level).trim();
      if (level > 1 && words.isNotEmpty) {
        blocks.add(PolicyHeading(_runs(words)));
      }
    } else if (bare == '-' || bare.startsWith('- ') || bare.startsWith('* ')) {
      flush();
      bullet = true;
      final words = bare.substring(1).trim();
      if (words.isNotEmpty) lines.add(words);
    } else {
      lines.add(bare);
    }
  }
  flush();
  return blocks;
}

final _italicLine = RegExp(r'^\*([^*].*[^*]|[^*])\*$');

/// [text]'s runs: `**…**` strong, code ticks dropped. An unclosed `**`
/// is text.
List<PolicyRun> _runs(String text) {
  final plain = text.replaceAll('`', '');
  final runs = <PolicyRun>[];
  var at = 0;
  while (at < plain.length) {
    final open = plain.indexOf('**', at);
    final close = open < 0 ? -1 : plain.indexOf('**', open + 2);
    if (close < 0) {
      runs.add(PolicyRun(plain.substring(at)));
      break;
    }
    if (open > at) runs.add(PolicyRun(plain.substring(at, open)));
    runs.add(PolicyRun(plain.substring(open + 2, close), strong: true));
    at = close + 2;
  }
  return [
    for (final run in runs)
      if (run.text.isNotEmpty) run,
  ];
}

/// Read when the policy is opened; let go when it closes.
@riverpod
Future<List<PolicyBlock>> privacyPolicy(Ref ref) async =>
    parsePrivacyPolicy(await rootBundle.loadString(privacyPolicyAsset));
