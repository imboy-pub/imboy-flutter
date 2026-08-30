# `page/workspace/project/w2/project_milestones_page.dart`

> 功能点 13 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 项目详情「项目协作」区点「里程碑」入口进入（路由 …/milestones），页标题「项目里程碑」 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 数据三态+403：首屏加载视图 / 错误视图+重试 / 非成员直访 403 无权限专属视图 / 无里程碑空态视图 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 里程碑卡片渲染：名称、状态文案（已达成绿色/计划中灰色）、截止日期（有则显示）与状态图标（达成印章/计划旗子） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 创建里程碑：点「创建里程碑」按钮弹对话框填名称（+可选截止日期）确认后成功 toast + 列表刷新 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 创建校验：名称必填；截止日期填写时必须为 YYYY-MM-DD 格式，否则错误提示不发请求 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 标记达成：planned 行点「标记达成」按钮，状态变 reached（图标/文案变化）+ 成功 toast | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 重复标记幂等：对已达成里程碑再次触发 reach，显示「已达成」明确 toast，不报错 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 状态单向不可回退：reached 行不渲染任何操作按钮，无法改回 planned | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 状态筛选：all/planned/reached 分段按钮切换，筛选变化后列表重置第 1 页重新拉取 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 加载更多启发式：已加载条数达到满页（每页 10 条）时显示「加载更多」按钮追加下一页 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | Workspace Guest 进入：显示只读说明行，创建按钮与标记达成按钮隐藏（服务端 403 兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 归档工作区下进入：创建/标记达成入口禁用隐藏（写操作被服务端 980 拒绝兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_milestones_page.dart` | 下拉刷新：下拉重新拉取当前筛选下已加载的全部页数据 | 未测 | - | 0 | 0 | 0 | |
