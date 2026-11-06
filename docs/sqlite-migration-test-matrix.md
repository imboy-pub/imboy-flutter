# SQLite 迁移验证矩阵

本表是维护与验收要求，不是通过报告。版本、降级边及数据损失从 `kMigrationManifest` 读取，当前目标以源码为准；执行记录绑定实际提交、命令、退出码和原始日志，保存在仓外。

| 验证面 | 必须证明的结果 | 主要入口 |
|---|---|---|
| 生成器 | SQL asset 与 Dart manifest 一致 | `tool/generate_sqlite_migrations.dart --check` |
| 迁移图 | 完整路径、顺序正确，缺边明确拒绝 | `migration_script_planner_test`、`migration_missing_path_test`、`migration_manifest_test` |
| 新库与历史升级 | 两类建库路径及历史起点到目标版本 schema 一致，保留有效数据 | `sqlite_migration_matrix_test`、`db_multi_version_upgrade_test`、schema contract 测试 |
| 降级 | 存在完整支持路径才执行；数据损失符合声明，缺边保持原库与版本 | `db_multi_version_downgrade_test`、降级专项 |
| 失败回滚 | SQL/约束失败版本不推进，原数据保留，修复后可重试 | `migration_atomic_failure_test` |
| 快照与恢复 | WAL 已提交数据进入一致快照，原子保存，恢复失败保留原库 | `database_snapshot_service_test`、`database_migration_orchestrator_test` |
| 账户隔离 | 不同 uid 库、密钥和快照不能交叉复用 | `sqlite_uid_isolation_test`、快照专项 |
| 加密与原生 | 实际平台正确传密码、拒绝错误密钥，快照保持加密 | 原生设备验收 |
| 中断恢复 | 迁移期间杀进程后可完成或安全拒绝，无静默数据丢失 | 原生 kill replay |
| 旧包回退 | 保留应用数据的实际覆盖安装后，旧包能读取合同内的数据 | 原生安装与旧包验证 |

统一入口：`bash scripts/run_sqlite_migration_gate.sh --local` 或 `--ci`，详细规则见 [维护指南](./sqlite-migration-guide.md)。旧测试中的 v31 是历史场景；针对 manifest 当前版本的结论必须另核覆盖范围，不能机械替换测试版本号或删除历史回归。空库、最小数据、边界数据、大库均需实际执行，行数不减少也不能代替字段值、约束与索引验证。

## 消息 FTS v38 的注册前验证 / Message FTS v38 admission

当前生产版本由 manifest 决定，仍为 **37**。`upgradeV38Fts` 是显式应用于隔离测试库的草稿；
结构合同支持验证 v38 不表示它已注册。两个直写 SQL 同步用例的原有 skip 继续由统一运行器
记为 `UNEXPECTED_SKIP`，不签发完整 PR/覆盖率通过。禁止为了消除 skip 提前注册迁移。

生产开库和 FFI/Web/SQLCipher 草稿测试共用 `SqliteService.configureConnection`：每次连接
设置并读回 `recursive_triggers=1`，驱动不支持或未确认时开库失败。v38 结构合同继承 v37
业务列与 TEXT 消息 ID 约束，并对照同一份迁移 SQL 检查两组视图、FTS 表和十个触发器。
查询使用消息行的撤回、墓碑、解密状态及聊天同源的到期期限；索引仍有旧词也不能直接返回
已失效正文。失效候选不占最终结果上限。

宿主 FTS 和离线 Chrome/WASM 目标均进入现有 PR 计划，Chrome 使用主 CI 的 Ubuntu
矩阵 worker，与宿主沿用同一计划、机器事件和最终对账。CI 覆盖率仍只收集 Linux 分片，
不会为 Chrome 再选或重跑一份目标。PR 纳入 Web 不代表 SQLCipher 真机验收或 v38 已注册。

先在仓外设置 `REPORT_DIR`；以下命令用于单独重跑明确专项，不能据此宣称 full 通过：

```bash
# Host draft/configuration and schema contract; use macos on that host.
python3 scripts/auto_test.py execution-run --profile sqlite --platform linux \
  --target test/unit_test/service/migration_v38_fts_connection_test.dart \
  --target test/unit_test/service/migration_v38_fts_draft_test.dart \
  --target test/unit_test/service/schema_contract_test.dart \
  --target test/unit_test/store/repository/message_fts_repo_test.dart \
  --artifact-dir "$REPORT_DIR/fts-host"

# Re-run the PR Chrome target with the tracked WASM; no external fixture server.
python3 scripts/auto_test.py execution-plan --profile web \
  --target test/unit_test/service/migration_v38_fts_web_test.dart \
  --output "$REPORT_DIR/fts-web-plan.json"
python3 scripts/auto_test.py execution-run --plan "$REPORT_DIR/fts-web-plan.json" \
  --artifact-dir "$REPORT_DIR/fts-web"

# Inspect all native obligations. No backend/account is required for this target.
python3 scripts/auto_test.py execution-plan --profile device-single \
  --target integration_test/sqlcipher_fts_v38_draft_test.dart \
  --output "$REPORT_DIR/fts-native-all.json"

# Set ANDROID_DEVICE_ID to the verified physical device ID, never an emulator.
IMBOY_EXECUTION_DEVICE_ANDROID="$ANDROID_DEVICE_ID" \
python3 scripts/auto_test.py execution-run --profile device-single --platform android \
  --target integration_test/sqlcipher_fts_v38_draft_test.dart \
  --artifact-dir "$REPORT_DIR/fts-native-android"

# Run on a macOS host with the native SQLCipher implementation.
IMBOY_EXECUTION_DEVICE_MACOS=macos \
python3 scripts/auto_test.py execution-run --profile device-single --platform macos \
  --target integration_test/sqlcipher_fts_v38_draft_test.dart \
  --artifact-dir "$REPORT_DIR/fts-native-macos"
```

FTS 草稿与离线群消息两个 Web 目标共用固定 `SQLITE_WASM_URL=/fixtures/sqlite3.wasm`；
该 fixture 是指向现有 `web/sqlite3.wasm` 的 Git 符号链接，避免复制二进制。
需要可正常启动并建立测试本地 socket
的 Chrome；不在运行时下载替代 WASM。浏览器启动失败是 `ENV_MISSING`，不计业务执行。
`execution-plan --profile web` 可查看全部浏览器目标，`execution-run --plan` 可单独重跑。
也可使用既有 `Integration Tests` 手动工作流的 `profile=web`、`platform=web`、
`execute=true`，前提是已准备好 `self-hosted/imboy-test` runner；默认仅生成计划。
真实后端、设备配对等外部任务仍保留明确手动用途，不因离线 Web 进入 PR 恢复自动触发。
SQLCipher 目标使用临时数据库和合成密码，只能由真正支持加密的原生驱动满足；通过
`IMBOY_EXECUTION_DEVICE_ANDROID/IOS/MACOS` 指定设备。缺 SDK、浏览器或合格设备为
`ENV_MISSING`，主机 SQLite 探针不能代替原生证明。

原生入口从真实 baseline 执行 16→37，使用完整的 v37 schema 和合成消息/会话数据，再
显式应用 v38 草稿。它检查字段值保持、旧索引重建、加密快照、独立错误密钥连接拒绝、
DDL/版本/meta/数据写入后的事务失败回滚、关闭重开和成功重试；同时保留独立连接的
recursive trigger、REPLACE/UPSERT 与 WAL 可见性验证。这些断言只有在原生运行后才是
证据，静态分析或宿主 FFI 不能代替。该入口不安装新旧应用包，不证明保留数据的覆盖升级、
旧包回退或进程被杀后的恢复。

### 远端到期合同 / Remote expiry contract

[后端 PR #37](https://github.com/imboy-pub/imboy/pull/37) 补齐 C2C/C2G 搜索 formatter 的
`expire_at` 透传，复用已有 REST 时间转换：JSON 字段为 epoch **毫秒**或 `null`。
客户端经 `ApiTime.parseEpochMillis` 读取并在 JSON 往返中保留；不按数字长度猜秒/毫秒，
缺失或非法值保持未知。0/负值按真实过去时刻处理，已知期限取远端与本地事实的较早者；
接收方未读不能以创建时间冒充已读。未下载过本地行的历史也按服务端绝对期限过滤并在
展示期间到期，不需要再次搜索。筛掉结果仍保留原页条数，避免提前结束后续分页。

Flutter 定向验证复用统一 PR 入口，精确目标可在无设备环境执行：

```bash
python3 scripts/auto_test.py execution-run --profile pr --platform linux \
  --target test/unit_test/store/api/fts_api_test.dart \
  --target test/unit_test/page/search/message_search_provider_test.dart \
  --target test/unit_test/page/search/message_search_local_pagination_test.dart \
  --artifact-dir "$REPORT_DIR/fts-expiry-client"
```

后端四个模块接入既有已迁移、带中文分词配置的隔离 PostgreSQL CI：`fts_logic_tests`、
`fts_handler_tests`、`fts_user_ds_tests`、`fts_user_repo_tests`。本地在同等合成测试库、
测试配置及依赖就绪后，可从后端仓执行：

```bash
IMBOYENV=local make eunit-local EUNIT_CONFIG=config/sys EUNIT_USE_RELAY=0 \
  EUNIT_MODS='fts_logic_tests fts_handler_tests fts_user_ds_tests fts_user_repo_tests'
```

响应测试真实执行 logic→REST 时间转换→JSON，覆盖 C2C/C2G 的绝对期限及 null；真实 PG
三态回归目前覆盖 C2C 的 null/未来/过去期限。它们不是部署后的双端 HTTP 验收，模拟响应
也不能代替该数据库证据。CI 要求四个模块都有非零、无失败/跳过的 XML 和成功进程结果，
上传 `fts-expiry-contract` 工件；缺数据库不能退化为零执行通过。

### 尚待取得的注册证据 / Outstanding admission evidence

注册 v38 前仍需绑定当前候选代码的真实 SQLCipher/安装二进制证据，并完成阅后即焚的
本地查询、隔离后端远端回退和展示期到期验收。沿用原项目已裁决的 Android 真机 + macOS
App 范围；暂缓的 iOS 不升级为本次前置修复 PR 的新合并条件，其 catalog/full 义务仍保留，
不能据此宣称全平台通过。保留原数据的新旧包升级、旧目标安全拒绝及实际中断证据应另附
确切包版本、哈希、设备、命令与机器结果；本地草稿 fixture 不满足这些条件。
v38 声明 `reversible: false` 且没有 38→37 降级边，旧包必须按现有协议安全拒绝而不破坏库，
或使用已验证的快照恢复流程；不要求凭空成功降级，也不能临时添加降级边掩盖风险。
既有 v31 安装/16→31 kill replay 是历史回归，不能重标为本次 37→38 二进制证据。

只有实际证据满足注册条件后，才注册 manifest、重生成迁移资产并移除原来两个针对
生产当前版本的 skip，随后重跑 Linux/macOS PR 和覆盖率对账。不能通过隐藏所有未过期
burn 消息、添加 skip 豁免、改为草稿 fixture 或假造时钟消除阻塞。缺原生环境为
`ENV_MISSING`，现有两个被选中的直写用例继续为 `UNEXPECTED_SKIP`，两个原因不可混写。

**English:** v38 remains an unregistered draft. The shared production connection configurator
and draft schema checks are prerequisites, not native deployment evidence. Run the declared
host, Chrome/WASM and native SQLCipher instances separately and retain machine events and
receipts. Offline Chrome/WASM now runs in the existing PR Ubuntu matrix and can be rerun with
the same `web` profile; coverage remains Linux-only. Missing environments block execution.
Existing direct-SQL skips remain unexpected.
The native fixture now uses the real v37 schema and tests encrypted snapshots, rollback and
retry, but does not install old/new applications. The companion backend PR #37 preserves
absolute expiry in milliseconds; client tests cover unseen remote history and display-time
expiry. Audit backend, client, native and retained-data binary evidence separately. Activation
still requires those real results; preserve the existing Android/macOS scope decision and the
separate iOS/full obligations. Do not infer a recipient's read time or hide valid unexpired burn
messages to make the gate pass.
