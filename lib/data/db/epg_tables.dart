import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/tables.dart';

/// Which of the four rules in docs/02 attached a channel to a guide
/// channel. Kept so Settings → Guide can say how a match was made, and
/// so a weaker rule never overwrites a stronger one.
enum EpgMatchRule { exactId, caseInsensitiveId, normalizedName, manual }

/// One XMLTV import for one source. It plays the part `sync_runs` plays
/// for the catalogue — a marker the staged rows carry, and the record
/// Settings → Guide reads ("updated 2 hours ago", or why it failed) —
/// but it is a table of its own, because Settings → Sources watches
/// `sync_runs` and a guide import is not a catalogue sync.
@DataClassName('EpgImportRow')
class EpgImports extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// [SyncOutcome], the same four states a sync run has. An import still
  /// `running` at launch belongs to a process that is gone.
  TextColumn get outcome =>
      textEnum<SyncOutcome>().withDefault(const Constant('running'))();

  /// An `AppFailure.code`, never raw exception text (it can carry a
  /// credential-bearing URL).
  TextColumn get failure => text().nullable()();

  IntColumn get failureStatus => integer().nullable()();

  /// `EpgImportCounts` as JSON: what was read, and why rows were skipped.
  TextColumn get countsJson => text().nullable()();

  /// True for the one import per source whose rows are in the live
  /// tables. Set by the swap, cleared from the import it replaces.
  BoolColumn get isLive => boolean().withDefault(const Constant(false))();
}

/// The channels the guide declares (`<channel id>`), live. Not the
/// provider's channels: these are matched to those through [EpgMatches].
@DataClassName('EpgChannelRow')
class EpgChannels extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// The XMLTV id, as the file writes it.
  TextColumn get xmltvId => text()();

  TextColumn get displayName => text().nullable()();

  TextColumn get iconUrl => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, xmltvId},
  ];
}

/// Programmes, live. Times are epoch milliseconds UTC in their own
/// integer columns (docs/02): drift's `DateTime` columns are ISO-8601
/// text, which neither compares nor packs well over millions of rows.
///
/// [epgChannelId] is the XMLTV id the programme names, not a row id: a
/// programme can name a channel the file never declares (and real files
/// do), and the import must not have to resolve a parent to stage a row.
@DataClassName('EpgProgramRow')
@TableIndex(
  name: 'epg_programs_channel_start',
  columns: {#sourceId, #epgChannelId, #startUtc},
)
class EpgPrograms extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get epgChannelId => text()();

  IntColumn get startUtc => integer()();

  IntColumn get endUtc => integer()();

  TextColumn get title => text()();

  TextColumn get subtitle => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get category => text().nullable()();
}

/// Where an import writes while it runs (decision 2). The live guide is
/// untouched until the swap, so a killed import loses nothing but its own
/// work, and its rows go on the next launch.
///
/// Staged rows carry only the import they belong to, not the source: the
/// import knows the source, and a column saved is a column not written
/// several hundred thousand times.
@DataClassName('EpgChannelStagingRow')
class EpgChannelsStaging extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get importRun =>
      integer().references(EpgImports, #id, onDelete: KeyAction.cascade)();

  TextColumn get xmltvId => text()();

  TextColumn get displayName => text().nullable()();

  TextColumn get iconUrl => text().nullable()();

  /// A file that declares the same channel twice is a quirk we tolerate
  /// (docs/06): the first one staged wins, the rest are counted.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {importRun, xmltvId},
  ];
}

/// See [EpgChannelsStaging]. Indexed by the import alone: the swap reads
/// a whole run and then deletes it, and nothing else ever queries this.
@DataClassName('EpgProgramStagingRow')
@TableIndex(name: 'epg_programs_staging_run', columns: {#importRun})
class EpgProgramsStaging extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get importRun =>
      integer().references(EpgImports, #id, onDelete: KeyAction.cascade)();

  TextColumn get epgChannelId => text()();

  IntColumn get startUtc => integer()();

  IntColumn get endUtc => integer()();

  TextColumn get title => text()();

  TextColumn get subtitle => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get category => text().nullable()();
}

/// The user's own channel → guide-channel mapping (Settings → Guide).
/// Keyed by the provider's key rather than a row id, like every other
/// piece of user data, so a re-sync that renumbers rows keeps it; an
/// import never writes here, and the matcher only reads it.
@DataClassName('EpgMappingRow')
class EpgMappings extends Table {
  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get channelRemoteKey => text()();

  TextColumn get xmltvId => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, channelRemoteKey};
}

/// What the matcher resolved, one row per matched channel (Phase 4
/// step 4 fills it). Derived state, rewritten after an import and after
/// a sync — never the user's mapping, which lives in [EpgMappings] and
/// is only read from here.
///
/// It exists so the guide grid joins `channels → epg_matches →
/// epg_programs` on indexed columns instead of matching names per row.
@DataClassName('EpgMatchRow')
@TableIndex(name: 'epg_matches_source', columns: {#sourceId, #xmltvId})
class EpgMatches extends Table {
  IntColumn get channelId =>
      integer().references(Channels, #id, onDelete: KeyAction.cascade)();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get xmltvId => text()();

  TextColumn get rule => textEnum<EpgMatchRule>()();

  @override
  Set<Column<Object>> get primaryKey => {channelId};
}
