// 降级脚本完整性回归：v19~v25 降级块必须存在于 kDowngradeScriptSql
// Regression: v19–v25 downgrade blocks must exist in kDowngradeScriptSql
//
// A-21 记录的历史缺口：kDowngradeScriptSql 止于 v18，v19~v25 全缺。
// 降级时旧版 app 会执行到不存在版本块，MigrationScriptPlanner 对降级
// 方向不校验 → 静默跳过高版本降级，数据停留在 v25 而 app 认为已降到
// 旧版，schema 与 app 预期分叉。
//
// 本测试只守护「块存在 + PRAGMA 目标版本正确」（解析层），不跑完整
// 降级链（DDL 语义由 db_* 集成测试 + 真机覆盖；此处守护的是 A-21 的
// 同步契约——曾发生块只写进 .sql 参考副本而运行时 embedded 缺失）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/migration_service.dart';

void main() {
  group('A-21 回归: v19~v25 降级块存在', () {
    setUp(() async {
      await MigrationService.to.init();
    });

    test('降级脚本解析后 v19~v25 均有块', () {
      // 通过公开 API 读已加载的降级脚本集合
      final scripts = MigrationService.to.debugDowngradeScripts;

      // v19~v25 每个版本都应有降级块（从 N 降到 N-1）
      for (var v = 19; v <= 25; v++) {
        expect(
          scripts.containsKey(v),
          isTrue,
          reason: 'kDowngradeScriptSql 缺少 v$v 降级块（A-21 缺口）',
        );
      }
    });

    test('每个降级块 targetVersion = version-1（PRAGMA 正确）', () {
      final scripts = MigrationService.to.debugDowngradeScripts;
      for (var v = 19; v <= 25; v++) {
        final s = scripts[v];
        expect(s, isNotNull, reason: 'v$v 缺块');
        expect(
          s!.targetVersion,
          v - 1,
          reason: 'v$v 降级块 PRAGMA user_version 应为 ${v - 1}',
        );
      }
    });

    test('v19 降级块移除 mute_until（重建表结构无该列）', () {
      final s = MigrationService.to.debugDowngradeScripts[19]!;
      final sql = s.sqlStatements.join('\n');
      expect(sql, contains('CREATE TABLE group_member_v18'));
      // 注释里含"移除 mute_until"字样，故只断言重建表列定义不含该列：
      // 取 CREATE TABLE 到 DROP TABLE 之间的建表段检查
      final createTableBlock =
          RegExp(
            r'CREATE TABLE group_member_v18[\s\S]*?(?=DROP TABLE group_member;)',
          ).firstMatch(sql)?.group(0) ??
          '';
      expect(
        createTableBlock,
        isNot(contains('mute_until')),
        reason: 'v19 重建表（v18 结构）不应含 mute_until 列',
      );
      expect(sql, contains('PRAGMA user_version = 18'));
    });

    test('v25 降级块移除 sender_did', () {
      final s = MigrationService.to.debugDowngradeScripts[25]!;
      final sql = s.sqlStatements.join('\n');
      expect(sql, contains('CREATE TABLE msg_c2c_v24'));
      expect(sql, isNot(contains('sender_did')));
      expect(sql, contains('PRAGMA user_version = 24'));
    });
  });
}
