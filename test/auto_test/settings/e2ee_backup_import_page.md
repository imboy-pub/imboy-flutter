# `page/settings/e2ee_backup_import_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
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
| 阻塞 | 需可弃用测试账号（导入会覆盖本地密钥） | `page/settings/e2ee_backup_import_page.dart` | 输入密码导入并恢复私钥到安全存储 | 未测 | - | 0 | 0 | 0 | 危险操作未执行 |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 导入成功弹窗展示脱敏设备与密钥标识 | 未测 | - | 0 | 0 | 0 | device_id 仅作归档展示不覆盖本机 |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 云端恢复弹出口令确认框可取消 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可弃用测试账号 | `page/settings/e2ee_backup_import_page.dart` | 云端口令错误时提示口令不正确 | 未测 | - | 0 | 0 | 0 | 无备份/失败分支各自提示 |
| 阻塞 | 需可弃用测试账号且有群聊历史 | `page/settings/e2ee_backup_import_page.dart` | 恢复后回填群聊会话密钥 | 未测 | - | 0 | 0 | 0 | 单条写失败不整体回滚 |
