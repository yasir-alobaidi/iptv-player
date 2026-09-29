import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/domain/search_words.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_state.g.dart';

/// How long typing rests before a search runs (docs/05).
const searchDelay = Duration(milliseconds: 150);

/// What the overlay shows: the text, the results of the last search that
/// finished (kept while a newer one runs, so rows don't blink), whether
/// one runs, how the last one failed, and the recent searches.
@immutable
final class SearchView {
  const new({
    this.text = '',
    this.results,
    this.searching = false,
    this.failure,
    this.recent = const [],
  });

  final String text;

  /// Null until a search finished since the text last had words.
  final SearchResults? results;
  final bool searching;
  final AppFailure? failure;
  final List<String> recent;

  /// No word typed: the overlay shows the recent searches.
  bool get idle => searchWords(text).isEmpty;

  SearchView copyWith({
    String? text,
    SearchResults? results,
    bool clearResults = false,
    bool? searching,
    AppFailure? failure,
    bool clearFailure = false,
    List<String>? recent,
  }) => SearchView(
    text: text ?? this.text,
    results: clearResults ? null : results ?? this.results,
    searching: searching ?? this.searching,
    failure: clearFailure ? null : failure ?? this.failure,
    recent: recent ?? this.recent,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchView &&
      other.text == text &&
      other.results == results &&
      other.searching == searching &&
      other.failure == failure &&
      listEquals(other.recent, recent);

  @override
  int get hashCode =>
      Object.hash(text, results, searching, failure, Object.hashAll(recent));
}

/// One opening of the overlay: the search as it is typed. Gone when the
/// overlay closes.
@riverpod
class SearchSession extends _$SearchSession {
  Timer? _wait;

  /// Bumped by every search started and every text with no words, so an
  /// answer that arrives after a newer question is dropped.
  var _generation = 0;

  @override
  SearchView build() {
    ref.onDispose(() => _wait?.cancel());
    // After build: a repository that can't be made fails synchronously.
    unawaited(Future.microtask(_loadRecent));
    return const SearchView();
  }

  SearchRepository get _repository => ref.read(searchRepositoryProvider);

  /// The text typed. A search runs [searchDelay] after the last change;
  /// until it answers, the last results stay.
  void setText(String text) {
    if (text == state.text) return;
    _wait?.cancel();
    if (searchWords(text).isEmpty) {
      _generation++;
      state = state.copyWith(
        text: text,
        clearResults: true,
        searching: false,
        clearFailure: true,
      );
      return;
    }
    state = state.copyWith(text: text, searching: true);
    // No source, nothing to search: the overlay says so.
    if (ref.read(currentSourceProvider) == null) {
      state = state.copyWith(searching: false);
      return;
    }
    _wait = Timer(searchDelay, () => unawaited(_search(text)));
  }

  /// Runs the search for the text now, as Retry does.
  Future<void> retry() => _search(state.text);

  Future<void> _search(String text) async {
    final generation = ++_generation;
    state = state.copyWith(searching: true);
    Result<SearchResults> result;
    try {
      result = await _repository.search(
        text,
        now: ref.read(appClockProvider)(),
        preferredSourceId: ref.read(currentSourceProvider)?.id,
      );
    } on Object catch (error) {
      // The repository never throws; one that can't be made does.
      result = Err(AppFailure.fromError(error));
    }
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok(:final value) => state.copyWith(
        results: value,
        searching: false,
        clearFailure: true,
      ),
      Err(:final failure) => state.copyWith(searching: false, failure: failure),
    };
  }

  /// Saves the text typed to the recent searches: when a result is
  /// opened, not on every keystroke (decision 4).
  Future<void> rememberText() async {
    final text = state.text.trim();
    if (text.isEmpty) return;
    await _repository.rememberSearch(text);
  }

  Future<void> forget(String text) async {
    await _repository.forgetSearch(text);
    await _loadRecent();
  }

  Future<void> clearRecent() async {
    await _repository.clearRecentSearches();
    await _loadRecent();
  }

  /// None when they can't be read, whatever the reason: the overlay
  /// works without them.
  Future<void> _loadRecent() async {
    List<String> recent;
    try {
      recent = (await _repository.recentSearches()).valueOrNull ?? const [];
    } on Object {
      recent = const [];
    }
    if (!ref.mounted) return;
    state = state.copyWith(recent: recent);
  }
}
