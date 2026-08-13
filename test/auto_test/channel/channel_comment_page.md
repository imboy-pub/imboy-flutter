# `page/channel/channel_comment_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 0 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_comment_page.dart` | 发布评论落库与自动滚动到底 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 评论点赞与取消点赞计数增减 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 标题栏评论计数随增删刷新 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_comment_page.dart` | 无评论时空态渲染 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 待复验 | 2026-08-06 | `page/channel/channel_comment_page.dart` | 原消息正文预览渲染语音消息 | 待重验 | 批次26 | 1 | 0 | 1 | 代码侧闭环核验（2026-08-09）：发布端 channel_publish_bar.dart L202 content:'[voice]'；渲染端 channel_article_page.dart L572-587 _displayBody '[voice]'→本地化「语音」提示、'[media]'→''（媒体由 _buildMedia 渲染）；阅读页无音频播放器是设计意图（注释 L576），非缺陷；过时注释（声称的 _buildAudioContent 不存在）已修；剩余=需真实语音频道消息数据+设备空闲真机复验 |
| 回归复测 | 2026-08-06 | `page/channel/channel_comment_page.dart` | 评论输入框表情面板输入与删除 | 已通过 | 批次37 | 0 | 0 | 0 | 真机：😋😜 输入+退格删除，面板 9 tab 网格正常 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 评论首屏加载与失败态重试 | 已通过 | 批次37 | 0 | 0 | 0 | 真机首屏加载正常；失败态 NoDataView+onTop 重试代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 下拉刷新重载评论列表 | 已通过 | 批次37 | 0 | 0 | 0 | 真机下拉+RefreshIndicator onRefresh 代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 滚动到底加载更多评论分页 | 已通过 | 批次37 | 0 | 0 | 0 | 仅 1 条评论(<20)未触发分页；分页链代码确认(_onScroll 距底200px→offset游标→hasMore) |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 回复评论引用条显示、聚焦与取消 | 已通过 | 批次37 | 0 | 0 | 0 | 真机三态：引用条出现→发送落库→取消收起 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 删除本人评论确认与无权限提示 | 已通过 | 批次37 | 0 | 0 | 0 | 真机：弹窗/取消保留/确认删除/计数 2→1；isMine 非本人无删除入口代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_comment_page.dart` | 有内容才展开发送按钮的动效收放 | 已通过 | 批次37 | 0 | 0 | 0 | 真机：输入出现/清空收起；_hasText listener 代码确认 |
