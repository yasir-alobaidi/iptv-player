/// How typed text becomes what search looks for. Pure: the query and the
/// overlay's highlighting read it the same way.
library;

/// Words past this many are ignored: nobody types more into a search box,
/// and each word is one more term for the index to intersect.
const searchWordLimit = 8;

/// Characters kept of each word.
const searchWordLength = 64;

final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

/// The words of [text] as the index splits names into words: runs of
/// letters, marks and digits in any script, everything else a separator.
/// So quotes, `*`, `-`, `NEAR`'s parentheses, emoji and lone surrogates
/// are only separators, and no text can make a query fail. Empty when
/// [text] has no word.
List<String> searchWords(String text) {
  final words = <String>[];
  for (final match in _word.allMatches(text)) {
    final word = match[0]!;
    // By code point, so a cut never splits a surrogate pair.
    words.add(
      word.length > searchWordLength
          ? String.fromCharCodes(word.runes.take(searchWordLength))
          : word,
    );
    if (words.length == searchWordLimit) break;
  }
  return words;
}
