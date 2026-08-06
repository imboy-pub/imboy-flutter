# `page/settings/e2ee_backup_import_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 点击选择区调起文件选择器 | 未测 | - | 0 | 0 | 0 | 仅允许 enc 后缀单选 |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 选中文件后校验并展示备份元信息 | 未测 | - | 0 | 0 | 0 | 版本/算法/文件大小 |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 文件格式非法时提示校验失败 | 未测 | - | 0 | 0 | 0 | — |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 未选合法文件时密码框保持禁用 | 未测 | - | 0 | 0 | 0 | — |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 密码为空时导入按钮置灰禁用 | 未测 | - | 0 | 0 | 0 | — |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 顶部警告卡片提示覆盖密钥风险 | 未测 | - | 0 | 0 | 0 | — |
| 待首测 | 2026-08-07 | `page/settings/e2ee_backup_import_page.dart` | 存在云端备份时展示云端恢复卡片 | 未测 | - | 0 | 0 | 0 | 探测失败按无备份静默处理 |
| 阻塞 | 需可弃用测试账号（导入会覆盖本地密钥） | `page/settings/e2ee_backup_import_page.dart` | 输入密码导入并恢复私钥到安全存储 | 未测 | - | 0 | 0 | 0 | 危险操作未执行 |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 导入成功弹窗展示脱敏设备与密钥标识 | 未测 | - | 0 | 0 | 0 | device_id 仅作归档展示不覆盖本机 |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 云端恢复弹出口令确认框可取消 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 云端口令错误时提示口令不正确 | 未测 | - | 0 | 0 | 0 | 无备份/失败分支各自提示 |
| 阻塞 | 需可弃用测试账号且有群聊历史 | `page/settings/e2ee_backup_import_page.dart` | 恢复后回填群聊会话密钥 | 未测 | - | 0 | 0 | 0 | 单条写失败不整体回滚 |
