# WP7 真机验收执行手册

> 状态：**READY_TO_RUN（材料就绪，等待用户确认门）**
> 脚本：`sqlite_migration_device_acceptance_test.dart`
> 判据：docs/sqlite-migration-test-matrix.md §6、
> docs/sqlite-migration-release-gate.md

## 0. 用户确认门（未确认不得执行）

运行前必须由用户逐项确认：

- [ ] 目标真机：Android ______ / iOS ______（型号 + 连接方式）
- [ ] "上一稳定版"安装包来源已确认可信：
      APK/IPA 构建号 ______（对应 schema v30 时代的版本）
- [ ] 测试账号策略：本自动化脚本 **不需要任何账号/网络/生产数据**
      （自建合成命名空间）；若补做"旧 App 建样"人工步骤，其使用的
      账号由用户提供并承担数据责任
- [ ] 授权在设备上创建/删除 `imboy_wp7_` 前缀临时目录与本测试的数据库
- [ ] （仅手动步骤需要）允许在该设备安装指定旧版包并在验证后卸载

## 1. 自动化部分（app 内自足，不碰真实账号库）

```bash
cd imboyapp
# Android
flutter test integration_test/sqlite_migration/sqlite_migration_device_acceptance_test.dart \
  -d <ANDROID_DEVICE_ID> 2>&1 | tee /tmp/wp7-android.log
# iOS
flutter test integration_test/sqlite_migration/sqlite_migration_device_acceptance_test.dart \
  -d <IOS_DEVICE_ID> 2>&1 | tee /tmp/wp7-ios.log
```

通过标准：`All tests passed!` 且日志含 6 组 `[WP7-EVIDENCE]`：

| step | 断言要点 |
|---|---|
| step1 | 双升级路径 fingerprint 相同 |
| step2 | meta_state=ok、application_id=0x494d424f、user_version=31 |
| step3_wal/snapshot/cipher | journal_mode=wal；快照含未 checkpoint 行；加密平台 headerMagicAbsent=true（加密继承实测） |
| step4 | 31→30 成功、消息保留、visibility 列丢弃 |
| step5 | 30→29 拒绝、originalIntact=true |
| step6 | restoredVersion=30、dataPreserved=true |

iOS 注意：仓库 `ios/*` 为保留区，若当前 Xcode 工程不支持所选模拟器/
真机构建窗口，由用户决定是否解禁或提供构建渠道；脚本本身不修改保留区。

## 2. 手动部分（自动化不可替代的最后缺口）

### M1 旧版 App 真实建样（计划 Step8 第 1 步）

1. 安装已确认的上一稳定版；
2. 用用户提供的测试账号登录（禁止使用生产主账号）；
3. 创建无 PII 样本：两条合成文本消息（内容用
   `synthetic-wp7-msg-a/b`）、一个会话、完成一次 E2EE 密钥生成、
   频道页进入一次付费频道（产生 has_purchased/channel 权益行）、
   断网发送一条消息产生 outbox 残留；
4. 记录设备型号/OS/App build 号。

### M2 升级到新版（第 2 步）

1. 不卸载旧版数据，直接安装新版 build；
2. 启动后从日志/Hub 抓取 `[WP7-EVIDENCE]` 与迁移日志
   （MigrationService 的 Progress/Migration completed 行）；
3. 核对：能进入主页、历史样本可见、E2EE 会话可解密、设置页正常。

### M3 WAL 快照能力（第 3 步）

跑一遍 §1 自动化脚本（它在新版 App 进程内自证 step3）；
结果回填即可，无需重复手动操作。

### M4 回滚 v31→v30（第 4 步）

1. 卸载新版，安装上一稳定版（**不删除应用数据**——iOS 选择覆盖
   安装保数据，Android adb install -r）；
2. 启动旧版：必须能打开库且看到样本（31→30 是 manifest 承诺窗口）；
3. 异常判定：打不开库 = FAIL（立即停，勿点任何"清除数据"类按钮，
   原样封存设备日志等复现分析）。

### M5 不可逆路径拒绝验证（第 5 步）

逻辑由自动化 STEP5 在新版进程内证明。补充手动观察：M4 若误装了比
v30 更早的历史版本导致无法打开，属于预期 fail-closed 行为——记录现象、
装回新版恢复，不算事故。

### M6 杀进程/重启恢复（第 6 步）

1. 新版启动后立刻强杀进程（Android: 最近任务划掉 / `adb shell am force-stop`；
   iOS: 上滑杀掉）×3 次，每次重启核对样本仍在；
2. 迁移中途杀进程的真机重放：清数据后重装、启动瞬间杀掉（迁移窗口内），
   再重启——预期要么完成迁移、要么打开失败且数据可由新版重开修复；
   绝不允许出现"版本进了但数据读不出"。出现即 FAIL 并留证。

## 3. 证据归档

两端各留：设备型号、OS 版本、新旧 build 号、完整日志（§1 输出 +
手动步骤录屏或截图脱敏版）、六步证据表。放入
`/tmp/imboyapp-sqlite-migration-<ts>/device-{android,ios}/`。
单平台缺失则发布决策维持 PARTIAL；双端齐备方可改判 PASS。

## 4. 安全红线（违反任一 = 立即停止）

- 不使用生产主账号 / 真实好友会话做验证；
- 不执行任何"清除存储/删除数据库"系统按钮；
- 密钥/token/手机号/消息正文不入日志与报告（fixture 一律 synthetic-*）；
- 手动装包前二次核对来源为用户确认的那一份。
