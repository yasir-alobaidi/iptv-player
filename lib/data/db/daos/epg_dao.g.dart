// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_dao.dart';

// ignore_for_file: type=lint
mixin _$EpgDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $EpgImportsTable get epgImports => attachedDatabase.epgImports;
  $EpgChannelsTable get epgChannels => attachedDatabase.epgChannels;
  $EpgProgramsTable get epgPrograms => attachedDatabase.epgPrograms;
  $EpgChannelsStagingTable get epgChannelsStaging =>
      attachedDatabase.epgChannelsStaging;
  $EpgProgramsStagingTable get epgProgramsStaging =>
      attachedDatabase.epgProgramsStaging;
  $EpgMappingsTable get epgMappings => attachedDatabase.epgMappings;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ChannelsTable get channels => attachedDatabase.channels;
  $EpgMatchesTable get epgMatches => attachedDatabase.epgMatches;
  EpgDaoManager get managers => EpgDaoManager(this);
}

class EpgDaoManager {
  final _$EpgDaoMixin _db;
  EpgDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$EpgImportsTableTableManager get epgImports =>
      $$EpgImportsTableTableManager(_db.attachedDatabase, _db.epgImports);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db.attachedDatabase, _db.epgChannels);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db.attachedDatabase, _db.epgPrograms);
  $$EpgChannelsStagingTableTableManager get epgChannelsStaging =>
      $$EpgChannelsStagingTableTableManager(
        _db.attachedDatabase,
        _db.epgChannelsStaging,
      );
  $$EpgProgramsStagingTableTableManager get epgProgramsStaging =>
      $$EpgProgramsStagingTableTableManager(
        _db.attachedDatabase,
        _db.epgProgramsStaging,
      );
  $$EpgMappingsTableTableManager get epgMappings =>
      $$EpgMappingsTableTableManager(_db.attachedDatabase, _db.epgMappings);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
  $$EpgMatchesTableTableManager get epgMatches =>
      $$EpgMatchesTableTableManager(_db.attachedDatabase, _db.epgMatches);
}
