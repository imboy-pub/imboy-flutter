# `page/workspace/project/w2/project_channels_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 项目详情「项目协作」区点「项目频道」入口进入（路由 …/channels），页标题「项目频道」 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 数据三态+403：首屏加载视图 / 错误视图+重试 / 非成员直访 403 无权限专属视图 / 无关联频道空态视图 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 403/空态实测过；断网走重试拦截器 3 次约 3 分钟，期间无 UI 反馈 |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 已关联频道列表渲染：频道头像（无头像显示音量图标）+ 频道名，可写行尾显示解除关联图标按钮 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 关联频道：点「关联频道」拉取候选后底部弹层列出候选频道名，选择后关联成功 toast + 列表刷新 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 候选范围：选择器仅列出当前工作区的频道集合（同工作区频道，不含 personal/私信） | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 无候选提示：工作区无可用频道时点「关联频道」提示无候选频道，不弹选择器 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 重复关联幂等：选择已关联的频道再次关联，显示「已关联」明确 toast，不报错不重复入库 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 解除关联：点解除图标 → 确认弹层（标题含频道名）→ 确认后成功 toast，该频道行从列表移除 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 分页加载更多：关联频道超过一页时显示「加载更多」按钮追加下一页，加载中底部显示转圈 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | Workspace Guest 进入：服务端直接 403，整页显示「无权限：仅项目成员…」专属视图（比隐藏按钮更严） | 已通过 | 批次W2R1 | 0 | 0 | 0 | 原描述「按钮隐藏」不准，实测为整页 403 视图 |
| 无待办 | - | `page/workspace/project/w2/project_channels_page.dart` | 归档工作区下进入：写入口全部隐藏禁用（写操作被服务端 980 拒绝兜底） | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
