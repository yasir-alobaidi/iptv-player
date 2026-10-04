import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/logging/redact.dart';

/// What is cast, as the facts are remembered by: a source's channel,
/// movie or episode.
@immutable
final class CastStreamKey {
  const new({required this.sourceId, required this.kind, required this.id});

  final String sourceId;
  final CastStreamKind kind;

  /// The provider's id for it (`stream_id`, an episode's id).
  final String id;

  @override
  bool operator ==(Object other) =>
      other is CastStreamKey &&
      other.sourceId == sourceId &&
      other.kind == kind &&
      other.id == id;

  @override
  int get hashCode => Object.hash(sourceId, kind, id);

  @override
  String toString() => 'CastStreamKey($sourceId, ${kind.name}, $id)';
}

enum CastStreamKind { live, movie, episode, libraryFile }

/// The facts a cast's plan starts from, cheapest first (Phase 7 decision
/// 4): the laptop's player when it is playing this very stream, then
/// facts found earlier in this run, then ffprobe. Zapping back and forth
/// while casting probes each channel once.
final class StreamFactsLookup {
  new({required this._probe, this.capacity = 256});

  /// How many streams' facts are remembered; the least recently used go
  /// first.
  final int capacity;

  final StreamProbe _probe;
  final _remembered = <CastStreamKey, StreamFacts>{};
  final _probing = <CastStreamKey, Future<StreamProbeResult>>{};

  /// The facts for [key]. [fromPlayer] are the laptop's player's, when it
  /// plays this stream now. [probeInput] gives what ffprobe reads (the
  /// relay's proxy), asked only when a probe is needed. Probes of one key
  /// at once share one ffprobe. Never throws: a failed probe answers why,
  /// and isn't remembered.
  Future<StreamProbeResult> factsFor(
    CastStreamKey key, {
    required Future<String> Function() probeInput,
    StreamFacts? fromPlayer,
    String? userAgent,
  }) async {
    if (fromPlayer != null) {
      remember(key, fromPlayer);
      return StreamProbed(fromPlayer);
    }
    final known = _remembered.remove(key);
    if (known != null) {
      _remembered[key] = known;
      return StreamProbed(known.copyWith(origin: StreamFactsOrigin.remembered));
    }
    final running = _probing[key];
    if (running != null) return await running;
    final probe = _run(key, probeInput, userAgent);
    _probing[key] = probe;
    try {
      return await probe;
    } finally {
      // Not `whenComplete(() => _probing.remove(key))`: remove would
      // answer the future itself, which would wait for itself.
      _probing.removeWhere((k, v) => k == key && identical(v, probe));
    }
  }

  /// Facts learned another way: FFmpeg's report of the streams it opened
  /// (step 5).
  void remember(CastStreamKey key, StreamFacts facts) {
    _remembered
      ..remove(key)
      ..[key] = facts;
    while (_remembered.length > capacity) {
      _remembered.remove(_remembered.keys.first);
    }
  }

  /// The stream turned out different from its facts (a codec switch):
  /// the next cast of it asks again.
  void forget(CastStreamKey key) => _remembered.remove(key);

  Future<StreamProbeResult> _run(
    CastStreamKey key,
    Future<String> Function() probeInput,
    String? userAgent,
  ) async {
    final String input;
    try {
      input = await probeInput();
    } on Object catch (error) {
      return StreamProbeFailed(
        StreamProbeFailure.couldNotStart,
        redact('$error'),
      );
    }
    final result = await _probe.probe(input, userAgent: userAgent);
    if (result case StreamProbed(:final facts)) remember(key, facts);
    return result;
  }
}
