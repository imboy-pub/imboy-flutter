// 多级升级链式执行集成测试 V9 → V10 → V11
// Multi-version chained upgrade integration test (V9 → V10 → V11)
//
// 对称补全 db_multi_version_downgrade_test.dart：验证 MigrationScriptPlanner
// 在升级场景下给出升序执行计划，并在真实 in-memory DB 上链式执行成功。
//
// 覆盖的潜在 bug（回归）：
// - 升级脚本若按降序执行，V11 block 会引用 V10 block 尚未创建的 sessions 表
//   而失败（SQLITE_ERROR: no such table）
//
// Symmetric counterpart to db_multi_version_downgrade_test.dart. Verifies
// planner returns ascending order for upgrades and that the full chain runs
// successfully on a real in-memory DB. Includes regression guard: descending
// execution must fail because V11 depends on V10's sessions table.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 合成的 V10 升级 block：
/// - users 表增加 email 列
/// - 创建 sessions 表（供 V11 依赖）
///
/// Synthetic V10 upgrade: ADD COLUMN users.email + CREATE TABLE sessions
/// (the sessions table is a dependency for V11)
MigrationScript syntheticUpgradeV10() => MigrationScript(
      version: 10,
      targetVersion: 10,
      description: 'v9 → v10',
      sqlStatements: [
        'ALTER TABLE users ADD COLUMN email TEXT;',
        '''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          token TEXT NOT NULL
        );
        ''',
      ],
    );

/// 合成的 V11 升级 block：依赖 V10 创建的 sessions 表增加 expires_at 列。
/// 若在 V9 schema 下执行（sessions 不存在）则必然失败 — 正是回归守护想证明的事。
///
/// Synthetic V11 upgrade: depends on V10's sessions table. Fails against a
/// V9 schema — exactly what the descending-order regression guard proves.
MigrationScript syntheticUpgradeV11() => MigrationScript(
      version: 11,
      targetVersion: 11,
      description: 'v10 → v11',
      sqlStatements: [
        'ALTER TABLE sessions ADD COLUMN expires_at INTEGER;',
      ],
    );

/// 构造 V9 基线 schema：只含 users 表。
/// Build V9 baseline schema: users table only.
Future<void> createV9Schema(Database db) async {
  await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''');
  await db.execute('PRAGMA user_version = 9');
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

  group('多级升级 V9→V11 / multi-version upgrade chain', () {
    late Database db;
    late Map<int, MigrationScript> scripts;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await createV9Schema(db);
      scripts = {
        10: syntheticUpgradeV10(),
        11: syntheticUpgradeV11(),
      };
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'planner 给出升序 [V10, V11] 的执行顺序 / plan is ascending',
      () {
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 11,
        );
        expect(plan.map((s) => s.version).toList(), [10, 11]);
      },
    );

    test(
      '按升序执行能成功升级 V9→V11 / ascending plan completes successfully',
      () async {
        // 插入 V9 样本数据
        await db.insert('users', {'name': 'alice'});

        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 11,
        );
        await runPlan(db, plan);

        // 验证 users 表已加 email 列
        final userInfo = await db.rawQuery('PRAGMA table_info(users)');
        final userCols = userInfo.map((r) => r['name'] as String).toSet();
        expect(userCols, containsAll({'id', 'name', 'email'}));

        // 验证 sessions 表已建且含 expires_at 列
        final sessInfo = await db.rawQuery('PRAGMA table_info(sessions)');
        final sessCols = sessInfo.map((r) => r['name'] as String).toSet();
        expect(
          sessCols,
          containsAll({'id', 'user_id', 'token', 'expires_at'}),
        );

        // V9 原有数据必须保留
        final rows = await db.query('users', where: 'name = ?', whereArgs: ['alice']);
        expect(rows, hasLength(1));
      },
    );

    test(
      '按降序执行（模拟 bug）会失败 / descending plan fails (regression guard)',
      () async {
        // 手动构造降序 plan 模拟错误排序
        // Simulate wrong descending order for upgrade
        final descending = [
          syntheticUpgradeV11(), // 先 V11：ALTER sessions，但 sessions 还没建，失败
          syntheticUpgradeV10(),
        ];

        // V11 的 ALTER TABLE sessions 会失败（no such table）
        await expectLater(
          () => runPlan(db, descending),
          throwsA(isA<DatabaseException>()),
          reason: '证明：降序执行在 V9 schema 下必然失败（V11 依赖 V10 的 sessions 表），'
              '升序执行才正确',
        );
      },
    );

    test(
      '单级升级 V9→V10 不受影响 / single-hop upgrade unaffected',
      () async {
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 9,
          toVersion: 10,
        );
        expect(plan.map((s) => s.version).toList(), [10]);

        await runPlan(db, plan);

        // sessions 表应已创建，但不含 V11 的 expires_at
        final sessInfo = await db.rawQuery('PRAGMA table_info(sessions)');
        final sessCols = sessInfo.map((r) => r['name'] as String).toSet();
        expect(sessCols, {'id', 'user_id', 'token'});
        expect(sessCols.contains('expires_at'), isFalse);
      },
    );

    test(
      '从中间版本继续升级 V10→V11 只执行 V11 / intermediate upgrade V10→V11',
      () async {
        // 先把 DB 升到 V10
        await runPlan(db, [syntheticUpgradeV10()]);
        await db.execute('PRAGMA user_version = 10');

        // 然后继续 V10→V11
        final plan = MigrationScriptPlanner.plan(
          scripts: scripts,
          fromVersion: 10,
          toVersion: 11,
        );
        expect(plan.map((s) => s.version).toList(), [11]);

        await runPlan(db, plan);

        final sessInfo = await db.rawQuery('PRAGMA table_info(sessions)');
        final sessCols = sessInfo.map((r) => r['name'] as String).toSet();
        expect(sessCols.contains('expires_at'), isTrue);
      },
    );
  });
}
