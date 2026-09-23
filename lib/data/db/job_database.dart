import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/data/db/app_database.dart';

/// The app's database, opened from a guarded background job
/// (`startGuardedJob`) over the connection the app handed it.
///
/// Every transaction the job begins — and a batch is one, opened and
/// committed by this side a request at a time — is marked on
/// [cancellation], so the job is never killed while one is open, and none
/// begins once the job has been asked to stop. Without it, a kill between
/// a batch's begin and its commit leaves the transaction open in the
/// database isolate, which never rolls back for a client that died, and
/// every query in the app waits behind it (ADR-011 step 3).
///
/// With no [cancellation] (the job's body run directly, as tests do) the
/// connection is used as it is.
Future<AppDatabase> openJobDatabase(
  DriftIsolate connection,
  JobCancellation? cancellation,
) async {
  final connected = await connection.connect();
  return AppDatabase(
    cancellation == null
        ? connected
        : connected.interceptWith(_TransactionGuard(cancellation)),
  );
}

final class _TransactionGuard extends QueryInterceptor {
  new(this._cancellation);

  final JobCancellation _cancellation;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    _cancellation.enter();
    try {
      return parent.beginTransaction();
    } on Object {
      _cancellation.leave();
      rethrow;
    }
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    try {
      await inner.send();
    } finally {
      _cancellation.leave();
    }
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    try {
      await inner.rollback();
    } finally {
      _cancellation.leave();
    }
  }
}
