# `page/workspace/project/w2/project_insights_page.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 项目详情「项目协作」区点「内容聚合」入口进入（路由 …/insights），页标题对应聚合入口文案 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 标题「内容聚合」 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 四 Tab 渲染与切换：置顶消息/资源链接/项目动态/相关帖子 TabBar，点 Tab 或左右滑动切换视图 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 点切+左滑切均实测 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | Tab 独立三态：每个 Tab 各自的加载视图/空态/错误视图+重试互不影响，切 Tab 不重置其他 Tab 数据 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 四 Tab 混合切换各态独立正常 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 非项目成员直访：403 时对应 Tab 显示无权限专属视图（锁图标 + 文案 + 重试） | 已通过 | 批次W2R1 | 0 | 0 | 0 | Guest 四端点均 403，UI 锁图标视图 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 置顶消息 Tab：渲染置顶摘要行（作者名或消息类型 + 时间，无消息正文），满页时显示「加载更多」分页追加 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 11 条实测 10+加载更多→11 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 资源链接 Tab：渲染资源行（名称 + URL 文本只读展示），后端有界数组单页直出 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 项目动态 Tab：渲染事件行（事件类型 + 时间，无消息正文），满页时显示「加载更多」分页追加 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 5 条实测无正文 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 相关帖子 Tab：渲染帖子摘要行（作者名或消息类型 + 时间），后端有界摘要单页直出 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 种子无帖子，空态+单页契约 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 各 Tab 空态：无数据时显示对应空态文案（doc_text_search 图标 + 标题/副标题） | 已通过 | 批次W2R1 | 0 | 0 | 0 | 置顶/相关帖子空态实测 |
| 无待办 | - | `page/workspace/project/w2/project_insights_page.dart` | 下拉刷新：有数据的 Tab 下拉重新拉取该 Tab 数据（含分页回到第 1 页重载） | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
