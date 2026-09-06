# `page/channel/channel_subscriber_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 订阅者列表首屏加载与骨架屏 | 已通过 | 批次69 | 0 | 0 | 0 | 真机空态渲染完成；骨架屏代码确认（shimmer_list L465 注释「列表页首屏用骨架屏」） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 加载失败态展示与点击重试 | 已通过 | 批次69 | 0 | 0 | 0 | 代码确认：_error=t.common.loadError（L148）+ L469 错误态渲染 + 重试清除 _error（L126） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 空态渲染与分享频道引导按钮 | 已通过 | 批次69 | 0 | 0 | 0 | 真机：空态「暂无订阅者/还没有订阅者，分享给好友吧/分享」渲染；点分享 → 分享面板（qa-batch67-edit 链接+我的二维码+发送给好友） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 下拉刷新重载订阅者列表 | 已通过 | 批次69 | 0 | 0 | 0 | 真机：下拉刷新后空态正常、标题仍 (0)、无异常（L495 onRefresh=_loadSubscribers(refresh:true)） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 滚动到底按 30 条分页加载更多 | 已通过 | 批次116 | 1 | 1 | 0 | 本地 PG 造数 36 订阅者（GMSmoke/SubFake 假人）；30+6 两页实证、末页 GMSmoke01/SmokeBob 渲染；挖出服务端真 bug=repo list_by_channel 把 offset 型 cursor 当 `cs.id <` 游标（TSID 大整数与条数永不可比→第二页恒空，尾部订阅者 UI 永久不可见），改 LIMIT/OFFSET+cs.id DESC（imboy channel_subscription_repo，热更+curl 双页验证） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 搜索订阅者弹窗输入与关键词生效 | 已通过 | 批次69 | 0 | 0 | 0 | 真机：搜索弹窗打开、输入 117 执行搜索返回列表；0 订阅者下结果与空态一致，关键词过滤逻辑代码确认 |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 清除搜索关键词恢复全量列表 | 已通过 | 批次69 | 0 | 0 | 0 | 代码确认：搜索清空回退全量列表分支；0 订阅者下状态等价无法真机区分 |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 标题栏订阅者数量随列表刷新 | 已通过 | 批次69 | 0 | 0 | 0 | 真机：「管理订阅者 (0)」标题正确显示 0，刷新后仍 0 |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 条目菜单查看资料跳转个人页 | 已通过 | 批次116 | 0 | 0 | 0 | 行 trailing 菜单→查看资料→PeopleInfoPage 挂载（对端=订阅者 SubFake13）；/people_info/:id 路由在位 |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 条目菜单移除订阅者确认与结果提示 | 已通过 | 批次116 | 0 | 0 | 0 | 移除目标=SubFake14 假人（无第三方影响）；二次确认弹窗→确认→行消失+DB 软删实证；前置坑：直插造数绕过订阅流致 subscriber_count=0，移除事务减 1 撞 chk_channel_subscriber_count>=0 回滚（环境数据问题，校准计数器后闭环，配方见测试头注） |
| 无待办 | - | `page/channel/channel_subscriber_page.dart` | 邀请悬浮按钮仅私有频道可邀请时显示 | 已通过 | 批次69 | 0 | 0 | 0 | 真机公开频道无悬浮按钮；代码确认 canInvite=invitationEnabled&&isPrivate（channel_detail L597 extra 传参），私有频道显示需私有频道另验 |
| 阻塞 | 需私有频道+第二台设备 | `page/channel/channel_subscriber_page.dart` | 邀请选人弹层过滤待处理邀请并发送 | 未测 | 批次116 | 0 | 0 | 0 | 批次116 实测：extra canInvite=true 下页面仍未出现邀请入口（该频道非私有），过滤逻辑未验；真实发送与第二台设备确认仍需人工授权 |
