# `page/wallet/transfer_send_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 进页自动拉取真实余额 | 已通过 | 批次74 | 0 | 0 | 0 | 真机：117 账号进转账页自动拉取余额 ¥94.32 |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 从通讯录加载收款人显示名 | 已通过 | 批次74 | 0 | 0 | 0 | 真机：收款人显示名正确（BUG#111 同源修复生效） |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 校验转账金额非空与格式 | 已通过 | 批次74 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 拦截低于 0.1 元的转账金额 | 已通过 | 批次74 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 拦截超出余额的转账金额 | 已通过 | 批次74 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 备注留空时回填默认备注 | 已通过 | 批次74 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 二次确认展示收款人昵称 | 已通过 | 批次74 | 1 | 1 | 0 | 真机复验通过：二次确认弹窗展示收款人昵称（BUG#111 已闭环，74b67501） |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 取消二次确认中止转账 | 已通过 | 批次74 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 提交转账请求并刷新余额 | 已通过 | 批次74 | 0 | 0 | 0 | 真机：1 元转账成功提交，余额刷新 |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 回传转账结果给聊天页投递 | 已通过 | 批次74 | 0 | 0 | 0 | 真机：转账成功回聊天页投递 transfer 气泡（2a06d0de 渲染修复） |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 转账失败错误提示 | 已通过 | 批次74 | 1 | 0 | 1 | 行为证据：失败时页面不 pop、余额不变、无新气泡 + 代码路径 sendTransfer null → operationFailedAgainLater；⚠️发现：前后端最低转账金额不一致（前端 0.1 / 后端 Amount>=100 即 1.0，transfer_logic:send 自 d559b475）→ 0.1~0.99 元通过前端校验必被服务端拒「转账参数不合法」（实测 0.5 元 400）；资金路径改动待用户拍板；另记录：EasyLoading toast 不进 Flutter 语义树（widget 测试实测），无障碍不可达，组件层机制 |
| 无待办 | - | `page/wallet/transfer_send_page.dart` | 展示可用余额提示条 | 已通过 | 批次74 | 0 | 0 | 0 | 真机：提示条与钱包页真实余额一致 |
