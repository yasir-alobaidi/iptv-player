import 'package:drift/drift.dart';

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

/// A configured provider.
///
/// There are no credential columns here on purpose (hard rule 3): the
/// password lives in flutter_secure_storage under [Sources.credentialRef],
/// and only that key is ever written to the database.
@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();

  TextColumn get type => textEnum<SourceType>()();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// The Xtream server base URL, the playlist URL, or the local file path,
  /// depending on [type].
  TextColumn get url => text()();

  /// Xtream only. Not a secret, but it never reaches a log unredacted.
  TextColumn get username => text().nullable()();

  /// The flutter_secure_storage key holding this source's password.
  TextColumn get credentialRef => text().nullable()();

  /// Overrides the XMLTV URL the provider advertises.
  TextColumn get epgUrl => text().nullable()();

  TextColumn get userAgent => text().nullable()();

  TextColumn get liveFormat =>
      textEnum<LiveFormat>().withDefault(const Constant('ts'))();

  /// Added to every EPG time, for providers that publish the wrong zone.
  IntColumn get epgOffsetMinutes => integer().withDefault(const Constant(0))();

  /// How old the data may get before a sync runs on launch.
  IntColumn get refreshHours => integer().withDefault(const Constant(12))();

  /// Set only when the user knows better than the provider's
  /// `max_connections` (hard rule 7).
  IntColumn get maxConnectionsOverride => integer().nullable()();

  /// The provider's raw account payload, kept for the Settings screen.
  TextColumn get accountJson => text().nullable()();

  DateTimeColumn get expiresAt => dateTime().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small app-wide values, one JSON document per key. Anything that grows
/// rows instead of values gets its own table.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  /// Always valid JSON, so a reader can decode without guessing. Readers
  /// still treat a bad value as missing (hard rule 1).
  TextColumn get valueJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
