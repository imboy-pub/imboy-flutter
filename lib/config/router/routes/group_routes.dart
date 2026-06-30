library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../barrel/pages_barrel.dart';

List<RouteBase> groupRoutes() => [
  // ==================== 群组相关 ====================
  GoRoute(
    path: '/group',
    name: 'group',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const GroupListPage()),
    routes: [
      GoRoute(
        path: '/list',
        name: 'group_list',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const GroupListPage()),
      ),
      GoRoute(
        path: '/detail/:groupId',
        name: 'group_detail',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: GroupDetailPage(
              groupId: groupId,
              title: extra['title']?.toString() ?? '',
              memberCount:
                  int.tryParse(extra['memberCount']?.toString() ?? '0') ?? 0,
              options: extra['options'] as Map<String, dynamic>?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/member',
        name: 'group_member',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: GroupMemberPage(groupId: extra['groupId']?.toString() ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/member_detail',
        name: 'group_member_detail',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: GroupMemberDetailPage(
              groupId: extra['groupId']?.toString() ?? '',
              userId: extra['userId']?.toString() ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/add_member',
        name: 'group_add_member',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: AddMemberPage(groupId: extra['groupId']?.toString() ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/remove_member',
        name: 'group_remove_member',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: RemoveMemberPage(
              groupId: extra['groupId']?.toString() ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/announcement',
        name: 'group_announcement',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: GroupAnnouncementPage(
              groupId: extra['groupId']?.toString() ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/launch_chat',
        name: 'group_launch_chat',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LaunchChatPage()),
      ),
      GoRoute(
        path: '/select',
        name: 'group_select',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const GroupSelectPage()),
      ),
      GoRoute(
        path: '/face_to_face',
        name: 'face_to_face',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const FaceToFacePage()),
      ),
      GoRoute(
        path: '/face_to_face_confirm',
        name: 'face_to_face_confirm',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final code = extra?['code']?.toString() ?? '';
          final gid = extra?['gid']?.toString() ?? '';
          final memberList = extra?['memberList'] as List<dynamic>? ?? [];
          return CupertinoPage(
            key: state.pageKey,
            child: FaceToFaceConfirmPage(
              gid: gid,
              code: code,
              memberList: memberList.cast(),
            ),
          );
        },
      ),
    ],
  ),
];
