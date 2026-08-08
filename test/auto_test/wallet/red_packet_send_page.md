# `page/wallet/red_packet_send_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 进页自动拉取真实余额 | 待重验 | - | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/wallet/red_packet_send_page.dart` | 单聊场景加载收款人显示名 | BUG已修待验 | - | 0 | 0 | 0 | BUG#111 同源修改 |
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 群聊切换普通与拼手气红包 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 校验红包金额最小 0.01 元 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 拦截超出余额的红包金额 | 待重验 | - | 0 | 0 | 0 | BUG#48「缺余额校验」已改判为误判，校验实际存在 |
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 校验群聊红包个数最小 1 个 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 祝福语留空时回填默认祝福语 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 二次确认展示收款人昵称 | BUG已修待验 | - | 1 | 1 | 0 | BUG#111 同源；批次32 复核：修复 74b67501（08-06）已在 APK（14:55）内，但钱包实测余额 ¥0.00，发送 0.01 元即被「超出余额」校验拦截，二次确认弹窗不可达，条件不具备转阻塞 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 群聊二次确认展示红包个数 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 提交红包并携带会话上下文 | 未测 | - | 0 | 0 | 0 | scopeType/scopeId 越权领取判定 |
| 阻塞 | 需余额>0 且用户授权 | `page/wallet/red_packet_send_page.dart` | 回传红包结果给聊天页投递 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/wallet/red_packet_send_page.dart` | 展示可用余额提示条 | 待重验 | - | 0 | 0 | 0 | |
