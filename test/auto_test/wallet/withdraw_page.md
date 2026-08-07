# `page/wallet/withdraw_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 展示当前零钱余额卡片 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 校验提现金额非空与格式 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 拦截低于 1 元的提现金额 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 拦截超出余额的提现金额 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 切换支付宝与微信提现渠道 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 校验支付宝邮箱或手机号格式 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 校验微信号 6-20 位字母开头 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 二次确认展示金额渠道账号 | 待重验 | - | 0 | 0 | 0 | |
| 待复验 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 确认按钮使用破坏性红配色 | BUG已修待验 | 批次27 | 1 | 0 | 1 | 提现不是破坏性操作，iosRed 是留给删除/退出这类不可逆动作的。已把确认按钮从 `isDestructiveAction` 改为 `isDefaultAction`（主操作语义，加粗蓝），待真机看弹窗配色 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/withdraw_page.dart` | 提交提现请求并刷新余额返回 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/withdraw_page.dart` | 展示手续费与到账时效中性说明 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/withdraw_page.dart` | 提现失败错误提示 | 未测 | - | 0 | 0 | 0 | |
