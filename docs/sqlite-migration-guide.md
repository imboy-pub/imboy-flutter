# SQLite 迁移维护指南

本页记录可重复执行的维护方法，不保存某次测试成绩或发布结论。迁移版本以 `lib/service/sqlite.dart` 和 `lib/service/migrations/manifest_all.dart` 为准；当前源版本为 32。历史 v31 测试场景不能单独证明当前版本验收通过。

## 修改迁移

迁移边的唯一真源是 `kMigrationManifest` 聚合的 Dart 文件。新增边必须明确起止版本、SQL、数据损失、重同步要求、前置与后置条件及受影响对象。SQL asset 由 `tool/generate_sqlite_migrations.dart` 生成；不要单独修改生成 SQL。

```bash
dart run tool/generate_sqlite_migrations.dart
dart run tool/generate_sqlite_migrations.dart --check
bash scripts/run_sqlite_migration_gate.sh --local
```

Gate 的 `--local` 使用仓外临时目录，`--ci` 使用 ignored `build/sqlite-migration-gate`。退出码为 0 全部子项通过、1 子项失败、2 缺前提未执行、64 参数错误；缺依赖与未运行不能算通过。日志与发布证据应留在仓外，不回填为本页的固定成绩。

## 数据安全边界

升级和降级必须有完整路径；缺边由规划器拒绝，不能只修改 `user_version`。每条边的数据损失需与实际执行结果一致。当前 32→31 恢复 `group.user_id_sum` 列时历史值置 0，31→30 会移除频道字段；“存在降级 SQL”不等于已验证旧版安装包兼容。

`DatabaseMigrationOrchestrator.prepareForOpen` 在迁移事务前执行预检与快照；`MigrationService` 在数据库版本回调事务内执行。不要在活动迁移事务内复制主数据库文件、关闭连接或覆盖库。快照和恢复由 `DatabaseSnapshotService` 管理；需同时验证 WAL 提交数据与加密库处理。损坏或密钥错误时保留原库，不能自动删库以伪装修复。

本地消息、未发送数据和个人密钥不能默认视为云端可重建缓存。清缓存保留消息索引；删除聊天记录不自动恢复。账号切换、数据库与快照目录须隔离，测试只能使用合成数据。

## 验证入口

完整验收维度见 [迁移验证矩阵](./sqlite-migration-test-matrix.md)。Gate 包含生成器、规划器、缺边、事务回滚、schema fingerprint、快照、账户隔离及历史版本测试。运行前应核对脚本列出的实际测试文件与当前候选；不能把某次静态绿灯当作原生加密库或旧包回滚证明。

真机入口见 [原生迁移验证](../integration_test/sqlite_migration/README.md)，夹具维护见 [Fixture 指南](../test/fixtures/sqlite_migration/README.md)。Android 与 macOS 使用独立测试包和合成账号，保留升级前后数据；不能卸载或清数据后再声称验证了原位升级。若当前平台无法运行，记录未执行及原因，不静默删去该矩阵项。
