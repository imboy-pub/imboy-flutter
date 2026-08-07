# `page/channel/channel_list_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_list_page.dart` | 「已订阅」tab 列表加载与渲染 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_list_page.dart` | 滚动到底加载更多与底部转圈收起 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_list_page.dart` | 频道头像渲染与📢兜底图标降级 | 已通过 | 批次28 | 1 | 1 | 0 | 真机复验通过：三个频道均正常显示📢圆形兜底图标。⚠️本次仅覆盖 no-URL 分支；`errorBuilder`（URL 存在但加载失败）需断网构造，尚未覆盖 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 切换「我管理的」tab 触发对应列表加载 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 管理列表角色标签与认证图标渲染 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 点击频道项跳详情（customId 优先） | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 下拉刷新重载当前 tab 列表 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 首屏骨架屏加载态渲染 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 加载失败态展示与点击重试 | 待重验 | 批次25 | 0 | 0 | 0 | 需断网或造错构造失败态 |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 空态渲染与「发现频道」引导跳转 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 顶部搜索入口跳发现页（flag 控制） | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_list_page.dart` | 溢出菜单我的订单与频道邀请入口 | 待重验 | 批次25 | 0 | 0 | 0 | |
