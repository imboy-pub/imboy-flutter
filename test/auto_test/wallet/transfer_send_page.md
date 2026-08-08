# `page/wallet/transfer_send_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/wallet/transfer_send_page.dart` | 进页自动拉取真实余额 | 待重验 | - | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/wallet/transfer_send_page.dart` | 从通讯录加载收款人显示名 | BUG已修待验 | - | 0 | 0 | 0 | BUG#111 同源修改，`ContactRepo().findByUid()` |
| 回归复测 | 2026-08-07 | `page/wallet/transfer_send_page.dart` | 校验转账金额非空与格式 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/transfer_send_page.dart` | 拦截低于 0.1 元的转账金额 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/transfer_send_page.dart` | 拦截超出余额的转账金额 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 备注留空时回填默认备注 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 二次确认展示收款人昵称 | BUG已修待验 | - | 1 | 1 | 0 | BUG#111 原显示裸 TSID uid；批次35 复核：74b67501（08-06）在 APK（14:55）内，钱包页实测余额 ¥0.00，输入 0.1 即被「超出余额」拦截，二次确认弹窗不可达，条件不具备转阻塞（待充值） |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 取消二次确认中止转账 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 提交转账请求并刷新余额 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 回传转账结果给聊天页投递 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/transfer_send_page.dart` | 转账失败错误提示 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/transfer_send_page.dart` | 展示可用余额提示条 | 待重验 | - | 0 | 0 | 0 | |
