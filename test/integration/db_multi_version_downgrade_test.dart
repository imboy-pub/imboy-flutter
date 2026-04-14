// 多级降级链式执行集成测试 V11 → V10 → V9
// Multi-version chained downgrade integration test (V11 → V10 → V9)
//
// 验证 MigrationScriptPlanner + 真实 in-memory DB 的组合能正确处理假设未来
// 添加的 V11 降级块。使用合成的 V11 schema 和合成的 V11 降级脚本，避免等实际
// 出现 V11 需求时才暴露 bug。
//
// 覆盖的潜在 bug（回归）：
// - 降级脚本按升序执行（原 _getMigrationScripts 的缺陷）会导致 V10→V9 的 SQL
//   在 V11 schema 上执行失败
//
// Verifies the planner + real in-memory DB correctly execute a hypothetical
// future V11 downgrade. Uses a synthetic V11 schema and a synthetic V11
// downgrade block to catch the bug before it hits production.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 合成的 V10 降级 block：`msg_c2c → message` 重命名 + 删 msg_type 列。
/// Synthetic V10 downgrade: rename msg_c2c → message + drop msg_type.
MigrationScript syntheticDowngradeV10() => MigrationScript(
      version: 10,
      targetVersion: 9,
      description: 'v10 → v9',
      sqlStatements: [
        'ALTER TABLE msg_c2c RENAME TO message;',
        // SQLite 不支持 DROP COLUMN (<3.35)，用表重建模拟真实 downgrade.sql 做法
        '''
        CREATE TABLE message_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
        ''',
        '''
        INSERT INTO message_new (id, payload, created_at)
          SELECT id, payload, created_at FROM message;
        ''',
        'DROP TABLE message;',
        'ALTER TABLE message_new RENAME TO message;',
      ],
    );

/// 合成的 V11 降级 block：`msg_c2c_v11 → msg_c2c` 重命名 + 删 v11 新增列。
/// Synthetic V11 downgrade: rename msg_c2c_v11 → msg_c2c + drop v11 column.
MigrationScript syntheticDowngradeV11() => MigrationScript(
      version: 11,
      targetVersion: 10,
      description: 'v11 → v10',
      sqlStatements: [
        'ALTER TABLE msg_c2c_v11 RENAME TO msg_c2c;',
        '''
        CREATE TABLE msg_c2c_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          msg_type TEXT
        );
        ''',
        '''
        INSERT INTO msg_c2c_new (id, payload, created_at, msg_type)
          SELECT id, payload, created_at, msg_type FROM msg_c2c;
        ''',
        'DROP TABLE msg_c2c;',
        'ALTER TABLE msg_c2c_new RENAME TO msg_c2c;',
      ],
    );

/// 构造合成 V11 schema（模拟真实产线某天升到 V11 的表结构）
/// Build synthetic V11 schema (what production would look like at V11)
Future<void> createV11Schema(Database db) async {
  await db.execute('''
    CREATE TABLE msg_c2c_v11 (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payload TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      msg_type TEXT,
      v11_extra_field TEXT
    )
  ''');
  await db.execute('PRAGMA user_version = 11');
}

/// 顺序执行一组脚本的全部 SQL 语句
/// Execute all SQL statements in a list of scripts, in order
Future<void> runPlan(Database db, List<MigrationScript> plan) async {
  for (final script in plan) {
    for (final sql in script.sqlStatements) {
      await db.execute(sql);
    }
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('多级降级 V11→V9 / multi-version downgrade chain', () {
    late Database db;
    late Map<int, MigrationScript> scripts;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await createV11Schema(db);
      scripts = {
        10: syntheticDowngradeV10(),
        11: syntheticDowngradeV11(),
      };
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'planner 给出降序 [V11, V10] 的执行顺序 / plan is descending',
      () {
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 11,
          toVersion: 9,
        );
        expect(plan.map((s) => s.version).toList(), [11, 10]);
      },
    );

    test(
      '按降序执行能成功降级 V11→V9 / descending plan completes successfully',
      () async {
        // 插入 V11 样本数据
        await db.insert('msg_c2c_v11', {
          'payload': 'hello',
          'created_at': 1000,
          'msg_type': 'text',
          'v11_extra_field': 'should be dropped',
        });

        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 11,
          toVersion: 9,
        );

        // 全程不应抛错
        await runPlan(db, plan);

        // 验证最终 schema 为 V9：表名 `message`，只剩 V9 字段
        final info = await db.rawQuery('PRAGMA table_info(message)');
        final columns = info.map((r) => r['name'] as String).toSet();
        expect(columns, {'id', 'payload', 'created_at'});

        // 数据必须保留
        final rows = await db.query('message');
        expect(rows, hasLength(1));
        expect(rows.first['payload'], 'hello');
      },
    );

    test(
      '按升序执行（模拟 bug）会失败 / ascending plan fails (regression guard)',
      () async {
        // 手动构造升序 plan 模拟原 _getMigrationScripts 的行为
        // Simulate the legacy ascending order to prove it breaks
        final ascending = [
          syntheticDowngradeV10(), // 先 10→9 ← V11 schema 下表名叫 msg_c2c_v11，不是 msg_c2c，失败
          syntheticDowngradeV11(),
        ];

        // V10 脚本的第一句 `ALTER TABLE msg_c2c RENAME TO message` 会失败，
        // 因为当前 DB 是 V11 schema，表名是 msg_c2c_v11
        // The very first statement of the V10 block fails because the V11
        // schema's table is msg_c2c_v11, not msg_c2c
        await expectLater(
          () => runPlan(db, ascending),
          throwsA(isA<DatabaseException>()),
          reason: '证明：升序执行在 V11 schema 下必然失败，降序执行才正确',
        );
      },
    );

    test(
      '单级降级 V10→V9 不受影响 / single-hop downgrade unaffected',
      () async {
        // 另起一个 V10 的 DB
        final v10Db = await databaseFactory.openDatabase(
          inMemoryDatabasePath,
        );
        try {
          await v10Db.execute('''
            CREATE TABLE msg_c2c (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              msg_type TEXT
            )
          ''');
          await v10Db.execute('PRAGMA user_version = 10');

          final plan = MigrationScriptPlanner.plan(
            scripts: scripts,
            fromVersion: 10,
            toVersion: 9,
          );
          expect(plan.map((s) => s.version).toList(), [10]);

          await runPlan(v10Db, plan);

          final info = await v10Db.rawQuery('PRAGMA table_info(message)');
          final columns = info.map((r) => r['name'] as String).toSet();
          expect(columns, {'id', 'payload', 'created_at'});
        } finally {
          await v10Db.close();
        }
      },
    );
  });
}
