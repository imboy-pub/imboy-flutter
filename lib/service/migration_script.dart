// 迁移脚本数据模型（纯 Dart，零依赖）
// Migration script data model (pure Dart, zero deps)
//
// 从 migration_service.dart 抽取，让 MigrationScriptPlanner 等纯逻辑能在
// 不引入 path_provider / sqflite_sqlcipher / rootBundle 的前提下使用。
//
// Extracted from migration_service.dart so pure-logic collaborators (e.g.
// MigrationScriptPlanner) can use it without pulling in path_provider,
// sqflite_sqlcipher, or rootBundle.
library;

/// 单个版本块的迁移脚本。
///
/// 约定：
/// - 升级脚本：`version = targetVersion = N`，表示从 N-1 → N
/// - 降级脚本：`version = N`, `targetVersion = N - 1`（由 PRAGMA 提取），
///   表示从 N → N-1
///
/// Upgrade: version == targetVersion == N (transition N-1 → N)
/// Downgrade: version = N, targetVersion = N-1 (transition N → N-1)
class MigrationScript {
  MigrationScript({
    required this.version,
    required this.targetVersion,
    required this.description,
    required this.sqlStatements,
  });

  final int version; // 起始版本
  final int targetVersion; // 目标版本
  final String description;
  final List<String> sqlStatements;

  String get fullSql => sqlStatements.join('\n');
}
