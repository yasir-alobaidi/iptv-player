// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_dao.dart';

// ignore_for_file: type=lint
mixin _$RemindersDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $RemindersTable get reminders => attachedDatabase.reminders;
  RemindersDaoManager get managers => RemindersDaoManager(this);
}

class RemindersDaoManager {
  final _$RemindersDaoMixin _db;
  RemindersDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
}
