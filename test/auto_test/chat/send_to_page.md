# `page/chat/send_to/send_to_page.dart`

> 功能点 10 个 | bug 发现 5 / 解决 3 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待复验 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 加载可转发的会话联系人列表 | BUG已修待验 | 批次27 | 2 | 0 | 2 | 批次27 真机发现两处，均已修待验：①群会话标题为空 —— 本页用裸 `contact.title`，而 `ConversationModel.displayTitle` 的注释明确要求 UI 一律走它；连带修了 provider 搜索同样用裸 title（导致群名搜不出来）②`Container(color:)` 的 ColoredBox 挡在 Scaffold 的 Material 与 ListTile 之间，水波纹画不出且刷 "ink was not painted" —— 改用 Scaffold.backgroundColor，去掉整层容器 |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 输入关键词过滤联系人 | 待重验 | 批次20 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 点选与取消选择联系人 | 待重验 | 批次20 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/send_to/send_to_page.dart` | 点发送转发消息给选中对象 | 已通过 | 批次20 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/send_to/send_to_page.dart` | 发送成功后关闭页面回退 | 已通过 | 批次20 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 未选联系人直接点发送即返回 | 待重验 | 批次20 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 部分转发失败留页并提示 | 待重验 | 批次20 | 0 | 0 | 0 | 需断网构造部分失败 |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 无联系人时展示空态文案 | 待重验 | 批次20 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/send_to/send_to_page.dart` | 转发成功 toast 文案提示 | 已通过 | 批次27 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/send_to/send_to_page.dart` | 点返回按钮取消转发 | 待重验 | 批次20 | 0 | 0 | 0 | |
