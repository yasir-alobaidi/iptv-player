import 'dart:async';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/search/domain/search.dart';

/// Answers each text from a script; can hold its answers, or fail.
final class ScriptedSearch implements SearchRepository {
  final Map<String, SearchResults> answers = {};
  final List<String> asked = [];
  List<String> recent = [];
  final List<String> remembered = [];
  Completer<void>? gate;
  AppFailure? failure;

  @override
  Future<Result<SearchResults>> search(
    String text, {
    required DateTime now,
    String? preferredSourceId,
  }) async {
    asked.add(text);
    final wait = gate;
    if (wait != null) await wait.future;
    final failed = failure;
    if (failed != null) return Err(failed);
    return Ok(answers[text.trim()] ?? SearchResults(text: text));
  }

  @override
  Future<Result<List<String>>> recentSearches() async => Ok(List.of(recent));

  @override
  Future<Result<void>> rememberSearch(String text) async {
    remembered.add(text);
    recent = [text, ...recent.where((r) => r != text)];
    return const Ok(null);
  }

  @override
  Future<Result<void>> forgetSearch(String text) async {
    recent.remove(text);
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearRecentSearches() async {
    recent = [];
    return const Ok(null);
  }
}
