# DF-11 E2EE 建立 → 安全消息 → 密钥备份/恢复

> 优先级：P0
> 状态：`本地密码学与只读入口通过 / 生产策略为 optional / 双设备和恢复阻塞`
> 安全等级：高风险，密钥恢复步骤默认不执行

## 1. 目标

验证端到端加密设备建立、加密消息收发、设备状态和密钥备份页面的安全边界。该流程优先级为 P0，但不能用普通聊天通过替代 E2EE 证据。

## 2. 前置条件

- [ ] 使用两个授权测试账号、两台测试设备和非生产环境。
- [ ] 测试密钥、恢复码和备份文件只保存在受控位置，不写入仓库或日志。
- [ ] 明确“验证读取”与“导入/恢复密钥”的边界；后者需要人工确认。
- [ ] 不清空真实账号密钥、不对第三方会话做恢复操作。

## 3. TODO 步骤

- [x] 只读挂载密钥恢复、备份导出和备份导入入口，不执行任何生成、删除、导出、上传、导入或恢复操作。
  - 证据：`integration_test/mine/mine_subpages_smoke_test.dart` Android 真机 `1/1`。
- [ ] 两个测试设备完成登录和 Olm/设备握手。
  - 预期：设备身份建立，未出现明文降级或未解释的密钥错误。
  - 参考：`integration_test/e2ee_olm_device_test.dart`
- [ ] A 向 B 发送唯一测试消息，B 解密并回复。
  - 预期：双方看到相同明文，服务端只承载加密消息结构。
  - 可执行入口：`integration_test/demo_flow/dual_account_message_flow_test.dart`，增加 `--dart-define=TEST_EXPECT_E2EE=true` 后，仅在服务端 policy 为 `required` 或 `compliance` 时执行；策略为 `optional` 会明确 `SKIP`，不把明文消息算作 E2EE 通过。
- [ ] 设备重启/重新进入会话后再次读取消息。
  - 预期：本地密钥状态和消息恢复正确。
- [ ] 在专用测试账号上导出 E2EE 备份并检查文件存在性。
  - 页面计划：[e2ee_backup_export_page.md](../auto_test/settings/e2ee_backup_export_page.md)
- [ ] 只有取得人工授权后，验证导入、密钥恢复和恢复失败引导。
  - 页面计划：[e2ee_backup_import_page.md](../auto_test/settings/e2ee_backup_import_page.md)、[e2ee_key_recovery_page.md](../auto_test/settings/e2ee_key_recovery_page.md)

## 4. 验收标准

- [ ] 双端加密消息可互相解密，且有设备级证据。
- [ ] 密钥缺失、解密失败和恢复失败有明确安全提示。
- [ ] 备份文件不泄露密钥内容，恢复操作不会静默覆盖现有密钥。
- [ ] 未授权的密钥清空、导入、恢复一律标记 `阻塞`。

## 5. 当前覆盖与阻塞

- Android 真机已执行 `integration_test/e2ee_olm_device_test.dart`，5/5 通过，覆盖本地 Olm/X3DH/Ed25519/OTK/pickle 密码学行为。
- 2026-08-10：Android 华为真机重跑 `integration_test/e2ee_olm_device_test.dart`，`5/5 All tests passed`；vodozemac、X3DH/Olm 双向解密、签名、OTK 消费和 session pickle 恢复均通过，但仍属于单机协议/持久化证据。
- 两个授权测试账号分别运行 `contact_api_test.dart` 与 `e2ee_api_test.dart`，各自联系人 5/5、E2EE 13 项中 12 通过和 1 项条件跳过；这是账号级只读证据，不等于双设备握手或加密消息闭环。
- 该结果不等于双设备登录、设备握手、加密消息互通或备份恢复 UI 闭环。
- 本轮生产 API 回归中，E2EE 相关条件分支因测试账号没有可用设备密钥而受控跳过；没有导入、恢复或清空生产密钥。
- 蓝绿发布后的定向 P0 API 套件中，E2EE 文件为 `8` 项通过、`1` 项条件跳过；与此前双账号各 `12` 项通过、`1` 项跳过的只读复核口径不同，均未执行导入、恢复或清空密钥。
- 2026-08-09：本地 widget 回归 `e2ee_backup_export_page_widget_test.dart` 与 `e2ee_backup_import_page_widget_test.dart` 合计 `9/9` 通过，覆盖备份文件校验、按钮禁用和风险提示；没有导入、恢复或清空任何真实密钥。
- 2026-08-09：Android 华为真机 `mine_subpages_smoke_test.dart` `1/1` 通过，新增覆盖 E2EE 密钥恢复、备份导出、备份导入三个只读入口；导入页仅触发云端备份信息读取，未点击导入/恢复，导出页未生成文件。
- 双设备、密钥材料和恢复操作是主要阻塞，不能由单设备 UI 通过替代；Android 真机本地密码学测试已通过，但尚未完成双设备 UI 握手和备份恢复证据。
- 2026-08-09：当前可安全执行的 E2EE 范围已完成：本地密码学 `5/5`、备份页面 widget `9/9`、Android 账号/E2EE 子页 `1/1`；双设备握手、加密消息互通、重进恢复和真实备份导入/恢复均受控 `SKIP`。
- 2026-08-09：生产 `/api/v1/app/policy` 只读探测返回 `e2ee_mode=optional`、`storage_mode=archived`；因此当前普通双账号消息 flow 按策略走明文，不能计入 E2EE 验收。已将 Olm per-device 元数据断言接入双账号 flow，待专用非生产 strict/compliance 环境或明确策略切换后复跑。
- 2026-08-10：Android/118 使用 `TEST_EXPECT_E2EE=true` 对生产双账号 flow 做策略门禁探测，测试在发送前明确 `SKIP`（policy 不是 `required/compliance`）；未产生本轮业务消息写入。当前 `.env.local*` 没有可用双账号凭证，`.env.e2e.example` 只是模板，尚未发现可直接执行的非生产 strict/compliance 环境。
- 2026-08-10：本地 `e2ee_backup_restore_test.dart` 与 `integration/room_key_olm_roundtrip_test.dart` 定向复跑，备份/恢复及密码、篡改检测共 `13` 项通过；room-key roundtrip 因 `spikes/e2ee-group/rust/target/release` 动态库未构建而受控跳过。该结果不替代真实双设备 strict E2EE 证据。
- 2026-08-10：本地 E2EE 策略门禁与 per-device fan-out 定向回归共 `18` 项通过，覆盖未初始化 fail-closed、设备信封缺失/篡改、独立 header/ciphertext 和外层元数据契约；`olm_pfs_production_path_test.dart` 在 macOS 主机因缺少 `vodozemac_bindings_dart.framework` 动态库未能初始化，未计入通过，也不影响双设备 strict E2EE 仍未验收的结论。
- 2026-08-10：为本地验证临时用 `flutter_vodozemac` Rust 源码构建 macOS arm64 动态库后，`olm_pfs_production_path_test.dart` 的 `9` 项和 `room_key_olm_roundtrip_test.dart` 的 `1` 项均通过；这补齐了本地 OLM/PFS 与 room-key-over-Olm 协议证据，但仍不等于生产 strict/compliance 双设备消息或真实备份恢复。
- 2026-08-09：按 App 真实 MD5 登录契约重新做签名只读探测：117（UID `50`）的 `user_keys` 返回 `3` 个设备，118（UID `4`）返回 `8` 个设备，设备公钥读取成功；这证明当前账号侧确有多设备密钥材料，但生产 policy 仍为 `optional`，不能把设备存在误报为加密消息闭环通过。`key/status` 在本次探测返回业务 `400`，未据此推断密钥有效性。
- 2026-08-11：华为 Android 真机 `XWE6R19916004085` 重跑 `integration_test/e2ee_olm_device_test.dart`，`5/5 All tests passed`；覆盖 vodozemac 初始化、X3DH/Olm 双向解密、Ed25519、OTK 消费和 session pickle 恢复，仍只计为单机密码学证据。
- 2026-08-11：macOS 主机运行 `integration_test/e2ee_olm_device_test.dart -d macos`，`5/5 All tests passed`；证明桌面端本地 vodozemac/Olm 协议路径可用，但仍不等于 Android↔macOS 双端消息闭环。
- 2026-08-11：iPhone 8 真机完成 Xcode 构建，但安装/启动阶段返回 `Unable to start the app on the device`，未加载任何测试用例；本次不计为 iOS 通过，也未形成双设备 E2EE 消息闭环。

## 6. 未来自动化目标

现有 `integration_test/e2ee_olm_device_test.dart`、`integration_test/mine/mine_subpages_smoke_test.dart`、备份 widget 测试及双账号 flow 的 `TEST_EXPECT_E2EE` 门已覆盖当前安全可执行范围。双设备和恢复测试必须使用非生产账号、受控密钥材料及显式授权。
