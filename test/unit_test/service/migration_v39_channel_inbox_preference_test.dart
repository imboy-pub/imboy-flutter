import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _FailVersionAdvance implements DatabaseExecutor {
  _FailVersionAdvance(this.inner);
  final DatabaseExecutor inner;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('PRAGMA user_version = 39')) {
      throw StateError('injected failure');
    }
    return inner.execute(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _migrate(
  Database db,
  int from,
  int to, {
  bool fail = false,
}) async {
  await db.transaction((txn) async {
    final result = await MigrationService.to.migrate(
      db: fail ? _FailVersionAdvance(txn) : txn,
      fromVersion: from,
      toVersion: to,
      isUpgrade: to > from,
    );
    if (!result.success) throw StateError(result.error!);
  });
}

Future<List<Map<String, Object?>>> _existingSchema(Database db) => db.rawQuery(
  "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' AND name != 'channel_inbox_preference' ORDER BY type, name",
);
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });
  test(
    'v37 ↔ v39 changes only local preferences; v38 FTS stays unregistered',
    () async {
      final db = await openFixtureDatabaseAtVersion(version: 37);
      addTearDown(db.close);
      final schemaBefore = await _existingSchema(db);
      await db.insert('channel', {
        'id': 71,
        'name': 'fixture',
        'creator_id': 1,
        'created_at': 1,
        'updated_at': 1,
        'scope': 'personal',
      });
      await db.insert('channel_subscription', {
        'channel_id': 71,
        'subscribed_at': 1,
        'unread_count': 6,
        'is_muted': 1,
        'is_pinned': 1,
      });
      final channelBefore = await db.query('channel');
      final subscriptionBefore = await db.query('channel_subscription');
      await _migrate(db, 37, 39);
      expect(await db.getVersion(), 39);
      expect(await SchemaContract.verifyInvariants(db, version: 39), isEmpty);
      expect(await db.query('channel'), channelBefore);
      expect(await db.query('channel_subscription'), subscriptionBefore);
      expect(await db.query('channel_inbox_preference'), isEmpty);
      expect(
        await _existingSchema(db),
        schemaBefore,
        reason: 'No existing table, trigger, view or FTS definition changes',
      );
      expect(kMigrationManifest.upgradesByTo.containsKey(38), isFalse);
      expect(kMigrationManifest.upgradesByTo[39]!.fromVersion, 37);
      expect(MigrationScriptPlanner.allowedVersionGaps, {15, 38});
      final repeat = await MigrationService.to.migrate(
        db: db,
        fromVersion: 39,
        toVersion: 39,
      );
      expect(repeat.success, isTrue);
      await db.insert('channel_inbox_preference', {
        'endpoint': 'https://one.invalid',
        'channel_id': '71',
        'scope': 'personal',
      });
      await _migrate(db, 39, 37);
      expect(await db.getVersion(), 37);
      expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
      expect(await _existingSchema(db), schemaBefore);
      expect(await db.query('channel'), channelBefore);
      expect(await db.query('channel_subscription'), subscriptionBefore);
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'channel_inbox_preference'",
        ),
        isEmpty,
      );
    },
  );
  test('v39 failure rolls back table and version; retry succeeds', () async {
    final db = await openFixtureDatabaseAtVersion(version: 37);
    addTearDown(db.close);
    await expectLater(_migrate(db, 37, 39, fail: true), throwsStateError);
    expect(await db.getVersion(), 37);
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'channel_inbox_preference'",
      ),
      isEmpty,
    );
    await _migrate(db, 37, 39);
    expect(await SchemaContract.verifyInvariants(db, version: 39), isEmpty);
  });
  test('preferences require personal scope and preserve full text ids per endpoint', () async {
    final db = await openFixtureDatabaseAtVersion(version: 39);
    addTearDown(db.close);
    const id = '184467440737095516160001';
    for (final endpoint in ['https://one.invalid', 'https://two.invalid']) {
      await db.insert('channel_inbox_preference', {
        'endpoint': endpoint,
        'channel_id': id,
        'scope': 'personal',
      });
    }
    expect(
      (await db.query('channel_inbox_preference'))
          .map((row) => row['channel_id']),
      [id, id],
    );
    await expectLater(
      db.insert('channel_inbox_preference', {
        'endpoint': 'https://one.invalid',
        'channel_id': id,
        'scope': 'personal',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('channel_inbox_preference', {
        'endpoint': 'https://one.invalid',
        'channel_id': '2',
        'scope': 'workspace',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await db.delete(
      'channel_inbox_preference',
      where: 'endpoint = ?',
      whereArgs: ['https://one.invalid'],
    );
    expect(
      (await db.query('channel_inbox_preference')).single['endpoint'],
      'https://two.invalid',
    );
  });
  test('production planner rejects draft v38 as source or target', () {
    for (final route in [(37, 38), (39, 38), (38, 39), (38, 38)]) {
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: {},
          fromVersion: route.$1,
          toVersion: route.$2,
        ),
        throwsStateError,
      );
    }
  });
}
