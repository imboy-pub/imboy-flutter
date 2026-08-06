# `page/channel/channel_comment_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 0 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_comment_page.dart` | 发布评论落库与自动滚动到底 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 评论点赞与取消点赞计数增减 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 标题栏评论计数随增删刷新 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 无评论时空态渲染 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/channel/channel_comment_page.dart` | 原消息正文预览渲染语音消息 | BUG已修待验 | 批次26 | 1 | 0 | 1 | 已修待真机复验：真实渲染点是 channel_article_page.dart；根因是 publish_bar 为绕过后端空 content 校验塞了占位符，改在渲染侧映射 |
| 回归复测 | 2026-08-06 | `page/channel/channel_comment_page.dart` | 评论输入框表情面板输入与删除 | 待重验 | 批次26 | 0 | 0 | 0 | 已撤回：同上，退格键默认渲染，需真机复核 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 评论首屏加载与失败态重试 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 下拉刷新重载评论列表 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 滚动到底加载更多评论分页 | 待重验 | 批次25 | 0 | 0 | 0 | 需单条消息 20 条以上评论 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 回复评论引用条显示、聚焦与取消 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 删除本人评论确认与无权限提示 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 有内容才展开发送按钮的动效收放 | 待重验 | 批次25 | 0 | 0 | 0 | |
