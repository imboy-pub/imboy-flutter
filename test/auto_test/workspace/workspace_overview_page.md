# `page/workspace/workspace_overview_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 零工作区账号 | `page/workspace/workspace_overview_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS1~WS4,macOS)：零工作区登录落点=bootstrap 引导页（还没有工作区+创建/加入/切换到个人/重试四入口）整页空态实证；tab 页 WorkspaceEmptyView 为防御分支（零工作区时 shell 不挂载），空态职责由引导页等价承担（AT-WS1） |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 进入 Overview 先显示加载圆圈再渲染区块数据 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：ACC_A 登录进壳复现全屏加载圆圈→区块数据渲染 |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 加载失败展示服务端错误消息与重试按钮，点重试重新拉取 | 已通过 | 批次W2R2 | 0 | 0 | 0 | W2R4 未复测（需断网重启；历史断网触发 EMUI 防误触锁屏怪癖）；批次W2R2 断网证据沿用，本页收敛仅新增成员卡区块、加载/错误态代码未变 |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 资源摘要卡展示项目/群组/频道三个计数瓦片与数量 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：WS1（项目2/群组1/频道1）与 WS2（项目1/群组1/频道1）双工作区计数与 API 一致 |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 点击项目计数瓦片切换壳导航到项目列表页 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：点项目瓦片切到项目 Tab（底栏第5项高亮，标题「项目」） |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 点击群组计数瓦片切换壳导航到群组列表页 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：点群组瓦片切到群组 Tab（底栏第4项高亮，标题「群组」） |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 点击频道计数瓦片切换壳导航到频道列表页 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：点频道瓦片切到频道 Tab（底栏第3项高亮，标题「频道」） |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | Channel 置顶内容区块展示空态说明（不聚合群公告） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：空态文案「群公告不在此聚合」在位 |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 最近文件区块展示空态说明（附件在频道内查看） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：空态文案「最近上传的文件将在此展示」在位 |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 成员预览展示头像+昵称（空则账号）+角色徽标，最多 8 个 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 重点复测（47461adc 新增成员卡）：头像+昵称+角色徽标渲染正常，「查看全部」进新路由 /workspace/members 正常；WS1 甲(Owner)/乙、WS2 仅甲（8 个上限仍未触发，沿用批次W2R2） |
| 无待办 | - | `page/workspace/workspace_overview_page.dart` | 成员预览为空时展示暂无成员提示文案 | 已通过 | 批次130 | 0 | 0 | 0 | AT-WOV1 全绿（integration_test/workspace/workspace_overview_empty_members_test.dart）：adapterForTest 注入空 overview payload（code=0+member_preview 缺省）→ 壳 Overview 成员预览显示 t.workspace.membersEmpty 文案 → 解除拦截 invalidate workspaceOverviewProvider 重新拉取 → 成员行恢复；无需删改 DB 成员行 |
