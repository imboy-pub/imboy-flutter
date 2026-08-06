# `page/wallet/red_packet_detail_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 展示详情加载中转圈态 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 红包不存在时展示兜底页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 拉取详情失败错误提示 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 顶部渐变头展示祝福语 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 高亮展示本人已领金额 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 未领到红包时展示替代文案 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 切换已抢光与进行中统计条 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 渲染领取记录列表与时间 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 计算并标记手气最佳领取人 | 未测 | - | 0 | 0 | 0 | 仅拼手气红包 |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 无人领取时展示空态提示 | 未测 | - | 0 | 0 | 0 | |
| 待修复 | 2026-08-06 | `page/wallet/red_packet_detail_page.dart` | 展示领取人身份标识 | 有BUG待修 | - | 1 | 0 | 1 | 与 BUG#111 同源仍未修：`redPacketReceiverLabel(uid: r.receiverUid)` 直接渲染裸 TSID，未接 ContactRepo |
| 阻塞 | 需真实红包消息素材 | `page/wallet/red_packet_detail_page.dart` | 展示零信任端解密角标 | 未测 | - | 0 | 0 | 0 | 文案硬编码未走 i18n |
