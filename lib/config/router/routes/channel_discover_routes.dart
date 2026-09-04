import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';

List<RouteBase> channelDiscoverRoutes() => <RouteBase>[
  GoRoute(
    path: '/discover',
    name: 'channel_discover',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const ChannelDiscoverPage()),
  ),
];
