# `page/mention/mention_list_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mention/mention_list_page.dart` | 首屏加载 @我 的提及列表 | 已通过 | 批次29 | 0 | 0 | 0 | deep link 进入 → logcat GET /api/v1/mention/list + /unread 发出并返回 → 页面渲染 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 加载失败展示错误态与重试 | 已通过 | 批次29 | 0 | 0 | 0 | 飞行模式进入 → 「加载失败，请重试」+重试按钮（get_ui 实测）→ 恢复网络点重试 → 空态恢复，闭环通过 |
| 无待办 | - | `page/mention/mention_list_page.dart` | 无提及时展示空态文案 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「暂无@提及」（请求成功返回空） |
| 阻塞 | 需存在 @我 的提及数据 | `page/mention/mention_list_page.dart` | 下拉刷新重新拉取列表 | 未测 | 批次29 | 0 | 0 | 0 | 空态 NoDataView 不可下拉；有数据后 ListView 可验 onRefresh L238 |
| 阻塞 | 解阻塞条件：需超过 20 条 @提及数据 | `page/mention/mention_list_page.dart` | 滚动触底加载下一页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需他人在群里 @当前账号 | `page/mention/mention_list_page.dart` | 未读条目显示红点标识 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需存在未读 @提及 | `page/mention/mention_list_page.dart` | 点「全部已读」清空未读数 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需存在未读 @提及 | `page/mention/mention_list_page.dart` | 点击条目标记该提及已读 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：需他人在群里 @当前账号 | `page/mention/mention_list_page.dart` | 点击跳转群聊并定位消息 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需含缺失 group_id/msg_id 字段的提及数据 | `page/mention/mention_list_page.dart` | 跳转信息缺失时提示无法定位 | 未测 | 批次29 | 0 | 0 | 0 | SnackBar(navInfoMissing) 代码证实 L176-180，需数据实测 |
| 阻塞 | 解阻塞条件：需第二台设备实时发送 @消息 | `page/mention/mention_list_page.dart` | 收到新提及事件后自动刷新 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需存在 @我 的提及数据 | `page/mention/mention_list_page.dart` | 条目时间按相对格式展示 | 未测 | 批次29 | 0 | 0 | 0 | _formatTime L341-360 代码证实（7天/天/时/分/刚刚），需条目实测 |
