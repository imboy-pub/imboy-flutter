import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database, openDatabase;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher supports v38 FTS draft', (tester) async {
    expect(isEncryptionSupported, isTrue);
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = await temporaryDirectory.createTemp('imboy_fts_v38_');
    final databasePath = path.join(directory.path, 'synthetic.db');
    const password = 'synthetic-test-password';
    Future<void> configure(Database database) async {
      await database.execute('PRAGMA recursive_triggers = ON');
    }
    var db = await openEncryptedDatabase(
      databasePath,
      password: password,
      onConfigure: configure,
    );
    try {
      final cipher = await db.rawQuery('PRAGMA cipher_version');
      expect(cipher, isNotEmpty);
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await db.execute('CREATE TABLE $table (auto_id INTEGER PRIMARY KEY, '
            'id TEXT UNIQUE, conversation_uk3 TEXT, msg_type TEXT, payload TEXT, status INTEGER)');
        await db.execute('CREATE VIRTUAL TABLE ${table}_fts USING fts5('
            "id, conversation_uk3, text_content, content='')");
        await db.insert(table, {
          'id': 'synthetic-$table',
          'conversation_uk3': 'synthetic',
          'msg_type': 'text',
          'payload': '{"text":"ciphermigrationword"}',
          'status': 20,
        });
      }
      await db.execute('PRAGMA user_version = 37');
      await db.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      for (final table in ['msg_c2c', 'msg_c2g']) {
        final rows = await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['ciphermigrationword'],
        );
        expect(rows.single['id'], 'synthetic-$table');
        await db.update(table, {'status': 30},
            where: 'id = ?', whereArgs: ['synthetic-$table']);
        expect(await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['ciphermigrationword'],
        ), isEmpty);
      }
      final version = await db.rawQuery('SELECT user_version FROM pragma_user_version');
      expect(version.single['user_version'], 38);
      await db.close();
      db = await openEncryptedDatabase(
        databasePath,
        password: password,
        onConfigure: configure,
      );
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
        expect(await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['replaceword'],
        ), isEmpty);
        expect(await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['upsertword'],
        ), hasLength(1));
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
          db.rawUpdate(
            'UPDATE OR REPLACE $table SET id = ? WHERE id = ?',
            ['other-$table', 'synthetic-$table'],
          ),
          throwsA(isA<Exception>()),
        );
        expect(await db.query(table), hasLength(2));
        expect(await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['upsertword'],
        ), hasLength(1));
        expect(await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['rejectedword'],
        ), isEmpty);
        expect(await db.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          ['otherword'],
        ), hasLength(1));
        await db.execute(
          "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
        );
      }
    } finally {
      await db.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  testWidgets('v38 guards independently configured WAL connections', (tester) async {
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
        await database.execute('PRAGMA recursive_triggers = ON');
        await database.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
    Database? unconfigured;
    try {
      for (final table in ['msg_c2c', 'msg_c2g']) {
        await configured.execute('CREATE TABLE $table (auto_id INTEGER PRIMARY KEY, '
            'id TEXT UNIQUE, conversation_uk3 TEXT, msg_type TEXT, payload TEXT, status INTEGER)');
        await configured.execute('CREATE VIRTUAL TABLE ${table}_fts USING fts5('
            "id, conversation_uk3, text_content, content='')");
      }
      await configured.transaction((txn) async {
        for (final sql in upgradeV38Fts.sqlStatements) {
          await txn.execute(sql);
        }
      });
      unconfigured = await openDatabase(
        databasePath,
        password: password,
        singleInstance: false,
        onConfigure: (database) async {
          await database.execute('PRAGMA recursive_triggers = OFF');
        },
      );
      expect((await configured.rawQuery('PRAGMA journal_mode')).single.values.single, 'wal');
      expect((await configured.rawQuery('PRAGMA recursive_triggers')).single.values.single, 1);
      expect((await unconfigured.rawQuery('PRAGMA recursive_triggers')).single.values.single, 0);
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
          throwsA(predicate<Object>((error) => error.toString().contains(
            'message FTS requires recursive triggers for conflicting inserts',
          ))),
        );
        expect(await configured.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?', ['originalword'],
        ), hasLength(1));
        await configured.rawInsert(
          'INSERT OR REPLACE INTO $table(id, msg_type, payload, status) VALUES(?, ?, ?, ?)',
          ['synthetic-$table', 'text', '{"text":"replacementword"}', 20],
        );
        expect(await unconfigured.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?', ['originalword'],
        ), isEmpty);
        expect(await unconfigured.rawQuery(
          'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?', ['replacementword'],
        ), hasLength(1));
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
