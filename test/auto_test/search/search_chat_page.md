# `page/search/search_chat_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | ``page/search/search_chat_page.dart`` | 输入关键词防抖搜索本会话 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/search/search_chat_page.dart`` | 回车提交立即执行搜索 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/search/search_chat_page.dart`` | 按全部/文本/图片类型筛选 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | — | `page/search/search_chat_page.dart` | 搜索被策略关闭时展示锁图标态 | 已通过 | 批次63 | 1 | 1 | 0 | 真机复见「消息搜索未启用/端到端加密已开启」锁图标态（L293-299 NoDataView lock_outline，无重试入口） |
| 无待办 | - | ``page/search/search_chat_page.dart`` | 搜索出错时展示重试入口 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/search/search_chat_page.dart` | 点历史记录回填并重搜 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 macOS 沙箱：历史展示+回填重搜出结果；配方见 integration_test/search/sc_acceptance_test.dart | |
| 无待办 | - | `page/search/search_chat_page.dart` | 结果列表渲染与关键词高亮 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：TextHighlight 渲染+关键词高亮 | |
| 无待办 | - | `page/search/search_chat_page.dart` | 异步加载结果作者头像昵称 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：占位符替换为 SmokeAlice | |
| 无待办 | - | `page/search/search_chat_page.dart` | 点结果跳聊天页并定位消息 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：ChatPage.peerId=对端+msgId 定位 | |
| 无待办 | - | `page/search/search_chat_page.dart` | 无匹配结果时展示空态 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：search 图标+无结果文案空态 | |
| 无待办 | - | `page/search/search_chat_page.dart` | 搜索框占位文案展示 | 已通过 | 批次26 | 1 | 1 | 0 | 真机复验通过：placeholder 已是「搜索聊天内容」 |
