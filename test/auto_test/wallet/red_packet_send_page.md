# `page/wallet/red_packet_send_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 进页自动拉取真实余额 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：单聊附加面板进红包发送页，GET /wallet/balance 调用成功，余额提示条「钱包余额 ￥0.00」与实际余额一致渲染 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 单聊场景加载收款人显示名 | 已通过 | 批次159 | 0 | 0 | 0 | macOS：mock topup 后确认框展示「用户：Alice」（ContactRepo.findByUid 实查显示名，非裸 TSID 回退）；测试=wallet/red_packet_acceptance_batch159_test.dart AT-RP1 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 群聊切换普通与拼手气红包 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 校验红包金额最小 0.01 元 | 已通过 | 批次66 | 0 | 0 | 0 | 真机红包页金额输0点「放入钱包发送」→ validator 拦截「金额必须大于 0」（L72/L238 amountFen<1 即 <0.01元 生效） |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 拦截超出余额的红包金额 | 已通过 | 批次66 | 0 | 0 | 0 | 真机群红包页金额输10(>余额0)点提交→弹「余额不足」toast（L76-77 amountFen>maxBalanceFen→showError 生效）；BUG#48 确为误判，校验实际存在 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 校验群聊红包个数最小 1 个 | 已通过 | 批次66 | 0 | 0 | 0 | 真机群聊(117)红包页个数输0点「放入钱包发送」→ validator 拦截显示「红包个数需大于等于 1」（L260-261 count<1 生效）；未实际发送（资金保护） |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 祝福语留空时回填默认祝福语 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 二次确认展示收款人昵称 | 已通过 | 批次159 | 0 | 0 | 0 | macOS：mock topup 200 分后确认框断言「用户：Alice」+金额摘要 ￥1.00；BUG#111 修复效果复核通过；测试=…AT-RP1 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 群聊二次确认展示红包个数 | 已通过 | 批次159 | 0 | 0 | 0 | macOS：群深链须显式 ?type=C2G（缺省按 C2C 打开=run5 坑）→ 个数输 2 → 确认框精确断言「红包个数：2个」；测试=…AT-RP2 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 提交红包并携带会话上下文 | 已通过 | 批次159 | 0 | 0 | 0 | macOS：0.5 元红包真提交，DB 断言 red_packet 行 scope_type=C2C / scope_id=1000000051 / amount=50 / greeting=AT-RP159（B-11 会话上下文落库）；测试=…AT-RP3 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 回传红包结果给聊天页投递 | 已通过 | 批次159 | 0 | 0 | 0 | macOS：pop 回传→handleRedPacketSelection→E2EE 7101B WS 发送→msg_c2c msg_type=redPacket 行落库（C2C 出站表=msg_c2c 非-msg_c2s，run11 坑）+聊天气泡渲染祝福语；测试=…AT-RP3 |
| 无待办 | - | `page/wallet/red_packet_send_page.dart` | 展示可用余额提示条 | 已通过 | 批次35 | 0 | 0 | 0 | 真机：automation-buddy 单聊附加面板翻页进红包发送页，「钱包余额 ￥0.00」提示条渲染且与钱包页真实余额一致 |
