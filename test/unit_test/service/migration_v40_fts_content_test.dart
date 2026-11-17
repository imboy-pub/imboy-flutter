import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/migrations/upgrade_edges_v40.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/schema_fingerprint.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _FailVersionAdvance implements DatabaseExecutor {
  _FailVersionAdvance(this.inner, this.version);
  final DatabaseExecutor inner;
  final int version;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('PRAGMA user_version = $version')) {
      throw StateError('synthetic version failure');
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

Future<void> _migrate(Database db, int from, int to, {bool fail = false}) =>
    db.transaction((txn) async {
      final result = await MigrationService.to.migrate(
        db: fail ? _FailVersionAdvance(txn, to) : txn,
        fromVersion: from,
        toVersion: to,
        isUpgrade: to > from,
      );
      if (!result.success) throw StateError(result.error!);
    });

Future<List<Map<String, Object?>>> _matches(
  Database db,
  String table,
  String text,
) => db.rawQuery('SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?', [
  text,
]);

Future<void> _seedDirtyIndex(Database db, String table) async {
  final rowid = await db.insert(table, {
    'id': 'synthetic-$table',
    'msg_type': 'text',
    'payload': '{"text":"currentword"}',
    'status': 20,
    'conversation_uk3': 'synthetic',
  });
  // Reproduce the shipped contentless upsert: both old and new terms survive.
  for (final text in ['oldword', 'currentword']) {
    await db.insert('${table}_fts', {
      'rowid': rowid,
      'id': 'synthetic-$table',
      'conversation_uk3': 'synthetic',
      'text_content': text,
    });
  }
  await db.insert('${table}_fts', {
    'rowid': 999,
    'id': 'synthetic-orphan',
    'conversation_uk3': 'gone',
    'text_content': 'orphanword',
  });
  for (final row in [
    {'id': 'revoked', 'payload': '{"text":"revokedword"}', 'status': 31},
    {
      'id': 'encrypted',
      'payload': '{"text":"cipherword","_e2ee_failed":true}',
      'status': 20,
    },
    {'id': 'invalid', 'payload': 'not-json', 'status': 20},
    {'id': 'empty', 'payload': '{"text":""}', 'status': 20},
  ]) {
    await db.insert(table, {
      ...row,
      'msg_type': 'text',
      'conversation_uk3': 'synthetic',
    });
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });

  test('v40 is a reversible index migration without the v38 draft', () {
    final up = kMigrationManifest.edge(39, 40)!;
    final down = kMigrationManifest.edge(40, 39)!;
    expect(up.reversible, isTrue);
    expect(up.dataLoss, isFalse);
    expect(down.dataLoss, isFalse);
    expect(up.requiresResync, isFalse);
    expect(down.requiresResync, isFalse);
    expect(up.affectedObjects, ['msg_c2c_fts', 'msg_c2g_fts']);
    expect(down.affectedObjects, up.affectedObjects);
    expect(kMigrationManifest.upgradesByTo.containsKey(38), isFalse);
    expect(up.sql, isNot(contains('CREATE TRIGGER')));
    expect(up.sql, isNot(contains('CREATE VIEW')));
  });

  for (final start in [16, 37, 39]) {
    test('v$start to v40 repairs old terms and retains messages', () async {
      final db = await openFixtureDatabaseAtVersion(version: start);
      addTearDown(db.close);
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in messageFtsTables) {
        await _seedDirtyIndex(db, table);
        before[table] = await db.query(table, orderBy: 'auto_id');
        expect(await _matches(db, table, 'oldword'), hasLength(1));
        expect(await _matches(db, table, 'orphanword'), hasLength(1));
      }
      if (start == 39) {
        await db.insert('channel_inbox_preference', {
          'endpoint': 'https://synthetic.invalid',
          'channel_id': '184467440737095516160001',
          'scope': 'personal',
        });
      }
      await _migrate(db, start, 40);
      expect(await db.getVersion(), 40);
      expect(await SchemaContract.verifyInvariants(db, version: 40), isEmpty);
      for (final table in messageFtsTables) {
        final after = await db.query(table, orderBy: 'auto_id');
        // Older paths add ordering/TEXT columns; every original value survives.
        for (var index = 0; index < after.length; index++) {
          for (final entry in before[table]![index].entries) {
            expect(after[index][entry.key], entry.value);
          }
        }
        expect(after, hasLength(before[table]!.length));
        expect(await _matches(db, table, 'oldword'), isEmpty);
        expect(await _matches(db, table, 'orphanword'), isEmpty);
        expect(await _matches(db, table, 'currentword'), hasLength(1));
        final contents = await db.query('${table}_fts');
        expect(contents, hasLength(1));
        expect(contents.single['text_content'], 'currentword');
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts) VALUES('integrity-check')",
        );
      }
      if (start == 39) {
        expect(await db.query('channel_inbox_preference'), [
          {
            'endpoint': 'https://synthetic.invalid',
            'channel_id': '184467440737095516160001',
            'scope': 'personal',
          },
        ]);
      }
    });
  }

  test('v40 to v39 rebuilds only indexes and can upgrade again', () async {
    final db = await openFixtureDatabaseAtVersion(version: 39);
    addTearDown(db.close);
    for (final table in messageFtsTables) {
      await _seedDirtyIndex(db, table);
    }
    await db.insert('channel_inbox_preference', {
      'endpoint': 'https://synthetic.invalid',
      'channel_id': 'opaque-channel',
      'scope': 'personal',
    });
    await _migrate(db, 39, 40);
    final before = <String, List<Map<String, Object?>>>{};
    for (final table in [...messageFtsTables, 'channel_inbox_preference']) {
      before[table] = await db.query(table);
    }
    await _migrate(db, 40, 39);
    expect(await db.getVersion(), 39);
    expect(await SchemaContract.verifyInvariants(db, version: 39), isEmpty);
    for (final table in before.keys) {
      expect(await db.query(table), before[table]);
    }
    for (final table in messageFtsTables) {
      expect(await _matches(db, table, 'currentword'), hasLength(1));
      expect((await db.query('${table}_fts')).single['text_content'], isNull);
      expect(await _matches(db, table, 'oldword'), isEmpty);
    }
    await _migrate(db, 39, 40);
    expect(await SchemaContract.verifyInvariants(db, version: 40), isEmpty);
  });

  for (final from in [39, 40]) {
    final to = from == 39 ? 40 : 39;
    test('v$from to v$to failure restores schema index and version', () async {
      final db = await openFixtureDatabaseAtVersion(version: 39);
      addTearDown(db.close);
      for (final table in messageFtsTables) {
        await _seedDirtyIndex(db, table);
      }
      if (from == 40) await _migrate(db, 39, 40);
      final schemaBefore = await db.rawQuery(
        'SELECT type, name, sql FROM sqlite_master ORDER BY type, name',
      );
      final contentsBefore = <String, List<Map<String, Object?>>>{};
      for (final table in messageFtsTables) {
        contentsBefore[table] = await db.query(table);
      }
      await expectLater(_migrate(db, from, to, fail: true), throwsStateError);
      expect(await db.getVersion(), from);
      expect(
        await db.rawQuery(
          'SELECT type, name, sql FROM sqlite_master ORDER BY type, name',
        ),
        schemaBefore,
      );
      for (final table in messageFtsTables) {
        expect(await db.query(table), contentsBefore[table]);
        expect(await _matches(db, table, 'currentword'), hasLength(1));
        expect(
          (await _matches(db, table, 'oldword')).length,
          from == 39 ? 1 : 0,
        );
      }
      await _migrate(db, from, to);
      expect(await db.getVersion(), to);
      expect(await SchemaContract.verifyInvariants(db, version: to), isEmpty);
    });
  }

  test('v40 rejects contentless tables with the same column names', () async {
    final db = await openFixtureDatabaseAtVersion(version: 40);
    addTearDown(db.close);
    await db.execute('DROP TABLE msg_c2c_fts');
    await db.execute(messageFtsCreateTableSql('msg_c2c', contentless: true));
    expect(
      await SchemaContract.verifyInvariants(db, version: 40),
      contains('unexpected table definition: msg_c2c_fts (v40)'),
    );
  });

  test(
    'content shadows are excluded but the v38 content views remain',
    () async {
      for (final version in [38, 40]) {
        final db = await openFixtureDatabaseAtVersion(
          version: version == 38 ? 37 : 40,
        );
        try {
          if (version == 38) {
            await db.transaction((txn) async {
              for (final statement in upgradeV38Fts.sqlStatements) {
                await txn.execute(statement);
              }
            });
          }
          final normalized = await SchemaFingerprint.normalize(db);
          final contract = await SchemaContract.capture(db, version: version);
          expect(
            (contract['tables'] as Map).containsKey('msg_c2c_fts_content'),
            isFalse,
          );
          expect(
            (contract['others'] as Map).containsKey('view:msg_c2c_fts_content'),
            version == 38,
          );
          expect(normalized.contains('msg_c2c_fts_content'), version == 38);
        } finally {
          await db.close();
        }
      }
    },
  );

  test(
    'v40 SQL matches Dart trimming without changing interior text',
    () async {
      final db = await openFixtureDatabaseAtVersion(version: 39);
      addTearDown(db.close);
      final whitespace = [
        ...List.generate(5, (index) => String.fromCharCode(9 + index)),
        ' ',
        '\u0085',
        '\u00a0',
        '\u1680',
        ...List.generate(11, (index) => String.fromCharCode(0x2000 + index)),
        '\u2028',
        '\u2029',
        '\u202f',
        '\u205f',
        '\u3000',
        '\ufeff',
      ];
      final cases = <(String, Map<String, dynamic>)>[
        for (final space in whitespace)
          ('text', {'text': '${space}word$space'}),
        ('text', {'text': 'plain  interior\nspace'}),
        ('quote', {'quote_text': '\ufeffquoted\u3000'}),
        ('location', {'title': '\u3000A\u3000', 'address': '\u00a0B\u00a0'}),
        ('location', {'title': 'A  B', 'address': '\nC\n'}),
        ('text', {'text': 7}),
        ('text', {'text': 'hidden', '_e2ee_failed': true}),
        ('text', {'text': 'kept', '_e2ee_failed': false}),
        ('text', {'text': 'kept', '_e2ee_failed': 1}),
        ('text', {'text': 'kept', '_e2ee_failed': 'true'}),
      ];
      for (var index = 0; index < cases.length; index++) {
        final (type, payload) = cases[index];
        await db.insert('msg_c2c', {
          'id': 'trim-$index',
          'msg_type': type,
          'payload': jsonEncode(payload),
          'status': 20,
        });
        final rows = await db.rawQuery(
          'SELECT ${messageFtsCurrentTextSql('message.')} AS text '
          'FROM msg_c2c AS message WHERE message.id = ?',
          ['trim-$index'],
        );
        expect(
          rows.single['text'],
          MessageFtsRepo.extractTextContent(type, payload),
          reason: 'case $index: $type / $payload',
        );
      }
    },
  );
}
