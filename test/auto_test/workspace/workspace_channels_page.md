# `page/workspace/workspace_channels_page.dart`

> 功能点 8 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 零工作区账号 | `page/workspace/workspace_channels_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS1~WS4,macOS)：零工作区登录落点=bootstrap 引导页（还没有工作区+创建/加入/切换到个人/重试四入口）整页空态实证；tab 页 WorkspaceEmptyView 为防御分支（零工作区时 shell 不挂载），空态职责由引导页等价承担（AT-WS2） |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 进入频道导航先显示加载态后渲染频道列表 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | 幽灵工作区注入(非法wsId=999999999) | `page/workspace/workspace_channels_page.dart` | 加载失败展示服务端错误消息与重试按钮，点重试重新拉取 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS6,macOS)：幽灵工作区注入驱动 shell 挂载，非法 wsId 服务端 403「非工作区成员，禁止访问该资源」透出 WorkspaceErrorView+重试按钮可点，点重试仍 403 保持错误视图（waitFor 30s） |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 频道卡渲染天线圆标+频道名+「N 人订阅」副标题+右箭头 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 频道列表为空时空态展示标题与副标题提示 | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：空工作区 → 「还没有工作区频道」+副标题 |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 点击频道卡进入频道详情页 /workspace/:wsId/channels/:channelId | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 列表按 scope=workspace 严格分区，仅展示本工作区频道（其他来源频道不出现） | 已通过 | 批次115 | 0 | 0 | 0 | 批次115 沙箱：本区 Announcements 在、他区 at-ws2-announcements 不在 |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 离开再进入频道导航重新拉取列表（provider 自动销毁重建） | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 已修：页面ref.listen壳目的地切回即invalidate重拉；logcat证切回后新GET channels |
