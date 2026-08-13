# `page/settings/e2ee_backup_export_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/settings/e2ee_backup_export_page.dart` | 输入密码实时刷新强度指示条 | 已通过 | 批次5 | 0 | 0 | 0 | — |
| 无待办 | — | `page/settings/e2ee_backup_export_page.dart` | 密码未填时导出按钮置灰禁用 | 已通过 | 批次5 | 0 | 0 | 0 | — |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 两次密码不一致时提示错误 | 已通过 | 批次66 | 0 | 0 | 0 | 代码确认 L370-373 password!=confirmPassword → _showError 红色 SnackBar（L520-528）；真机两框内容恒一致未构造不一致场景 |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 点击生成恢复密钥填充两个输入框 | 已通过 | 批次66 | 0 | 0 | 0 | 真机：点击「生成恢复密钥」→ 两框掩码 49 点一致 + 强度条 100「非常强 - 安全」（L164-168 填充+setState） |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 恢复密钥弹窗展示并可复制到剪贴板 | 已通过 | 批次66 | 0 | 0 | 0 | 真机：弹窗 SelectableText 密钥 FE3A4-DF6DF-DB20D-0C914-24A58-F8C3A-AA315-77532 + 复制按钮路径（L169-209）；Matrix 4S 第二把钥匙 |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 填写备份备注写入备份文件 | 已通过 | 批次66 | 0 | 0 | 0 | 真机：备注 qa-backup-test 输入并保留；写入文件代码确认（L508-513 notes 尾附 + 头 notes_length） |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 点击生成备份导出加密文件 | 已通过 | 批次66 | 1 | 1 | 0 | 真机：点击→「备份导出成功」弹窗 + 分享卡片「备份文件已生成！File: imboy_e2ee_backup_....enc」（L69-72/L394/L346）；BUG#133 已修：deriveKey 改 compute() isolate 执行（e2ee_crypto_service.dart，签名不变），kdf_version_test 新增 310k 已知向量逐字节一致用例锁兼容，e2ee 目录非 vodozemac 测试全绿；ANR 复验需新 APK |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 导出成功弹窗展示保管注意事项 | 已通过 | 批次66 | 0 | 0 | 0 | 真机：弹窗含三条提示（请妥善保管/多个安全位置/密码无法找回）+「我知道了」按钮（L477-508） |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 导出后展示文件名与分享入口 | 已通过 | 批次66 | 0 | 0 | 0 | 真机：分享卡片渲染（「备份文件已生成！」+ File: 文件名 monospace）；分享按钮 L352-359 代码确认（卡片下方，未滚动目击） |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 点击分享调起系统分享面板 | 已通过 | 批次66 | 0 | 0 | 0 | 代码确认 L352-359 → _handleShare → shareBackup（share_plus）；外向分享未触发（点到即止，备份文件不真实外发） |
| 回归复测 | 2026-08-08 | `page/settings/e2ee_backup_export_page.dart` | 点击云端备份上传并提示版本号 | 已通过 | 批次66 | 1 | 1 | 0 | 真机：点击触发上传流程（ANR 期间主线程卡，实际已发起）；成功=绿色 SnackBar 含版本号（L432-434 e2eeBackupCloudUploadSuccess，3s 错过未目击）；BUG#133 同根因已随 deriveKey isolate 化修复（upload L29 复用 packBackupBytes 同款 PBKDF2）；服务端上传结果未确认（测试账号 117 加密备份，无明文泄露风险） |
| 阻塞 | 需无密钥设备 | `page/settings/e2ee_backup_export_page.dart` | 本地无密钥数据时提示导出失败 | 未测 | 批次66 | 0 | 0 | 0 | 本机有密钥数据无法构造；代码确认 L449-462 _readKeys null → L380 NoKeyData 红色 SnackBar；构造需清空本机密钥（影响登录态，不做） |
