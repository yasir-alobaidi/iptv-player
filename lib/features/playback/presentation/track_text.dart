/// How the player names a file's sound and subtitle tracks (ADR-065).
///
/// A track's language is the file's own tag, and a lone tag proves
/// nothing: an encoder writes "eng" by default, and Matroska reads a
/// track with no tag as English. A provider's Turkish episode with one
/// sound track said "Audio: English". So a language is named only when
/// the tracks of a kind carry two different ones, which someone tagged on
/// purpose; otherwise a track is what the decoder measures (Stereo, AAC)
/// under its title or its number.
library;

import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';

/// Whether [tracks]' tags tell them apart: two different languages at
/// least ("en" and "eng" are one).
bool namesLanguages(List<MediaTrack> tracks) =>
    {
      for (final t in tracks)
        if (_code(t) case final code?) languageTag(code),
    }.length >=
    2;

/// The track's language code, unless it has none ("", "und").
String? _code(MediaTrack t) => switch (t.language?.trim()) {
  final code? when code.isNotEmpty && code.toLowerCase() != 'und' => code,
  _ => null,
};

String? _title(MediaTrack t) => switch (t.title?.trim()) {
  final title? when title.isNotEmpty => title,
  _ => null,
};

/// A track in a word or two: its language when [languages] (from
/// [namesLanguages]) and it has one, else its title, else "Track 2" for
/// the [number]th of its kind (from 1).
String trackName(MediaTrack t, int number, {required bool languages}) {
  if (languages && _code(t) != null) return languageName(_code(t)!);
  return _title(t) ?? 'Track $number';
}

/// A track as its menu names it: "English · Commentary · 5.1 · AC3",
/// "Track 1 · Stereo · AAC".
String trackLine(MediaTrack t, int number, {required bool languages}) {
  final name = trackName(t, number, languages: languages);
  final title = _title(t);
  return [
    name,
    // A title that only repeats the name says nothing more.
    if (title != null && title.toLowerCase() != name.toLowerCase()) title,
    ?channelsLabel(t.channels),
    ?codecLabel(t.codec),
  ].join(' · ');
}

/// The Audio control's words: "Audio: Turkish" when the tags tell the
/// tracks apart, else what is heard ("Audio: Stereo"), else "Audio".
String audioLabel(PlayerTracks? tracks) {
  final all = tracks?.audio ?? const <MediaTrack>[];
  final on = all.where((t) => t.id == tracks?.audioId).firstOrNull;
  if (on == null) return 'Audio';
  if (namesLanguages(all) && _code(on) != null) {
    return 'Audio: ${languageName(_code(on)!)}';
  }
  return switch (channelsLabel(on.channels)) {
    final sound? => 'Audio: $sound',
    null => 'Audio',
  };
}

/// The Subtitles control's words: "Subtitles: Off", "Subtitles: French"
/// when the tags tell the tracks apart, else the track's title, else
/// "Subtitles: On".
String subtitlesLabel(PlayerTracks? tracks) {
  final all = tracks?.subtitles ?? const <MediaTrack>[];
  final on = all.where((t) => t.id == tracks?.subtitleId).firstOrNull;
  if (on == null) return 'Subtitles: Off';
  if (namesLanguages(all) && _code(on) != null) {
    return 'Subtitles: ${languageName(_code(on)!)}';
  }
  return 'Subtitles: ${_title(on) ?? 'On'}';
}

/// mpv's channel layout as said: "Mono", "Stereo", "5.1", "7.1"; null
/// when unknown.
String? channelsLabel(String? layout) {
  final text = layout?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (RegExp(r'^\d+\.\d+').firstMatch(text) case final m?) return m[0];
  return switch (channelCount(text)) {
    1 => 'Mono',
    2 => 'Stereo',
    6 => '5.1',
    8 => '7.1',
    final n? => '$n channels',
    null => null,
  };
}

/// A codec as people know it: "AAC", "E-AC3", "SRT"; any other in
/// capitals.
String? codecLabel(String? codec) {
  final text = codec?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (text.startsWith('pcm')) return 'PCM';
  return _codecs[text] ?? text.toUpperCase();
}

const _codecs = {
  'eac3': 'E-AC3',
  'truehd': 'TrueHD',
  'opus': 'Opus',
  'vorbis': 'Vorbis',
  'subrip': 'SRT',
  'srt': 'SRT',
  'webvtt': 'WebVTT',
  'mov_text': 'Text',
  'hdmv_pgs_subtitle': 'PGS',
  'dvd_subtitle': 'VobSub',
  'dvb_subtitle': 'DVB',
};
