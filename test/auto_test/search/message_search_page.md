# `page/search/message_search_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | ``page/search/message_search_page.dart`` | 输入关键词防抖触发搜索 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/search/message_search_page.dart` | 点清除按钮重置搜索状态 | 已通过 | 批次81 | 1 | 1 | 0 | |
| 无待办 | - | `page/search/message_search_page.dart` | 按会话类型筛选搜索结果 | 已通过 | 批次62 | 1 | 1 | 0 | 真机：点「私聊」chip→logcat type=C2C 实锤；chips「全部/私聊/群聊」渲染 |
| 无待办 | - | ``page/search/message_search_page.dart`` | 按时间范围筛选搜索结果 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | — | `page/search/message_search_page.dart` | E2EE 下展示搜索关闭说明态 | 已通过 | 批次62 | 0 | 0 | 0 | 真机：错误态重试后呈现「消息搜索未启用/端到端加密已开启」（fts 请求→FtsFeatureDisabledException→searchDisabled 态） |
| 无待办 | - | ``page/search/message_search_page.dart`` | 搜索出错时展示重试入口 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/search/message_search_page.dart` | 展示历史记录并点击回填搜索 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 macOS 沙箱（9801 能力注入 message_search+明文种子）：历史区展示+点击回填重搜出结果；环境配方与判据见 integration_test/search/ms_history_acceptance_test.dart | |
| 无待办 | - | `page/search/message_search_page.dart` | 删除单条历史与清空全部历史 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 macOS 沙箱：xmark 单条删除+清除全部+空历史态文案均验证 | |
| 无待办 | - | ``page/search/message_search_page.dart`` | 展示搜索范围并切到全局搜索 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/search/message_search_page.dart` | 滚动触底加载更多结果 | 已通过 | 批次112 | 1 | 1 | 0 | 批次112 沙箱全链通过（统计条 total=25+第二页条目）。连带修复后端 fts 六处 SQL 缺陷（C2G 列名/jsonb/参数双记账/C2C 中文分词等，imboy 23f96d4e，C2G 搜索与筛选搜索此前从未可用） | |
| 无待办 | - | `page/search/message_search_page.dart` | 点结果跳聊天页并定位消息 | 已通过 | 批次112 | 1 | 1 | 0 | 批次112 沙箱：ChatPage.peerId=发送者 msgId 定位（回归断言）。连带修复对端判定 P1（C2C 恒取 toId 收到消息打开和自己聊天；C2G 取 fromId 全错，imboyapp 8b5b7290） | |
| 无待办 | - | `page/search/message_search_page.dart` | 无结果空态与重置筛选按钮 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 沙箱：无结果空态+时间筛选激活后重置按钮可点 | |
