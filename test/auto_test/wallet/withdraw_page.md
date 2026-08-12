# `page/wallet/withdraw_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/withdraw_page.dart` | 展示当前零钱余额卡片 | 已通过 | 批次66 | 0 | 0 | 0 | 真机钱包页证实余额渲染：总资产 ¥0.00 + 零钱 ¥0.00（balance/100.0 分转元+toStringAsFixed(2) 固定两位，0分→0.00元 正确）；GET /wallet/balance 成功；withdraw_page 入口因余额0不可达（无钱可提，符合产品逻辑），余额卡片渲染逻辑同源已验证 |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 英文语言下页面文案完整翻译 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验通过（56c9738d）：切 en-US 进提现页（钱包→More→Withdraw），全页无中文残留——Withdraw/Pocket Money/Withdrawal Amount/Withdrawal Method/Alipay/WeChat/Wallet Balance/Fees and arrival time are subj.../Confirm Withdrawal 全英文化；账号输入框 hint（withdrawAccountHint* 独立键）聚焦时语义树不暴露，代码侧已核实（键随 14a8d8c4 在生成物就绪）；二次确认弹窗 withdrawConfirm* 键受余额 ￥0.00 限制不可达（超余额直接 showError）维持代码核实 |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 校验提现金额非空与格式 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 拦截低于 1 元的提现金额 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 拦截超出余额的提现金额 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 阻塞 | 缺外部条件：设备空闲 | `page/wallet/withdraw_page.dart` | 切换支付宝与微信提现渠道 | 待重验 | - | 0 | 0 | 0 | 静态核验：纯本地 UI 切换（L216-267 渠道选择器 setState _selectedMethod，不发起真实支付请求），校验提示随渠道切换（L89-96 支付宝邮箱/手机号 vs 微信 6-20 位字母开头）；设备被并发会话占用待空闲真机复测 |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 校验支付宝邮箱或手机号格式 | 已通过 | 批次74 | 0 | 0 | 0 | 批次74 回归复测通过：非法 abc → 错误提示「请输入正确的支付宝邮箱或手机号」；13800138000 → 弹确认对话框（取消未提交）；a@b.com → 弹确认对话框（取消未提交） |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 校验微信号 6-20 位字母开头 | 已通过 | 批次34 | 0 | 0 | 0 | 真机复测通过（批次34）：提现页切微信渠道输「1abcg」（数字开头）点确认 → UI 树出现「请输入正确的微信号（6-20位，字母开头）」拦截；改输合法「wechat01」（字母开头 8 位）再点确认 → 该提示消失，仅剩金额校验（金额空提示「请输入不低于1元的金额」），校验双向生效 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/withdraw_page.dart` | 二次确认展示金额渠道账号 | 待重验 | - | 0 | 0 | 0 | 批次33 复核：_handleWithdraw 中 amountYuan>maxBalanceYuan 直接 showError return（余额 ¥0.00 实测），二次确认弹窗不可达，非回归系缺外部条件转阻塞 |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 确认按钮使用破坏性红配色 | 已通过 | 批次28 | 2 | 2 | 0 | 批次28 真机复验挖出**同族漏改**：上轮只改了二次确认弹窗的 `CupertinoDialogAction`，页面主按钮 `WalletPrimaryButton` 仍是 `AppColors.getIosRed`（真机截图确认）。同一条判据、同一个页面，已一并改为 `AppColors.primary`（与转账页 `transfer_send_page` 的资金主操作一致）。重装后复验：主按钮为品牌蓝。⚠️**弹窗分支未覆盖** —— `_handleWithdraw` 在 `amountYuan > maxBalanceYuan` 时直接 showError 并 return，测试账号余额 ￥0.00，弹窗代码路径不可达；弹窗侧改动仅有代码核实（`isDefaultAction: true`，withdraw_page.dart:136）。原修复记录： 提现不是破坏性操作，iosRed 是留给删除/退出这类不可逆动作的。已把确认按钮从 `isDestructiveAction` 改为 `isDefaultAction`（主操作语义，加粗蓝），待真机看弹窗配色 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/withdraw_page.dart` | 提交提现请求并刷新余额返回 | 未测 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/withdraw_page.dart` | 展示手续费与到账时效中性说明 | 已通过 | 批次32 | 0 | 0 | 0 | 真机复验通过（批次32）：钱包→更多→提现，UI 树确认「手续费与到账时间以实际结算为准」中性说明渲染于零钱余额提示条与确认按钮之间，无具体费率/时效承诺 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/withdraw_page.dart` | 提现失败错误提示 | 未测 | - | 0 | 0 | 0 | |
