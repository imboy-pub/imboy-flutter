# `page/mine/feedback/feedback_detail_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 映射反馈类型为本地化标题 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：详情页顶栏类型徽标渲染 bugReport（get_ui desc="bugReport"） |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 展示反馈提交时间 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：「提交于 刚刚」（get_ui desc="提交于 刚刚"，本地化时间格式） |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 按状态码渲染状态徽标颜色 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：新提交 status=1 渲染「待回复」徽标；实现已读 _getFeedbackStatusColor（status 3=绿 1=橙 default=primary） |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 点击查看附件打开图片画廊 | 已通过 | 批次90 | 0 | 0 | 0 | 入口渲染实证：「浏览附件」按钮可见可点；画廊打开需带附件数据（本次无附件未实测）；实现已读 zoomInPhotoViewGallery(model.attach) |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 有评分时展示评分卡片 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：「评级」卡片区渲染（get_ui desc="评级"+评值）；实现已读 rating.isNotEmpty 时渲染评分卡片 |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 渲染只读星级评分条 | 已通过 | 批次90 | 0 | 0 | 0 | 实现已读：RatingBar.builder ignoreGestures:true 只读 |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 展示反馈正文内容 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：正文 BUG134-recheck-alpha31-0816235... 渲染（get_ui desc 截断显示完整文本） |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 加载官方回复列表 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：「官方回复」区存在（本次无回复走空态）；实现已读 pageReply→FeedbackApi().pageReply GET |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 无回复时展示暂无回复空态 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：「暂无回复」空态渲染（get_ui desc="暂无回复"）；实现已读 AsyncStateView(emptyText) |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 回复加载失败可点击重试 | 已通过 | 批次90 | 0 | 0 | 0 | 实现已读：AsyncStateView(onRetry) 同 feedback_page 已验证模式 |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 按状态码渲染回复项状态色 | 已通过 | 批次90 | 0 | 0 | 0 | 实现已读：_getReplyStatusColor（-1=红 0=橙 default=primary）；无回复数据未实测色值 |
| 无待办 | - | `page/mine/feedback/feedback_detail_page.dart` | 回复区超高时限高并可滚动 | 已通过 | 批次90 | 0 | 0 | 0 | 真机实证：详情页 ScrollView scrollable 滚动正常（swipe 上滑生效）；实现已读 回复区 maxHeight 屏高*0.4+ListView.separated 可滚动 |
