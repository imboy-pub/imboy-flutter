# `page/conversation/conversation_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 2 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/conversation/conversation_page.dart` | 加载并展示会话列表 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 下拉刷新拉取服务端权威列表 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 顶部搜索框本地过滤会话 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/conversation/conversation_page.dart` | 点击会话进入对应聊天页 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/conversation/conversation_page.dart` | 新建群会话进入会话列表 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 点击头像进入对方资料页 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 侧滑标记已读/未读 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 侧滑置顶与取消置顶会话 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 侧滑删除会话并同步服务端 | 待重验 | 批次25 | 0 | 0 | 0 | 删除为不可逆操作，须用测试会话 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 展示与关闭 E2EE 恢复横幅 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/conversation/conversation_page.dart` | 群名缺失时的标题兜底显示 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待真机复验：computeTitle 字段全仓从未被赋值，回落成员昵称拼接且不落库 |
| 回归复测 | 2026-08-07 | `page/conversation/conversation_page.dart` | 空列表与搜索无结果空态 | 待重验 | 批次25 | 0 | 0 | 0 | |
