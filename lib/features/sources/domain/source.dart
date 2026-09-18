import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';

part 'source.freezed.dart';

/// Where a source gets its channel list.
enum SourceType {
  /// Xtream Codes `player_api.php`.
  xtream,

  /// An M3U playlist fetched over HTTP.
  m3uUrl,

  /// An M3U playlist read from a local file.
  m3uFile,
}

/// The container a provider serves live streams in. Xtream offers both;
/// `ts` is the default because it starts faster and zaps better (docs/03).
enum LiveFormat { ts, hls }

/// A configured provider, as the app shows it. Holds no secrets: every
/// URL here is safe to display and log. The real values come from
/// [SourceRepository.credentialsFor] when a sync or a stream needs them.
@freezed
abstract class Source with _$Source {
  const factory({
    required String id,
    required SourceType type,
    required String name,

    /// The Xtream server, the playlist URL's origin (`http://host/…`), or
    /// the local file path, depending on [type].
    required String displayUrl,
    required LiveFormat liveFormat,
    required int epgOffsetMinutes,
    required int refreshHours,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? username,

    /// The EPG URL override's origin, like [displayUrl].
    String? epgUrlDisplay,
    String? userAgent,
    int? maxConnectionsOverride,
    DateTime? expiresAt,
    DateTime? lastSyncedAt,
  }) = _Source;
}

/// What the user typed when adding or editing a source. [password],
/// [url] and [epgUrl] can all carry credentials; the repository keeps them
/// out of the database.
@freezed
abstract class SourceDraft with _$SourceDraft {
  const factory({
    required SourceType type,
    required String name,

    /// The Xtream server, the playlist URL, or the local file path.
    required String url,
    String? username,
    String? password,
    String? epgUrl,
    String? userAgent,
    @Default(LiveFormat.ts) LiveFormat liveFormat,
    @Default(0) int epgOffsetMinutes,
    @Default(12) int refreshHours,
    int? maxConnectionsOverride,
  }) = _SourceDraft;
}

/// The real, unmasked values a sync or a stream needs. Never logged, never
/// stored in the database, never kept longer than the work that needs it.
///
/// Hand-written rather than freezed: a generated `toString()` would print
/// the password, and this one prints only what is safe.
@immutable
final class SourceCredentials {
  const new({
    required this.url,
    this.username,
    this.password,
    this.epgUrl,
    this.advertisedEpgUrls = const [],
  });

  /// The Xtream server, playlist URL, or file path, unmasked.
  final String url;
  final String? username;
  final String? password;

  /// The user's EPG override.
  final String? epgUrl;

  /// The EPG URLs the playlist's own header names (`url-tvg`), as the
  /// last sync found them.
  final List<String> advertisedEpgUrls;

  @override
  bool operator ==(Object other) =>
      other is SourceCredentials &&
      other.url == url &&
      other.username == username &&
      other.password == password &&
      other.epgUrl == epgUrl &&
      _sameList(other.advertisedEpgUrls, advertisedEpgUrls);

  @override
  int get hashCode => Object.hash(
    url,
    username,
    password,
    epgUrl,
    Object.hashAll(advertisedEpgUrls),
  );

  @override
  String toString() =>
      'SourceCredentials(${redact(url)}, '
      'password: ${password == null ? 'none' : redactionMask})';
}

/// The sources the user configured, and the secrets that go with them.
///
/// Nothing throws across this boundary. A draft that can't be saved comes
/// back as an [Err]; so does a system keyring that won't open, as a
/// [SecureStorageFailure] — credentials are never written anywhere else.
abstract interface class SourceRepository {
  /// In the user's order; the first is the default.
  Stream<List<Source>> watchAll();

  Future<Result<List<Source>>> all();

  Future<Result<Source?>> byId(String id);

  /// Stores the source at the end of the list and returns it.
  Future<Result<Source>> add(SourceDraft draft);

  /// Replaces everything the user can edit. A null [SourceDraft.password]
  /// keeps the stored one, so an edit form never has to show it.
  Future<Result<Source>> update(String id, SourceDraft draft);

  /// Removes the source, its catalogue and its secrets.
  Future<Result<void>> remove(String id);

  /// Stores [idsInOrder] as the user's order.
  Future<Result<void>> reorder(List<String> idsInOrder);

  Future<Result<SourceCredentials>> credentialsFor(String id);

  /// Keeps the EPG URLs an M3U playlist's header names with the source's
  /// other secrets: they usually carry the same credentials as the
  /// playlist URL. Writes to the keyring only when they changed.
  Future<Result<void>> setAdvertisedEpgUrls(String id, List<String> urls);

  /// Deletes stored secrets that no source refers to any more, left behind
  /// when a removal could not reach the keyring. Call it right after the
  /// keyring was used successfully (the sync engine does, once a session),
  /// never on its own at launch: listing a locked keyring asks the user to
  /// unlock it, and an app that prompts for a password on every start,
  /// with nothing to sync, is broken.
  Future<Result<int>> pruneOrphanedSecrets();
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
