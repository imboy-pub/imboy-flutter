// Shared checkpoint for the native kill replay and its host rollback contract.
// Call only with the caller's live transaction; this helper never commits it.
import 'package:imboy/service/migration_service.dart';
import 'package:sqflite_common/sqlite_api.dart';

Future<MigrationResult> migrateKillReplayWithCheckpoint(
  Transaction txn, {
  required Future<void> Function(Transaction) onCheckpoint,
}) async {
  final beforeVersion = await txn.rawQuery('PRAGMA user_version');
  final beforeColumns = await txn.rawQuery('PRAGMA table_info(conversation)');
  if (beforeVersion.single['user_version'] != 16 ||
      beforeColumns.any((column) => column['name'] == 'mention_unread')) {
    throw StateError('Kill replay requires the unchanged v16 starting schema');
  }

  final started = await MigrationService.to.migrate(
    db: txn,
    fromVersion: 16,
    toVersion: 17,
  );
  if (!started.success) throw StateError(started.error!);

  final checkpointVersion = await txn.rawQuery('PRAGMA user_version');
  final columns = await txn.rawQuery('PRAGMA table_info(conversation)');
  if (checkpointVersion.single['user_version'] != 17 ||
      !columns.any(
        (column) =>
            column['name'] == 'mention_unread' &&
            column['type'] == 'INTEGER' &&
            column['notnull'] == 1,
      )) {
    throw StateError('Kill replay did not reach the v17 mutation checkpoint');
  }

  // v17 has changed this transaction, but the caller has not committed.
  // The native callback emits readiness and waits for a bounded interval.
  await onCheckpoint(txn);

  final completed = await MigrationService.to.migrate(
    db: txn,
    fromVersion: 17,
    toVersion: 31,
  );
  if (!completed.success) throw StateError(completed.error!);
  return MigrationResult.success(fromVersion: 16, toVersion: 31);
}
