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

先在仓外设置 `REPORT_DIR`，沿用统一计划、机器事件和最终对账；以下均为明确专项，不能
据此宣称 full 通过：

```bash
# Host draft/configuration and schema contract; use macos on that host.
python3 scripts/auto_test.py execution-run --profile sqlite --platform linux \
  --target test/unit_test/service/migration_v38_fts_connection_test.dart \
  --target test/unit_test/service/migration_v38_fts_draft_test.dart \
  --target test/unit_test/service/schema_contract_test.dart \
  --target test/unit_test/store/repository/message_fts_repo_test.dart \
  --artifact-dir "$REPORT_DIR/fts-host"

# Chrome and the application's tracked WASM; no external fixture server.
python3 scripts/auto_test.py execution-plan --profile web \
  --target test/unit_test/service/migration_v38_fts_web_test.dart \
  --output "$REPORT_DIR/fts-web-plan.json"
python3 scripts/auto_test.py execution-run --plan "$REPORT_DIR/fts-web-plan.json" \
  --artifact-dir "$REPORT_DIR/fts-web"

# Inspect all native obligations before selecting a physical Android device,
# physical iOS device, or native macOS runner. No backend/account is required.
python3 scripts/auto_test.py execution-plan --profile device-single \
  --target integration_test/sqlcipher_fts_v38_draft_test.dart \
  --output "$REPORT_DIR/fts-native-all.json"
python3 scripts/auto_test.py execution-run --profile device-single --platform android \
  --target integration_test/sqlcipher_fts_v38_draft_test.dart \
  --artifact-dir "$REPORT_DIR/fts-native-android"
```

Web 合同固定 `SQLITE_WASM_URL=/fixtures/sqlite3.wasm`；该 fixture 是指向现有
`web/sqlite3.wasm` 的 Git 符号链接，避免复制二进制。需要可正常启动并建立测试本地 socket
的 Chrome；不在运行时下载替代 WASM。浏览器启动失败是 `ENV_MISSING`，不计业务执行。
也可使用既有 `Integration Tests` 手动工作流的 `profile=web`、`platform=web`、
`execute=true`，前提是已准备好 `self-hosted/imboy-test` runner；默认仅生成计划。
SQLCipher 目标使用临时数据库和合成密码，只能由真正支持加密的原生驱动满足；通过
`IMBOY_EXECUTION_DEVICE_ANDROID/IOS/MACOS` 指定设备。缺 SDK、浏览器或合格设备为
`ENV_MISSING`，主机 SQLite 探针不能代替原生证明。

注册 v38 前仍需绑定当前候选代码的真实 SQLCipher/安装二进制证据，并完成阅后即焚的
本地查询、远端回退和展示期到期验收。搜索结果已知期限取可信来源中较早者；接收方未读
不能以创建时间冒充已读。当前服务端搜索响应没有绝对 `expire_at`，仅远端保存的历史消息
无法由客户端独立证明其服务端期限；需先补齐该响应合同及隔离后端验收，不能通过隐藏所有
未过期 burn 消息、添加 skip 豁免或假造时钟消除阻塞。

**English:** v38 remains an unregistered draft. The shared production connection configurator
and draft schema checks are prerequisites, not native deployment evidence. Run the declared
host, Chrome/WASM and native SQLCipher instances separately and retain machine events and
receipts. Missing environments block execution. Existing direct-SQL skips remain unexpected.
Activation also requires current physical/native binary evidence and a verified server expiry
contract for remote-only burn history; do not infer a recipient's read time or hide valid
unexpired burn messages to make the gate pass.
