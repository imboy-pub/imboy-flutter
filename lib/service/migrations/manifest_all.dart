// 全局迁移清单聚合 —— kMigrationManifest 的唯一定义点
// Aggregates every migration edge into the single global manifest.
//
// 顺序约定：upgrade 边按版本升序（三段文件），随后 downgrade 边。
// 新增边时在对应段文件追加并重跑生成器 --check 与契约测试。
library;

import 'package:imboy/service/migration_manifest.dart';
import 'package:imboy/service/migrations/downgrade_edges_all.dart';
import 'package:imboy/service/migrations/upgrade_edges_v09_v16.dart';
import 'package:imboy/service/migrations/upgrade_edges_v17_v24.dart';
import 'package:imboy/service/migrations/upgrade_edges_v25_v31.dart';

/// 全局唯一迁移清单实例（唯一真源）。
///
/// 消费方：MigrationService（构造执行脚本）、
/// tool/generate_sqlite_migrations.dart（生成 .sql 参考文件）、
/// schema contract（版本与 affectedObjects）。任何旁路维护的 SQL 副本
/// 都是违规——改迁移必须改这里的边数据。
final MigrationManifest kMigrationManifest = MigrationManifest([
  ...kUpgradeEdgesV09V16,
  ...kUpgradeEdgesV17V24,
  ...kUpgradeEdgesV25V31,
  ...kDowngradeEdgesAll,
])..validatePairing();
