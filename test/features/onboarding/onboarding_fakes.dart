import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_check.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// In-memory stand-ins for the domain interfaces onboarding talks to, so
/// its widget tests need no database, keyring, network or isolate.
final class OnboardingFakes {
  final sources = FakeSourceRepository();
  late final sync = FakeSyncService(sources);
  final checker = FakeSourceChecker();
  final categories = FakeCategoryRepository();
  final overviews = FakeSourceOverviewRepository();

  /// What the file dialog returns; null is "closed without choosing".
  String? pickedFile;
  int pickerCalls = 0;

  DateTime now = DateTime.utc(2026, 9, 14, 12);

  List<Override> get overrides => [
    sourceRepositoryProvider.overrideWithValue(sources),
    syncServiceProvider.overrideWithValue(sync),
    sourceCheckerProvider.overrideWithValue(checker),
    categoryRepositoryProvider.overrideWithValue(categories),
    playlistFilePickerProvider.overrideWithValue(() async {
      pickerCalls++;
      return pickedFile;
    }),
    onboardingClockProvider.overrideWithValue(() => now),
    sourceOverviewRepositoryProvider.overrideWithValue(overviews),
    appClockProvider.overrideWithValue(() => now),
  ];
}

final class FakeSourceRepository implements SourceRepository {
  final _sources = <Source>[];
  final _changes = StreamController<List<Source>>.broadcast();
  final added = <SourceDraft>[];
  final removed = <String>[];

  final updated = <(String, SourceDraft)>[];
  final reorders = <List<String>>[];

  /// Makes the next [add] fail with this.
  AppFailure? addFailure;

  /// Makes every [update], [reorder] fail with this.
  AppFailure? writeFailure;

  /// What [credentialsFor] answers; by default a stored password.
  Result<SourceCredentials>? credentials;
  var _next = 0;

  Source seed({
    String id = 'src-1',
    SourceType type = SourceType.xtream,
    String name = 'Northwind TV',
    DateTime? lastSyncedAt,
  }) {
    final source = _source(id, type, name).copyWith(
      username: type == SourceType.xtream ? 'alice' : null,
      lastSyncedAt: lastSyncedAt,
    );
    _sources.add(source);
    _changes.add(List.of(_sources));
    return source;
  }

  static Source _source(String id, SourceType type, String name) => Source(
    id: id,
    type: type,
    name: name,
    displayUrl: switch (type) {
      SourceType.xtream => 'http://line.northwind.test',
      SourceType.m3uUrl => 'http://lists.northwind.test/…',
      SourceType.m3uFile => '/home/alice/playlists/northwind.m3u',
    },
    liveFormat: LiveFormat.ts,
    epgOffsetMinutes: 0,
    refreshHours: 12,
    sortOrder: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  @override
  Stream<List<Source>> watchAll() async* {
    yield List.of(_sources);
    yield* _changes.stream;
  }

  @override
  Future<Result<List<Source>>> all() async => Ok(List.of(_sources));

  @override
  Future<Result<Source?>> byId(String id) async =>
      Ok(_sources.where((s) => s.id == id).firstOrNull);

  @override
  Future<Result<Source>> add(SourceDraft draft) async {
    added.add(draft);
    if (addFailure case final failure?) {
      addFailure = null;
      return Err(failure);
    }
    final source = _source('new-${++_next}', draft.type, draft.name);
    _sources.add(source);
    _changes.add(List.of(_sources));
    return Ok(source);
  }

  @override
  Future<Result<void>> remove(String id) async {
    removed.add(id);
    _sources.removeWhere((s) => s.id == id);
    _changes.add(List.of(_sources));
    return const Ok(null);
  }

  @override
  Future<Result<Source>> update(String id, SourceDraft draft) async {
    updated.add((id, draft));
    if (writeFailure case final failure?) return Err(failure);
    final index = _sources.indexWhere((s) => s.id == id);
    if (index < 0) return Err(NotFoundFailure(id));
    final source = _sources[index].copyWith(
      name: draft.name,
      username: draft.username,
      userAgent: draft.userAgent,
      liveFormat: draft.liveFormat,
    );
    _sources[index] = source;
    _changes.add(List.of(_sources));
    return Ok(source);
  }

  @override
  Future<Result<void>> reorder(List<String> idsInOrder) async {
    reorders.add(idsInOrder);
    if (writeFailure case final failure?) return Err(failure);
    final byId = {for (final s in _sources) s.id: s};
    _sources
      ..clear()
      ..addAll([for (final id in idsInOrder) byId[id]!]);
    _changes.add(List.of(_sources));
    return const Ok(null);
  }

  @override
  Future<Result<SourceCredentials>> credentialsFor(String id) async {
    if (credentials case final answer?) return answer;
    final source = _sources.where((s) => s.id == id).firstOrNull;
    if (source == null) return Err(NotFoundFailure(id));
    return Ok(
      SourceCredentials(
        url: source.type == SourceType.m3uUrl
            ? 'http://lists.northwind.test/get.php?username=alice&password=s3cret'
            : source.displayUrl,
        username: source.username,
        password: source.type == SourceType.xtream ? 's3cret' : null,
      ),
    );
  }

  @override
  Future<Result<void>> setAdvertisedEpgUrls(String id, List<String> urls) =>
      throw UnimplementedError();

  @override
  Future<Result<int>> pruneOrphanedSecrets() async => const Ok(0);
}

/// Overviews the test sets per source; an unset one is an empty overview.
final class FakeSourceOverviewRepository implements SourceOverviewRepository {
  final _overviews = <String, SourceOverview>{};
  final _changes = StreamController<String>.broadcast();

  /// Makes [watch] fail with this.
  AppFailure? failure;

  void set(String id, SourceOverview overview) {
    _overviews[id] = overview;
    _changes.add(id);
  }

  @override
  Stream<SourceOverview?> watch(String sourceId) async* {
    if (failure case final failure?) throw failure;
    yield _overviews[sourceId] ?? const SourceOverview();
    yield* _changes.stream
        .where((id) => id == sourceId)
        .map((id) => _overviews[id]);
  }
}

/// A sync service the test drives: [emit] sets a source's status.
final class FakeSyncService implements SyncService {
  new(this._sources);

  final FakeSourceRepository _sources;
  final _status = <String, SyncStatus>{};
  final _changes = StreamController<(String, SyncStatus)>.broadcast();
  final syncCalls = <String>[];
  final cancelCalls = <String>[];
  final removeCalls = <String>[];
  final _runs = <String, Completer<Result<SyncReport>>>{};

  void emit(String id, SyncStatus status) {
    _status[id] = status;
    _changes.add((id, status));
    if (status is SyncSucceeded) _runs.remove(id)?.complete(Ok(status.report));
  }

  @override
  SyncStatus statusOf(String sourceId) => _status[sourceId] ?? const SyncIdle();

  @override
  Stream<SyncStatus> watch(String sourceId) async* {
    yield statusOf(sourceId);
    yield* _changes.stream.where((c) => c.$1 == sourceId).map((c) => c.$2);
  }

  @override
  Future<Result<SyncReport>> sync(String sourceId) {
    syncCalls.add(sourceId);
    emit(sourceId, const SyncRunning(SyncProgress(stage: SyncStage.account)));
    return (_runs[sourceId] ??= Completer()).future;
  }

  @override
  Future<void> cancel(String sourceId) async {
    cancelCalls.add(sourceId);
    _runs.remove(sourceId)?.complete(Err(CancelledFailure()));
  }

  @override
  Future<Result<void>> removeSource(String sourceId) async {
    removeCalls.add(sourceId);
    await cancel(sourceId);
    _status.remove(sourceId);
    return await _sources.remove(sourceId);
  }

  @override
  Future<void> startUp() async {}
}

final class FakeSourceChecker implements SourceChecker {
  final checked = <SourceDraft>[];

  /// What [check] answers.
  Result<SourceCheck> result = Ok(activeAccount);

  /// Set by [hold]: [check] waits on it, holding the test "running".
  Completer<Result<SourceCheck>>? held;

  static final activeAccount = SourceCheck(
    where: 'line.northwind.test',
    responseTime: const Duration(milliseconds: 240),
    account: ProviderAccount(
      status: 'Active',
      expiresAt: DateTime.utc(2026, 11, 3, 12),
      activeConnections: 0,
      maxConnections: 2,
      allowedFormats: const ['ts', 'm3u8'],
      serverTimezone: 'Europe/London',
    ),
  );

  /// Call inside the test body: a future made in `setUp` completes in
  /// another zone, which a widget test's fake clock never runs.
  void hold() => held = Completer();

  void release([Result<SourceCheck>? answer]) {
    held!.complete(answer ?? result);
    held = null;
  }

  @override
  Future<Result<SourceCheck>> check(SourceDraft draft) {
    checked.add(draft);
    return held?.future ?? Future.value(result);
  }
}

/// Categories per kind, kept in memory; every write re-emits the list.
final class FakeCategoryRepository implements CategoryRepository {
  final lists = <CatalogueKind, CategoryList>{};
  final _changes = StreamController<void>.broadcast();
  final writes = <String>[];

  /// Makes every write fail with this.
  AppFailure? writeFailure;

  /// Holds [watch] before its first list, for the loading state.
  Completer<void>? gate;

  /// Makes [watch] fail with this.
  AppFailure? watchFailure;

  @override
  Stream<CategoryList> watch(String sourceId, CatalogueKind kind) async* {
    if (gate case final gate?) await gate.future;
    if (watchFailure case final failure?) throw failure;
    yield lists[kind] ?? const CategoryList(categories: []);
    yield* _changes.stream.map(
      (_) => lists[kind] ?? const CategoryList(categories: []),
    );
  }

  Future<Result<void>> _change(
    String what,
    bool Function(CategoryChoice c) where,
    bool hidden,
  ) async {
    writes.add(what);
    if (writeFailure case final failure?) return Err(failure);
    for (final entry in lists.entries.toList()) {
      lists[entry.key] = entry.value.copyWith(
        categories: [
          for (final c in entry.value.categories)
            if (where(c)) c.copyWith(isHidden: hidden) else c,
        ],
      );
    }
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setHidden(int id, {required bool hidden}) =>
      _change('setHidden $id $hidden', (c) => c.id == id, hidden);

  @override
  Future<Result<void>> setHiddenMany(
    Iterable<int> ids, {
    required bool hidden,
  }) {
    final set = ids.toSet();
    return _change(
      'setHiddenMany ${set.length} $hidden',
      (c) => set.contains(c.id),
      hidden,
    );
  }

  @override
  Future<Result<void>> setAllHidden(
    String sourceId,
    CatalogueKind kind, {
    required bool hidden,
  }) => _change('setAllHidden ${kind.name} $hidden', (_) => true, hidden);

  @override
  Future<Result<void>> rename(int id, String? name) async {
    writes.add('rename $id ${name ?? '<provider>'}');
    if (writeFailure case final failure?) return Err(failure);
    for (final entry in lists.entries.toList()) {
      lists[entry.key] = entry.value.copyWith(
        categories: [
          for (final c in entry.value.categories)
            if (c.id != id)
              c
            else if (name == null || name.trim().isEmpty)
              c.copyWith(name: c.providerName ?? c.name, providerName: null)
            else
              c.copyWith(
                name: name.trim(),
                providerName: c.providerName ?? c.name,
              ),
        ],
      );
    }
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> reorder(List<int> idsInOrder) async {
    writes.add('reorder ${idsInOrder.join(',')}');
    if (writeFailure case final failure?) return Err(failure);
    for (final entry in lists.entries.toList()) {
      final byId = {for (final c in entry.value.categories) c.id: c};
      if (!idsInOrder.every(byId.containsKey)) continue;
      lists[entry.key] = entry.value.copyWith(
        categories: [for (final id in idsInOrder) byId[id]!],
        customOrder: true,
      );
    }
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> resetOrder(String sourceId, CatalogueKind kind) async {
    writes.add('resetOrder ${kind.name}');
    if (writeFailure case final failure?) return Err(failure);
    final list = lists[kind];
    if (list != null) {
      lists[kind] = list.copyWith(
        categories: [...list.categories]..sort((a, b) => a.id.compareTo(b.id)),
        customOrder: false,
      );
    }
    _changes.add(null);
    return const Ok(null);
  }
}

/// A catalogue shaped like the canvas: UK and US clusters, a lone tag,
/// and untagged categories.
Map<CatalogueKind, CategoryList> sampleCategories() {
  var id = 0;
  CategoryChoice c(String name, int count, {bool hidden = false}) =>
      CategoryChoice(id: ++id, name: name, isHidden: hidden, itemCount: count);
  return {
    CatalogueKind.live: CategoryList(
      categories: [
        c('UK | Sports', 214),
        c('UK | News', 96),
        c('UK | Entertainment', 520),
        c('UK | Kids', 72, hidden: true),
        c('US | News', 300),
        c('US | Sports', 410),
        c('AR | MBC', 64, hidden: true),
        c('AR | Rotana', 30, hidden: true),
        c('Music', 41),
        c('Regional', 35),
      ],
      uncategorized: 12,
    ),
    CatalogueKind.movie: CategoryList(
      categories: [c('Action', 800), c('Drama', 650)],
    ),
    CatalogueKind.series: const CategoryList(categories: []),
  };
}

/// True when the keyboard focus is on the control [finder] finds: its
/// focus node wraps it (a button's label) or sits inside it (a text
/// field's editable text).
bool focusIsOn(WidgetTester tester, Finder finder) {
  final primary = FocusManager.instance.primaryFocus;
  // A scope with the focus is no control: its element is an ancestor of
  // everything in it, which would make any finder match.
  if (primary == null || primary is FocusScopeNode) return false;
  final focused = primary.context;
  if (focused == null) return false;
  final target = tester.element(finder);
  if (target == focused) return true;
  var found = false;
  target.visitAncestorElements((element) {
    found = element == focused;
    return !found;
  });
  if (found) return true;
  focused.visitAncestorElements((element) {
    found = element == target;
    return !found;
  });
  return found;
}
