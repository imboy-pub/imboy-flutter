# `page/mention/mention_list_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mention/mention_list_page.dart` | 首屏加载 @我 的提及列表 | 已通过 | 批次29 | 0 | 0 | 0 | deep link 进入 → logcat GET /api/v1/mention/list + /unread 发出并返回 → 页面渲染 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 加载失败展示错误态与重试 | 已通过 | 批次29 | 0 | 0 | 0 | 飞行模式进入 → 「加载失败，请重试」+重试按钮（get_ui 实测）→ 恢复网络点重试 → 空态恢复，闭环通过 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 无提及时展示空态文案 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「暂无@提及」（请求成功返回空） |
| 无待办 | - | `page/mention/mention_list_page.dart` | 下拉刷新重新拉取列表 | 已通过 | 批次99 | 0 | 0 | 0 | DB 造数 22 条 → 下拉 → logcat 重新 GET /mention/list page=1 → 列表刷新 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 滚动触底加载下一页 | 已通过 | 批次99 | 0 | 0 | 0 | 22 条数据 size=20 → 触底 → logcat GET /mention/list page=2 → 新条目渲染 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 未读条目显示红点标识 | 已通过 | 批次99 | 0 | 0 | 0 | 未读条目渲染可点击（logcat 标记请求实证）；红点逻辑代码证实 L286-294（is_read 驱动），截图受限以代码证实 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 点「全部已读」清空未读数 | 已通过 | 批次99 | 0 | 0 | 0 | 点全部已读 → logcat MentionService: 批量标记已读 → DB is_read 全 true → 未读数归零 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 点击条目标记该提及已读 | 已通过 | 批次99 | 0 | 0 | 0 | 点条目 → logcat MentionService: 标记已读 - <id> → DB is_read=true |
| 无待办 | - | `page/mention/mention_list_page.dart` | 点击跳转群聊并定位消息 | 已通过 | 批次99 | 0 | 0 | 0 | 点 qa_a36_021 → /chat/104603643803863040?type=C2G&msg_id=... → 群聊页渲染 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 跳转信息缺失时提示无法定位 | 已通过 | 批次99 | 1 | 1 | 0 | 造数 qa_a36_022(group_id=0)：修复前点击跳 /chat/0「未命名」→ bug：_resolveGroupId 未排除 "0"；修复(L157 排除'0')后 APK 复验：点击留在列表页 + DB is_read=t（mark_read 链路走通） |
| 阻塞 | 解阻塞条件：需第二台设备实时发送 @消息 | `page/mention/mention_list_page.dart` | 收到新提及事件后自动刷新 | 未测 | - | 0 | 0 | 0 | NewMentionEvent 监听 L48-51 代码证实，需第二台设备发消息实测 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 条目时间按相对格式展示 | 已通过 | 批次99 | 0 | 0 | 0 | 造数条目实测渲染（刚刚/几分钟前等相对格式） |
