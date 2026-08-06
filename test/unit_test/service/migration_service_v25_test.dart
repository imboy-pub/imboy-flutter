/// A-21 回归守护：v25 迁移（msg_c2c.sender_did）必须同步进运行时实际加载的
/// embedded_schema_scripts.dart，不能只写进 assets/migrations/upgrade.sql。
///
/// 曾发生的 bug：v25 块只进了 upgrade.sql（MigrationService 从不读 asset），
/// 运行时加载的 kUpgradeScriptSql 仍止于 v24 → _dbVersion=25 但 migrate()
/// 找不到 v25 脚本 → 新老用户的 msg_c2c.sender_did 列永久缺失 → PFv3 离线
/// 消息全部判 context_mismatch_sender_did 不可读。
///
/// 现有 db_v25_msg_c2c_sender_did_test.dart 硬编码了 v25 SQL，抓不到这层同步
/// 契约（它一直 GREEN，生产却 RED）。本测试经 MigrationService 公开 API 验证
/// 解析+加载后的 targetVersion，直接守护 embedded 同步。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_service.dart';

void main() {
  group('A-21: v25 (sender_did) 同步进 embedded_schema_scripts', () {
    setUp(() async {
      await MigrationService.to.init();
    });

    test('init 后 targetVersion == 25（v25 块已被解析加载）', () {
      expect(
        MigrationService.to.targetVersion,
        equals(25),
        reason:
            '若 embedded kUpgradeScriptSql 漏 v25，targetVersion 会卡在 24 '
            '（A-21 原bug：upgrade.sql 有 v25 但运行时不读 asset）',
      );
    });

    test('kUpgradeScriptSql 含 sender_did 的 ALTER 语句', () {
      expect(
        kUpgradeScriptSql,
        contains('ALTER TABLE msg_c2c ADD COLUMN sender_did'),
      );
    });
  });
}
