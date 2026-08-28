# SQLite 迁移发布门（WP8）

> 日期：2026-08-27 | HEAD（工作区）：`b0d3eb33` + 本治理未提交改动
> 判据：docs/sqlite-migration-implementation-plan-2026-08-27.md §8

## 发布决策

```text
SQLite migration release decision: PARTIAL
HEAD: b0d3eb3376a11fff0ad5bd44b697eea4d26f5891（+ 未提交的治理改动）
Upgrade paths: 24/24（6 起点 × 4 数据形态）+ fresh × 4 形态 = 28/28 自动化 PASS
Supported downgrade edges: v31→v30（manifest 声明 dataLoss=true/requiresResync=false，
  矩阵实测数据影响与声明一致）
Rejected downgrade edges: 30→29, 27→26, 26→25, 31→25（fail-closed，实测库不变）
Android real device: 自动化六步 PASS（2026-08-27，MRD-AL00/Android 9/真实
  SQLCipher；六步证据见 /tmp/.../device-android/summary.md）；旧包人工回滚
  M1/M2/M4 未做
iOS real device: BLOCKED（同上）
Data-loss incidents: 0（自动化范围内；矩阵含 800 行大数据零丢失断言）
Version/schema mismatch incidents: 0（三建库路径 fingerprint 收敛 + 迁移后
  verify + _imboy_schema_meta 记录）
Evidence root: /tmp/imboyapp-sqlite-migration-20260827-182502/
Open blockers: iOS 端未测；旧版安装包人工回滚 M1/M2/M4 未做；kill -9 真杀进程重放未做
```

**PARTIAL 而非 PASS 的原因（2026-08-27 更新）**：Android 自动化六步已在真机
全绿（含 SQLCipher 加密继承实证），但 iOS 端未测、旧版安装包人工回滚
（M1/M2/M4）与 kill -9 重放未执行——计划 §8 要求双端真机+旧包回滚齐全。

## PASS 已达成项

| 完成标准（计划 §8） | 状态 |
|---|---|
| WP0–WP6 自动化全部通过 | ✅（Gate 13/13 ×2 模式） |
| 所有受支持升级起点到 v31 有真实执行测试 | ✅（24+4 格矩阵） |
| 允许的降级边有 manifest + 数据影响声明 | ✅（31→30） |
| 不支持的降级边 fail-closed | ✅（4 边实测拒绝） |
| WAL/事务失败/错误 key/空间不足/损坏快照故障注入 | ✅（除进程被杀，见下） |
| schema 单一真源、生成确定、hash 可复现 | ✅（字节级 54748/21811B） |
| 数据丢失事故 0 / 静默错配 0 / 密钥 PII 泄漏 0 | ✅（自动化范围） |
| 非本任务 dirty changes 未被修改 | ✅（登记在案） |
| gate --local / analyze（本任务面）/ git diff --check | ✅ 全绿 |

## 已知限制与遗留（如实声明）

1. **进程被杀注入未自动化**：单进程 flutter test 无法注入；由 sqflite 事务
   回滚语义（SQL 中途失败用例）代表，真机杀进程恢复归 WP7。
2. **真机能力未证**：SQLCipher 下 VACUUM INTO 快照加密继承、大库耗时、
   双进程窗口——全部 CAPABILITY_PROBED（本地 ffi 证据），真机为 WP7。
3. **生产缺陷 #6 修复的影响面**：fresh 建库将新建 `i_cv_UserId_IsShow_`
   `LastTime` 索引（此前被解析 bug 静默丢弃）。存量已建库**不会自动补建**
   该索引（无迁移边）——影响：存量库会话列表查询维持现状。是否为存量库
   补索引（v32 边）由产品决策，本文档不擅自扩版本。
4. **列序差异**（发现 #7）：baseline 与升级路径的 contact 列序不同已由
   fingerprint 规范化吸收（列序非契约）；不建议单独修正 baseline。
5. **`_onOpen` 启动自检未加**（meta hash vs 现算比对）：每开库成本与误伤
   风险待真机验证后决定，WP8 建议（见下）。
6. `sqlite.dart:95` 注释仍引用已删除的 `_restoreFromSnapshot`（历史说明，
   WP5 未顺手改该注释行以缩小 diff——建议下次触碰该文件时清理）。

## 发布前必做（用户决策/输入）

> 执行材料已就绪（2026-08-27）：WP7 自动化脚本 + 手册见
> `integration_test/sqlite_migration/`——确认门通过后即可执行。

- [x] Android 真机自动化六步：PASS（2026-08-27，MRD-AL00，用户授权后执行，
      含 SQLCipher 加密继承实证）
- [x] kill -9 迁移中真杀进程重放：PASS（2026-08-27，KILLED_ROLLED_BACK，
      原子性+零丢失实证；首轮曾触发设备存储满、flutter 工具链自动卸载重装
      清空调试壳本地数据——已记录）
- [x] 本地/CI 自动化 + analyze（本任务面）+ git diff --check：全绿
- [ ] 确认 iOS 真机渠道（注意 ios/* 保留区对构建的约束）并执行六步
- [x] 旧包回滚 M1：PASS（2026-08-28，git 考古基点 5c06cc7b 本地构建旧包，
      测试号登录，旧版真实创建 v30 加密库 pro_6.db；alpha.15 旧客户端登录
      生产后端兼容可用）——证据 /tmp/.../device-android/old-rollback/
- [ ] 旧包回滚 M2/M4：BLOCKED（设备 /data 99% 满、安装会话超限）——
      **需用户在 MRD-AL00 上自行清理约 2GB**；新/旧 arm32 包已就绪，
      恢复后两条命令完成
- [x] kill -9 真杀进程重放
- [ ] 决策：存量库是否补建缺失索引（附录 A1）
- [ ] 决策：`_onOpen` meta hash 启动自检是否启用（附录 A2）
- [ ] 以上补齐可改判 PASS；**或**由您明确接受现状为发布基线（届时记录于此节）

## 复验命令

```bash
cd imboyapp
bash scripts/run_sqlite_migration_gate.sh --local   # 期望 exit 0
dart run tool/generate_sqlite_migrations.dart --check
git diff --check
```

---

## 附录 A：待用户决策卡（2026-08-27 补）

### A1 存量库缺失索引补建（v32 候选边）

| 项 | 内容 |
|---|---|
| 现状 | fresh 新装库已有 `i_cv_UserId_IsShow_LastTime`；**存量升级库**因缺陷 #6 从未拥有该索引，修复不会自动回填 |
| 影响 | 会话列表按 (user_id,is_show,last_time) 的查询在存量库走全表扫描；数据无损，纯性能债 |
| 方案 | v32 upgrade 边：`CREATE INDEX IF NOT EXISTS i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time); PRAGMA user_version = 32;` |
| 可逆性 | reversible=true（32→31 down 边 = DROP INDEX IF EXISTS …），双向 dataLoss=false、requiresResync=false |
| 代价 | 约 0.5 天：manifest 加边 → generator --output → golden v32 → inventory/矩阵 target 全链改 31→32 → gate 回归 |
| 建议 | 与下一个功能版本顺车发布；不单独发版 |

### A2 `_onOpen` meta 哈希自检

| 项 | 内容 |
|---|---|
| 方案 | 打开库后若存在 `_imboy_schema_meta`，比对存储的 schema_hash 与现算 fingerprint；不一致 → 记录结构日志 + 向用户呈现恢复指引（可用 restoreLatest 走快照恢复）；绝不自动删库/重建 |
| 开关 | 静态开关默认 **false**，先在 WP7 真机量取大库指纹计算耗时后再决定默认值 |
| 失败语义 | 只告警 + 引导，不阻断启动（避免误伤造成不可用）；异常路径白名单化 |
| 决策点 | WP7 时实测设备上真实量级库的 compute 耗时：<50ms 可考虑默认开 |
