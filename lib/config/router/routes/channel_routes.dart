library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_admin_page.dart';
import 'package:imboy/page/channel/channel_article_page.dart';
import 'package:imboy/page/channel/channel_comment_page.dart';
import 'package:imboy/page/channel/channel_compose_page.dart';
import 'package:imboy/page/channel/channel_create_page.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_edit_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_subscriber_page.dart';
import 'package:imboy/page/qrcode/channel_qrcode_page.dart';

List<RouteBase> channelRoutes({
  List<RouteBase> featureRoutes = const <RouteBase>[],
}) => [
  GoRoute(
    path: '/qrcode/channel',
    name: 'qrcode_channel',
    pageBuilder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return CupertinoPage(
        key: state.pageKey,
        child: extra == null
            ? CupertinoPageScaffold(
                child: Center(child: Text(t.common.dataNotFound)),
              )
            : ChannelQrCodePage(channelData: extra),
      );
    },
  ),
  // ==================== 频道相关 ====================
  GoRoute(
    path: '/channel',
    name: 'channel_list',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const ChannelListPage()),
    routes: [
      ...featureRoutes,
      GoRoute(
        path: '/create',
        name: 'channel_create',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ChannelCreatePage()),
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
            path: '/compose',
            name: 'channel_compose',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelComposePage(channelId: channelId),
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
          // 频道沉浸式全屏阅读页（订阅号消费模型）
          GoRoute(
            path: '/article/:messageId',
            name: 'channel_article',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final extra = state.extra;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelArticlePage(
                  channelId: channelId,
                  message: extra is ChannelMessageModel ? extra : null,
                ),
              );
            },
          ),
          // 频道消息评论页
          GoRoute(
            path: '/message/:messageId/comments',
            name: 'channel_comments',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final messageId = state.pathParameters['messageId']!;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelCommentPage(
                  channelId: channelId,
                  messageId: messageId,
                ),
              );
            },
          ),
        ],
      ),
    ],
  ),
];
