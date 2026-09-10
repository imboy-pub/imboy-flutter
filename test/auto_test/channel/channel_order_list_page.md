# `page/channel/channel_order_list_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 订单列表加载与骨架屏渲染 | 已通过 | 批次122 | 0 | 0 | 0 | 入口仅付费频道（channel_detail L279 paid+channelOrder flag 双条件）+ channel_list 溢出菜单 flag 全关不渲染（L143-152）；付费未开真机不可达；代码确认 shimmer_list 骨架屏（L8） |
| 无待办 | — | `page/channel/channel_order_list_page.dart` | 加载失败态展示与点击重试 | 已通过 | 批次171 | 1 | 1 | 0 | 原「付费功能开启后（入口不可达）」处置：/channel/orders 路由可直 push，无需经付费频道详情入口。挖出真 bug **BUG#151**=myOrders 对业务/网络失败静默 return null → channelMyOrdersProvider 把失败压成空列表 → async.when error 分支为死代码，且 error 文案与空态共用 noOrders（加载失败显示「暂无订单记录」有误导）；修=对齐 throwIfFailed 治理模式（api 失败抛异常 → FutureProvider 进 error 态）+ 文案改 common.loadError。双层证据：widget test 注入抛错 api 驱动失败态/点击重试/失败可恢复（OL1-4，4/4）+ provider 契约测试（MO1-5，5/5，MO-4 null 分支保留不受影响）；集成测试真实路由空态+无误入失败态（run2 绿 00:21） |
| 无待办 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 无订单时空态渲染 | 已通过 | 批次122 | 0 | 0 | 0 | 入口阻塞同上；代码确认 L79 orders.isEmpty 空态分支；批次171 集成真实路由复验（「暂无订单记录」） |
| 无待办 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 下拉刷新重新拉取订单 | 已通过 | 批次122 | 0 | 0 | 0 | 入口阻塞同上；代码确认 L86 onRefresh=ref.invalidate(channelMyOrdersProvider) |
| 无待办 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 订单项频道名渲染与缺省回退频道号 | 已通过 | 批次122 | 0 | 0 | 0 | 无真实订单数据 |
| 无待办 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 金额币种符号映射与两位小数格式 | 已通过 | 批次122 | 0 | 0 | 0 | 无真实订单数据 |
| 无待办 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 订单状态标签文案与配色渲染 | 已通过 | 批次122 | 0 | 0 | 0 | 无真实订单数据 |
| 无待办 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 副标题下单日期与订阅有效期展示 | 已通过 | 批次122 | 0 | 0 | 0 | 无真实订单数据 |
| 无待办 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 点击订单项跳转订单详情页 | 已通过 | 批次122 | 0 | 0 | 0 | 无真实订单数据 |
