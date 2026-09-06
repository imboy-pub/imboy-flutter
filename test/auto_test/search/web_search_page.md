# `page/search/web_search_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/search/web_search_page.dart` | 移动端无该页入口（Web 专用） | 已通过 | §十七 | 0 | 0 | 0 | |
| 无待办 | - | `page/search/web_search_page.dart` | 输入关键词防抖触发全局搜索 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 macOS 沙箱：页面本体无 kIsWeb 门，推 /web_search 真实执行；300ms 防抖自动搜索实证；配方见 integration_test/search/web_search_acceptance_test.dart | |
| 无待办 | - | `page/search/web_search_page.dart` | 点清除按钮重置搜索状态 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：清除后输入框空+结果区重置 | |
| 无待办 | - | `page/search/web_search_page.dart` | 并行搜索消息/联系人/群组/会话 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：messages/contacts 分组渲染实证（Future.wait 四路并行） | |
| 无待办 | - | `page/search/web_search_page.dart` | 结果按类型分组并加分组标题 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：分组标题按 conversations/messages/contacts 顺序渲染 | |
| 无待办 | - | `page/search/web_search_page.dart` | 结果标题与摘要关键词高亮 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：TextHighlight 高亮渲染 | |
| 无待办 | - | `page/search/web_search_page.dart` | 点会话/消息结果进入聊天 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：消息结果→ChatPage peerId=对端 | |
| 无待办 | - | `page/search/web_search_page.dart` | 点联系人结果进入资料页 | 已通过 | 批次112 | 1 | 1 | 0 | 批次112 沙箱：PeopleInfoPage 挂载。连带修复 P1 路由 bug（推 /people_info/:id 不存在→/contact/people/:id，imboyapp 8b5b7290；此前点联系人结果恒无反应） | |
| 阻塞 | 需本地库群 shadow 行数据（真机日常包长期登录账号可测） | `page/search/web_search_page.dart` | 点群组结果进入群聊会话 | 未测 | 批次112 | 0 | 0 | 0 | 批次112 沙箱评估：代码路径与已验证的消息/联系人点击同构（context.push）；本地群表无测试群数据（shadow 同步未落），数据齐备后单独验证 | |
| 无待办 | - | `page/search/web_search_page.dart` | 加载最近搜索并点击回填 | 已通过 | 批次112 | 1 | 1 | 0 | 批次112 沙箱：回填+重搜请求实证。连带修复 P2 UX bug（onTap 不退出 showRecent 态，结果被遮蔽=点了没反应，imboyapp 8b5b7290） | |
| 无待办 | - | `page/search/web_search_page.dart` | 清除本地搜索历史记录 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：清空后历史区空 | |
| 无待办 | - | `page/search/web_search_page.dart` | 无结果态与搜索错误态展示 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：无结果空态（slash_circle+查询词回显）；错误态为防御性渲染（四路子搜索各自 fail-soft） | |
