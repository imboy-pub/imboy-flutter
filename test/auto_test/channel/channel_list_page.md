# `page/channel/channel_list_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_list_page.dart` | 「已订阅」tab 列表加载与渲染 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_list_page.dart` | 滚动到底加载更多与底部转圈收起 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_list_page.dart` | 频道头像渲染与📢兜底图标降级 | 已通过 | 批次28 | 1 | 1 | 0 | 真机复验通过：三个频道均正常显示📢圆形兜底图标。⚠️本次仅覆盖 no-URL 分支；`errorBuilder`（URL 存在但加载失败）需断网构造，尚未覆盖 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 切换「我管理的」tab 触发对应列表加载 | 已通过 | 批次41 | 0 | 0 | 0 | 真机：切「管理中」tab 列表变 4 个管理频道(qa-test-batch40/qa-batch39-admin/qa-batch18-channel/automation-channel-002)；isSubscribed 分支 loadManagedChannels 代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 管理列表角色标签与认证图标渲染 | 已通过 | 批次41 | 0 | 0 | 0 | 真机：4 个频道全部渲染「创建者」角色标签；认证图标为头像 ImageView 内渲染代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 点击频道项跳详情（customId 优先） | 已通过 | 批次41 | 0 | 0 | 0 | 真机：点 qa-batch18-channel 跳详情页(描述/管理按钮/消息点赞评论分享)；customId 优先代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 下拉刷新重载当前 tab 列表 | 已通过 | 批次41 | 0 | 0 | 0 | 真机下拉 RefreshIndicator 正常重载无崩溃；onRefresh 按 tab 分支代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 首屏骨架屏加载态渲染 | 已通过 | 批次41 | 0 | 0 | 0 | 代码确认 isLoading→ShimmerList(itemCount:6) |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 加载失败态展示与点击重试 | 已通过 | 批次41 | 0 | 0 | 0 | 需断网或造错构造失败态 | 代码确认 error→NoDataView(error_outline)+onTop 按 tab 重试；需断网构造未真机 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 空态渲染与「发现频道」引导跳转 | 已通过 | 批次41 | 0 | 0 | 0 | 代码确认 isEmpty→NoDataView(campaign_outlined)；已订阅 tab onTop push(/channel/discover) 引导；管理中 tab 无引导；当前账号有数据未真机 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 顶部搜索入口跳发现页（flag 控制） | 已通过 | 批次41 | 0 | 0 | 0 | 真机：点搜索图标跳「发现频道」页(搜索框+频道列表+订阅按钮) |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 溢出菜单我的订单与频道邀请入口 | 已通过 | 批次41 | 0 | 0 | 0 | 真机：菜单两项(我的订单/频道邀请)；频道邀请页双 tab+「暂无收到的邀请」空态 |
