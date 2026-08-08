# `page/search/message_search_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/search/message_search_page.dart` | 输入关键词防抖触发搜索 | 已通过 | 批次62 | 0 | 0 | 0 | 真机：logcat 实锤 fts/msg?keyword=qa-collect-59-test&page=1&size=20（L82-92 300ms 防抖） |
| 回归复测 | 2026-08-07 | `page/search/message_search_page.dart` | 点清除按钮重置搜索状态 | 有BUG待修 | 批次62 | 1 | 0 | 1 | BUG#130：真机清空后点「私聊」chip 旧关键词 fts/msg 请求复出+chips 残留；根因 resetSearch copyWith 无 currentQuery:''（L118-127）；agent 已修 15/15 测试全绿，真机复验需新 APK |
| 无待办 | - | `page/search/message_search_page.dart` | 按会话类型筛选搜索结果 | 已通过 | 批次62 | 1 | 1 | 0 | 真机：点「私聊」chip→logcat type=C2C 实锤；chips「全部/私聊/群聊」渲染 |
| 回归复测 | 2026-08-07 | `page/search/message_search_page.dart` | 按时间范围筛选搜索结果 | 已通过 | 批次62 | 0 | 0 | 0 | 真机：点「今天」chip→logcat start_date=2026-08-08 实锤；chips「所有时间/今天/本周」渲染 |
| 无待办 | — | `page/search/message_search_page.dart` | E2EE 下展示搜索关闭说明态 | 已通过 | 批次62 | 0 | 0 | 0 | 真机：错误态重试后呈现「消息搜索未启用/端到端加密已开启」（fts 请求→FtsFeatureDisabledException→searchDisabled 态） |
| 回归复测 | 2026-08-07 | `page/search/message_search_page.dart` | 搜索出错时展示重试入口 | 已通过 | 批次62 | 0 | 0 | 0 | 真机闭环：断网错误态「搜索错误/搜索失败，请重试」+重试按钮可点；恢复网络点重试→logcat fts/msg 请求发出（keyword=zz404-offline-test 条件保留）→错误态消失进 E2EE 禁用态 |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 展示历史记录并点击回填搜索 | 未测 | - | 0 | 0 | 0 | 历史仅在搜索成功时写入；E2EE 下搜索恒禁用→恒暂无搜索历史，无写入路径 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 删除单条历史与清空全部历史 | 未测 | - | 0 | 0 | 0 | 同历史区不可达（仅搜索成功才写入）；代码确认清空全部按钮在历史非空才渲染（L458-530） | |
| 回归复测 | 2026-08-07 | `page/search/message_search_page.dart` | 展示搜索范围并切到全局搜索 | 已通过 | 批次62 | 0 | 0 | 0 | 代码确认 L129-130 仅 conversationTitle 非空才显示范围提示（L376-398 含切全局搜索）；唯一入口 right_button.dart:60 不带该参数→当前不可达（死路径） |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 滚动触底加载更多结果 | 未测 | - | 0 | 0 | 0 | 服务端搜索被策略关闭，无结果列表可滚动 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 点结果跳聊天页并定位消息 | 未测 | - | 0 | 0 | 0 | 无结果可点（服务端搜索被策略关闭） | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 无结果空态与重置筛选按钮 | 未测 | - | 0 | 0 | 0 | 空态依赖真实搜索结果；E2EE 下恒搜索关闭态 | |
