import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 模拟驱动忽略 PRAGMA / 不返回可确认结果；其余 SQL 仍在真实 FFI 库执行。
class _RecursiveTriggerReadbackDatabase implements Database {
  _RecursiveTriggerReadbackDatabase(this.delegate, this.readback);

  final Database delegate;
  final List<Map<String, Object?>> readback;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      delegate.execute(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => sql == 'PRAGMA recursive_triggers'
      ? readback
      : await delegate.rawQuery(sql, arguments);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production onConfigure enables FTS replacement after every open', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('fts_connection_');
    final path = '${directory.path}/synthetic.db';
    var db = await openFixtureDatabaseAtVersion(version: 37, path: path);
    try {
      await db.close();
      for (var opening = 0; opening < 2; opening++) {
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            singleInstance: false,
            onConfigure: SqliteService.configureConnection,
          ),
        );
        SqliteService.setDbForTest(db);
        expect(
          (await db.rawQuery('PRAGMA recursive_triggers'))
              .single['recursive_triggers'],
          1,
        );
        if (opening == 0) {
          // 草稿仍未注册；只在本隔离库显式应用，不冒充生产迁移验收。
          await db.transaction((txn) async {
            for (final sql in upgradeV38Fts.sqlStatements) {
              await txn.execute(sql);
            }
          });
        }
        for (final table in ['msg_c2c', 'msg_c2g']) {
          final row = <String, dynamic>{
            'id': 'configured-$table',
            'conversation_uk3': 'synthetic',
            'msg_type': 'text',
            'payload': '{"text":"oldword"}',
            'status': 20,
          };
          expect(await SqliteService.to.insert(table, row), greaterThan(0));
          // 真实应用写入口默认 INSERT OR REPLACE，必须同步删旧词并写新词。
          row['payload'] = '{"text":"replacementword"}';
          expect(await SqliteService.to.insert(table, row), greaterThan(0));
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['oldword'],
            ),
            isEmpty,
          );
          expect(
            (await db.rawQuery(
              'SELECT id FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['replacementword'],
            )).single['id'],
            'configured-$table',
          );
          await db.execute(
            "INSERT INTO ${table}_fts(${table}_fts, rank) VALUES('integrity-check', 1)",
          );
        }
        // 连接属性必须由下次开库恢复，不能依赖之前连接或编译时默认值。
        await db.execute('PRAGMA recursive_triggers = OFF');
        await db.close();
      }
    } finally {
      SqliteService.setDbForTest(null);
      if (db.isOpen) await db.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'production onConfigure rejects disabled or unconfirmed recursion',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      for (final readback in <List<Map<String, Object?>>>[
        [],
        [
          <String, Object?>{'recursive_triggers': 0},
        ],
      ]) {
        await expectLater(
          SqliteService.configureConnection(
            _RecursiveTriggerReadbackDatabase(db, readback),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('recursive_triggers could not be enabled'),
            ),
          ),
        );
      }
    },
  );
}
