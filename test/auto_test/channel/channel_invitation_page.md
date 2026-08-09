# `page/channel/channel_invitation_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 「我发出的」tab 列表渲染与发起邀请入口 | 已通过 | 批次18 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 收到与发出两类邀请并行加载与加载态 | 已通过 | 批次70 | 0 | 0 | 0 | 真机：双 tab 均渲染（我收到的/我发出的），空态各自独立 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 加载失败整页错误态与重试按钮 | 已通过 | 批次70 | 0 | 0 | 0 | 代码确认：_error=t.common.loadError（L81）+ 重试清 _error（L57/L72） |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 「我收到的」卡片频道名邀请人时间渲染 | 已通过 | 批次71 | 0 | 0 | 0 | 真机：频道名「双真机测试频道-20260808」+ 待处理 + 拒绝/接受/打开频道按钮齐全 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 接受邀请提交、提示与列表刷新 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：117 点「接受」→ POST accept 200(61B) → 邀请 DB status=1 → channel_subscription uid=50 status=1 → my 列表 265B→70B 刷空 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 拒绝邀请提交与结果提示 | 已通过 | 批次71 | 0 | 0 | 0 | 真机三次拒绝成功（61B+DB status=2+列表刷空）；一次63B not_found 系页面陈旧数据误点旧卡片（已accepted），非代码缺陷 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 处理中按钮禁用与异常后解锁 | 已通过 | 批次70 | 0 | 0 | 0 | 代码确认：_processingIds 集合（L33/L94-97）+ try-finally 解锁（L109-114 注释：旧实现无 try-finally 会永久禁用，已修） |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 五种邀请状态文案与配色映射 | 已通过 | 批次70 | 0 | 0 | 0 | 代码确认 L144-174：0 pending(orange)/1 accepted(green)/2 rejected/3 expired/4 cancelled(gray) |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 两个 tab 的无邀请空态渲染 | 已通过 | 批次70 | 0 | 0 | 0 | 真机：「我收到的」→暂无收到的邀请；「我发出的」→暂无发出的邀请 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 下拉刷新与右上角刷新按钮 | 已通过 | 批次70 | 0 | 0 | 0 | 真机：右上角刷新按钮触发重载；下拉刷新后空态正常无异常 |
| 无待办 | - | `page/channel/channel_invitation_page.dart` | 点击条目或打开频道按钮跳详情 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：118 创建新邀请(01:06) → 117 刷新后卡片出现 → 点「打开频道」→ GET /channel/{id} 200(321B) + messages?limit=20 200 + stats 200(172B) → 详情页渲染（AppBar 频道名 + 已订阅 + 1 订阅者 + 空态文案） |
