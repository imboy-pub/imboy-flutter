# `page/live_room/subscriber/subscriber_page.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)
> ⛔ **2026-09-10 用户拍板：直播间/WHIP 推拉流域暂缓，自动化不再攻坚**（含本页 WHIP/推流/拉流相关阻塞行；解冻需用户重新授权）。

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 进入页面初始化远端视频渲染器 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 输入并保存拉流服务器地址 | 未测 | - | 0 | 0 | 0 | 键盘提交时落库 |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 点击开始播放建立拉流连接 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 连接中禁用按钮并显示连接中文案 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 点击停止播放关闭拉流会话 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 远端画面按裁剪模式铺满渲染区 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 左上角状态徽章显示播放状态 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 列表导航可达（批次142 修列表重复键 bug + /start 纯 DB 翻转 status=1 可造直播中房间）；拉流本身仍需 WHIP 服务器 | `page/live_room/subscriber/subscriber_page.dart` | 标题栏右侧展示当前观看人数 | 未测 | - | 0 | 0 | 0 | — |
| 无待办 | - | `page/live_room/subscriber/subscriber_page.dart` | 标题栏显示房间名或默认标题 | 已通过 | 批次157 | 0 | 0 | 0 | 真机：从列表点击进入后标题栏展示房间名 AT-LIVE-FIXTURE-138+观看人数（viewer_count=0）渲染；拉流功能行仍需 WHIP 维持阻塞；测试=misc/acceptance_batch157_test.dart AT-LR3 |
| 阻塞 | 需有正在推流的直播间 | `page/live_room/subscriber/subscriber_page.dart` | 退出页面关闭会话并释放渲染器 | 未测 | - | 0 | 0 | 0 | 代码注释明写建议真机验证释放顺序 |
