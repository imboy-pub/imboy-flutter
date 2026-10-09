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

统一入口：`bash scripts/run_sqlite_migration_gate.sh --local` 或 `--ci`，详细规则见 [维护指南](./sqlite-migration-guide.md)。旧测试中的 v31 是历史场景；针对当前 v32 的结论必须另核覆盖范围，不能机械替换测试版本号或删除历史回归。空库、最小数据、边界数据、大库均需实际执行，行数不减少也不能代替字段值、约束与索引验证。
