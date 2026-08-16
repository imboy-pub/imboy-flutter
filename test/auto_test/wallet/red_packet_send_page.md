# `page/wallet/red_packet_send_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 进页自动拉取真实余额 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：单聊附加面板进红包发送页，GET /wallet/balance 调用成功，余额提示条「钱包余额 ￥0.00」与实际余额一致渲染 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 单聊场景加载收款人显示名 | 待重验 | - | 0 | 0 | 0 | BUG#111 同源修改；批次33 复核：真机进入单聊（automation-buddy）红包发送页，_receiverName 仅渲染于二次确认弹窗（redPacketReceiverLabel），页面本体无展示；弹窗必经 amountYuan>maxBalanceYuan 拦截（余额 ¥0.00 实测），不可达 → 转阻塞；0816复核:余额已足¥28.32(生产DB实测),仍缺资金测试授权 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 群聊切换普通与拼手气红包 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 校验红包金额最小 0.01 元 | 已通过 | 批次66 | 0 | 0 | 0 | 真机红包页金额输0点「放入钱包发送」→ validator 拦截「金额必须大于 0」（L72/L238 amountFen<1 即 <0.01元 生效） |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 拦截超出余额的红包金额 | 已通过 | 批次66 | 0 | 0 | 0 | 真机群红包页金额输10(>余额0)点提交→弹「余额不足」toast（L76-77 amountFen>maxBalanceFen→showError 生效）；BUG#48 确为误判，校验实际存在 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 校验群聊红包个数最小 1 个 | 已通过 | 批次66 | 0 | 0 | 0 | 真机群聊(117)红包页个数输0点「放入钱包发送」→ validator 拦截显示「红包个数需大于等于 1」（L260-261 count<1 生效）；未实际发送（资金保护） |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 祝福语留空时回填默认祝福语 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 二次确认展示收款人昵称 | 待重验 | - | 1 | 1 | 0 | BUG#111 同源；批次32 复核：修复 74b67501（08-06）已在 APK（14:55）内，但钱包实测余额 ¥0.00，发送 0.01 元即被「超出余额」校验拦截，二次确认弹窗不可达，条件不具备转阻塞；0816复核:余额已足¥28.32,仍缺资金测试授权 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 群聊二次确认展示红包个数 | 未测 | - | 0 | 0 | 0 | 0816复核:余额已足¥28.32(生产DB实测),仍缺资金测试授权 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 提交红包并携带会话上下文 | 未测 | - | 0 | 0 | 0 | scopeType/scopeId 越权领取判定；0816复核:余额已足¥28.32,仍缺资金测试授权 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 回传红包结果给聊天页投递 | 未测 | - | 0 | 0 | 0 | 0816复核:余额已足¥28.32,仍缺资金测试授权 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 展示可用余额提示条 | 已通过 | 批次35 | 0 | 0 | 0 | 真机：automation-buddy 单聊附加面板翻页进红包发送页，「钱包余额 ￥0.00」提示条渲染且与钱包页真实余额一致 |
