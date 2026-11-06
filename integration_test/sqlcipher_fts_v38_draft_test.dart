// Native database admission for the unregistered v38 draft. This does not
// exercise a retained-data installation or activate v38 in the application.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/database_migration_orchestrator.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show Database, DatabaseException, DatabaseExecutor, openDatabase;

Future<void> _verifySchema(DatabaseExecutor db, int version) async {
  final result = await DatabaseMigrationOrchestrator.to.verifyAfterMigration(
    db,
    toVersion: version,
    migrationId: 'native_fts_draft_v$version',
  );
  expect(result.ok, isTrue, reason: result.violations.join('; '));
  expect(
    (await db.rawQuery('PRAGMA user_version')).single.values.single,
    version,
  );
  expect(
    (await db.rawQuery('PRAGMA application_id')).single.values.single,
    kImboyApplicationId,
  );
  final meta = await ImboySchemaMeta.readAll(db);
  expect(meta[ImboySchemaMeta.keySchemaVersion], '$version');
  expect(meta[ImboySchemaMeta.keyMigrationState], 'ok');
}

Future<void> _createV37Fixture(Database db) async {
  await db.transaction((txn) async {
    // Same baseline source and error policy as SqliteService._onCreate.
    // Native driver incompatibilities must fail instead of using a mini schema.
    for (final sql
        in kBaselineSchemaSql
            .split(';')
            .map((sql) => sql.trim())
            .where((sql) => sql.isNotEmpty && !sql.startsWith('--'))) {
      if (sql.toLowerCase().contains('sqlite_')) continue;
      try {
        await txn.execute(sql);
      } catch (error) {
        if (!error.toString().toLowerCase().contains('already exists')) rethrow;
      }
    }
    await txn.execute('PRAGMA user_version = 16');
    final migration = await MigrationService.to.migrate(
      db: txn,
      fromVersion: 16,
      toVersion: 37,
    );
    expect(migration.success, isTrue, reason: migration.error);
    await _verifySchema(txn, 37);
  });
}

Future<void> _applyDraft(Database db) async {
  await db.transaction((txn) async {
    for (final sql in upgradeV38Fts.sqlStatements) {
      await txn.execute(sql);
    }
    await _verifySchema(txn, 38);
  });
}

Future<void> _expectRows(
  DatabaseExecutor db,
  Map<String, List<Map<String, Object?>>> expected,
) async {
  for (final entry in expected.entries) {
    expect(await db.query(entry.key), entry.value, reason: entry.key);
  }
}

Future<void> _expectEncryptedFile(String databasePath) async {
  final header = await File(databasePath)
      .openRead(0, 16)
      .expand((bytes) => bytes)
      .toList();
  expect(String.fromCharCodes(header), isNot(startsWith('SQLite format 3')));
  Database? wrongKey;
  try {
    await expectLater(() async {
      wrongKey = await openDatabase(
        databasePath,
        password: 'synthetic-wrong-password',
        singleInstance: false,
      );
      await wrongKey!.rawQuery('SELECT name FROM sqlite_master');
    }(), throwsA(isA<DatabaseException>()));
  } finally {
    // A cleanup error must fail the case, never satisfy key rejection.
    await wrongKey?.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher v37 to v38 draft preserves data and rolls back failure', (
    tester,
  ) async {
    expect(isEncryptionSupported, isTrue);
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = await temporaryDirectory.createTemp('imboy_fts_v38_');
    final databasePath = path.join(directory.path, 'synthetic.db');
    const password = 'synthetic-test-password';
    var db = await openEncryptedDatabase(
      databasePath,
      password: password,
      onConfigure: SqliteService.configureConnection,
    );
    try {
      final cipher = await db.rawQuery('PRAGMA cipher_version');
      expect(cipher, isNotEmpty);
      await _createV37Fixture(db);
      for (final table in ['msg_c2c', 'msg_c2g']) {
        final rowid = await db.insert(table, {
          'id': 'synthetic-$table',
          'conversation_uk3': 'synthetic',
          'msg_type': 'text',
          'payload': '{"text":"ciphermigrationword"}',
          'status': 20,
          'from_id': 990001,
          'to_id': 990002,
          'created_at': 1700000000000,
          'accepted_at': 1700000001000,
          'conv_seq': 42,
        });
        // Rebuild must replace stale v37 index content, not retain it.
        await db.insert('${table}_fts', {
          'rowid': rowid,
          'id': 'synthetic-$table',
          'conversation_uk3': 'synthetic',
          'text_content': 'staleindexword',
        });
      }
      await db.insert('conversation', {
        'type': 'C2C',
        'user_id': 990001,
        'peer_id': 990002,
        'last_msg_id': 'synthetic-msg_c2c',
      });
      final beforeRows = {
        for (final table in ['msg_c2c', 'msg_c2g', 'conversation'])
          table: await db.query(table),
      };
      final beforeSchema = await SchemaFingerprint.compute(db);
      final beforeMeta = await ImboySchemaMeta.readAll(db);
      await db.close();
      await _expectEncryptedFile(databasePath);

      final preparation = await DatabaseMigrationOrchestrator.to.prepareForOpen(
        dbPath: databasePath,
        baseDir: directory.path,
        env: 'fts_draft_selftest',
        uid: 'synthetic',
        targetVersion: 38,
        password: password,
      );
      expect(preparation.proceed, isTrue, reason: preparation.abortReason);
      expect(preparation.migrationNeeded, isTrue);
      expect(preparation.currentVersion, 37);
      expect(preparation.snapshotPath, isNotNull);
      await _expectEncryptedFile(preparation.snapshotPath!);
      final snapshot = await openEncryptedDatabase(
        preparation.snapshotPath!,
        password: password,
        onConfigure: SqliteService.configureConnection,
      );
      try {
        expect(
          (await snapshot.rawQuery('PRAGMA user_version')).single.values.single,
          37,
        );
        await _expectRows(snapshot, beforeRows);
      } finally {
        await snapshot.close();
      }
      db = await openEncryptedDatabase(
        databasePath,
        password: password,
        onConfigure: SqliteService.configureConnection,
      );
      var failureInjected = false;
      await expectLater(
        db.transaction((txn) async {
          for (final sql in upgradeV38Fts.sqlStatements) {
            await txn.execute(sql);
          }
          await _verifySchema(txn, 38);
          expect(
            await txn.update(
              'msg_c2c',
              {'payload': '{"text":"uncommittedword"}'},
              where: 'id = ?',
              whereArgs: ['synthetic-msg_c2c'],
            ),
            1,
          );
          // Fail after DDL, user_version, meta and a data write have changed.
          failureInjected = true;
          await txn.execute('INSERT INTO synthetic_missing_table VALUES (1)');
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(failureInjected, isTrue);
      expect(
        (await db.rawQuery('PRAGMA user_version')).single.values.single,
        37,
      );
      expect(await SchemaFingerprint.compute(db), beforeSchema);
      expect(await ImboySchemaMeta.readAll(db), beforeMeta);
      await _expectRows(db, beforeRows);
      await db.close();
      db = await openEncryptedDatabase(
        databasePath,
        password: password,
        onConfigure: SqliteService.configureConnection,
      );
      expect(
        (await db.rawQuery('PRAGMA user_version')).single.values.single,
        37,
      );
      expect(await SchemaFingerprint.compute(db), beforeSchema);
      expect(await ImboySchemaMeta.readAll(db), beforeMeta);
      await _expectRows(db, beforeRows);
      for (final table in ['msg_c2c', 'msg_c2g']) {
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['staleindexword'],
          ),
          hasLength(1),
        );
      }

      // Explicit draft only: this never adds an edge to the production manifest.
      await _applyDraft(db);
      await _expectRows(db, beforeRows);
      for (final table in ['msg_c2c', 'msg_c2g']) {
        final rows = await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['ciphermigrationword'],
        );
        expect(rows.single['id'], 'synthetic-$table');
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['staleindexword'],
          ),
          isEmpty,
        );
        await db.update(
          table,
          {'status': 30},
          where: 'id = ?',
          whereArgs: ['synthetic-$table'],
        );
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['ciphermigrationword'],
          ),
          isEmpty,
        );
      }
      final version = await db.rawQuery(
        'SELECT user_version FROM pragma_user_version',
      );
      expect(version.single['user_version'], 38);
      final afterDraftRows = {
        for (final table in beforeRows.keys) table: await db.query(table),
      };
      await db.close();
      db = await openEncryptedDatabase(
        databasePath,
        password: password,
        onConfigure: SqliteService.configureConnection,
      );
      expect(await SchemaContract.verifyInvariants(db, version: 38), isEmpty);
      final meta = await ImboySchemaMeta.readAll(db);
      expect(meta[ImboySchemaMeta.keySchemaVersion], '38');
      expect(meta[ImboySchemaMeta.keyMigrationState], 'ok');
      await _expectRows(db, afterDraftRows);
      final recursive = await db.rawQuery('PRAGMA recursive_triggers');
      expect(recursive.single.values.single, 1);
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.rawInsert(
          'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
          ['synthetic-$table', 'text', '{"text":"replaceword"}', 20],
        );
        await db.rawInsert(
          'INSERT INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET payload = excluded.payload',
          ['synthetic-$table', 'text', '{"text":"upsertword"}', 20],
        );
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['replaceword'],
          ),
          isEmpty,
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['upsertword'],
          ),
          hasLength(1),
        );
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
      await db.execute('PRAGMA recursive_triggers = OFF');
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.insert(table, {
          'id': 'other-$table',
          'msg_type': 'text',
          'payload': '{"text":"otherword"}',
          'status': 20,
        });
        await expectLater(
          db.rawInsert(
            'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
            ['synthetic-$table', 'text', '{"text":"rejectedword"}', 20],
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.rawUpdate('UPDATE OR REPLACE $table SET id = ? WHERE id = ?', [
            'other-$table',
            'synthetic-$table',
          ]),
          throwsA(isA<Exception>()),
        );
        expect(await db.query(table), hasLength(2));
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['upsertword'],
          ),
          hasLength(1),
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['rejectedword'],
          ),
          isEmpty,
        );
        expect(
          await db.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['otherword'],
          ),
          hasLength(1),
        );
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  testWidgets('v38 guards independently configured WAL connections', (
    tester,
  ) async {
    expect(isEncryptionSupported, isTrue);
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = await temporaryDirectory.createTemp('imboy_fts_v38_wal_');
    final databasePath = path.join(directory.path, 'synthetic.db');
    const password = 'synthetic-test-password';
    final configured = await openDatabase(
      databasePath,
      password: password,
      singleInstance: false,
      onConfigure: (database) async {
        await SqliteService.configureConnection(database);
        await database.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
    Database? unconfigured;
    try {
      await _createV37Fixture(configured);
      await _applyDraft(configured);
      unconfigured = await openDatabase(
        databasePath,
        password: password,
        singleInstance: false,
        onConfigure: (database) async {
          await database.execute('PRAGMA recursive_triggers = OFF');
        },
      );
      expect(
        (await configured.rawQuery('PRAGMA journal_mode')).single.values.single,
        'wal',
      );
      expect(
        (await configured.rawQuery('PRAGMA recursive_triggers'))
            .single
            .values
            .single,
        1,
      );
      expect(
        (await unconfigured.rawQuery('PRAGMA recursive_triggers'))
            .single
            .values
            .single,
        0,
      );
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await configured.insert(table, {
          'id': 'synthetic-$table',
          'msg_type': 'text',
          'payload': '{"text":"originalword"}',
          'status': 20,
        });
        await expectLater(
          unconfigured.rawInsert(
            'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
            ['synthetic-$table', 'text', '{"text":"rejectedword"}', 20],
          ),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                'message FTS requires recursive triggers for conflicting inserts',
              ),
            ),
          ),
        );
        expect(
          await configured.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['originalword'],
          ),
          hasLength(1),
        );
        await configured.rawInsert(
          'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
          ['synthetic-$table', 'text', '{"text":"replacementword"}', 20],
        );
        expect(
          await unconfigured.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['originalword'],
          ),
          isEmpty,
        );
        expect(
          await unconfigured.rawQuery(
            'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['replacementword'],
          ),
          hasLength(1),
        );
        await configured.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await unconfigured?.close();
      await configured.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
