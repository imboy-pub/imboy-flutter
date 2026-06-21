library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/store/model/channel_model.dart';
import '../barrel/pages_barrel.dart';

List<RouteBase> channelRoutes() => [
  // ==================== 频道相关 ====================
  GoRoute(
    path: '/channel',
    name: 'channel_list',
    builder: (context, state) => const ChannelListPage(),
    routes: [
      // 具体路径必须放在动态参数路由之前，否则 /discover 会被当作 channelId
      GoRoute(
        path: '/discover',
        name: 'channel_discover',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const ChannelDiscoverPage(),
        ),
      ),
      GoRoute(
        path: '/create',
        name: 'channel_create',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ChannelCreatePage()),
      ),
      GoRoute(
        path: '/invitations',
        name: 'channel_invitations',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const ChannelInvitationPage(),
        ),
      ),
      // 静态路径须放在 /:channelId 之前，否则 /orders 会被当作 channelId
      GoRoute(
        path: '/orders',
        name: 'channel_orders',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const ChannelOrderListPage(),
        ),
      ),
      GoRoute(
        path: '/order/:orderNo',
        name: 'channel_order_detail',
        pageBuilder: (context, state) {
          final orderNo = state.pathParameters['orderNo']!;
          return CupertinoPage(
            key: state.pageKey,
            child: ChannelOrderDetailPage(orderNo: orderNo),
          );
        },
      ),
      GoRoute(
        path: '/:channelId',
        name: 'channel_detail',
        pageBuilder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          return CupertinoPage(
            key: state.pageKey,
            child: ChannelDetailPage(channelId: channelId),
          );
        },
        routes: [
          GoRoute(
            path: '/edit',
            name: 'channel_edit',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final extra = state.extra;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelEditPage(
                  channelId: channelId,
                  channel: extra is ChannelModel ? extra : null,
                ),
              );
            },
          ),
          GoRoute(
            path: '/admins',
            name: 'channel_admins',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelAdminPage(channelId: channelId),
              );
            },
          ),
          GoRoute(
            path: '/subscribers',
            name: 'channel_subscribers',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final extra = state.extra as Map<String, dynamic>?;
              final canInvite = extra?['canInvite'] as bool? ?? false;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelSubscriberPage(
                  channelId: channelId,
                  canInvite: canInvite,
                ),
              );
            },
          ),
        ],
      ),
    ],
  ),
];
