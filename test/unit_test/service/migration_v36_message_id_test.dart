import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _tables = ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c'];
const _ids = [
  '00123',
  '123',
  'opaque-alpha',
  'opaque-beta',
  '184467440737095516160001',
  '550e8400-e29b-41d4-a716-446655440000',
  'd1s0sm3j1dds73b7acog',
];

// INTEGER affinity has already damaged numeric TEXT in some old databases.
// BLOB seeds represent original bytes still retained; lost bytes are not recoverable.
Uint8List _retained(String id) => Uint8List.fromList(utf8.encode(id));

Future<void> _migrate(Database db, int from, int to) async {
  await db.transaction((txn) async {
    final result = await MigrationService.to.migrate(
      db: txn,
      fromVersion: from,
      toVersion: to,
      isUpgrade: to > from,
    );
    if (!result.success) throw StateError(result.error!);
  });
}

Future<List<Map<String, Object?>>> _schema(Database db) =>
    db.rawQuery("SELECT name, sql FROM sqlite_master ORDER BY name");

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });

  test('v36 irreversible manifest edge has no downgrade edge', () {
    expect(kMigrationManifest.latestVersion, 36);
    expect(kMigrationManifest.edge(35, 36)!.reversible, isFalse);
    expect(kMigrationManifest.edge(36, 35), isNull);
  });

  for (final start in [9, 16, 35]) {
    test(
      'real service transaction v$start→36 preserves opaque IDs and references',
      () async {
        final db = await openFixtureDatabaseAtVersion(version: start);
        addTearDown(db.close);
        for (var t = 0; t < _tables.length; t++) {
          final table = start == 9
              ? ['message', 'group_message', 'c2s_message', 's2c_message'][t]
              : _tables[t];
          for (var i = 0; i < _ids.length; i++) {
            await db.insert(table, {
              'auto_id': i + 10,
              'id': _retained(_ids[i]),
              'from_id': 1,
              'to_id': 2,
              'payload': '{"text":"payload-$i"}',
              'status': 1,
              'is_author': 0,
              'created_at': 1000 + i,
              'conversation_uk3': 'conversation',
              'topic_id': 0,
              if (start == 35) 'conv_seq': i + 1,
              if (start == 35) 'accepted_at': 2000 + i,
            });
          }
        }
        for (var i = 0; i < _ids.length; i++) {
          await db.insert('conversation', {
            'id': i + 1,
            'type': 'C2C',
            'user_id': 1,
            'peer_id': i + 10,
            'last_msg_id': start == 9 ? _ids[i] : _retained(_ids[i]),
          });
          await db.insert('user_collect', {
            'auto_id': i + 1,
            'user_id': 1,
            'kind': 1,
            'kind_id': start == 9 ? _ids[i] : _retained(_ids[i]),
          });
        }
        await db.insert('conversation', {'id': 100, 'last_msg_id': null});
        await db.insert('conversation', {'id': 200, 'last_msg_id': null});
        await db.delete('conversation', where: 'id = 200');
        final ftsBefore = await db.rawQuery(
          "SELECT name, sql FROM sqlite_master WHERE name LIKE '%_fts%' ORDER BY name",
        );
        await _migrate(db, start, 36);
        expect(await db.getVersion(), 36);
        expect(await SchemaContract.verifyInvariants(db, version: 36), isEmpty);
        for (final table in _tables) {
          final rows = await db.rawQuery(
            'SELECT * FROM $table ORDER BY auto_id',
          );
          expect(rows.map((r) => r['id']), _ids);
          for (var i = 0; i < rows.length; i++) {
            expect(rows[i]['auto_id'], i + 10);
            expect(rows[i]['payload'], '{"text":"payload-$i"}');
            if (start == 35) {
              expect(rows[i]['conv_seq'], i + 1);
              expect(rows[i]['accepted_at'], 2000 + i);
            }
          }
          expect(
            await db.rawQuery('SELECT DISTINCT typeof(id) AS t FROM $table'),
            [
              {'t': 'text'},
            ],
          );
          await expectLater(
            db.insert(table, {'id': _ids.first}),
            throwsA(anything),
          );
        }
        final conv = await db.rawQuery(
          'SELECT last_msg_id FROM conversation ORDER BY id',
        );
        expect(conv.map((r) => r['last_msg_id']), [..._ids, null]);
        // Historical v16 rebuild already resets deleted-row watermarks.
        expect(
          await db.insert('conversation', {'last_msg_id': null}),
          start == 9 ? 101 : 201,
        );
        final collects = await db.rawQuery(
          'SELECT CAST(kind_id AS TEXT) AS id FROM user_collect ORDER BY auto_id',
        );
        expect(collects.map((r) => r['id']), _ids);
        if (start != 9) {
          expect(
            await db.rawQuery(
              "SELECT name, sql FROM sqlite_master WHERE name LIKE '%_fts%' ORDER BY name",
            ),
            ftsBefore,
          );
        }
      },
    );
  }

  for (final start in [9, 16, 35]) {
    test(
      'v$start zero empty pointers differ from retained zero message IDs',
      () async {
        final db = await openFixtureDatabaseAtVersion(version: start);
        addTearDown(db.close);
        if (start == 9) {
          // Legacy SQLite values may retain different storage classes; no affinity
          // lets this fixture seed numeric zero separately from original TEXT/BLOB.
          await db.execute('ALTER TABLE conversation DROP COLUMN last_msg_id');
          await db.execute(
            'ALTER TABLE conversation ADD COLUMN last_msg_id BLOB',
          );
        }
        final values = <Object?>[
          0,
          _retained('0'),
          '',
          null,
          _retained('00123'),
        ];
        for (var i = 0; i < values.length; i++) {
          await db.insert('conversation', {
            'id': i + 1,
            'last_msg_id': values[i],
          });
        }
        expect(
          (await db.rawQuery(
            'SELECT typeof(last_msg_id) AS t FROM conversation ORDER BY id',
          )).map((row) => row['t']),
          ['integer', 'blob', 'text', 'null', 'blob'],
        );
        final messageTables = start == 9
            ? ['message', 'group_message', 'c2s_message', 's2c_message']
            : _tables;
        for (final table in messageTables) {
          await db.insert(table, {
            'id': 0,
            'from_id': 1,
            'to_id': 2,
            'payload': '{}',
            'created_at': 1000,
            'conversation_uk3': 'synthetic',
          });
        }
        await _migrate(db, start, 36);
        expect(
          (await db.query(
            'conversation',
            orderBy: 'id',
          )).map((row) => row['last_msg_id']),
          ['', '0', '', null, '00123'],
        );
        for (final table in _tables) {
          expect((await db.query(table)).single['id'], '0');
        }
        await db.insert('conversation', {'id': 100, 'last_msg_id': '0'});
        expect(
          (await db.query(
            'conversation',
            where: 'id = 100',
          )).single['last_msg_id'],
          '0',
        );
      },
    );
  }

  test(
    'new baseline install reaches v36 with distinct leading-zero strings',
    () async {
      final db = await openFixtureDatabaseAtVersion(version: 16);
      addTearDown(db.close);
      await _migrate(db, 16, 36);
      for (final table in _tables) {
        for (final id in _ids) {
          await db.insert(table, {'id': id});
        }
        expect(
          (await db.query(table)).map((row) => row['id']).toSet(),
          _ids.toSet(),
        );
      }
    },
  );

  test(
    'failed v35→36 rolls back all schema, rows and version changes',
    () async {
      final db = await openFixtureDatabaseAtVersion(version: 35);
      addTearDown(db.close);
      await db.insert('msg_c2c', {'id': 'opaque-alpha', 'payload': 'keep'});
      await db.execute('ALTER TABLE msg_c2g DROP COLUMN action');
      final schema = await _schema(db);
      final rows = await db.query('msg_c2c');
      await expectLater(_migrate(db, 35, 36), throwsStateError);
      expect(await _schema(db), schema);
      expect(await db.query('msg_c2c'), rows);
      expect(await db.getVersion(), 35);
    },
  );

  test(
    'v36 downgrade rejected without changing schema, rows or version',
    () async {
      final db = await openFixtureDatabaseAtVersion(version: 35);
      addTearDown(db.close);
      await _migrate(db, 35, 36);
      await db.insert('msg_c2c', {'id': '00123', 'payload': 'keep'});
      final schema = await _schema(db);
      final rows = await db.query('msg_c2c');
      for (final target in [35, 16, 9]) {
        await expectLater(_migrate(db, 36, target), throwsStateError);
        expect(await _schema(db), schema);
        expect(await db.query('msg_c2c'), rows);
        expect(await db.getVersion(), 36);
      }
    },
  );

  test(
    'planner bridge is scoped, complete and fails closed on statement drift',
    () {
      final original = MigrationService.to.debugUpgradeScripts;
      final to35 = MigrationScriptPlanner.plan(
        scripts: original,
        fromVersion: 9,
        toVersion: 35,
      );
      expect(
        to35.firstWhere((s) => s.version == 16).sqlStatements,
        original[16]!.sqlStatements,
      );
      final to36 = MigrationScriptPlanner.plan(
        scripts: original,
        fromVersion: 9,
        toVersion: 36,
      );
      expect(
        to36
                .firstWhere((s) => s.version == 16)
                .fullSql
                .split(' AS BLOB)')
                .length -
            1,
        6,
      );
      final old = original[16]!;
      final statements = [...old.sqlStatements];
      final position = statements.indexWhere(
        (sql) => sql.startsWith('INSERT INTO msg_c2c_new SELECT'),
      );
      statements[position] = statements[position].replaceFirst(
        'CAST(id AS INTEGER)',
        'id',
      );
      final drift = {
        ...original,
        16: MigrationScript(
          version: 16,
          targetVersion: 16,
          description: old.description,
          sqlStatements: statements,
        ),
      };
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: drift,
          fromVersion: 9,
          toVersion: 36,
        ),
        throwsStateError,
      );
      statements[position] = old.sqlStatements[position];
      statements.add(old.sqlStatements[position]);
      expect(
        () => MigrationScriptPlanner.plan(
          scripts: drift,
          fromVersion: 9,
          toVersion: 36,
        ),
        throwsStateError,
      );
    },
  );
}
