import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/channel/channel_order_detail_page.dart';
import 'package:imboy/page/channel/channel_order_list_page.dart';

List<RouteBase> channelOrderRoutes() => <RouteBase>[
  GoRoute(
    path: '/orders',
    name: 'channel_orders',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const ChannelOrderListPage()),
  ),
  GoRoute(
    path: '/order/:orderNo',
    name: 'channel_order_detail',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: ChannelOrderDetailPage(
        orderNo: state.pathParameters['orderNo'] ?? '',
      ),
    ),
  ),
];
