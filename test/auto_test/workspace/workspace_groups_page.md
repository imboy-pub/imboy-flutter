# `page/workspace/workspace_groups_page.dart`

> 功能点 8 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需无任何工作区的账号 | `page/workspace/workspace_groups_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 未测 | 批次W2R1 | 0 | 0 | 0 | 现有AB账号均有工作区 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 进入群组导航先显示加载态后渲染群列表 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 加载帧瞬态以请求渲染链判定 |
| 阻塞 | 需错误注入手段 | `page/workspace/workspace_groups_page.dart` | 加载失败展示服务端错误消息与重试按钮，点重试重新拉取 | 未测 | 批次W2R1 | 0 | 0 | 0 | 断网致启动受阻无法到达错误态 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 群卡渲染群头像（无头像展示占位图标）+群名+「N 名成员」副标题+聊天气泡图标 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 阻塞 | 需无群的工作区 | `page/workspace/workspace_groups_page.dart` | 群列表为空时空态展示标题与副标题提示 | 未测 | 批次W2R1 | 0 | 0 | 0 | 模板建区必含General群 |
| 无待办 | - | `page/workspace/workspace_groups_page.dart` | 点击群卡复用现有群聊页进入 /chat/:groupId（C2G 会话，带标题与头像） | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 阻塞 | 需他区群作反例 | `page/workspace/workspace_groups_page.dart` | 列表按 scope=workspace 严格分区，仅展示本工作区群（其他来源群不出现） | 未测 | 批次W2R1 | 0 | 0 | 0 | create临时区建好后可解 |
| 待修复 | 2026-08-30 | `page/workspace/workspace_groups_page.dart` | 离开再进入群组导航重新拉取列表（provider 自动销毁重建） | 有BUG待修 | 批次W2R1 | 1 | 0 | 1 | 壳IndexedStack保活切回无重拉请求 |
