import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/privacy_policy.dart';

void main() {
  group('parsePrivacyPolicy', () {
    test('headings, a note, paragraphs and items, the title left to the '
        'dialog', () {
      final blocks = parsePrivacyPolicy('''
# Bijou privacy policy

*Effective 27 October 2026.*

Bijou is a video player
for Android.

## What Bijou keeps

- **The sources you add:** their names
  and addresses.
- A log.
''');

      expect(blocks.map((block) => block.runtimeType), [
        PolicyNote,
        PolicyParagraph,
        PolicyHeading,
        PolicyBullet,
        PolicyBullet,
      ]);
      expect(blocks[0].text, 'Effective 27 October 2026.');
      expect(blocks[1].text, 'Bijou is a video player for Android.');
      expect(blocks[2].text, 'What Bijou keeps');
      expect(blocks[3].runs, const [
        PolicyRun('The sources you add:', strong: true),
        PolicyRun(' their names and addresses.'),
      ]);
      expect(blocks[4].text, 'A log.');
    });

    test('code shows as its words; bold mid-sentence', () {
      final [block] = parsePrivacyPolicy(
        'Prefer `https` addresses. **Bijou has no account,** at all.',
      );
      expect(block.runs, const [
        PolicyRun('Prefer https addresses. '),
        PolicyRun('Bijou has no account,', strong: true),
        PolicyRun(' at all.'),
      ]);
    });

    test('malformed: an unclosed ** stays text, a lone # and stray blank '
        'lines are skipped, Windows line ends are read', () {
      final blocks = parsePrivacyPolicy(
        '#\r\n\r\n\r\nSome **words\r\n##   \r\n- \r\n*\r\n',
      );
      expect(blocks.map((block) => block.text), ['Some **words', '*']);
      expect(blocks.first, isA<PolicyParagraph>());
      expect(blocks.last, isA<PolicyBullet>(), reason: 'after a bare -');
      expect(parsePrivacyPolicy(''), isEmpty);
    });
  });

  test('the bundled policy (docs/privacy-policy.md) reads as its sections, '
      'nothing in it left as Markdown', () {
    final blocks = parsePrivacyPolicy(
      File(privacyPolicyAsset).readAsStringSync(),
    );

    expect(
      [for (final block in blocks.whereType<PolicyHeading>()) block.text],
      containsAllInOrder([
        'What Bijou keeps on your device',
        'What leaves your device',
        'Children',
        'Keeping and deleting your information',
        'Changes',
        'Contact',
      ]),
    );
    expect(blocks.first, isA<PolicyNote>());
    for (final block in blocks) {
      expect(block.text, isNot(contains('**')), reason: block.text);
      expect(block.text, isNot(contains('`')), reason: block.text);
      expect(block.text, isNot(startsWith('#')), reason: block.text);
    }
  });

  test("the policy is in the app's bundle", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final text = await rootBundle.loadString(privacyPolicyAsset);
    expect(parsePrivacyPolicy(text), isNotEmpty);
  });
}
