# `page/channel/channel_order_list_page.dart`

> 功能点 9 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 订单列表加载与骨架屏渲染 | 阻塞 | 批次70 | 0 | 0 | 0 | 入口仅付费频道（channel_detail L279 paid+channelOrder flag 双条件）+ channel_list 溢出菜单 flag 全关不渲染（L143-152）；付费未开真机不可达；代码确认 shimmer_list 骨架屏（L8） |
| 阻塞 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 加载失败态展示与点击重试 | 阻塞 | 批次70 | 0 | 0 | 0 | 入口阻塞同上；失败态实现同页模式（loadError+重试） |
| 阻塞 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 无订单时空态渲染 | 阻塞 | 批次70 | 0 | 0 | 0 | 入口阻塞同上；代码确认 L79 orders.isEmpty 空态分支 |
| 阻塞 | 付费功能开启后 | `page/channel/channel_order_list_page.dart` | 下拉刷新重新拉取订单 | 阻塞 | 批次70 | 0 | 0 | 0 | 入口阻塞同上；代码确认 L86 onRefresh=ref.invalidate(channelMyOrdersProvider) |
| 阻塞 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 订单项频道名渲染与缺省回退频道号 | 未测 | - | 0 | 0 | 0 | 无真实订单数据 |
| 阻塞 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 金额币种符号映射与两位小数格式 | 未测 | - | 0 | 0 | 0 | 无真实订单数据 |
| 阻塞 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 订单状态标签文案与配色渲染 | 未测 | - | 0 | 0 | 0 | 无真实订单数据 |
| 阻塞 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 副标题下单日期与订阅有效期展示 | 未测 | - | 0 | 0 | 0 | 无真实订单数据 |
| 阻塞 | 付费功能开启且有真实订单后 | `page/channel/channel_order_list_page.dart` | 点击订单项跳转订单详情页 | 未测 | - | 0 | 0 | 0 | 无真实订单数据 |
