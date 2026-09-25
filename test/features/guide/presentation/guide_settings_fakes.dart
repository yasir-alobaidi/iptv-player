import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

import '../../onboarding/onboarding_fakes.dart';

/// In-memory stand-ins for what Settings → Guide talks to: the guide
/// store, the importer, the matcher and the settings store. The sources
/// come from [OnboardingFakes].
final class GuideFakes {
  new(this.base);

  final OnboardingFakes base;
  final guide = FakeEpgRepository();
  late final imports = FakeGuideImportService(guide);
  late final matching = FakeGuideMatching(guide);
  final settingsStore = FakeGuideSettingsStore();

  List<Override> get overrides => [
    ...base.overrides,
    epgRepositoryProvider.overrideWithValue(guide),
    guideImportServiceProvider.overrideWithValue(imports),
    guideMatchingProvider.overrideWithValue(matching),
    guideSettingsStoreProvider.overrideWithValue(settingsStore),
  ];
}

/// A guide store holding one source's channels, matches and coverage.
final class FakeEpgRepository implements EpgRepository {
  final _coverage = <String, GuideCoverage>{};
  final _coverageChanges = StreamController<String>.broadcast();
  final _changes = StreamController<void>.broadcast();

  /// The source's visible channels, in number order.
  final channels = <String, List<ChannelGuideMatch>>{};

  /// What [matchCandidates] offers, before its query filter.
  final candidates = <String, List<GuideChannelCandidate>>{};

  /// The user's mappings: `(source, remote key)` → xmltv id.
  final userMappings = <(String, String), String>{};

  final mappingCalls = <String>[];

  /// Makes [setMapping] and [removeMapping] fail with this.
  AppFailure? writeFailure;

  /// Makes [watchCoverage] wait for it before the first value.
  Completer<void>? coverageGate;

  /// Makes [watchCoverage] fail with this.
  AppFailure? coverageFailure;

  void setCoverage(String sourceId, GuideCoverage coverage) {
    _coverage[sourceId] = coverage;
    _coverageChanges.add(sourceId);
  }

  void setChannels(String sourceId, List<ChannelGuideMatch> rows) {
    channels[sourceId] = rows;
    notifyChanged();
  }

  /// What `watchChanges` fires on: matches or imports written.
  void notifyChanged() {
    _changes.add(null);
    _coverageChanges.add('*');
  }

  @override
  Stream<GuideCoverage> watchCoverage(String sourceId) async* {
    if (coverageGate case final gate?) await gate.future;
    if (coverageFailure case final failure?) throw failure;
    yield _coverage[sourceId] ?? const GuideCoverage();
    await for (final changed in _coverageChanges.stream) {
      if (changed == sourceId || changed == '*') {
        yield _coverage[sourceId] ?? const GuideCoverage();
      }
    }
  }

  @override
  Future<Result<GuideCoverage>> coverage(String sourceId) async =>
      Ok(_coverage[sourceId] ?? const GuideCoverage());

  @override
  Stream<void> watchChanges() => _changes.stream;

  List<ChannelGuideMatch> _filtered(
    String sourceId,
    ChannelMatchFilter filter,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return [
      for (final c in channels[sourceId] ?? const <ChannelGuideMatch>[])
        if (switch (filter) {
              ChannelMatchFilter.unmatched => !c.isMatched,
              ChannelMatchFilter.manual => c.isManual,
              ChannelMatchFilter.all => true,
            } &&
            (q.isEmpty ||
                c.name.toLowerCase().contains(q) ||
                '${c.number}' == q))
          c,
    ];
  }

  @override
  Future<Result<List<ChannelGuideMatch>>> channelMatches(
    String sourceId, {
    ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
    String query = '',
    int offset = 0,
    int limit = 100,
  }) async =>
      Ok(_filtered(sourceId, filter, query).skip(offset).take(limit).toList());

  @override
  Future<Result<int>> countChannelMatches(
    String sourceId, {
    ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
    String query = '',
  }) async => Ok(_filtered(sourceId, filter, query).length);

  @override
  Future<Result<ChannelGuideMatch?>> channelMatch(int channelId) async => Ok(
    channels.values
        .expand((rows) => rows)
        .where((c) => c.channelId == channelId)
        .firstOrNull,
  );

  ChannelMatchCounts _counts(String sourceId) {
    final rows = channels[sourceId] ?? const <ChannelGuideMatch>[];
    return ChannelMatchCounts(
      channels: rows.length,
      matched: rows.where((c) => c.isMatched).length,
      manual: rows.where((c) => c.isManual).length,
    );
  }

  @override
  Stream<ChannelMatchCounts> watchChannelMatchCounts(String sourceId) async* {
    yield _counts(sourceId);
    await for (final _ in _changes.stream) {
      yield _counts(sourceId);
    }
  }

  @override
  Future<Result<List<GuideChannelCandidate>>> matchCandidates(
    String sourceId, {
    required String channelName,
    String query = '',
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    return Ok(
      [
        for (final c in candidates[sourceId] ?? const <GuideChannelCandidate>[])
          if (q.isEmpty ||
              c.channel.label.toLowerCase().contains(q) ||
              c.channel.xmltvId.toLowerCase().contains(q))
            c,
      ].take(limit).toList(),
    );
  }

  @override
  Future<Result<void>> setMapping({
    required String sourceId,
    required String channelRemoteKey,
    required String xmltvId,
  }) async {
    mappingCalls.add('set $channelRemoteKey → $xmltvId');
    if (writeFailure case final failure?) return Err(failure);
    userMappings[(sourceId, channelRemoteKey)] = xmltvId;
    return const Ok(null);
  }

  @override
  Future<Result<void>> removeMapping({
    required String sourceId,
    required String channelRemoteKey,
  }) async {
    mappingCalls.add('remove $channelRemoteKey');
    if (writeFailure case final failure?) return Err(failure);
    userMappings.remove((sourceId, channelRemoteKey));
    return const Ok(null);
  }

  @override
  Future<Result<List<EpgMapping>>> mappings(String sourceId) =>
      throw UnimplementedError();

  @override
  Future<Result<int>> startImport(String sourceId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> stageChannels(int importRun, List<GuideChannel> rows) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> stagePrograms(int importRun, List<EpgProgramme> rows) =>
      throw UnimplementedError();

  @override
  Future<Result<EpgImportCounts>> commitImport({
    required String sourceId,
    required int importRun,
    EpgImportCounts counts = const EpgImportCounts(),
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> abandonImport(
    int importRun, {
    required GuideImportOutcome outcome,
    AppFailure? failure,
    EpgImportCounts counts = const EpgImportCounts(),
  }) => throw UnimplementedError();

  @override
  Future<Result<int>> recoverInterrupted() => throw UnimplementedError();

  @override
  Future<Result<Map<int, EpgNowNext>>> nowNextForChannels(
    List<int> channelIds,
    DateTime at,
  ) => throw UnimplementedError();

  @override
  Future<Result<Map<int, List<EpgProgramme>>>> windowForChannels(
    List<int> channelIds,
    DateTime from,
    DateTime to,
  ) => throw UnimplementedError();

  @override
  Future<Result<List<GuideChannel>>> guideChannels(
    String sourceId, {
    String? query,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> clearGuide(String sourceId) =>
      throw UnimplementedError();
}

/// An importer the test drives: each import waits for [gate] when one is
/// set, then answers [result].
final class FakeGuideImportService implements GuideImportService {
  new(this._guide);

  final FakeEpgRepository _guide;
  final _progress = StreamController<(String, EpgImportProgress)>.broadcast();
  final calls = <String>[];
  final origins = <String, Result<GuideOrigin>>{};
  final _running = <String>{};

  /// Holds every import until completed.
  Completer<void>? gate;

  /// What an import answers.
  Result<EpgImportCounts> result = const Ok(EpgImportCounts());

  void report(String sourceId, EpgImportProgress progress) =>
      _progress.add((sourceId, progress));

  @override
  Stream<(String, EpgImportProgress)> get progress => _progress.stream;

  @override
  bool isImporting(String sourceId) => _running.contains(sourceId);

  @override
  Future<Result<EpgImportCounts>> importGuide(String sourceId) {
    calls.add('import $sourceId');
    return _run(sourceId);
  }

  @override
  Future<Result<EpgImportCounts>> reimport(String sourceId) {
    calls.add('reimport $sourceId');
    return _run(sourceId);
  }

  Future<Result<EpgImportCounts>> _run(String sourceId) async {
    _running.add(sourceId);
    _guide.notifyChanged();
    try {
      if (gate case final gate?) await gate.future;
      return result;
    } finally {
      _running.remove(sourceId);
      _guide.notifyChanged();
    }
  }

  @override
  Future<void> cancel(String sourceId) async {
    calls.add('cancel $sourceId');
  }

  @override
  Future<Result<GuideOrigin>> guideOrigin(String sourceId) async =>
      origins[sourceId] ?? const Ok(GuideOrigin(GuideOriginKind.panel));
}

/// A matcher that applies the fake store's mappings to its channels.
final class FakeGuideMatching implements GuideMatching {
  new(this._guide);

  final FakeEpgRepository _guide;
  final calls = <String>[];

  /// Makes [rematch] fail with this.
  AppFailure? failure;

  /// The guide channels' labels, by id, for what a mapping shows.
  final labels = <String, String>{};

  @override
  Future<Result<EpgMatchSummary>> rematch(String sourceId) async {
    calls.add(sourceId);
    if (failure case final failure?) return Err(failure);
    final rows = _guide.channels[sourceId] ?? const <ChannelGuideMatch>[];
    _guide.setChannels(sourceId, [
      for (final c in rows)
        switch (_guide.userMappings[(sourceId, c.remoteKey)]) {
          final id? => _with(c, id, GuideMatchRule.manual, labels[id]),
          null when c.isManual => _with(c, null, null, null),
          null => c,
        },
    ]);
    return Ok(EpgMatchSummary(channels: rows.length));
  }

  static ChannelGuideMatch _with(
    ChannelGuideMatch c,
    String? id,
    GuideMatchRule? rule,
    String? label,
  ) => ChannelGuideMatch(
    channelId: c.channelId,
    sourceId: c.sourceId,
    remoteKey: c.remoteKey,
    name: c.name,
    providerName: c.providerName,
    number: c.number,
    logoUrl: c.logoUrl,
    epgKey: c.epgKey,
    xmltvId: id,
    rule: rule,
    guideLabel: label,
    inGuide: label != null,
  );
}

final class FakeGuideSettingsStore implements GuideSettingsStore {
  GuideSettings stored = const GuideSettings();
  final saved = <GuideSettings>[];

  @override
  Future<Result<GuideSettings>> load() async => Ok(stored);

  @override
  Future<Result<void>> save(GuideSettings settings) async {
    saved.add(settings);
    stored = settings;
    return const Ok(null);
  }
}

/// A channel row for the fakes.
ChannelGuideMatch guideRow(
  int id,
  String name, {
  String sourceId = 'src-1',
  String? xmltvId,
  GuideMatchRule? rule,
  String? guideLabel,
}) => ChannelGuideMatch(
  channelId: id,
  sourceId: sourceId,
  remoteKey: 'ch-$id',
  name: name,
  providerName: name,
  number: 100 + id,
  xmltvId: xmltvId,
  rule: xmltvId == null ? null : rule ?? GuideMatchRule.normalizedName,
  guideLabel: xmltvId == null ? null : guideLabel ?? xmltvId,
  inGuide: xmltvId != null,
);

/// A guide channel candidate for the picker.
GuideChannelCandidate candidate(String id, String name, double score) =>
    GuideChannelCandidate(
      channel: GuideChannel(xmltvId: id, displayName: name),
      score: score,
    );
