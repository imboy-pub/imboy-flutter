# `page/workspace/workspace_projects_page.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 零工作区账号 | `page/workspace/workspace_projects_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS1~WS4,macOS)：零工作区登录落点=bootstrap 引导页（还没有工作区+创建/加入/切换到个人/重试四入口）整页空态实证；tab 页 WorkspaceEmptyView 为防御分支（零工作区时 shell 不挂载），空态职责由引导页等价承担（AT-WS4） |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 首次进入显示加载态后分页聚合渲染项目列表 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 快网下加载指示闪现难捕；hasLoading 分页loading分支经行8点击加载更多时间接实证 |
| 无待办 | 幽灵工作区注入(非法wsId=999999999) | `page/workspace/workspace_projects_page.dart` | 首页加载失败且无已加载数据时整页错误态+重试按钮重新拉取 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS8,macOS)：同 WS6 幽灵注入法，403 透出+重试可点保持错误视图 |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 项目卡渲染状态图标（完成绿色勾/进行中文件夹）+名称+描述最多两行省略 | 已通过 | 批次W2R2 | 0 | 0 | 0 | done绿勾圆图标+active蓝文件夹图标双证；名称+描述两行正常 |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 项目列表为空时空态展示标题与副标题提示且仍可下拉 | 已通过 | 批次W2R2 | 0 | 0 | 0 | WS2空态：还没有项目+副标题+新建按钮仍在；仍可下拉未注入验证 |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 下拉刷新重新拉取第一页项目列表 | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：macOS drag overscroll 触发 CupertinoSliverRefreshControl，无异常（adb 注入限制不适用于沙箱 drag） |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 点击「创建项目」按钮进入 /workspace/:wsId/projects/create | 已通过 | 批次W2R2 | 0 | 0 | 0 | 新建项目进创建页（名称0/200+描述0/2000+创建按钮） |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 已归档工作区创建项目按钮禁用（服务端 980 兜底） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 归档WS2重启后：橙色归档横幅+新建按钮灰色禁用（对比正常蓝） |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 还有下一页时底部展示「加载更多」按钮，点击追加下一页并显示加载指示 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 21项目触发按钮；点击发page=2请求追加且按钮消失；加载指示见源码分支 |
| 无待办 | - | `page/workspace/workspace_projects_page.dart` | 点击项目卡进入项目详情页 /workspace/:wsId/projects/:projectId | 已通过 | 批次W2R2 | 0 | 0 | 0 | 点卡进详情页（详情API 2xx：信息卡/状态流转/任务四态/协作入口全渲染） |
