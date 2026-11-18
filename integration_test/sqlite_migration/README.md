# 原生 SQLite 迁移验证

这是可重复执行的验证流程，不是某次验收成绩。维护合同见 [迁移指南](../../docs/sqlite-migration-guide.md)。使用独立测试安装包、合成账号和独占真机，不操作日常账号数据库；发布证据留在仓外，并绑定源提交、包哈希、设备/平台、前置库版本、命令、退出码及行为断言。

当前生产 schema 目标版本以 `lib/service/sqlite.dart` 的 `_dbVersion` 和 `lib/service/migrations/manifest_all.dart` 为准，**当前为 v40**。设备验收入口包含 STEP1–STEP7：STEP1–STEP6 保留既有迁移、快照、加密和恢复回归；**STEP7 专门覆盖 v39→v40 的 FTS 正文索引重建、rowid 复用、40→39 配对降级及 v39 快照恢复**。不要把 STEP1–STEP6 的历史目标版本误读为当前 schema 版本。

## 执行

在已准备好目标平台 SDK、签名和授权设备的环境中执行：

```bash
flutter test integration_test/sqlite_migration/sqlite_migration_device_acceptance_test.dart -d <DEVICE_ID>
```

通过要求是命令成功且每个适用断言均实际执行；仅有部分步骤、旧场景或宿主 FFI 测试通过，不能声称当前版本的设备验收全部通过。Android 与 macOS 平台项分别记录；不能以模拟器替代 Android 真机，也不能以 SQLCipher 参数测试替代真实加密库。

## 当前 v40 设备验收记录

截至 Flutter PR [#78](https://github.com/imboy-pub/imboy-flutter/pull/78) 合并提交 `49ff2fc32be4794a207e2fdb033ba163506c91a4`：

- **macOS：STEP1–STEP7，7/7 PASS**。STEP7 使用生产式 `openDatabase` version 回调，在原生 SQLCipher/FTS5 引擎执行 v39→40；核验迁移前快照、消息正文保持、旧索引词清除、FTS5 integrity-check、rowid 复用不回潮、40→39 contentless 读回及快照恢复。记录的 STEP7 fingerprint 前缀为 `05e82886`。
- **Android：BLOCKED-ENV**。因 MIUI USB 安装门未满足而未完成本轮设备执行；不得将其写成 PASS，也不得用模拟器结果替代。按同目录后续执行记录补齐设备、安装和证据后再更新状态。
- **其他平台**：没有本 PR 提供的对应设备验收证据，不据此推断通过。

PR #78 同时增加 60,000 行（两张消息表各 30,000 行）的 v40 规模化重建单元测试，并将 v40/v38/FTS-content 相关测试纳入迁移 gate 的 analyze 清单。该单元测试与设备 STEP7 是不同证据：规模化 FFI/单元测试通过不能替代原生 SQLCipher 设备验收。

PR #78 合并记录的专项结果：SQLite gate **156/156 PASS**；`gate --checks-only` **3/3 PASS**；macOS 设备验收 **7/7 PASS**。这些是该 PR 所记录的结果，不是每次重新执行本 README 命令都会自动成立的常驻成绩。当前 Android 设备义务仍为阻塞状态。

## 验收范围

- 两条建库路径 schema 一致；application_id、user_version、结构与数据校验正确。
- WAL 已提交行进入一致快照；真实加密继承与错误密钥拒绝。
- 支持的降级边数据损失符合声明；缺边安全拒绝。
- 恢复失败保留原库；迁移中断后安全重开。
- **v40 STEP7**：从真实 v39 库开始，执行生产式 39→40；确认 contentful FTS 重建仅保留当前消息正文、旧词消失、rowid 对齐和 integrity-check；删除最大 rowid 后复用不得命中旧词；执行配对 40→39，确认 contentless 索引读回为 NULL 且搜索仍可用；最后恢复迁移前 v39 快照并验证原消息数据保留。

旧包升级与回退使用保数据覆盖安装。先由旧包创建合成消息、会话与未发送数据，再安装新包检查迁移和历史，最后按明确支持的窗口安装旧包检查数据。卸载或清数据会破坏这一前提，不能用于证明回滚成功。STEP7 的数据库内 40→39 配对降级及快照恢复**不等于**已验证新旧应用包保留数据覆盖安装；两者必须分别取证。任何异常均先保留原库和日志；不点清除数据，不把自动重建当作无损恢复。

受保护的平台工程不能为取得绿色结果而临时改动。环境无法构建、签名或连接时记录未执行及原因；恢复环境后用相同候选重新验证。
