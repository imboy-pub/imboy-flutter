# `page/live_room/live_room_list/live_room_list_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)
> ⛔ **2026-09-10 用户拍板：直播间/WHIP 推拉流域暂缓，自动化不再攻坚**（含本页 WHIP/推流/拉流相关阻塞行；解冻需用户重新授权）。

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 首次进入拉取直播间首页列表 | 已通过 | 批次29 | 0 | 0 | 0 | deep link 进入页 → logcat GET /api/v1/live_room/my_list?page=1&size=20 发出并返回 → 页面正常渲染空态 |
| 阻塞 | 待环境恢复执行（数据已就绪：批次142 修后端重复 list 键 bug，my_list 实测返回房间） | `page/live_room/live_room_list/live_room_list_page.dart` | 下拉刷新重新加载列表首页 | 未测 | 批次29 | 1 | 1 | 0 | 空态 NoDataView 内容不超高不可下拉（Android ClampingScrollPhysics 无 overscroll），RefreshIndicator 不触发；有数据后 ListView 可验 onRefresh=L126。批次142 真 bug：page_with_total 返回 atom 键而 handler 用 binary 键读写→JSON 重复 "list" 键、客户端恒解析空（imboy 0e1de5b5 修复，9801 热加载+curl 复验单键含数据） |
| 阻塞 | 需后端 ≥2 页房间数据（curl create 可批量造，批次142 证修复后 my_list 可达） | `page/live_room/live_room_list/live_room_list_page.dart` | 上滑触底自动加载下一页 | 未测 | 批次29 | 0 | 0 | 0 | 距底 100px 触发逻辑代码存在 L52-57，当前 0 条数据无滚动区可验 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 无数据时展示空态视图 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「暂无数据」空态（NoDataView） |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 首屏加载中展示进度圈 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L127-128 isLoading&&items.isEmpty→CircularProgressIndicator；瞬态 get_ui 不可捕获 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 点击加号弹出创建直播间对话框 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测：标题+输入框+「还可输入 100 个字符」+取消/创建，maxLength=100 生效 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 标题为空时提示必须填写标题 | 已通过 | 批次29 | 0 | 0 | 0 | 空标题点创建→对话框关闭+logcat 无 POST create 请求（拦截生效）+代码 L90-92 showToast |
| 阻塞 | 待环境恢复执行（批次138/142 实证后端 list/create/my_list 本地全通，推翻「后端冻结未实现」旧认知；本地造数非生产写；路由无 live_room feature 守卫、深链可达，flag 硬关仅影响入口可见性） | `page/live_room/live_room_list/live_room_list_page.dart` | 创建成功跳转推流页并刷新列表 | 未测 | 批次29 | 0 | 0 | 0 | 会话内 create 走本地 9801 fixture（批次138 先例 curl create 已建 111596538331138048）；app_feature_registry L24 flag 硬关待后端 WHIP 就绪后解除 |
| 阻塞 | 待环境恢复执行（批次142 实证 my_list 不过滤 status：own idle 房间修复后即出现在列表，可点进推流页） | `page/live_room/live_room_list/live_room_list_page.dart` | 点击非直播房间进入推流页 | 未测 | 批次29 | 0 | 0 | 0 | 列表 0 条无可点项；代码 L216 push /live_room/publisher |
| 阻塞 | 待环境恢复执行（封面失效可造：UPDATE live_room SET cover=无效URL） | `page/live_room/live_room_list/live_room_list_page.dart` | 封面加载失败时展示占位图标 | 未测 | 批次29 | 0 | 0 | 0 | errorBuilder→Icons.live_tv 代码证实 L160；需含失效封面的房间才可实测 |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 点击直播中房间进入观看页 | 已通过 | 批次157 | 0 | 0 | 0 | 真机：tap 直播中房间行 → SubscriberPage 到达（extra 携带 room 模型）+标题栏房间名与观看人数渲染；测试=misc/acceptance_batch157_test.dart AT-LR2/3；无需 RTMP 拉流即可验证导航与 UI |
| 无待办 | - | `page/live_room/live_room_list/live_room_list_page.dart` | 房间行展示直播状态与观看人数 | 已通过 | 批次157 | 0 | 0 | 0 | 真机：fixture AT-LIVE-FIXTURE-138（status=1 viewer_count=0）行渲染 LIVE 徽章+eye 观看人数断言通过；测试=misc/acceptance_batch157_test.dart AT-LR1 |
