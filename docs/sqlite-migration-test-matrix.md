# SQLite 迁移测试矩阵（WP6）

> 日期：2026-08-27 | 权威版本：v31 | 唯一真源：
> `lib/service/migrations/manifest_all.dart` | Gate 脚本：
> `scripts/run_sqlite_migration_gate.sh`

## 统一入口

```bash
bash scripts/run_sqlite_migration_gate.sh --local   # 本地全量
bash scripts/run_sqlite_migration_gate.sh --ci      # CI（evidence 到 build/）
```

退出码契约：`0` PASS / `1` FAIL / `2` BLOCKED・NOT_RUN / `64` 参数错误。
子项失败不阻断后续子项，最终汇总含 PASS/FAIL/BLOCKED 与日志路径。

## 矩阵总表（自动化已覆盖 ✅ / 真机留验 🔶 / 不适用 ➖）

### 1. 升级矩阵（sqlite_migration_matrix_test.dart）

| 起点 → 终点 | 空库 | 最小数据 | 边界数据 | 大数据(800行) |
|---|---|---|---|---|
| fresh(baseline16)→31 | ✅ | ✅ | ✅ | ✅ |
| v9 → 31 | ✅ | ✅ | ✅ | ✅ |
| v16 → 31 | ✅ | ✅ | ✅ | ✅ |
| v18 → 31 | ✅ | ✅ | ✅ | ✅ |
| v25 → 31 | ✅ | ✅ | ✅ | ✅ |
| v29 → 31 | ✅ | ✅ | ✅ | ✅ |
| v30 → 31 | ✅ | ✅ | ✅ | ✅ |

每格断言：成功 + `user_version=31` + 关键 invariant + schema fingerprint
可计算 + 数据零丢失（行数不减少）。

- 加密逻辑路径：`DatabaseOpener` password 透传 ✅（逻辑证据）；
  真实 SQLCipher 加密/解密 🔶 WP7 真机。

### 2. 降级矩阵

| 边 | 结果 | 证据 |
|---|---|---|
| 31 → 30 | 允许（唯一受支持窗口）| ✅ 成功 + invariant + 数据影响与 manifest dataLoss 声明一致（visibility/access_type/join_policy 丢弃、type/消息保留）|
| 30 → 29 | 拒绝 | ✅ MissingMigrationPathException，打开失败，库/版本不变 |
| 27 → 26 | 拒绝 | ✅ 同上 |
| 26 → 25 | 拒绝 | ✅ 同上 |
| 31 → 25 | 拒绝 | ✅ 报告第一条缺边 30→29 + 全部缺失 [30,27,26] |

### 3. 故障注入

| 注入 | 预期 | 证据 |
|---|---|---|
| SQL 中途失败（缺表）| failure + 版本不推进 + 可重试（修复后成功）| ✅ |
| 约束错误（v9 contact NULL user_id → v16 重建撞 NOT NULL）| failure + 回滚 + 连接不关 + 版本不动 | ✅ |
| 空间不足（快照目录不可写）| prepareForOpen fail-closed 不迁移 | ✅ |
| 错误 key（opener 抛）| 预检 fail-closed | ✅ |
| 损坏库（垃圾字节）| 预检拒绝 + 原库字节原样保留 | ✅ |
| 快照中断（.tmp 残留）| 不覆盖 last good（原子 rename）| ✅（快照服务测试）|
| 进程被杀（迁移中）| **Android 真机 PASS（2026-08-27）**：am force-stop 命中 16→31 迁移事务 → 重开 user_version=16、quick_check ok、结构指纹==全新 v16、20k 种子行零丢失（sqlite_migration_kill_replay_test.dart + 外部编排） |
| 缺脚本 | planner/manifest 层 fail-fast | ✅（migration_missing_path_test）|

### 4. 快照与恢复（WP5 测试）

- WAL 未 checkpoint 的提交行进快照 ✅（VACUUM INTO 一致性）
- 恢复失败保留原库（preservedOriginal）✅；恢复成功数据/版本断言 ✅
- 多 uid 快照目录隔离 ✅；keepCount/maxAge 清理 ✅
- 真机：SQLCipher 快照加密继承 / 大库耗时 / 双进程窗口 🔶 WP7

### 5. 重复启动与幂等

- 已是 v31 的库再启动：无迁移、hash 稳定、数据可读写 ✅
- 迁移成功后重放同段迁移：precondition 承接重复 ALTER，库保持可用 ✅

### 6. 真机验收（WP7，需用户提供设备/安装包/账号）

> 执行材料已就绪（2026-08-27）：`integration_test/sqlite_migration/`
> （六步自足自动化脚本 + 手册与确认门）。当日实测华为 MRD-AL00
> 已连接但未获执行授权，维持 BLOCKED/PARTIAL。

- Android 真机：**自动化六步 PASS（2026-08-27，MRD-AL00）**——双路径指纹与
  本地逐字节同值、meta/application_id、WAL 快照+SQLCipher 加密继承（真机实证）、
  31→30 回退、30→29 拒绝、损坏恢复；证据 /tmp/.../device-android/summary.md。
  仍缺：旧版安装包人工回滚（M1/M2/M4）、kill -9 重放
- iOS 真机：同上（iOS 侧受保留区限制的构建窗口由用户确认）
- 快照加密继承（SQLCipher）实测
- 大库（真实量级）快照耗时/空间

## 子项 → 测试文件映射

| Gate 子项 | 文件 |
|---|---|
| 01 生成器一致 | tool/generate_sqlite_migrations.dart --check |
| 02 静态分析 | 本治理 owned 文件面（白名单）|
| 03 planner fail-fast | migration_script_planner / migration_missing_path |
| 04 manifest 契约 | migration_manifest_test |
| 05 原子失败 | migration_atomic_failure_test |
| 06 基线清单 | migration_baseline_inventory_test |
| 07 指纹 | schema_fingerprint_test |
| 08 golden contract | schema_contract_test |
| 09 快照服务 | database_snapshot_service_test |
| 10 协调器 | database_migration_orchestrator_test |
| 11 全矩阵 | sqlite_migration_matrix_test |
| 12 存量迁移回归 | v19→25 / v25 service / sync / encryption / uid isolation / db_* 系列 |
| 13 git diff --check | 仓库卫生 |

## 证据边界声明

本矩阵全部自动化项为 **sqflite_common_ffi 本地证据**。真机 SQLCipher、
生产环境、发布验收均以 WP7 真机证据为准；本文档不将本地 PASS 表述为
真机/生产 PASS。
