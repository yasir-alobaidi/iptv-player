import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

/// [DecoderNotes] in the `settings` table, as one JSON list: the newest
/// first, one per kind of video, [limit] at most.
///
/// A note that says what the list already says isn't written again:
/// zapping through fifty 1080p channels is one write, not fifty.
final class DbDecoderNotes implements DecoderNotes {
  new(this._settings, {DateTime Function()? clock, this.limit = 20})
    : _clock = clock ?? DateTime.now;

  final SettingsRepository _settings;
  final DateTime Function() _clock;
  final int limit;

  List<DecoderNote>? _notes;

  Future<List<DecoderNote>> _load() async {
    final held = _notes;
    if (held != null) return held;
    final stored = await _settings.readValue<Object?>(
      SettingsKeys.decoders,
      null,
    );
    final list = stored.valueOrNull;
    return _notes = [
      if (list is List)
        for (final entry in list) ?DecoderNote.fromJson(entry),
    ];
  }

  @override
  Future<void> note(StreamInfo info) async {
    final note = DecoderNote.of(info, _clock());
    if (note == null) return;
    final notes = await _load();
    final held = notes.where((n) => n.kind == note.kind).firstOrNull;
    if (held != null && held.decoder == note.decoder) return;
    final next = [
      note,
      for (final other in notes)
        if (other.kind != note.kind) other,
    ].take(limit).toList();
    _notes = next;
    // A failed write is a note lost; the list in memory still has it.
    await _settings.writeValue(SettingsKeys.decoders, [
      for (final n in next) n.toJson(),
    ]);
  }

  @override
  Future<List<DecoderNote>> recent() async => List.unmodifiable(await _load());
}
