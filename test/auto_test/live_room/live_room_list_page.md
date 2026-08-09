# `page/live_room/live_room_list/live_room_list_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 首次进入拉取直播间首页列表 | 已通过 | 批次29 | 0 | 0 | 0 | deep link 进入页 → logcat GET /api/v1/live_room/my_list?page=1&size=20 发出并返回 → 页面正常渲染空态 |
| 阻塞 | 需后端有房间数据（当前 my_list 返回 0 条） | `page/live_room/live_room_list/live_room_list_page.dart` | 下拉刷新重新加载列表首页 | 未测 | 批次29 | 0 | 0 | 0 | 空态 NoDataView 内容不超高不可下拉（Android ClampingScrollPhysics 无 overscroll），RefreshIndicator 不触发；有数据后 ListView 可验 onRefresh=L126 |
| 阻塞 | 需后端 ≥2 页房间数据 | `page/live_room/live_room_list/live_room_list_page.dart` | 上滑触底自动加载下一页 | 未测 | 批次29 | 0 | 0 | 0 | 距底 100px 触发逻辑代码存在 L52-57，当前 0 条数据无滚动区可验 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 无数据时展示空态视图 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「暂无数据」空态（NoDataView） |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 首屏加载中展示进度圈 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L127-128 isLoading&&items.isEmpty→CircularProgressIndicator；瞬态 get_ui 不可捕获 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 点击加号弹出创建直播间对话框 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测：标题+输入框+「还可输入 100 个字符」+取消/创建，maxLength=100 生效 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 标题为空时提示必须填写标题 | 已通过 | 批次29 | 0 | 0 | 0 | 空标题点创建→对话框关闭+logcat 无 POST create 请求（拦截生效）+代码 L90-92 showToast |
| 阻塞 | 创建=POST 写生产数据需授权；后端冻结未实现 | `page/live_room/live_room_list/live_room_list_page.dart` | 创建成功跳转推流页并刷新列表 | 未测 | 批次29 | 0 | 0 | 0 | 会真实创建直播间（对外可见），需授权；feature flag live_room 本地硬关闭（app_feature_registry.dart L24 后端待实现） |
| 阻塞 | 需后端有非直播房间数据 | `page/live_room/live_room_list/live_room_list_page.dart` | 点击非直播房间进入推流页 | 未测 | 批次29 | 0 | 0 | 0 | 列表 0 条无可点项；代码 L216 push /live_room/publisher |
| 阻塞 | 需封面 URL 失效的房间数据 | `page/live_room/live_room_list/live_room_list_page.dart` | 封面加载失败时展示占位图标 | 未测 | 批次29 | 0 | 0 | 0 | errorBuilder→Icons.live_tv 代码证实 L160；需含失效封面的房间才可实测 |
| 阻塞 | 需有正在直播的房间 | `page/live_room/live_room_list/live_room_list_page.dart` | 点击直播中房间进入观看页 | 未测 | - | 0 | 0 | 0 | 列表项与右侧播放按钮两个入口 |
| 阻塞 | 需有正在直播的房间 | `page/live_room/live_room_list/live_room_list_page.dart` | 房间行展示直播状态与观看人数 | 未测 | - | 0 | 0 | 0 | — |
