# IMBoy App SQLite 升降级治理实施计划

版本：1.0  
日期：2026-08-27  
目标仓库：`/Users/leeyi/project/imboy.pub/imboyapp`  
输入报告：`docs/sqlite-migration-strategy-2026-08-27.md`  
当前基线：`029ced9510e884f588cf174c98de829cd7ae4fb8`  
计划状态：READY；实施状态：WP0–WP6+WP8 完成（2026-08-27）；
WP7 BLOCKED（待用户确认设备/安装包/账号）→ 总体 PARTIAL（见 docs/sqlite-migration-release-gate.md）

## 1. 最终目标与验收口径

把当前 SQLite 迁移机制收敛为：

- 所有升级路径完整、原子、失败可回滚，禁止 schema/version 静默错配。
- 生产降级默认 fail-closed，只支持 manifest 明确声明且真实执行验证通过的边。
- 迁移快照在事务外生成且保证 WAL/SQLCipher 一致性。
- schema 有单一真源、可生成、可计算指纹、可在 CI 自动验证。
- Android/iOS 真机完成“上一稳定版回滚”验收；桌面 ffi 只作为本地结构证据。

最终 Gate 判定：

- `PASS`：WP0-WP8 全部完成，自动化 Gate 全绿，Android/iOS 真机证据齐全。
- `PARTIAL`：本地/CI 全绿，但任一真机或旧安装包回滚未完成。
- `BLOCKED`：环境、设备、旧安装包或插件能力不足，且已保留可复现证据。
- `FAIL`：出现数据丢失、版本号假成功、密钥/PII 泄漏、已有功能回归。

## 2. 全局执行规则

### 2.1 Preflight Lite

每个 Agent 开工前必须执行并保存输出：

```bash
cd /Users/leeyi/project/imboy.pub/imboyapp
git rev-parse --show-toplevel
git rev-parse HEAD
git status --short --untracked-files=all
```

规则：

- 本仓已有大量未提交改动；禁止 `git reset`、`git clean`、`git checkout --`、`git restore`。
- 禁止修改 `ios/*`、`macos/*`、`plugin/r_upgrade`。
- 只修改任务声明的 Owned files；发现重叠改动立即停止并报告。
- 不创建提交，除非用户另行确认 git author/committer 身份并明确要求。
- 测试 fixture、ffi、mock 不能称为真机 SQLCipher 或生产验收。
- 日志不得包含数据库密钥、消息正文、手机号、token 或其他 PII。

### 2.2 证据目录

运行证据只写入忽略目录或 `/tmp`，不得污染仓库：

```text
/tmp/imboyapp-sqlite-migration-<timestamp>/
  preflight.txt
  commands.log
  tests/
  schema/
  device-android/
  device-ios/
  final-summary.md
```

每个任务交付最少包含：状态、HEAD、改动文件、执行命令、退出码、通过数、失败摘要、未验证边界。

### 2.3 并行纪律

- 最多两个实现 Agent 并行；第三个并行槽只允许只读评审/资料核验。
- `lib/service/migration_service.dart`、`migration_script_planner.dart` 和新 manifest 核心由 Lane A 单一 Owner 管理。
- `assets/migrations/*`、`embedded_schema_scripts.dart` 的生成链由 Lane B 单一 Owner 管理。
- `.github/workflows/quality.yml` 当前已有用户改动，WP6 默认不得直接修改；先产出补丁建议，待确认无冲突后再落地。
- 集成点合并由主 Agent 串行完成，Worker 不可互相覆盖。

## 3. 依赖图与并行批次

```text
WP0 基线冻结
 ├─ WP1 降级 fail-fast（Lane A） ─┐
 └─ WP2 回滚/快照止血（Lane B） ─┤
                                  ├─ WP3 类型化 Manifest + 单一真源
                                  └─ WP4 Schema Contract/Hash
WP3 + WP4 ──> WP5 安全快照协调器
WP3 + WP4 + WP5 ──> WP6 自动化矩阵与 CI Gate
WP6 ──> WP7 Android/iOS 真机回滚验收
WP7 ──> WP8 最终审计、文档与发布决策
```

| 批次 | 可并行任务 | 进入条件 | 退出 Gate |
|---|---|---|---|
| B0 | WP0 | 无 | 基线与 fixture 可复现 |
| B1 | WP1 + WP2 | WP0 PASS | 两个 P0 风险均有失败测试和修复 |
| B2 | WP3 接口冻结后，WP3 实现 + WP4 并行 | B1 PASS | manifest 与 schema contract 可独立验证 |
| B3 | WP5；WP6 先写测试矩阵 | WP3/WP4 PASS | 快照恢复与自动化矩阵合流 |
| B4 | WP6 完整 Gate | WP5 PASS | 本地/CI PASS |
| B5 | WP7 Android 与 iOS 可并行 | WP6 PASS、设备/安装包可用 | 两端真机证据 |
| B6 | WP8 | WP7 完成或明确 BLOCKED | 最终 PASS/PARTIAL/NO-GO |

## 4. 通用任务执行模板

每个 Worker 必须复制并填写此模板：

```markdown
### Task <ID> — <标题>

Status: NOT_STARTED | IN_PROGRESS | PASS | FAIL | BLOCKED
Owner: <agent/lane>
Base HEAD: <sha>
Dependencies: <IDs>
Owned files: <exact paths>
Read-only files: <exact paths>
Out of scope: <explicit exclusions>

#### Intent
<本任务只解决什么问题>

#### Preconditions
- [ ] Git root 和 HEAD 已记录
- [ ] Owned files 与现有 dirty changes 无冲突
- [ ] 前置 Gate 已 PASS

#### TDD steps
1. 写出能复现问题的 RED 测试。
2. 单独运行并保存 RED 输出，确认失败原因正确。
3. 做最小实现使测试 GREEN。
4. 跑本任务定向测试、迁移回归组、`dart analyze`。
5. 检查 diff，只保留 Owned files。

#### Commands
<逐条列出，禁止用模糊占位符作为最终证据>

#### Acceptance
- [ ] <行为断言>
- [ ] <数据/版本断言>
- [ ] <无回归断言>

#### Stop conditions
- 发现用户已有改动重叠。
- 需要修改保留区或对外系统。
- 需要删库、真实账号写入或不可逆数据操作。
- 测试失败原因与预期不一致。

#### Evidence
- Commands/log: <path>
- Tests: <pass/fail count>
- Diff: <files>
- Remaining boundary: <not verified>
```

## 5. 工作包

## Step 1 — WP0 冻结基线与迁移 fixture

Status：PASS（2026-08-27，53/53；计划外发现 FTS 影子表/downgrade 注释语义）
Owner：主 Agent  
Dependencies：无  
Estimated weight：0.5 天

Owned files：

- `test/fixtures/sqlite_migration/README.md`
- `test/fixtures/sqlite_migration/` 下新增的无 PII fixture/生成说明
- `test/unit_test/service/migration_baseline_inventory_test.dart`

只读：全部迁移代码、SQL、现有测试。  
Out of scope：产品代码修改、真实用户数据库拷贝。

任务：

1. 记录实际版本 v31、upgrade/down block 列表、缺失边列表。
2. 建立无 PII 的 v9/v16/v18/v25/v29/v30/v31 最小 fixture 生成器或 SQL fixture。
3. 固化当前 39 个迁移测试基线。
4. 新增 inventory test：当前缺失降级边必须以“已知缺口”显式列出，后续 WP1 改为 fail-fast 断言。

自动测试：

```bash
flutter test \
  test/unit_test/service/migration_script_planner_test.dart \
  test/unit_test/service/embedded_schema_asset_sync_test.dart \
  test/unit_test/service/migration_downgrade_v19_to_v25_test.dart \
  test/unit_test/service/migration_downgrade_v19_to_v25_exec_test.dart \
  test/unit_test/integration/db_multi_version_upgrade_test.dart \
  test/unit_test/integration/db_multi_version_downgrade_test.dart \
  test/unit_test/integration/db_downgrade_v10_to_v9_test.dart \
  test/unit_test/integration/db_v30_channel_has_purchased_test.dart \
  --reporter expanded
```

验收：39/39 或更多 PASS；fixture 不含 PII；缺失边清单与代码一致。

## Step 2 — WP1 降级完整路径 fail-fast

Status：PASS（2026-08-27，MissingMigrationPathException + 跳号 allowlist 显式化）
Owner：Lane A  
Dependencies：WP0 PASS  
Estimated weight：1 天

Owned files：

- `lib/service/migration_script_planner.dart`
- `lib/service/migration_script.dart`
- `test/unit_test/service/migration_script_planner_test.dart`
- 新增 `test/unit_test/service/migration_missing_path_test.dart`

Out of scope：补写所有历史 down SQL、快照机制。

TDD：

1. RED：30→29、27→26、26→25、31→25 任一缺边必须抛出 `MissingMigrationPathException`，错误包含准确缺边。
2. RED：空脚本 map 的升级和降级均失败；`from == to` 仍为合法 no-op。
3. 实现显式边图校验；禁止通过“版本号跳号合法”掩盖缺边。历史特殊跳号必须在 manifest/allowlist 中显式声明。
4. 更新旧测试中“降级缺脚本仍按原样返回”的预期。

验收：

- 缺降级边不得返回空计划或 success。
- 异常能报告第一条缺边和完整 from/to。
- v25→18、v11→9 已有链继续 PASS。

## Step 3 — WP2 移除事务内危险恢复和宽泛错误吞噬

Status：PASS（2026-08-27，v9→31 全链经 migrate 首跑成功；precondition 替代吞错）
Owner：Lane B  
Dependencies：WP0 PASS  
Estimated weight：1 天

Owned files：

- `lib/service/migration_service.dart`
- 新增 `test/unit_test/service/migration_atomic_failure_test.dart`
- 必要时新增 `test/unit_test/helpers/fake_migration_database.dart`

Out of scope：正式 Backup API/VACUUM INTO 实现；只做 P0 止血。

TDD：

1. RED：SQL 中途失败时，`migrate()` 返回 failure/抛给上层，但不得关闭 Database。
2. RED：失败后 `user_version`、schema、样本行与迁移前一致。
3. RED：非预期 duplicate-column 必须失败，不能继续执行后续回填。
4. 移除 `_createSnapshot` 在回调事务中的调用以及 catch 内 `_restoreFromSnapshot`。
5. 将幂等兼容改为显式 precondition，不再字符串吞异常。

验收：失败只依赖 sqflite 外层事务回滚；测试能证明连接仍打开、数据未变化；无文件覆盖。

### B1 合并 Gate

主 Agent 串行合并 WP1/WP2 后运行：

```bash
flutter test test/unit_test/service/migration_script_planner_test.dart --reporter expanded
flutter test test/unit_test/service/migration_atomic_failure_test.dart --reporter expanded
flutter test test/unit_test/service/migration_downgrade_v19_to_v25_exec_test.dart --reporter expanded
dart analyze lib/service/migration_service.dart lib/service/migration_script.dart lib/service/migration_script_planner.dart
```

任何缺路径假成功或数据库被关闭均判 FAIL，禁止进入 B2。

## Step 4 — WP3 类型化 Migration Manifest 与单一真源

Status：PASS（2026-08-27，生成物与 .sql 字节级一致 54748/21811B；发现历史跨号边 v14→PRAGMA15）
Owner：Lane A  
Dependencies：B1 PASS  
Estimated weight：2–3 天

Owned files：

- 新增 `lib/service/migration_manifest.dart`
- 新增 `lib/service/migrations/*.dart`
- `lib/service/migration_script.dart`
- `lib/service/migration_script_planner.dart`
- `lib/service/migration_service.dart`（本批次 Lane A 独占）
- 新增 `tool/generate_sqlite_migrations.dart`
- 新增 `test/unit_test/service/migration_manifest_test.dart`

WP3 不直接修改 `assets/migrations/*` 和 `embedded_schema_scripts.dart`；只生成到临时目录，由 WP3 合流时主 Agent确认。

Manifest 每条边必须声明：ID、from/to、up、可选 down、reversible、dataLoss、requiresResync、pre/postconditions、affectedObjects。

并行微型 Gate：Lane A 先只提交 `migration_manifest.dart` 的只读接口和契约测试草案，由主 Agent确认接口后冻结；随后 Lane A 继续 WP3 实现，Lane B 才可并行启动 WP4。接口冻结后如需破坏性修改，必须先暂停 WP4 并由主 Agent重新协调。

验收：

- 目标路径完全由显式边构造，不再从注释/PRAGMA 猜方向。
- ID/from/to 唯一；不可逆边不能被 planner 用于降级。
- 生成器两次运行字节级一致。
- `MigrationService.targetVersion == SqliteService.dbVersion` 由测试守护；需为测试暴露只读版本 getter。

## Step 5 — WP4 Schema Contract、application_id 与 hash

Status：PASS（2026-08-27，三路径 fingerprint 收敛；发现并修复 P1 生产缺陷：fresh 建库丢 i_cv 索引）
Owner：Lane B  
Dependencies：B1 PASS，且 WP3 manifest 接口已通过微型 Gate 冻结  
Estimated weight：2 天

Owned files：

- 新增 `lib/service/schema_contract.dart`
- 新增 `lib/service/schema_fingerprint.dart`
- 新增 `test/fixtures/sqlite_migration/schema/*.json`
- 新增 `test/unit_test/service/schema_contract_test.dart`
- 新增 `test/unit_test/service/schema_fingerprint_test.dart`

只读：WP3 manifest 接口；不得修改 WP3 Owned files。

任务：

1. 规范化 `sqlite_schema`，排除 SQLite 内部对象并稳定排序。
2. 为 v9/v16/v25/v30/v31 生成 golden contract。
3. 定义固定非零 `application_id` 和 `_imboy_schema_meta` contract。
4. 关键业务 invariant：消息表、outbox、E2EE 引用、频道访问三字段、索引和外键。

验收：fresh v31、逐级到 v31、跨级到 v31 hash 相同；篡改一列/索引测试必失败；hash 不包含业务数据。

### B2 合并 Gate

```bash
dart run tool/generate_sqlite_migrations.dart --check
flutter test test/unit_test/service/migration_manifest_test.dart --reporter expanded
flutter test test/unit_test/service/schema_contract_test.dart --reporter expanded
flutter test test/unit_test/service/schema_fingerprint_test.dart --reporter expanded
dart analyze lib/service tool/generate_sqlite_migrations.dart
```

## Step 6 — WP5 事务外一致性快照与恢复协调器

Status：PASS（2026-08-27，本地 ffi；真机能力 CAPABILITY_PROBED 留 WP7；已接线 sqlite.dart 三回调）
Owner：Lane A  
Dependencies：WP3、WP4 PASS  
Estimated weight：3 天 + 真机能力核验

Owned files：

- 新增 `lib/service/database_snapshot_service.dart`
- 新增 `lib/service/database_migration_orchestrator.dart`
- `lib/service/sqlite.dart`
- `lib/config/init.dart`
- 新增 `test/unit_test/service/database_snapshot_service_test.dart`
- 新增 `test/unit_test/service/database_migration_orchestrator_test.dart`

策略顺序：运行时探测 Backup API/`VACUUM INTO`；若不可用，只允许“关闭唯一连接→checkpoint→复制 db/wal/shm→验证副本”。禁止活动事务中复制。

安全约束：

- 快照与主库同等级加密，按 env+uid 隔离。
- 空间不足、错误 key、损坏快照均 fail-closed。
- 有未同步 outbox 时禁止 destructive fallback。
- 恢复必须先关闭全部连接，替换后重新打开并验证 application_id、version、hash、quick/foreign key check。

自动测试：

- WAL 未 checkpoint 后快照仍含最新提交行。
- 快照中断不会覆盖有效旧快照。
- 恢复失败保留原库，不留下错误版本成功状态。
- 多 uid 快照互不访问。

验收：ffi 本地 PASS；Android/iOS 能力只能标记 CAPABILITY_PROBED，最终证据留给 WP7。

## Step 7 — WP6 全矩阵自动测试与 CI Gate

Status：PASS（2026-08-27，矩阵 38/38；Gate 13/13 exit 0；退出码契约 0/2/64 实测；quality.yml 已接 CI job）
Owner：Lane B  
Dependencies：WP3、WP4、WP5 PASS  
Estimated weight：2–3 天

Owned files：

- 新增 `test/unit_test/integration/sqlite_migration_matrix_test.dart`
- 新增 `scripts/run_sqlite_migration_gate.sh`
- 新增 `docs/sqlite-migration-test-matrix.md`
- `.github/workflows/quality.yml` 仅在主 Agent确认无现有改动冲突后允许修改

矩阵：

- fresh→31：加密/非加密逻辑路径。
- 9/16/18/25/29/30→31。
- 31→30；其余不可逆边必须拒绝。
- 每条边：空库、最小数据、边界数据、大数据。
- 注入：缺脚本、SQL 错、约束错、空间不足、错误 key、损坏 snapshot、进程中断。
- 重复启动和迁移重试。

统一入口：

```bash
bash scripts/run_sqlite_migration_gate.sh --local
bash scripts/run_sqlite_migration_gate.sh --ci
```

脚本退出码：0 PASS；1 FAIL；2 BLOCKED/NOT_RUN；64 参数错误。不得把 BLOCKED 当 PASS。

验收：失败项不阻断后续独立测试执行；最终汇总含 PASS/FAIL/BLOCKED/N/A 和日志路径；`git diff --check` PASS。

## Step 8 — WP7 Android/iOS 真机与旧版安装包回滚

Status：PARTIAL_DONE（2026-08-27：Android 自动化六步真机 PASS——用户授权后执行，SQLCipher 加密继承等三项 CAPABILITY_PROBED 转实证；iOS/旧包人工回滚/kill -9 未执行。是否接受为遗留待用户决策）
Owner：Android Lane 与 iOS Lane 可并行  
Dependencies：WP6 PASS；用户提供设备和可验证旧安装包  
Estimated weight：1–2 天

Owned files：仅 `integration_test/sqlite_migration_*` 与测试说明；禁止修改 `ios/*`。

人工确认点：

- 真机设备、旧/新安装包来源、测试账号和测试数据必须由用户确认。
- 不允许自动安装、登录、连接生产账号或删除设备数据库。

Android 与 iOS 分别执行：

1. 上一稳定版创建无 PII 样本：消息、会话、E2EE 引用、两类 outbox、频道权益。
2. 安装新版并升级到 v31；核对版本/hash/数据/功能。
3. 制造 WAL 活跃数据并执行快照能力测试。
4. 安装上一稳定版，验证 v31→v30 回退。
5. 验证不可逆路径被安全拒绝，原库仍可由新版打开。
6. 杀进程/重启恢复测试。

验收证据：设备型号、OS、App build、schema from/to、步骤时间、退出状态、脱敏截图/日志、数据断言。单个平台缺失则总体最多 PARTIAL。

## Step 9 — WP8 最终审计、文档与发布决策

Status：PASS（2026-08-27，发布决策 PARTIAL——唯一阻塞为 WP7 真机；见 docs/sqlite-migration-release-gate.md）
Owner：主 Agent + Flutter Reviewer + Security Reviewer  
Dependencies：WP7 完成或明确 BLOCKED  
Estimated weight：1 天

Owned files：

- 更新 `docs/sqlite-migration-strategy-2026-08-27.md`
- 更新本计划状态
- 新增 `docs/sqlite-migration-release-gate.md`
- 必要时更新 `lib/service/CLAUDE.md`、仓库 `CLAUDE.md` 的权威版本说明

最终审计：

- 代码/生成物/文档版本一致。
- 所有迁移边有 `reversible` 或 `irreversible` 明确结论。
- 无密钥/PII/业务正文进入日志或 fixture。
- 所有新增异常都有用户可恢复路径；不得静默返回空数据。
- 当前 dirty worktree 的非本任务改动保持不变。

最终命令：

```bash
bash scripts/run_sqlite_migration_gate.sh --local
dart analyze lib test/unit_test/service test/unit_test/integration
flutter test test/unit_test/service test/unit_test/integration --reporter expanded
git diff --check
git status --short --untracked-files=all
```

发布结论模板：

```text
SQLite migration release decision: PASS | PARTIAL | NO-GO
HEAD: <sha>
Upgrade paths: <passed>/<required>
Supported downgrade edges: <list>
Rejected downgrade edges: <list>
Android real device: PASS | BLOCKED
iOS real device: PASS | BLOCKED
Data-loss incidents: 0 required
Version/schema mismatch incidents: 0 required
Evidence root: <path>
Open blockers: <list>
```

## 6. Ready-to-paste Orchestrate 命令

说明：检测到 ECC plugin 模式；以下命令只生成/驱动对应工作包。不要一次启动有依赖关系的全部命令。每批次最多并行执行本计划标明的两个命令。

### WP0

```bash
/ecc:orchestrate custom "ecc:planner,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-1] 冻结当前 SQLite v31 迁移基线，建立无 PII 的 v9/v16/v18/v25/v29/v30/v31 fixture 或生成说明，并新增版本边 inventory 测试；严格保护 dirty worktree，仅修改 WP0 Owned files；Acceptance: 现有迁移组至少 39/39 PASS；缺失边清单与运行时代码一致；fixture 无 PII。"
```

### WP1（可与 WP2 并行）

```bash
/ecc:orchestrate custom "ecc:architect,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-2] 以 TDD 实现升级和降级完整路径 fail-fast，30→29、27→26、26→25 及跨边缺失均报告精确 MissingMigrationPathException，from==to 保持 no-op；只修改 WP1 Owned files；Acceptance: 缺边永不返回空计划或 success；现有 v25→18 与合成 v11→9 继续通过；定向 analyze 零问题。"
```

### WP2（可与 WP1 并行）

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:security-reviewer,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-3] 移除 MigrationService 在 sqflite 事务内的文件快照/恢复和宽泛 duplicate-column 吞错，以失败测试证明回滚后连接、版本、schema、样本行不变；只修改 WP2 Owned files；Acceptance: SQL 中途失败不关闭数据库；无主库文件覆盖；非预期重复列立即失败。"
```

### WP3（可与 WP4 并行）

```bash
/ecc:orchestrate custom "ecc:architect,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-4] 建立类型化 Migration Manifest 和确定性生成器，以显式 from/to/reversible/dataLoss/pre-postcondition 取代注释与 PRAGMA 推断；WP3 不直接覆盖 WP4 或用户 dirty 文件；Acceptance: 边 ID 和方向唯一；不可逆边降级被拒绝；生成器重复运行字节一致；targetVersion 与 dbVersion 契约测试通过。"
```

### WP4（可与 WP3 并行）

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:database-reviewer,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-5] 实现 application_id、规范化 sqlite_schema 指纹和 v9/v16/v25/v30/v31 schema contract/golden，覆盖消息、E2EE 引用、outbox、频道访问模型；只读消费 WP3 接口；Acceptance: fresh/逐级/跨级 v31 hash 一致；列或索引篡改必失败；hash 不含业务数据。"
```

### WP5

```bash
/ecc:orchestrate custom "ecc:architect,ecc:tdd-guide,ecc:security-reviewer,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-6] 实现事务外一致性加密快照与恢复协调器，运行时探测 Backup API/VACUUM INTO，fallback 仅允许关闭连接、checkpoint 后复制完整 db/wal/shm；Acceptance: WAL 最新提交进入快照；失败不覆盖原库；错误 key/空间不足 fail-closed；多 uid 隔离测试通过。"
```

### WP6

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-7] 建立 SQLite 全版本与故障注入自动测试矩阵及统一 Gate 脚本；暂不覆盖已有改动的 quality.yml，冲突时输出补丁建议；Acceptance: 9/16/18/25/29/30→31 与 31→30 有行为证据；不可逆边安全拒绝；退出码严格为 0/1/2/64；独立测试失败后继续汇总。"
```

### WP7

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:security-reviewer" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-8] 在用户确认设备、旧/新安装包和测试账号后执行 Android/iOS 真机 SQLCipher 升级与上一稳定版回滚验收；不得自动安装、登录或删库；Acceptance: 两端记录 build/schema/hash/数据断言；v31→v30 通过；不可逆路径拒绝且原库可由新版重开；缺任一平台标 PARTIAL。"
```

### WP8

```bash
/ecc:orchestrate custom "ecc:flutter-reviewer,ecc:security-reviewer,ecc:code-reviewer,ecc:doc-updater" "[Plan: docs/sqlite-migration-implementation-plan-2026-08-27.md#step-9] 对全部 SQLite 迁移改动做 Flutter、安全、通用代码和文档终审，运行本地 Gate 并形成 PASS/PARTIAL/NO-GO 发布决策；Acceptance: 数据丢失和 version/schema mismatch 均为 0；无密钥/PII 泄漏；非本任务 dirty changes 未改变；证据与未验证边界完整记录。"
```

## 7. 主 Agent 每批次合流模板

```markdown
Batch: <B0-B6>
Input HEAD: <sha>
Workers: <WP IDs>
Dependency Gate: PASS | FAIL | BLOCKED

1. 收集各 Worker 的状态、命令、退出码和 Owned files。
2. 检查重叠：`git diff --name-only` 必须落在声明范围。
3. 逐个运行定向测试，不直接信 Worker 摘要。
4. 运行本批次合并 Gate。
5. 检查 `git diff --check` 与完整 `git status`。
6. 判定：
   - PASS：进入下一批次。
   - FAIL：回到失败 WP，禁止扩大范围。
   - BLOCKED：记录同一阻塞条件、可复现命令和所需外部条件。
7. 输出 evidence root；不得将本地 PASS 表述为真机/生产 PASS。
```

## 8. 完成定义

- [ ] WP0-WP6 自动化全部 PASS。
- [ ] WP7 Android/iOS 均有真实设备证据，否则结论最多 PARTIAL。
- [ ] 所有支持升级起点到 v31 都有可执行测试。
- [ ] 只承诺清单内的降级边，其余均 fail-closed。
- [ ] WAL/事务/SQLCipher 快照经过故障注入验证。
- [ ] schema 单一真源、生成物一致、hash/golden 可复现。
- [ ] 数据丢失事故为 0；假成功为 0；密钥/PII 泄漏为 0。
- [ ] 用户已有 dirty changes 未被重置、覆盖或混入。
- [ ] 发布结论明确为 PASS、PARTIAL 或 NO-GO，不使用含糊的“基本完成”。
