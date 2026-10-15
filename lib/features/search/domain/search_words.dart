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

// ---------------------------------------------------------------- Arabic

/// The alef, written with or without its hamza or madda.
const _alefForms = ['ا', 'أ', 'إ', 'آ'];

/// Spellings asked for, at most, per word: each is one more prefix term.
const _maxSpellings = 32;

/// [text] with the Arabic letters a provider (and a viewer) writes several
/// ways read as one: the alef with or without its hamza or madda
/// (أ إ آ ٱ → ا), the closing ta marbuta as heh (ة → ه), the alef maqsura
/// as yeh (ى → ي), Arabic-Indic digits as 0–9, and no harakat or tatweel.
/// The user's catalogue has "ارطغرل" and "أرطغرل", "الخطوره" for
/// "الخطورة", "العميل ٧٧" (ADR-027). Text with no Arabic comes back as it
/// went in.
String foldArabic(String text) {
  if (!text.runes.any(_arabicBlock)) return text;
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (_harakat(rune) || rune == 0x0640) continue;
    out.write(switch (rune) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 => 'ا',
      0x0629 => 'ه',
      0x0649 => 'ي',
      >= 0x0660 && <= 0x0669 => String.fromCharCode(0x30 + rune - 0x0660),
      >= 0x06F0 && <= 0x06F9 => String.fromCharCode(0x30 + rune - 0x06F0),
      _ => String.fromCharCode(rune),
    });
  }
  return out.toString();
}

/// The spellings of [word] a name may have ([foldArabic]'s, undone): each
/// alef as any of its forms (but the article's, in "ال"), a closing heh as
/// ta marbuta too and a closing yeh as alef maqsura, and digits both as
/// 0–9 and as Arabic-Indic ones. At most 32; [word] alone when it has no
/// Arabic (a word of digits only has both kinds of digits).
List<String> searchSpellings(String word) {
  final folded = foldArabic(word);
  final runes = folded.runes.toList();
  final arabic = runes.any(_arabicBlock);
  final digits = runes.any(_digit) && (arabic || runes.every(_digit));
  if (!arabic && !digits) return [word];
  final ending = switch (runes.isEmpty ? null : runes.last) {
    0x0647 => const ['ه', 'ة'],
    0x064A => const ['ي', 'ى'],
    _ => null,
  };
  var budget = _maxSpellings ~/ ((ending == null ? 1 : 2) * (digits ? 2 : 1));
  var spellings = [''];
  for (final (i, rune) in runes.indexed) {
    final char = String.fromCharCode(rune);
    final List<String> forms;
    if (i == runes.length - 1 && ending != null) {
      forms = ending;
    } else if (char == 'ا' &&
        !(i == 0 && folded.startsWith('ال')) &&
        budget >= _alefForms.length) {
      budget ~/= _alefForms.length;
      forms = _alefForms;
    } else {
      forms = [char];
    }
    spellings = [
      for (final spelling in spellings)
        for (final form in forms) spelling + form,
    ];
  }
  if (!digits) return spellings;
  return [
    for (final spelling in spellings) ...{spelling, _arabicIndic(spelling)},
  ];
}

/// [word] as an FTS5 prefix term, with its other [searchSpellings] OR'ed
/// in: `"sky"*`, `("اخبار"* OR "أخبار"* OR …)`.
String searchTerm(String word) {
  final spellings = searchSpellings(word);
  if (spellings.length == 1) return '"${spellings.single}"*';
  return '(${[for (final s in spellings) '"$s"*'].join(' OR ')})';
}

bool _arabicBlock(int rune) => rune >= 0x0600 && rune <= 0x06FF;

bool _digit(int rune) => rune >= 0x30 && rune <= 0x39;

/// Harakat, the dagger alef and the Quranic marks.
bool _harakat(int rune) =>
    (rune >= 0x064B && rune <= 0x065F) ||
    rune == 0x0670 ||
    (rune >= 0x06D6 && rune <= 0x06ED);

String _arabicIndic(String text) => String.fromCharCodes([
  for (final rune in text.runes)
    if (_digit(rune)) 0x0660 + rune - 0x30 else rune,
]);
