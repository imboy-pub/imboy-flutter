# SQLite 迁移维护指南

本页记录可重复执行的维护方法，不保存某次测试成绩或发布结论。迁移版本以 `lib/service/sqlite.dart` 和 `lib/service/migrations/manifest_all.dart` 为准；当前源版本为 37。历史 v31 测试场景不能单独证明当前版本验收通过。

## 修改迁移

迁移边的唯一真源是 `kMigrationManifest` 聚合的 Dart 文件。新增边必须明确起止版本、SQL、数据损失、重同步要求、前置与后置条件及受影响对象。SQL asset 由 `tool/generate_sqlite_migrations.dart` 生成；不要单独修改生成 SQL。

```bash
dart run tool/generate_sqlite_migrations.dart
dart run tool/generate_sqlite_migrations.dart --check
bash scripts/run_sqlite_migration_gate.sh --local
```

Gate 的 `--local` 使用仓外临时目录，`--ci` 使用 ignored `build/sqlite-migration-gate`。退出码为 0 全部子项通过、1 子项失败、2 缺前提未执行、64 参数错误；缺依赖与未运行不能算通过。日志与发布证据应留在仓外，不回填为本页的固定成绩。

## 数据安全边界

升级和降级必须有完整路径；缺边由规划器拒绝，不能只修改 `user_version`。每条边的数据损失需与实际执行结果一致。32→31 恢复 `group.user_id_sum` 列时历史值置 0，31→30 会移除频道字段；“存在降级 SQL”不等于已验证旧版安装包兼容。

`DatabaseMigrationOrchestrator.prepareForOpen` 在迁移事务前执行预检与快照；`MigrationService` 在数据库版本回调事务内执行。不要在活动迁移事务内复制主数据库文件、关闭连接或覆盖库。快照和恢复由 `DatabaseSnapshotService` 管理；需同时验证 WAL 提交数据与加密库处理。损坏或密钥错误时保留原库，不能自动删库以伪装修复。

预检连接的所有失败出口都必须关闭句柄；降级 outbox 检查复用预检连接，不能递归等待正在初始化的业务连接。初始化固定 UID、环境和会话代次，过期会话不得发布连接或清理其他会话的快照。登出及登录补救清理须先等待初始化/密钥读写结束并关闭连接，再清理密钥；关闭失败时保留密钥并报告未完成。

SQLCipher 密钥命中 Apple 旧 accessibility 回退查询时，停止自动写回并保留原条目，等待无损原生迁移；重复条目错误也不得触发应用层删除重建。此约束不能证明原生插件内部的写入具有原子性，也不能仅凭当前配置宣称历史条目已迁到 ThisDeviceOnly，需真实保留安装验收。

显式快照恢复在同目录的独立暂存区保留原主库及 WAL/SHM/journal，最终验证成功后才清理。任何移动或验证失败都尝试还原完整文件集；若回滚未完成，`preservedOriginal` 为 false，错误中给出恢复目录，原件可能分布在该目录与原路径，不能清理这些文件。多文件移动不具备掉电原子性；当前没有自动恢复日志或重放流程，不能据此宣称已通过进程强杀/断电恢复验收。

Preflight handles close on every unsuccessful exit. Session-bound initialization drains before secret purge. Explicit restore retains the complete original file set until validation succeeds; failed rollback reports retained recovery files. This does not establish crash-atomic replacement or add automatic recovery.

本地消息、未发送数据和个人密钥不能默认视为云端可重建缓存。清缓存保留消息索引；删除聊天记录不自动恢复。账号切换、数据库与快照目录须隔离，测试只能使用合成数据。

## APP 数据库加密（I7D6LX）

Android、iOS 和 macOS 使用已锁定的 `sqflite_sqlcipher` 原生实现。每次加密开库都要求非空密钥，检查 `PRAGMA cipher_version`，并读取 `sqlite_master` 验证密钥后，才允许应用配置、建表和版本迁移。不能仅凭平台名称或依赖安装成功判断加密已经生效。当前锁定插件内置 SQLCipher 4.10.0；`cipher_status` 从 4.12.0 才提供，不能作为当前驱动的必需检查。

| 平台 | 当前全库加密边界 |
| --- | --- |
| Android / iOS / macOS | 非空密钥 + 原生 SQLCipher 检查；驱动或密钥异常即停止 |
| Windows / Linux / Web | 当前平台适配层未启用全库加密；不得声明已完成 SQLCipher 验收 |

密钥是 32 字节安全随机数的 64 位十六进制字符串，通过 `flutter_secure_storage` 保存，沿用 `db_cipher_key_<uid>` 命名。字符串作为原生插件的 password 传递，保留原有派生方式，不能改成 SQLCipher raw-key 语法后尝试打开旧库。数据库文件继续按环境和 UID 隔离；密钥未改名、未轮换，数据库 schema 不因此升级。

- **新数据库**：允许创建并持久化密钥；并发创建和显式删除串行执行，防止同一账号产生互相覆盖的密钥。
- **已有数据库**：只读取已有密钥；缺失或空值时停止，不写入一把无法解密旧库的新密钥。安全存储读写失败也不得降级为明文。
- **错钥、旧明文库或损坏库**：使用独立只读连接校验，失败保留文件。Android 的原生读写损坏处理可能删除文件，因此校验不能用默认读写开库。现有明文库没有自动转换入口；需要单独验收的恢复/迁移流程，不能以删库重建处理历史消息。
- **连接与快照**：加密连接禁用插件的同路径句柄复用；复用可能忽略新密码与回调。`SqliteService` 继续自行缓存业务连接，探测和快照独立关闭。快照服务只读打开源库，再由 `VACUUM INTO` 写出目标；目标继续用相同密钥校验。

原生验收入口为 `integration_test/sqlcipher_encryption_acceptance_test.dart`。它仅使用临时目录和合成密码，覆盖库文件/WAL 不含合成明文、新建后重开、无钥/错钥拒绝、旧明文原件保留，以及快照内容与主句柄独立性。该入口不模拟 Keychain/Keystore；宿主密钥测试只证明调用契约，仍需在签名后的真机包上验证安全存储持久化、重启和登出。

```bash
# 查看离线原生验收计划，不连接后端或自动执行设备任务。
python3 scripts/auto_test.py execution-plan --profile device-single \
  --platform android \
  --target integration_test/sqlcipher_encryption_acceptance_test.dart \
  --output /tmp/imboy-sqlcipher-plan.json
```

Android/iOS 需合格真机，macOS 使用原生驱动。发布前应按统一执行合同保留对应候选代码的实际结果；宿主 Mock/FFI 通过不能替代原生加密证明，也不能替代旧版本安装包升级/回退验证。加密不会恢复丢失的密钥，恢复失败不得静默重置本地数据。

Encryption is enforced for the declared native platforms before application callbacks. Existing database files never cause replacement key creation; failed probes preserve the file. Host tests establish control flow, while the offline native acceptance target establishes on-disk encryption and snapshot behavior. Device key-store persistence and release upgrade/rollback still require the signed application on supported devices.

参考：[原待办 I7D6LX](https://gitee.com/imboy-pub/imboy-flutter/issues/I7D6LX)、[SQLCipher 密钥校验与 API](https://www.zetetic.net/sqlcipher/sqlcipher-api/)、[sqflite 插件连接复用语义](https://github.com/davidmartos96/sqflite_sqlcipher/blob/master/sqflite/lib/sqflite.dart)。

## 验证入口

完整验收维度见 [迁移验证矩阵](./sqlite-migration-test-matrix.md)。Gate 包含生成器、规划器、缺边、事务回滚、schema fingerprint、快照、账户隔离及历史版本测试。运行前应核对脚本列出的实际测试文件与当前候选；不能把某次静态绿灯当作原生加密库或旧包回滚证明。

真机入口见 [原生迁移验证](../integration_test/sqlite_migration/README.md)，夹具维护见 [Fixture 指南](../test/fixtures/sqlite_migration/README.md)。Android 与 macOS 使用独立测试包和合成账号，保留升级前后数据；不能卸载或清数据后再声称验证了原位升级。若当前平台无法运行，记录未执行及原因，不静默删去该矩阵项。
