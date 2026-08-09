# `page/mine/feedback/feedback_detail_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 映射反馈类型为本地化标题 | 未测 | - | 0 | 0 | 0 | 详情页需列表有数据才能进入；feedback_page 提交 bug（CHECK 约束+fail-open 假成功）导致数据无法产生，链路修复后重测 |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 展示反馈提交时间 | 未测 | - | 0 | 0 | 0 | 同上（无数据无法进入详情页） |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 按状态码渲染状态徽标颜色 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：_getFeedbackStatusColor（status 3=绿 1=橙 default=primary） |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 点击查看附件打开图片画廊 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：zoomInPhotoViewGallery(model.attach) |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 有评分时展示评分卡片 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：rating.isNotEmpty 时渲染评分卡片 |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 渲染只读星级评分条 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：RatingBar.builder ignoreGestures:true 只读 |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 展示反馈正文内容 | 未测 | - | 0 | 0 | 0 | 同上 |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 加载官方回复列表 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：pageReply→FeedbackApi().pageReply GET |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 无回复时展示暂无回复空态 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：AsyncStateView(emptyText) |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 回复加载失败可点击重试 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：AsyncStateView(onRetry) |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 按状态码渲染回复项状态色 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：_getReplyStatusColor（-1=红 0=橙 default=primary） |
| 阻塞 | 待反馈提交链路修复 | `page/mine/feedback/feedback_detail_page.dart` | 回复区超高时限高并可滚动 | 未测 | - | 0 | 0 | 0 | 同上；实现代码已读：回复区 maxHeight 屏高*0.4+ListView.separated 可滚动 |
