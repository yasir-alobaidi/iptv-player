import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/search/domain/search_words.dart';

void main() {
  test('words are runs of letters, marks and digits in any script', () {
    expect(searchWords('Sky Sports'), ['Sky', 'Sports']);
    expect(searchWords('  sky   sports  '), ['sky', 'sports']);
    expect(searchWords('BBC-One+1'), ['BBC', 'One', '1']);
    expect(searchWords('Télé-Québec'), ['Télé', 'Québec']);
    expect(searchWords('الجزيرة الوثائقية'), ['الجزيرة', 'الوثائقية']);
    expect(searchWords('Первый канал'), ['Первый', 'канал']);
    expect(searchWords('e\u0301cole'), ['e\u0301cole']);
  });

  test('what FTS reads as syntax is only a separator', () {
    for (final text in [
      '"',
      '*',
      '{}:',
      '^',
      '-',
      '(',
      '\ud800',
      '😀',
      "'",
      '\u0000',
    ]) {
      expect(searchWords(text), isEmpty, reason: text);
    }
    expect(searchWords('"sky"* NEAR(news)'), ['sky', 'NEAR', 'news']);
    expect(searchWords('a\ud800b😀c'), ['a', 'b', 'c']);
  });

  test('eight words at most, 64 characters each, never half a pair', () {
    expect(searchWords('a b c d e f g h i j'), hasLength(searchWordLimit));
    final long = searchWords('x' * 200).single;
    expect(long, hasLength(searchWordLength));
    // 𝐀 (U+1D400) is a letter written as a surrogate pair.
    final astral = searchWords('\u{1D400}' * 70).single;
    expect(astral.runes, hasLength(searchWordLength));
    expect(astral.length, searchWordLength * 2);
  });
}
