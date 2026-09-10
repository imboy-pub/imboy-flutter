# `page/live_room/publisher/publisher_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)
> ⛔ **2026-09-10 用户拍板：直播间/WHIP 推拉流域暂缓，自动化不再攻坚**（含本页 WHIP/推流/拉流相关阻塞行；解冻需用户重新授权）。

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需可用 WHIP 媒体服务器（SFU 定案 LiveKit 未接入） | `page/live_room/publisher/publisher_page.dart` | 进入页面初始化本地视频渲染器 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 开始推流时申请摄像头与麦克风权限 | 未测 | - | 0 | 0 | 0 | 权限弹窗由系统弹出 |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 本地预览镜像展示采集画面 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 输入并保存推流服务器地址 | 未测 | - | 0 | 0 | 0 | 键盘提交时落库 |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 点击开始推流建立连接并上行 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 连接中禁用按钮并显示连接中文案 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 点击停止推流断开并释放采集 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 左上角状态徽章显示当前推流状态 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 列表导航可达（批次142 修列表重复键 bug 后 my_list 含 own 房间，点非直播行即携房间进本页）；推流本身仍需 WHIP 服务器 | `page/live_room/publisher/publisher_page.dart` | 右上角脱敏展示房间推流密钥 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 列表导航可达（批次142 后同上）；推流本身仍需 WHIP 服务器 | `page/live_room/publisher/publisher_page.dart` | 标题栏显示房间名或默认标题 | 未测 | - | 0 | 0 | 0 | — |
| 阻塞 | 需可用 WHIP 媒体服务器 | `page/live_room/publisher/publisher_page.dart` | 退出页面停止推流并熄灭摄像头指示灯 | 未测 | - | 0 | 0 | 0 | 代码注释明写建议真机验证释放顺序 |
