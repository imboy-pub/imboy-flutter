import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/channel/channel_invitation_page.dart';

List<RouteBase> channelInvitationRoutes() => <RouteBase>[
  GoRoute(
    path: '/invitations',
    name: 'channel_invitations',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const ChannelInvitationPage()),
  ),
];
