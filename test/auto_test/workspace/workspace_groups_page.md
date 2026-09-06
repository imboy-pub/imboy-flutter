# `page/workspace/workspace_groups_page.dart`

> 功能点 8 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需无任何工作区的账号 | `page/workspace/workspace_groups_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 未测 | 批次W2R1 | 0 | 0 | 0 | 现有AB账号均有工作区 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 进入群组导航先显示加载态后渲染群列表 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 加载帧瞬态以请求渲染链判定 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 加载失败展示服务端错误消息与重试按钮，点重试重新拉取 | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：adapterForTest 注入业务失败（app.main 前设置才打到已构造实例）→ WorkspaceErrorView+重试；解除后重试恢复空列表态 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 群卡渲染群头像（无头像展示占位图标）+群名+「N 名成员」副标题+聊天气泡图标 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 群列表为空时空态展示标题与副标题提示 | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：SQL 造空工作区（无模板群）→ 「还没有工作区群组」+副标题 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 点击群卡复用现有群聊页进入 /chat/:groupId（C2G 会话，带标题与头像） | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 列表按 scope=workspace 严格分区，仅展示本工作区群（其他来源群不出现） | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：本区 General 在、他区 AT-WS2-General（SQL 改名反例标记）不在；workspace_shell_acceptance_test.dart |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 离开再进入群组导航重新拉取列表（provider 自动销毁重建） | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 已修：与频道页同款ref.listen修法；logcat证切回后新GET groups |
