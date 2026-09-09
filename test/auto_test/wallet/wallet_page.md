# `page/wallet/wallet_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/wallet_page.dart` | 点击加号打开充值弹窗 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 校验充值金额 1~10000 元 | 已通过 | 批次67 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 弹出支付方式选择列表 | 已通过 | 批次67 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 门控生产环境 mock 支付通道 | 已通过 | 批次22 | 1 | 1 | 0 | BUG#82 资金红线；生产遗留一笔 mock 充值待用户决定如何处理 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 提交充值订单并刷新余额 | 已通过 | 批次156 | 0 | 0 | 0 | 真机：+→金额 1.00→「模拟支付（开发环境）」→ toast 充值成功 + DB 余额 +100 分 + UI 余额刷新（相对基线断言）；mock 门=PaymentConfig.isMockPayAllowed 仅非生产展示（BUG#82 红线不触生产）；测试=wallet_acceptance_batch156_test.dart AT-WTOP1 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 更多菜单跳转提现页 | 已通过 | 批次67 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/wallet_page.dart` | 渲染余额卡片与加载态 | 已通过 | 批次78 | 0 | 0 | 0 | 真机：总资产 ¥0.00 卡片正常渲染，GET /wallet/balance + /wallet/transactions?page=1&size=20 双请求成功（pro.imboy.pub），流水空态「暂无流水记录」正常 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 下拉刷新余额与流水 | 已通过 | 批次66 | 0 | 0 | 0 | 真机下拉触发 GET /wallet/balance + /wallet/transactions?page=1&size=20 双请求成功重拉 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 触底加载更多流水记录 | 已通过 | 批次156 | 1 | 1 | 0 | **修复真 bug（P1）**：_scrollController 创建并挂监听但从未传入 IosPageTemplate(controller:)→滚动事件永不到达、第 2 页永远加载不出（流水>20 条即复现）；修复=controller 透传模板 CustomScrollView（参照 contact_tag_list_page）；真机复验：触底加载 27/27 条与 DB 一致；单测 wallet 16 绿；测试=wallet_acceptance_batch156_test.dart AT-WFLOW2 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 渲染流水记录空态 | 已通过 | 批次22 | 1 | 1 | 0 | BUG#110 已在 `ImBoySettingsSection` 加空 children 守卫 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 区分收支方向并着色金额 | 已通过 | 批次78 | 0 | 0 | 0 | 通过 wallet_provider_test (WT-3) 及代码静态核验 |
| 无待办 | - | `page/wallet/wallet_page.dart` | 展示收款/银行卡即将开放禁用态 | 已通过 | 批次37 | 0 | 0 | 0 | 真机：钱包页「收付款」与「银行卡」区块各渲染「敬请期待」禁用态，零钱正常显示 ¥0.00 |
