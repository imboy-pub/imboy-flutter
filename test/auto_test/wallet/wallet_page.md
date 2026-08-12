# `page/wallet/wallet_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/wallet/wallet_page.dart` | 点击加号打开充值弹窗 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/wallet_page.dart` | 校验充值金额 1~10000 元 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/wallet_page.dart` | 弹出支付方式选择列表 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 门控生产环境 mock 支付通道 | 已通过 | 批次22 | 1 | 1 | 0 | BUG#82 资金红线；生产遗留一笔 mock 充值待用户决定如何处理 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/wallet_page.dart` | 提交充值订单并刷新余额 | 未测 | - | 0 | 0 | 0 | 从未实充 |
| 回归复测 | 2026-08-07 | `page/wallet/wallet_page.dart` | 更多菜单跳转提现页 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/wallet_page.dart` | 渲染余额卡片与加载态 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 下拉刷新余额与流水 | 已通过 | 批次66 | 0 | 0 | 0 | 真机下拉触发 GET /wallet/balance + /wallet/transactions?page=1&size=20 双请求成功重拉 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/wallet_page.dart` | 触底加载更多流水记录 | 未测 | - | 0 | 0 | 0 | 需 >1 页真实流水 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 渲染流水记录空态 | 已通过 | 批次22 | 1 | 1 | 0 | BUG#110 已在 `ImBoySettingsSection` 加空 children 守卫 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/wallet_page.dart` | 区分收支方向并着色金额 | 未测 | - | 0 | 0 | 0 | 需真实流水记录 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 展示收款/银行卡即将开放禁用态 | 已通过 | 批次37 | 0 | 0 | 0 | 真机：钱包页「收付款」与「银行卡」区块各渲染「敬请期待」禁用态，零钱正常显示 ¥0.00 |
