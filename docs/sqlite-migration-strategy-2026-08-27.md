# IMBoy App SQLite 升级与降级最优方案

生成日期：2026-08-27  
审计基线：`029ced9510e884f588cf174c98de829cd7ae4fb8`  
结论等级：**PARTIAL（升级基本可用，降级存在静默错配和备份一致性风险）**

## 1. 执行摘要

当前实现已经具备版本化脚本、升/降序规划、sqflite 事务回滚、完整性检查、SQLCipher、按账号隔离、内嵌脚本与 asset 同步测试，基础方向正确；已覆盖的迁移测试本轮实跑 39/39 PASS。

但它尚不适合宣称“完整支持 App 降级”：

1. 当前 schema 权威版本是 v31，但降级脚本缺少 v30、v27、v26 等边，规划器只对升级缺块 fail-fast，降级可能空计划后返回成功。
2. `MigrationService` 在 sqflite 已开启的版本迁移事务内直接复制主 `.db` 文件；WAL 或事务活跃时，单独复制数据库文件不是一致性快照。
3. 迁移失败时又在回调事务尚未完成的情况下关闭连接并覆盖原数据库文件，和 sqflite 的事务回滚职责冲突，存在句柄失效、WAL/SHM 不匹配风险。
4. 迁移执行器通过字符串匹配忽略所有 `duplicate column`，可能把脚本漂移或错误版本状态伪装成成功。
5. 同时维护 SQL asset 与 Dart 内嵌常量虽然有同步测试，但仍是双真源，增加人为漏同步概率。
6. 新库路径在不同平台不一致：加密平台从 v16 baseline 建库后跑增量；非加密平台复制 `example10.db`，需要持续证明两条路径最终 schema 完全等价。

最优策略不是为所有历史版本维护完全可逆 SQL，而是：**升级始终保数据且必须有完整迁移图；生产降级默认 fail-closed；只对“当前版 → 上一稳定版”的明确兼容窗口提供经过测试的有损降级；无法安全回退时保留加密快照并重建可从服务器恢复的缓存数据。**

## 2. 当前实现审计

### 2.1 已做对的部分

- `_dbVersion = 31`，sqflite 在 `onUpgrade/onDowngrade` 中触发迁移。
- `MigrationScriptPlanner` 升级升序、降级降序，避免跨版本依赖逆序。
- 升级目标块缺失时抛异常，防止版本号推进但 schema 未变化。
- `integrity_check` 与 `foreign_key_check` 同时使用；SQLite 官方说明前者不覆盖外键错误，两者组合是正确做法。
- `onConfigure` 启用外键、busy timeout；`onOpen` 开 WAL。
- SQLCipher 密钥按 uid 隔离，并避免把 key mismatch/损坏库误删成“明文迁移”。
- `embedded_schema_asset_sync_test` 防止运行时内嵌脚本与参考 SQL 漂移。

### 2.2 当前版本图

升级边：v9、10、11、12、13、14→15、16、17、18、19、20、21、22、23、24、25、26、27、28、29、30、31。  
降级边：31→30、29→28、28→27、25→24、24→23、23→22、22→21、21→20、20→19、19→18、18→17、17→16、10→9。

明确缺口：

- 30→29：`has_purchased` 没有回退边。
- 27→26：`user_role/is_subscribed` 没有回退边。
- 26→25：`last_seen_at` 没有回退边。
- 16→15、15→14、14→13、13→12、12→11、11→10：没有完整生产降级链。

其中 v30→v29 的缺块最危险：调用者请求降级时 planner 可能返回空计划，`migrate()` 仍返回 success；sqflite 随后把版本设为目标值，造成“schema 仍像 v30、版本号却是 v29”。

### 2.3 风险分级

| 风险 | 等级 | 后果 |
|---|---:|---|
| 降级缺块静默成功 | P0 | schema/version 撒谎，后续升级无法可靠判断状态 |
| 活跃事务/WAL 下 `File.copy(db.path)` | P0 | 快照可能缺 WAL 内容或复制到混合页 |
| 迁移 catch 内关闭并覆盖活动数据库 | P0 | 与外层事务回滚冲突，句柄和 sidecar 状态不一致 |
| 忽略任意 duplicate-column 错误 | P1 | 真实迁移缺陷被吞掉，约束/数据回填可能没执行 |
| 双真源 SQL | P1 | 人工维护负担，测试未运行时易漏同步 |
| 只验证四张消息表 | P1 | v20-v31 新表/字段缺失无法被最终 schema 校验发现 |
| 两条新库创建路径 | P1 | SQLCipher 与非加密平台可能产生不同 schema |
| 每个迁移块跑完整 `integrity_check` | P2 | 大库升级耗时和启动阻塞线性放大 |

## 3. 行业与官方约束

1. sqflite 明确说明 `onCreate/onUpgrade/onDowngrade` 已在事务中；回调抛错会回滚，不应在回调内另开事务或自行覆盖数据库文件。[sqflite 文档](https://pub.dev/packages/sqflite)
2. sqflite 把降级定义为罕见场景并建议尽量避免；官方同时提供“降级直接报错”和“删除重建”两种明确策略，而不是静默跳过。[openDatabase API](https://pub.dev/documentation/sqflite/latest/sqflite/openDatabase.html)、[onDatabaseVersionChangeError](https://pub.dev/documentation/sqflite/latest/sqflite/onDatabaseVersionChangeError.html)
3. SQLite 官方指出，事务进行中直接复制主数据库可能产生损坏快照；WAL/journal 存在时必须一起处理。安全方案是 Online Backup API、`VACUUM INTO`，或在无活动事务时复制完整文件集合。[SQLite 防损坏说明](https://www.sqlite.org/howtocorrupt.html)、[Online Backup API](https://www.sqlite.org/backup.html)
4. `VACUUM INTO` 可以生成一致性快照，但不能在当前连接的活动事务中执行；因此快照必须在版本迁移事务开始前完成。[VACUUM INTO](https://sqlite.org/lang_vacuum.html)
5. Android Room 的成熟策略也是：缺迁移路径默认抛错；只有明确接受丢失本地数据时才启用 destructive fallback，并允许把它限制为降级场景或指定起始版本。[Room 迁移指南](https://developer.android.com/training/data-storage/room/migrating-db-versions)
6. `PRAGMA user_version` 只是应用自用整数，SQLite 不验证它与 schema 的一致性，因此应用必须自己维护 schema 指纹和迁移图。[SQLite PRAGMA](https://www.sqlite.org/pragma.html)

## 4. 推荐目标架构

### 4.1 策略矩阵

| 场景 | 策略 | 数据处理 |
|---|---|---|
| 正常升级 N→M | 必须存在完整有向路径；事务内执行；任一步失败即回滚 | 全量保留 |
| 同一发布窗口降级 N→N-1 | 仅当 manifest 标注 `reversible` 且真实库测试通过才执行 | 明确列出有损字段/表 |
| 跨多个生产版本降级 | 默认拒绝打开写库，展示恢复指引 | 保留原库与安全快照 |
| 缺降级路径但本地全为可重建缓存 | 用户/产品策略明确允许后，安全快照→删除整套 db/wal/shm→按旧版重建→服务端重同步 | 本地未同步数据必须先导出或阻止操作 |
| 库损坏或密钥不匹配 | 绝不自动删库；隔离原文件并进入恢复流程 | fail-closed |

### 4.2 单一迁移清单

用 Dart 类型化 manifest 作为唯一真源，每条边包含：

- `fromVersion`、`toVersion`，禁止用含混的 `VERSION: N` 同时表达两种方向。
- `up`、可选 `down`；没有 `down` 就明确 `irreversible`。
- `dataLoss`、`requiresResync`、`minAppVersion`。
- `preconditions`、`postconditions`、涉及表、schema 指纹。
- 独立稳定 ID，例如 `20260827_channel_access_model_v31`。

SQL asset 和内嵌常量改为构建期自动生成物，不再手工复制。CI 校验生成物无 diff。

### 4.3 执行状态机

1. 只读打开或预检：读取 `user_version`、`application_id`、迁移状态表、SQLite/SQLCipher 能力。
2. 解析迁移图：要求从当前版本到目标版本的每一条边存在且方向正确。
3. 迁移前检查：磁盘空间、未同步 outbox、`quick_check`、`foreign_key_check`。
4. 在事务外创建一致性快照；优先插件暴露的 Backup API，其次验证运行时支持后使用 `VACUUM INTO`。若均不可用，先关闭唯一连接并 checkpoint，再复制 db/wal/shm，禁止只复制主文件。
5. 进入 sqflite 版本事务，逐边执行。不要在脚本里设置 `PRAGMA user_version`，由框架在整个迁移成功后一次性推进。
6. 每边执行结构/业务 postcondition；最终执行 schema 指纹、`foreign_key_check` 和 `quick_check`。完整 `integrity_check` 放在低频/发布验收，不必每一边都全库扫描。
7. 失败直接 throw，让 sqflite 回滚；不要在 catch 内关闭或覆盖活动数据库。事务完成且连接关闭后，恢复协调器才可执行文件级恢复。
8. 成功记录迁移耗时、from/to、迁移 ID、失败阶段、错误码；不得记录消息正文、密钥或 PII。

### 4.4 schema 身份与断言

- 设置固定 `application_id`，拒绝打开不属于 IMBoy 的 SQLite 文件。
- 新增 `_imboy_schema_meta`：`schema_version`、`schema_hash`、`last_migration_id`、`migration_state`。
- `schema_hash` 由规范化后的 `sqlite_schema` 生成，CI 保存每个受支持版本的 golden。
- 启动时同时验证 `user_version == expected` 与 hash/关键 invariants；不能只信版本整数。
- 将 `_verifyTableStructure` 从四张消息表扩展为每版本声明式 schema contract。

### 4.5 兼容发布纪律

数据库可降级的核心不是 down SQL，而是“新旧 App 同时能读写一段时间”：

1. Expand：先新增 nullable/default 列或新表，旧 App 不受影响。
2. Migrate：回填/双写，读路径兼容新旧表示。
3. Contract：至少跨过一个明确的回滚窗口后，再删除旧列/旧表。

对 v31 的访问模型，保留旧 `type` 是正确的 expand 设计；在旧版仍可能回滚期间必须继续维护 `type` 与三字段的一致映射。否则 v31→v30 虽能重建表，旧版看到的 `type` 也可能已陈旧。

## 5. IMBoy 落地顺序

### Gate 0：立即止血（P0）

- 降级规划器和执行器改为：目标范围内任何所需边缺失都抛错；禁止空计划 success。
- 删除 migration catch 内 `_restoreFromSnapshot(db, ...)`；只保留事务回滚。
- 暂时取消不安全的 `File(db.path).copy()` 快照，直到有一致性实现。
- 删除通用 duplicate-column 忽略；需要幂等时用显式 schema precondition 或单条迁移专用兼容逻辑。
- 为 v31→30→29→28→27→26→25 建立完整测试矩阵；缺边先默认拒绝，不急于伪造 down SQL。

验收：缺任一边必然 RED；迁移失败后原库 hash、版本、数据不变；不会关闭外层事务句柄。

### Gate 1：统一迁移真源

- 引入类型化 manifest 和生成器。
- 自动生成 upgrade/down SQL 参考文件与 embedded Dart。
- 为 v9/v16/v25/v30/v31 保存 schema golden。
- 新库、逐级升级、跨级升级三条路径最终 hash 一致。

验收：CI 中生成物无 diff；每条升级边与被声明 reversible 的降级边都有真实 SQLite 执行测试。

### Gate 2：安全快照与恢复

- 先确认 `sqflite_sqlcipher` 在 Android/iOS 暴露的 SQLite 版本及 `VACUUM INTO`/backup 能力；能力必须运行时探测。
- 迁移协调器在 open 的版本回调之前创建快照；快照完成后执行 `quick_check`、版本和 hash 校验。
- 恢复只允许在所有连接关闭后进行，并原子替换 db 与相关 sidecar；恢复后重新打开并验证。
- 快照加密强度不低于主库，按 uid 隔离，成功升级后按数量和期限清理。

验收：模拟断电/异常、WAL 未 checkpoint、大库、空间不足、错误 key；任何失败均保留原库且不给出假成功。

### Gate 3：发布级降级政策

- 产品层只承诺“回滚到上一稳定版”，不承诺任意历史版本降级。
- 每个 release manifest 明确 `minReadableSchema`、`maxReadableSchema`、`destructiveFallbackAllowed`。
- 有未同步的消息/频道 outbox 时禁止 destructive fallback。
- 真机覆盖 Android 与 iOS SQLCipher；桌面/Web 只能作为补充证据。

验收：上一稳定版真实安装包能打开经新版升级的真机数据库；关键消息、会话、E2EE 会话、outbox、频道权益均按策略保留或明确重同步。

## 6. 测试矩阵

最低必测：

- fresh install → v31（SQLCipher 与非加密路径）。
- 每个支持起点 → v31；重点 v9、v16、v18、v25、v29、v30。
- v31 → v30，以及允许的上一稳定版降级路径。
- 缺块、SQL 语法错、约束失败、重复启动、迁移中进程被杀。
- WAL 有未 checkpoint 数据、磁盘空间不足、快照损坏、错误密钥。
- schema hash、行数/关键字段、外键、outbox、E2EE 密钥引用、频道访问模型。
- 大数据集迁移耗时与峰值空间；启动迁移必须有预算和超时观测。

本轮已执行：

```text
flutter test <8 个迁移相关测试文件> --reporter expanded
结果：39/39 PASS
```

这只证明已有覆盖路径通过，不证明缺失的降级边或真机 SQLCipher/WAL 快照安全。

## 7. 最终决策

**推荐采用“强升级 + 窄窗口可逆降级 + 明确的受控重建”方案。**

- 不选“所有版本都写 down SQL”：维护成本高，删列/类型收窄天然有损，容易制造虚假的安全感。
- 不选“任何降级都删库”：IMBoy 存在消息、E2EE、outbox 等尚未必然可从服务端完整恢复的数据，风险不可接受。
- 不保留当前“缺脚本也成功”：这是最危险的状态，因为它隐藏 schema/version 错配。

优先级：先完成 Gate 0，再做 Gate 1；两者完成前，IMBoy App 的数据库升级可标为 **PARTIAL PASS**，生产降级应标为 **NO-GO（仅已验证的具体边例外）**。

## 8. 方法与来源

研究拆分为现状链路、失败/数据风险、官方标准、IMBoy 落地四个问题。读取并交叉核对了当前仓库迁移服务、规划器、升级/降级 SQL、内嵌脚本和相关测试；使用 SQLite、sqflite、Android Room 一手官方资料。Firecrawl/Exa 在当前环境未配置，因此网络研究使用公开检索回退；结论没有依赖博客或二手论坛内容。


---

## 9. 实施结果（2026-08-27 追加，WP8）

本方案已于 2026-08-27 按实施计划（docs/sqlite-migration-implementation-plan-2026-08-27.md）
落地 WP0–WP6 + WP8；WP7 真机验收 BLOCKED 待用户输入。**发布决策：PARTIAL**
（详见 docs/sqlite-migration-release-gate.md）。

### 研究结论与实测的对账

| 研究预判 | 实测结果 |
|---|---|
| P0 降级缺块静默成功 | 已修复：MissingMigrationPathException fail-fast；4 条缺边实测拒绝 |
| P0 事务内复制/覆盖主库 | 已修复：快照/恢复全部移出事务（VACUUM INTO + 协调器），迁移失败只靠 sqflite 回滚 |
| P1 duplicate-column 吞错 | 已修复：显式 ADD COLUMN precondition；v11/v12 历史重复 ALTER 由 precondition 承接 |
| P1 双真源 | 已修复：manifest 单一真源，.sql/embedded 均为生成物（字节级 --check 守护） |
| P1 两条建库路径分叉 | **实证并修复**：fresh 路径因注释解析 bug 丢 i_cv_UserId_IsShow_LastTime 索引（P1 生产缺陷）；修复后三路径 fingerprint 收敛（f6d4a55a…） |
| 只验证四张消息表 | 已扩展：声明式 invariant + golden contract（v9/v16/v25/v30/v31）+ _imboy_schema_meta |

### 研究未预判的发现

- 历史跨号边：upgrade VERSION:14 块的 PRAGMA 为 15（v14/v15 无 schema 差异，
  v15 跳号的真正来源）——manifest 以 from=13/to=15/blockLabel=14 显式建模。
- downgrade.sql 头部注释的语义描述与实际块语义相反（已钉死为 VERSION:N = N→N-1）。
