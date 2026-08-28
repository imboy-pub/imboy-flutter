# SQLite 迁移测试 Fixture（WP0 基线冻结）

> 建立日期：2026-08-27 | 基线 HEAD：`b0d3eb33` | 计划：
> `docs/sqlite-migration-implementation-plan-2026-08-27.md` §Step 1

## 目的

为 SQLite 升级/降级治理（WP1–WP6）提供**从生产脚本真实构建**的版本化
测试夹具，替代散落在各测试里的手工内联 mini-DDL（现状：
`db_v30_channel_has_purchased_test.dart` 等各自维护一份近似 schema，
无法证明与真实迁移产物一致）。

## 文件

| 文件 | 职责 |
|---|---|
| `migration_inventory.dart` | 版本边事实清单（权威版本 31、期望块集合、8 条已知缺失降级边、v15 跳号）。WP1 将以它为真源做降级 fail-fast。 |
| `sqlite_migration_fixtures.dart` | fixture 生成器：解析 `-- VERSION:` 块、v9 legacy 最小 schema、`openFixtureDatabaseAtVersion()` 一键构建任意受支持版本、无 PII 合成种子行。 |

## 语义钉死（重要）

`assets/migrations/downgrade.sql` **文件头注释是错的**（声称
"VERSION 标记的是目标版本号"）。实际运行时语义（以
`migration_script.dart` 与块内容为准）：

- upgrade 块 `VERSION: N` = 边 **(N-1) → N**
- downgrade 块 `VERSION: N` = 边 **N → (N-1)**

例：downgrade `VERSION: 31` 块的 DESC 是"从 v31 降级到 v30"。

## 构建路径（与生产一致）

- **v16+**：`kBaselineSchemaSql`（= `_onCreate` 加密平台建库路径）
  → `PRAGMA user_version = 16` → 逐块执行 (16, version] 升级块。
- **v9–v15**：v9 legacy 最小 schema（旧表名 + v16 重建涉及的 4 张旧形态表）
  → 逐块执行 (9, version] 升级块（v15 无块自然跳过）。

## 无 PII 原则（强制）

- 种子行只用 `synthetic-*` 前缀字符串与固定合成整数
  （如 `synthetic-conv-001`、`990001`、`1700000000000`）。
- payload 一律 `{"synthetic":true}` 之类的合成 JSON，禁止真实消息正文。
- 禁止真实手机号、账号、token、密钥、E2EE 真实密文出现在任何 fixture。

## 已知现状复刻（待 WP2 收紧）

生产 `MigrationService.migrate` 通过字符串匹配吞掉所有
`duplicate column` 错误（v11/v12 块对 v10 已加列的重复 ALTER 依赖此行为
幂等）。fixture 升级执行器**复刻同一行为**以保证与生产迁移结果一致；
WP2 把生产吞错改为显式 precondition 时，必须同步收紧
`upgradeFixtureToVersion()`。

## 使用示例

```dart
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

final db = await openFixtureDatabaseAtVersion(version: 25, withSyntheticRows: true);
```

## 证据边界

本目录 fixture 及其测试均为 **sqflite_common_ffi in-memory 本地证据**，
不构成真机 SQLCipher、生产环境或发布验收证明（见计划 §2.1）。
