// WP2 迁移原子性失败测试：事务内不得有文件快照/恢复、不得吞错
// WP2 migration atomic-failure tests: no in-transaction file snapshot/restore,
// no broad duplicate-column swallowing.
//
// 复现的缺陷（研究文档 §2.3 P0 三连）：
//   F1. migrate() 在 sqflite 版本迁移事务回调内 File(db.path).copy() 复制
//       主库 —— WAL 活跃/混合页下不是一致性快照；
//   F2. 失败 catch 里 _restoreFromSnapshot：db.close() + 快照覆盖主库文件
//       —— 与外层 sqflite 事务回滚职责冲突，句柄失效、sidecar 不一致；
//   F3. 所有 "duplicate column" 错误被字符串匹配吞掉 —— 脚本漂移/错误状态
//       被伪装成成功。
//
// 修复后契约：
//   - migrate() 失败只返回 failure（+ 由 SqliteService 回调 rethrow 触发
//     sqflite 事务回滚），绝不 close db、绝不写主库/快照文件；
//   - 失败后连接仍打开、user_version/schema/样本行不变；
//   - ADD COLUMN 幂等改为显式 precondition（列已存在 → 跳过并留痕），
//     其他 SQL 错误如实失败；
//   - 纯 ffi 环境可跑（不再触及 path_provider 的临时目录）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WP2 SQL 中途失败 → 事务回滚，连接不关 / atomic failure', () {
    late Database db;

    setUp(() async {
      // v25 fixture（真实脚本构建，含 group_member 等表 + 合成种子行）
      db = await openFixtureDatabaseAtVersion(
        version: 25,
        withSyntheticRows: true,
      );
    });

    tearDown(() async => db.close());

    test('坏 SQL 返回 failure 且错误含真实 SQL 错误（非快照/平台错误）', () async {
      MigrationResult? result;
      Object? thrown;
      // 复刻生产调用契约：onDowngrade 在 sqflite 事务内调 migrate，
      // failure 后 rethrow 触发回滚（sqlite.dart _onDowngrade 同款行为）
      try {
        await db.transaction((txn) async {
          result = await MigrationService.to.migrate(
            db: txn,
            fromVersion: 25,
            toVersion: 9,
            isUpgrade: false,
          );
          if (result != null && !result!.success) {
            throw Exception('Downgrade failed: ${result!.error}');
          }
        });
      } catch (e) {
        thrown = e;
      }

      // 25→9 跨边：缺块 11/12/13/14/16（WP1 fail-fast），或链前段执行遇错。
      // 两种都必须是 failure，且错误信息不得出现快照/临时目录痕迹。
      expect(result, isNotNull);
      expect(result!.success, isFalse);
      expect(thrown, isNotNull, reason: '回调必须 rethrow 让 sqflite 回滚');
      expect(result!.error, isNot(contains('TemporaryDirectory')));
      expect(result!.error, isNot(contains('MissingPluginException')));
    });

    test('SQL 中途失败后：连接仍打开、版本/schema/样本行不变', () async {
      final beforeVersion =
          (await db.rawQuery('PRAGMA user_version')).first.values.first as int;
      final beforeTables = await db.rawQuery(
        "SELECT count(*) AS c FROM sqlite_master WHERE type='table'",
      );
      final beforeRows = await db.query(
        'msg_c2c',
        where: 'conversation_uk3 = ?',
        whereArgs: ['synthetic-conv-001'],
      );

      MigrationResult? result;
      try {
        await db.transaction((txn) async {
          result = await MigrationService.to.migrate(
            db: txn,
            fromVersion: 25,
            toVersion: 9,
            isUpgrade: false,
          );
          if (result != null && !result!.success) {
            throw Exception('Downgrade failed: ${result!.error}');
          }
        });
      } catch (_) {
        /* 模拟 rethrow 触发回滚 */
      }
      expect(result!.success, isFalse);

      // 连接未被 migrate 关闭（F2 回归守护）
      expect(db.isOpen, isTrue, reason: 'migrate 失败不得 close 活动连接');

      // 事务回滚后库状态与迁移前一致
      final afterVersion =
          (await db.rawQuery('PRAGMA user_version')).first.values.first as int;
      expect(afterVersion, equals(beforeVersion));
      final afterTables = await db.rawQuery(
        "SELECT count(*) AS c FROM sqlite_master WHERE type='table'",
      );
      expect(
        afterTables.first['c'],
        equals(beforeTables.first['c']),
        reason: '回滚后表数量不得变化',
      );
      final afterRows = await db.query(
        'msg_c2c',
        where: 'conversation_uk3 = ?',
        whereArgs: ['synthetic-conv-001'],
      );
      expect(afterRows.length, equals(beforeRows.length));
    });
  });

  group('WP2 duplicate-column 显式 precondition / explicit idempotency', () {
    test('v9→31 真实全链（v11/v12 重复 ALTER 依赖 precondition 跳过）：成功', () async {
      // 真实依赖场景：v10 块已为 msg_* 加 type/msg_type/action/e2ee，
      // v11/v12 块对同列重复 ALTER TABLE ADD COLUMN。旧代码靠字符串吞错
      // 掩盖；新契约必须由显式 precondition（列已存在→跳过）保持链幂等。
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await applyV9LegacySchema(db);

      final result = await MigrationService.to.migrate(
        db: db,
        fromVersion: 9,
        toVersion: 31,
        isUpgrade: true,
      );

      expect(
        result.success,
        isTrue,
        reason: 'v9→31 全链不得因历史重复 ALTER 失败（失败原因：${result.error}）',
      );
      expect(db.isOpen, isTrue);
      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(31));
      final msgTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='msg_c2c'",
      );
      expect(msgTable, isNotEmpty);
    });

    test('全新升级 v16→31 在纯 ffi 环境成功（不触及 path_provider 临时目录）', () async {
      // 修复前 _createSnapshot 调 getTemporaryDirectory 在纯 ffi 测试环境
      // 必抛 MissingPluginException → migrate 恒 failure。修复后成功路径
      // 不再有任何文件系统副作用，此用例即可通过。
      final db = await openFixtureDatabaseAtVersion(version: 16);
      addTearDown(db.close);

      final result = await MigrationService.to.migrate(
        db: db,
        fromVersion: 16,
        toVersion: 31,
        isUpgrade: true,
      );
      expect(result.success, isTrue, reason: '失败原因：${result.error}');
      final uv = await db.rawQuery('PRAGMA user_version');
      expect(uv.first.values.first, equals(31));
    });
  });
}
