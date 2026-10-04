/// Language names for the codes files and streams carry (ISO 639-1 and
/// -2): "English" for `en` or `eng`. The app is in English only (docs/00);
/// a code not listed shows as itself, upper case.
library;

String languageName(String code) {
  final key = code.toLowerCase().split(RegExp('[-_]')).first;
  return _names[key] ?? code.toUpperCase();
}

const _names = {
  'en': 'English', 'eng': 'English', //
  'fr': 'French', 'fre': 'French', 'fra': 'French',
  'de': 'German', 'ger': 'German', 'deu': 'German',
  'es': 'Spanish', 'spa': 'Spanish',
  'it': 'Italian', 'ita': 'Italian',
  'pt': 'Portuguese', 'por': 'Portuguese',
  'ar': 'Arabic', 'ara': 'Arabic',
  'nl': 'Dutch', 'dut': 'Dutch', 'nld': 'Dutch',
  'sv': 'Swedish', 'swe': 'Swedish',
  'no': 'Norwegian', 'nor': 'Norwegian', 'nb': 'Norwegian',
  'da': 'Danish', 'dan': 'Danish',
  'fi': 'Finnish', 'fin': 'Finnish',
  'pl': 'Polish', 'pol': 'Polish',
  'tr': 'Turkish', 'tur': 'Turkish',
  'ru': 'Russian', 'rus': 'Russian',
  'el': 'Greek', 'gre': 'Greek', 'ell': 'Greek',
  'ja': 'Japanese', 'jpn': 'Japanese',
  'ko': 'Korean', 'kor': 'Korean',
  'zh': 'Chinese', 'chi': 'Chinese', 'zho': 'Chinese',
  'hi': 'Hindi', 'hin': 'Hindi',
  'he': 'Hebrew', 'heb': 'Hebrew',
  'fa': 'Persian', 'per': 'Persian', 'fas': 'Persian',
  'ur': 'Urdu', 'urd': 'Urdu',
  'ku': 'Kurdish', 'kur': 'Kurdish',
};
