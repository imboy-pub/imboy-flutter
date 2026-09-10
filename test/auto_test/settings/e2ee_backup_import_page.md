# `page/settings/e2ee_backup_import_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 点击选择区调起文件选择器 | 已通过 | 批次32 | 0 | 0 | 0 | 真机 documentsui 调起；FilePicker enc 过滤+单选；非 enc 文件被校验层拦截 |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 选中文件后校验并展示备份元信息 | 已通过 | 批次31 | 0 | 0 | 0 | widget 测试断言（初始文件注入 + 网络隔离），文件路径详见 test/unit_test/page/settings/e2ee_backup_import_page_widget_test.dart |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 文件格式非法时提示校验失败 | 已通过 | 批次31 | 1 | 1 | 0 | widget 测试断言（初始文件注入 + 网络隔离），文件路径详见 test/unit_test/page/settings/e2ee_backup_import_page_widget_test.dart |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 未选合法文件时密码框保持禁用 | 已通过 | 批次32 | 0 | 0 | 0 | 含选中非合法 p5.png 后仍保持禁用 |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 密码为空时导入按钮置灰禁用 | 已通过 | 批次32 | 0 | 0 | 0 | — |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 顶部警告卡片提示覆盖密钥风险 | 已通过 | 批次32 | 0 | 0 | 0 | — |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 存在云端备份时展示云端恢复卡片 | 已通过 | 批次31 | 0 | 0 | 0 | widget 测试断言（初始文件注入 + 网络隔离），文件路径详见 test/unit_test/page/settings/e2ee_backup_import_page_widget_test.dart |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 输入密码导入并恢复私钥到安全存储 | 已通过 | 批次162 | 1 | 1 | 0 | **BUG#147**：密码框缺 onChanged→输入不触发 setState→「导入密钥」死按钮（isEnabled 依赖 controller.text；导出页 BUG#132 同源），修复后 macOS 全链 PASS；链路=导出页真导出 .enc 落临时目录→initialFilePath 注入导入页→密码+导入密钥→导入成功弹窗；导入恢复的是刚导出的同一密钥四元组（净零变化），不需要弃用账号 |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 导入成功弹窗展示脱敏设备与密钥标识 | 已通过 | 批次162 | 0 | 0 | 0 | 弹窗含 `Device ID: xxxx…xxxx`/`Key ID: xxxx…xxxx`（_maskId 前4后4）；device_id 仅作归档展示不覆盖本机 |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 云端恢复弹出口令确认框可取消 | 已通过 | 批次162 | 0 | 0 | 0 | macOS 通道：本地 9801 真上传（已备份到云端）→导入页云卡出现→「从云端恢复」→口令框（placeholder 备份口令）→取消→框关闭不执行恢复 |
| 无待办 | - | `page/settings/e2ee_backup_import_page.dart` | 云端口令错误时提示口令不正确 | 已通过 | 批次162 | 0 | 0 | 0 | 错误口令→toast「口令错误或备份损坏」（e2eeBackupErrCloudPwd，ArgumentError 分支）；无备份分支另提示未测（需清云端备份） |
| 阻塞 | 需可弃用测试账号且有群聊历史 | `page/settings/e2ee_backup_import_page.dart` | 恢复后回填群聊会话密钥 | 未测 | - | 0 | 0 | 0 | 单条写失败不整体回滚；备份需含 Megolm 会话（当前 smoke_bob 本地无群历史入备份） |
