# SQLite 迁移 Fixture

夹具用于从生产迁移定义构建版本化 SQLite 库，只允许合成数据。维护合同见 [迁移指南](../../../docs/sqlite-migration-guide.md)。本目录的 SQL、schema golden 与生成器是可复用测试资产，应受版本控制；某次执行产生的数据库、密钥、日志和截图应放仓外。

`migration_inventory.dart` 记录版本边与已知缺边；`sqlite_migration_fixtures.dart` 提供建库及种子生成。v16 及之后版本由 baseline 与增量构建；较早版本使用 legacy 起点后逐块升级。构建目标及支持范围以实际函数与 manifest 为准。

升级 SQL 的 `VERSION: N` 表示目标边到 N，降级块表示从 N 离开；v15 历史跳号必须由规划器显式处理，不能把缺块都当作合法跳过。改生产迁移时同步验证夹具、schema golden、数据约束及生成物一致性，不能只修改测试预期来消除失败。

种子只用 `synthetic-*`、合成整数与合成 payload；禁止真实手机号、用户信息、token、密码、密钥或消息。golden 文件描述 schema，不保存一次运行的通过状态。
