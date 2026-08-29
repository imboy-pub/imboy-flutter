// SQLite 迁移基线清单（WP0 冻结快照，纯数据，零依赖）
// SQLite migration baseline inventory (WP0 frozen snapshot, pure data).
//
// 本文件是 2026-08-27 基线（HEAD b0d3eb33）上从
// lib/service/embedded_schema_scripts.dart 的 kUpgradeScriptSql /
// kDowngradeScriptSql 解析出的**版本边事实清单**，供
// migration_baseline_inventory_test.dart 做双向对照：
//   - 静态清单 ⊆ 实际解析结果：清单没有漂移；
//   - 实际解析结果 ⊆ 静态清单：没有未登记的新块悄悄混入。
//
// 语义（与 lib/service/migration_script.dart 一致，注意与
// assets/migrations/downgrade.sql 头部注释相矛盾时**以本清单为准**）：
//   - upgrade 块   `VERSION: N` = 边 (N-1) → N
//   - downgrade 块 `VERSION: N` = 边 N → (N-1)
//   - downgrade.sql 文件头注释声称 "VERSION 标记的是目标版本号"，与实际
//     块内容（VERSION: 31 块 DESC "从 v31 降级到 v30"）不符，属于历史
//     注释错误；WP0 在此钉死运行时语义，避免后续 WP 按注释理解错方向。
library;

/// 权威数据库版本（lib/service/sqlite.dart `_dbVersion`）。
/// 由 inventory test 通过源码扫描守护，防止 embedded 脚本与权威版本漂移。
const int kInventoryCurrentDbVersion = 32;

/// 新库基线版本：kBaselineSchemaSql（example10.db 模板）建库后 user_version。
/// SqliteService._onCreate 在加密平台执行 baseline 后设置此值，再跑增量。
const int kInventoryBaselineSchemaVersion = 16;

/// 历史遗留最早受支持升级起点（旧表名形态：message / group_message / …）。
const int kInventoryLegacyBaselineVersion = 9;

/// 历史跳号：v15 块在 upgrade/downgrade 中均不存在（历史废弃）。
/// v14 → v16 是合法单步升级（planner 区间 (14,16] 只命中 16）。
/// 任何"连续整数完整性"校验必须排除此集合，否则会锁死 v14 存量装机。
const Set<int> kInventorySkippedVersions = {15};

/// upgrade.sql 中实际存在的 VERSION 块（22 块）。
///
/// 注意 VERSION:9 是**空占位块**（无 SQL、无 PRAGMA）：它表示"基线版本
/// 起点"，不承载任何升级语句；解析结果中它的 sqlStatements 为空列表。
const Set<int> kInventoryExpectedUpgradeBlocks = {
  9,
  10,
  11,
  12,
  13,
  14,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
};

/// downgrade.sql 中实际存在的 VERSION 块（14 块，含 VERSION:9 空占位）。
///
/// 有效降级边（块 N = N→N-1）：
///   31→30, 29→28, 28→27, 25→24, 24→23, 23→22, 22→21, 21→20, 20→19,
///   19→18, 18→17, 17→16, 10→9
const Set<int> kInventoryExpectedDowngradeBlocks = {
  9,
  10,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  28,
  29,
  31,
  32,
};

/// 已知缺失的降级块（块 N = N→N-1 边不存在），共 8 条。
///
/// 对应缺失降级边：
///   30→29 (has_purchased 回退)、27→26 (user_role/is_subscribed 回退)、
///   26→25 (last_seen_at 回退)、16→14 (contact 四表重建的逆,
///         因 v15 跳号实际为跨级边)、14→13、13→12、12→11、11→10。
///
/// ⚠️ 这是 WP0 基线的"已知缺口"登记。当前 planner 对降级方向**不做
/// 缺块校验**，这些缺口会被静默跳过（migrate() 拿到空/部分计划仍返回
/// success，sqflite 随后推进 user_version，造成 schema/版本静默错配）。
/// WP1 将把本清单转化为 fail-fast 断言：任何落到缺口边的降级请求必须
/// 抛 MissingMigrationPathException，禁止空计划成功。
const Set<int> kInventoryKnownMissingDowngradeBlocks = {
  11,
  12,
  13,
  14,
  16,
  26,
  27,
  30,
};

/// 受支持升级起点（研究文档 §6 测试矩阵口径）：v9 / v16 / v18 / v25 /
/// v29 / v30 → v31，外加全新安装（baseline+增量）。
const Set<int> kInventorySupportedUpgradeOrigins = {9, 16, 18, 25, 29, 30, 31};

/// 当前唯一声明可逆的生产降级窗口：v31 → v30（访问模型三列回退）。
const int kInventorySupportedDowngradeFrom = 31;
const int kInventorySupportedDowngradeTo = 30;
