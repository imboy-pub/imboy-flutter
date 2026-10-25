// Current SQLite migration coverage complements the retained historical matrix.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import 'sqlite_migration_matrix_test.dart'
    show Shape, prepareShape, upgradeViaSqfliteSemantics;

Future<Database> _open(String path) => databaseFactory.openDatabase(
  path,
  options: OpenDatabaseOptions(singleInstance: false),
);

Future<Map<String, Object?>> _schema(Database db) async {
  final schema = await SchemaContract.capture(db, version: 34);
  final tables = Map<String, Object?>.from(schema['tables']! as Map);
  tables.remove('_imboy_schema_meta');
  return tables;
}

Future<void> _expectCurrentSchema(Database db) async {
  final fresh = await openFixtureDatabaseAtVersion(version: 34);
  try {
    expect(await _schema(db), await _schema(fresh));
  } finally {
    await fresh.close();
  }
  expect(await db.rawQuery('PRAGMA user_version'), [
    {'user_version': 34},
  ]);
  expect(await db.rawQuery('PRAGMA integrity_check'), [
    {'integrity_check': 'ok'},
  ]);
  expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('imboy_v34_'));
  tearDown(() async => tmp.delete(recursive: true));

  for (final origin in [9, 16, 18, 25, 29, 30, 31, 32, 33]) {
    for (final shape in Shape.values) {
      test(
        'v$origin → v34 [${shape.name}] preserves values and current schema',
        () async {
          final path = '${tmp.path}/matrix.db';
          var db = await openFixtureDatabaseAtVersion(
            version: origin,
            path: path,
          );
          await prepareShape(db, shape);
          // Legacy collect rows must remain readable with zero-valued v34 metadata.
          await db.insert('user_collect', {
            'user_id': 990001,
            'kind_id': '990000000001',
            'info': '合成收藏🎉',
            'created_at': 1790000000123,
          });
          final messages = origin >= 10 ? await db.query('msg_c2c') : null;
          await db.close();
          final (ok, error) = await upgradeViaSqfliteSemantics(
            path,
            from: origin,
            to: 34,
          );
          expect(ok, isTrue, reason: error);
          db = await _open(path);
          try {
            await _expectCurrentSchema(db);
            if (messages != null) {
              final after = await db.query('msg_c2c');
              expect([
                for (final row in after)
                  {
                    for (final key in messages.firstOrNull?.keys ?? <String>[])
                      key: row[key],
                  },
              ], messages);
            }
            final row = (await db.query('user_collect')).single;
            expect(row['info'], '合成收藏🎉');
            expect(row['created_at'], 1790000000123);
            expect(row['generation'], 0);
            expect(row['key_version'], 0);
            expect(row['attach_file_hash256'], '');
            await expectLater(
              db.update('user_collect', {'generation': null}),
              throwsA(isA<DatabaseException>()),
            );
            final schemaHash = await SchemaFingerprint.compute(db);
            final replay = await MigrationService.to.migrate(
              db: db,
              fromVersion: 34,
              toVersion: 34,
            );
            expect(replay.success, isTrue, reason: replay.error);
            expect(await SchemaFingerprint.compute(db), schemaHash);
          } finally {
            await db.close();
          }
          db = await _open(path);
          try {
            await _expectCurrentSchema(db);
            expect((await db.query('user_collect')).single['info'], '合成收藏🎉');
          } finally {
            await db.close();
          }
        },
      );
    }
  }

  test(
    'v34 partial DDL failure rolls back, reopens and retries without data loss',
    () async {
      final path = '${tmp.path}/rollback.db';
      var db = await openFixtureDatabaseAtVersion(version: 32, path: path);
      await seedSyntheticRows(db, 32);
      await db.insert('user_collect', {
        'user_id': 990001,
        'kind_id': 'synthetic-rollback',
        'info': 'must survive',
      });
      // The v33 table is created before v34 encounters the unavailable collect table.
      await db.execute(
        'ALTER TABLE user_collect RENAME TO synthetic_v34_failure',
      );
      final schemaHash = await SchemaFingerprint.compute(db);
      final rows = await db.query('synthetic_v34_failure');
      final messages = await db.query('msg_c2c');
      await db.close();
      final (ok, error) = await upgradeViaSqfliteSemantics(
        path,
        from: 32,
        to: 34,
      );
      expect(ok, isFalse);
      expect(error, contains('no such table: user_collect'));
      db = await _open(path);
      try {
        expect(await db.rawQuery('PRAGMA user_version'), [
          {'user_version': 32},
        ]);
        expect(await SchemaFingerprint.compute(db), schemaHash);
        expect(await db.query('synthetic_v34_failure'), rows);
        expect(await db.query('msg_c2c'), messages);
        await db.execute(
          'ALTER TABLE synthetic_v34_failure RENAME TO user_collect',
        );
      } finally {
        await db.close();
      }
      final (retry, retryError) = await upgradeViaSqfliteSemantics(
        path,
        from: 32,
        to: 34,
      );
      expect(retry, isTrue, reason: retryError);
      db = await _open(path);
      try {
        await _expectCurrentSchema(db);
        expect((await db.query('user_collect')).single['info'], 'must survive');
        expect(await db.query('msg_c2c'), messages);
      } finally {
        await db.close();
      }
    },
  );

  for (final stage in ['confirmed', 'put_done']) {
    test(
      'v34 → v33 → v32 $stage upload checkpoints respect downgrade guard',
      () async {
        final path = '${tmp.path}/downgrade.db';
        var db = await openFixtureDatabaseAtVersion(version: 34, path: path);
        await db.insert('user_collect', {
          'user_id': 990001,
          'kind_id': 'synthetic-downgrade',
          'info': 'legacy row survives',
        });
        await db.insert('attachment_upload_task', {
          'id': 'synthetic-task',
          'user_id': '990001',
          'scope': 'c2c',
          'file_name': 'synthetic.bin',
          'mime': 'application/octet-stream',
          'plain_size': 1,
          'plain_sha256': 'synthetic-hash',
          'stage': stage,
          'created_at': 1,
          'updated_at': 1,
        });
        await db.close();
        Future<void> downgrade(int version) async {
          final opened = await databaseFactory.openDatabase(
            path,
            options: OpenDatabaseOptions(
              singleInstance: false,
              version: version,
              onDowngrade: (txn, from, to) async {
                final result = await MigrationService.to.migrate(
                  db: txn,
                  fromVersion: from,
                  toVersion: to,
                  isUpgrade: false,
                );
                if (!result.success) throw StateError(result.error!);
              },
            ),
          );
          await opened.close();
        }

        await downgrade(33);
        db = await _open(path);
        final collectRows = await db.query('user_collect');
        expect(collectRows.single['info'], 'legacy row survives');
        expect(collectRows.single.containsKey('generation'), isFalse);
        final before = await SchemaFingerprint.compute(db);
        final tasks = await db.query('attachment_upload_task');
        await db.close();
        if (stage == 'put_done') {
          await expectLater(downgrade(32), throwsStateError);
        } else {
          await downgrade(32);
        }
        db = await _open(path);
        try {
          expect(await db.query('user_collect'), collectRows);
          expect(await db.rawQuery('PRAGMA user_version'), [
            {'user_version': stage == 'put_done' ? 33 : 32},
          ]);
          if (stage == 'put_done') {
            expect(await SchemaFingerprint.compute(db), before);
            expect(await db.query('attachment_upload_task'), tasks);
          } else {
            expect(
              await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE name = 'attachment_upload_task'",
              ),
              isEmpty,
            );
          }
        } finally {
          await db.close();
        }
      },
    );
  }
}
