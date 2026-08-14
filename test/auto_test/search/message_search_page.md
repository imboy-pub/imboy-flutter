# `page/search/message_search_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 1 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | ``page/search/message_search_page.dart`` | 输入关键词防抖触发搜索 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/search/message_search_page.dart`` | 点清除按钮重置搜索状态 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/search/message_search_page.dart` | 按会话类型筛选搜索结果 | 已通过 | 批次62 | 1 | 1 | 0 | 真机：点「私聊」chip→logcat type=C2C 实锤；chips「全部/私聊/群聊」渲染 |
| 无待办 | - | ``page/search/message_search_page.dart`` | 按时间范围筛选搜索结果 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | — | `page/search/message_search_page.dart` | E2EE 下展示搜索关闭说明态 | 已通过 | 批次62 | 0 | 0 | 0 | 真机：错误态重试后呈现「消息搜索未启用/端到端加密已开启」（fts 请求→FtsFeatureDisabledException→searchDisabled 态） |
| 无待办 | - | ``page/search/message_search_page.dart`` | 搜索出错时展示重试入口 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 展示历史记录并点击回填搜索 | 未测 | - | 0 | 0 | 0 | 历史仅在搜索成功时写入；E2EE 下搜索恒禁用→恒暂无搜索历史，无写入路径 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 删除单条历史与清空全部历史 | 未测 | - | 0 | 0 | 0 | 同历史区不可达（仅搜索成功才写入）；代码确认清空全部按钮在历史非空才渲染（L458-530） | |
| 无待办 | - | ``page/search/message_search_page.dart`` | 展示搜索范围并切到全局搜索 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 滚动触底加载更多结果 | 未测 | - | 0 | 0 | 0 | 服务端搜索被策略关闭，无结果列表可滚动 | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 点结果跳聊天页并定位消息 | 未测 | - | 0 | 0 | 0 | 无结果可点（服务端搜索被策略关闭） | |
| 阻塞 | 需非E2EE测试环境 | `page/search/message_search_page.dart` | 无结果空态与重置筛选按钮 | 未测 | - | 0 | 0 | 0 | 空态依赖真实搜索结果；E2EE 下恒搜索关闭态 | |
