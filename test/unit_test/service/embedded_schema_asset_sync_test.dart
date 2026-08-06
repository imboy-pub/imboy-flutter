/// A-22: embedded schema 常量与 assets/migrations/*.sql 同步守护。
///
/// 防 A-21 类 bug：v25 块曾只写进 upgrade.sql（asset）却漏同步运行时实际加载的
/// embedded_schema_scripts.dart，导致 migrate() 找不到脚本、msg_c2c.sender_did
/// 列永久缺失。asset 虽在 pubspec 注册，但 MigrationService 运行时只读 embedded
/// 常量（不读 asset），故两者必须手工同步——本测试守护这层同步契约：任一侧改动
/// 实质内容（VERSION 块/SQL）不同步另一侧即 RED。空行与行首尾空白被规范化忽略
/// （不影响运行时语义）。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';

/// 规范化：去行首尾空白、去空行后拼接。忽略纯格式差异，只比对实质 SQL/注释内容。
String _norm(String s) =>
    s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('A-22: embedded schema 常量与 assets/migrations/*.sql 同步', () {
    test('kUpgradeScriptSql == upgrade.sql', () async {
      final asset = await rootBundle.loadString(
        'assets/migrations/upgrade.sql',
      );
      expect(
        _norm(kUpgradeScriptSql),
        equals(_norm(asset)),
        reason: 'embedded 与 asset 不同步 → migrate() 读到的脚本缺版本（A-21 原bug）',
      );
    });

    test('kBaselineSchemaSql == baseline_schema.sql', () async {
      final asset = await rootBundle.loadString(
        'assets/migrations/baseline_schema.sql',
      );
      expect(_norm(kBaselineSchemaSql), equals(_norm(asset)));
    });

    test('kDowngradeScriptSql == downgrade.sql', () async {
      final asset = await rootBundle.loadString(
        'assets/migrations/downgrade.sql',
      );
      expect(_norm(kDowngradeScriptSql), equals(_norm(asset)));
    });
  });
}
