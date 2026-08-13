# `page/channel/channel_compose_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_compose_page.dart` | Markdown 格式工具栏七个按钮插入语法 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 空内容时预览与发布按钮置灰 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 退出保存草稿与再次进入恢复标题正文 | 已通过 | 批次68 | 0 | 0 | 0 | 真机：重进 compose 标题 qa_batch68_title + 正文 qa_batch68_body_test_001**** 完整恢复 |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 标题输入与临界字数计数器显隐 | 已通过 | 批次68 | 0 | 0 | 0 | 真机：标题 qa_batch68_title 输入；计数 2000-24=1976 实时显示（正文 24 字） |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 正文多行输入与聚焦边框态 | 已通过 | 批次68 | 0 | 0 | 0 | 真机：正文输入+加粗插入 **** 计数-4 联动；聚焦边框态代码确认 |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 选图上限九张与添加格子隐藏 | 已通过 | 批次78 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 长按图片标记封面与封面角标 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 删除已选图片与封面标记回退 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 预览弹层标题封面正文九宫格渲染 | 已通过 | 批次68 | 0 | 0 | 0 | 真机：预览弹层（纱罩+标题+正文 markdown 原样+继续编辑/发布）打开与关闭正常 |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 图片并发上传进度与部分失败重试 | 已通过 | 批次78 | 0 | 0 | 0 | |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 发布图文消息并清除草稿返回 | 已通过 | 批次68 | 0 | 0 | 0 | 真机：无图发布成功（qa_batch68_title 进消息流+点赞评论分享按钮渲染+返回频道详情）；重进 compose 草稿已清空（计数恢复 2000+预览发布 disabled 联动）；图文部分待 BUG#137 修复后复验 |
| 无待办 | - | `page/channel/channel_compose_page.dart` | 已选图返回时拦截确认弹窗 | 已通过 | 批次78 | 0 | 0 | 0 | |
