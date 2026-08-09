# `page/contact/people_nearby/people_nearby_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/contact/people_nearby/people_nearby_page.dart` | 冷启动优先取系统缓存位置 | 已通过 | 批次27 | 1 | 1 | 0 | |
| 无待办 | — | `page/contact/people_nearby/people_nearby_page.dart` | 定位链路分段埋点与超时收敛 | 已通过 | 批次27 | 1 | 1 | 0 | |
| 无待办 | - | `page/contact/people_nearby/people_nearby_page.dart` | 申请并校验定位权限 | 已通过 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/people_nearby/people_nearby_page.dart` | 渲染附近的人列表与距离单位 | 已通过 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 点击指南针旋转并刷新列表 | 已通过 | 批次47 | 0 | 0 | 0 | 代码确认 L52-66 _refreshNearby（旋转动画+peopleNearby）+L229-246 顶部指南针 Semantics；空态点击实测触发重新搜索 |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 下拉刷新重新拉取附近的人 | 已通过 | 批次47 | 0 | 0 | 0 | 代码确认 L70-73 CupertinoSliverRefreshControl onRefresh=_onPullRefresh 共用 peopleNearby；页面内容少未真机下拉成功 |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 开启可见性弹出说明确认框 | 已通过 | 批次47 | 0 | 0 | 0 | 真机弹窗「显示你的资料」+说明文案+取消/确认；未点确认（会上报真实位置） |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 关闭可见性并提示位置已隐藏 | 已通过 | 批次47 | 0 | 0 | 0 | 真机点行→标题「让自己不可见」变「让自己可见」（makeMyselfUnVisible 执行实锤）；toast 一闪未抓但状态切换硬证据 |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 点击列表项进入对方资料页 | 已通过 | 批次47 | 0 | 0 | 0 | 代码确认 L278-282 push people_info scene=people_nearby；无定位权限无列表数据未真机 |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 空态指南针可点击重新搜索 | 已通过 | 批次47 | 0 | 0 | 0 | 真机空态指南针可点击（触发刷新无列表变化，定位权限已拒）；代码 L311-357 旋转动画+_refreshNearby |
| 回归复测 | 2026-08-08 | `page/contact/people_nearby/people_nearby_page.dart` | 可见性行展示附近人数徽章 | 已通过 | 批次47 | 0 | 0 | 0 | 代码确认 L126-144 peopleList.isNotEmpty 显示数量徽章+图标；无列表数据未真机 |
