# `page/workspace/workspace_channels_page.dart`

> 功能点 8 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需无任何工作区的账号 | `page/workspace/workspace_channels_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 未测 | 批次W2R1 | 0 | 0 | 0 | 现有AB账号均有工作区 |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 进入频道导航先显示加载态后渲染频道列表 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 阻塞 | 需错误注入手段 | `page/workspace/workspace_channels_page.dart` | 加载失败展示服务端错误消息与重试按钮，点重试重新拉取 | 未测 | 批次W2R1 | 0 | 0 | 0 | 断网致启动受阻无法到达错误态 |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 频道卡渲染天线圆标+频道名+「N 人订阅」副标题+右箭头 | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 阻塞 | 需无频道的工作区 | `page/workspace/workspace_channels_page.dart` | 频道列表为空时空态展示标题与副标题提示 | 未测 | 批次W2R1 | 0 | 0 | 0 | 模板建区必含Announcements |
| 无待办 | - | `page/workspace/workspace_channels_page.dart` | 点击频道卡进入频道详情页 /workspace/:wsId/channels/:channelId | 已通过 | 批次W2R1 | 0 | 0 | 0 |  |
| 阻塞 | 需他区频道作反例 | `page/workspace/workspace_channels_page.dart` | 列表按 scope=workspace 严格分区，仅展示本工作区频道（其他来源频道不出现） | 未测 | 批次W2R1 | 0 | 0 | 0 | create临时区建好后可解 |
| 待修复 | 2026-08-30 | `page/workspace/workspace_channels_page.dart` | 离开再进入频道导航重新拉取列表（provider 自动销毁重建） | 有BUG待修 | 批次W2R1 | 1 | 0 | 1 | 壳IndexedStack保活切回无重拉请求 |
