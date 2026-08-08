# `page/search/search_chat_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/search/search_chat_page.dart` | 输入关键词防抖搜索本会话 | 已通过 | 批次63 | 0 | 0 | 0 | 真机：输入 qa-collect→logcat 实锤 fts/msg?keyword=qa-collect&page=1&size=50&type=C2C（L68-69 300ms 防抖，size=50 本会话范围） |
| 回归复测 | 2026-08-07 | `page/search/search_chat_page.dart` | 回车提交立即执行搜索 | 已通过 | 批次63 | 0 | 0 | 0 | 真机：焦点在输入框按回车→logcat 立即发出请求（L161 onSubmitted 直连 performSearch 无防抖）；首次按回车焦点丢失无请求，重聚焦后成功 |
| 回归复测 | 2026-08-07 | `page/search/search_chat_page.dart` | 按全部/文本/图片类型筛选 | 已通过 | 批次63 | 0 | 0 | 0 | 真机：点「文本」chip→logcat msg_type=text 实锤（L237-240 _applyFilter 入 provider） |
| 无待办 | — | `page/search/search_chat_page.dart` | 搜索被策略关闭时展示锁图标态 | 已通过 | 批次63 | 1 | 1 | 0 | 真机复见「消息搜索未启用/端到端加密已开启」锁图标态（L293-299 NoDataView lock_outline，无重试入口） |
| 回归复测 | 2026-08-07 | `page/search/search_chat_page.dart` | 搜索出错时展示重试入口 | 已通过 | 批次63 | 0 | 0 | 0 | 代码确认 L300-306 错误态 NoDataView(searchError)+onTop:performSearch 重试；断网同款错误态+重试闭环已在 message_search L13 真机验证（同一 FtsApi/catch 路径）；本页断网构造失败（svc wifi disable 后 SIM 数据兜底仍通） |
| 阻塞 | 需非E2EE测试环境 | `page/search/search_chat_page.dart` | 点历史记录回填并重搜 | 未测 | - | 0 | 0 | 0 | 历史仅在搜索成功时写入（L112 addToHistory）；E2EE 下搜索恒禁用→历史恒空（真机清空后无历史区，L266-267 空则 SizedBox.shrink） | |
| 阻塞 | 需非E2EE测试环境 | `page/search/search_chat_page.dart` | 结果列表渲染与关键词高亮 | 未测 | - | 0 | 0 | 0 | 服务端搜索被策略关闭无结果；代码确认高亮 L115-122 HighlightedWord（primary 色加粗） | |
| 阻塞 | 需非E2EE测试环境 | `page/search/search_chat_page.dart` | 异步加载结果作者头像昵称 | 未测 | - | 0 | 0 | 0 | 无结果不可见；代码确认 L337 getCachedContact 缓存头像昵称 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/search_chat_page.dart` | 点结果跳聊天页并定位消息 | 未测 | - | 0 | 0 | 0 | 无结果可点 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/search_chat_page.dart` | 无匹配结果时展示空态 | 未测 | - | 0 | 0 | 0 | 代码确认 L310-330 _buildEmptyResults（searchNoResults 文案+放大镜图标）；E2EE 下恒搜索关闭态不可达 | |
| 无待办 | - | `page/search/search_chat_page.dart` | 搜索框占位文案展示 | 已通过 | 批次26 | 1 | 1 | 0 | 真机复验通过：placeholder 已是「搜索聊天内容」 |
