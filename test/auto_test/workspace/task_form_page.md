# `page/workspace/project/tasks/task_form_page.dart`

> 功能点 13 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 项目详情任务区「+」进入创建表单（路由 …/tasks/new），页标题「新建任务」 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 表单渲染：标题输入框（上限 500 字）+ 负责人下拉（含「暂不指派」默认项）+ 创建任务按钮 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 标题为空点提交：显示标题必填错误 toast，不发起请求 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 执行人下拉列出当前工作区 active 成员（昵称为空时显示账号） | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 选择执行人 + 填标题提交：创建成功 toast，自动返回后任务区列表可见新任务 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 保持「未指派」提交：成功创建无执行人任务，返回后任务列表刷新 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 创建命中幂等（isIdempotentHit）：显示「任务已存在」toast 而非报错 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 编辑模式（路由 …/tasks/:taskId/edit）：加载既有任务回填标题与执行人，页标题「编辑任务」 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 编辑模式加载失败：显示错误视图，点重试重新拉取任务详情 | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 已修：空表单实为重试链(~15s)加载圈；断网出「无网络+重试」错误视图，恢复reverse点重试logcat即GET并回填表单 |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 编辑修改标题/执行人后保存：成功 toast，返回后任务列表与候选列表刷新 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 编辑时改选「未指派」保存：任务执行人被清除（clearAssignee） | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 顶栏「刷新候选」按钮重拉工作区成员候选；候选加载失败显示错误行 + 重试按钮 | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 已修：_parseException透传组件异常免被toString重包；断网点刷新logcat见重拉GET，错误文案「无网络」非Instance of（widget测试佐证） |
| 无待办 | - | `page/workspace/project/tasks/task_form_page.dart` | 服务端错误透传：指派非 active 成员 400 / Guest 403 / 归档工作区 980，toast 原样显示服务端消息 | 已通过 | 批次W2R3 | 0 | 0 | 0 | 980闭环：表单开着时API归档WS2再提交，toast原样「工作区已归档，写操作被拒绝」；400/403入口被UI只读门控前置隐藏不可达 |
