library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/change_info_page.dart';
import 'package:imboy/store/model/group_model.dart';

import '../barrel/pages_barrel.dart';

List<RouteBase> groupFeatureRoutes() => [
  // ==================== 群功能增强 ====================
  // 群资料编辑（0017：原 CupertinoPageRoute 直 push，迁 go_router 统一）
  GoRoute(
    path: '/group/change-info',
    name: 'group_change_info',
    pageBuilder: (context, state) {
      // 唯一调用点（群详情信息卡）经 extra 传 GroupModel。
      final group = state.extra! as GroupModel;
      return CupertinoPage(
        key: state.pageKey,
        child: ChangeInfoPage(
          group: group,
          title: t.group.groupName,
          subtitle: t.common.pleaseEnterContent,
        ),
      );
    },
  ),
  // 群分组
  GoRoute(
    path: '/group/category',
    name: 'group_category',
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const GroupCategoryPage()),
  ),
  // 群标签
  GoRoute(
    path: '/group/:groupId/tag',
    name: 'group_tag',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupTagPage(groupId: groupId),
      );
    },
  ),
  // 群文件
  GoRoute(
    path: '/group/:groupId/file',
    name: 'group_file',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupFilePage(groupId: groupId),
      );
    },
  ),
  // 群相册
  GoRoute(
    path: '/group/:groupId/album',
    name: 'group_album',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupAlbumPage(groupId: groupId),
      );
    },
  ),
  GoRoute(
    path: '/group/:groupId/album/:albumId/photos',
    name: 'group_album_photos',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      final albumId = state.pathParameters['albumId'] ?? '';
      final albumName = state.uri.queryParameters['album_name'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupAlbumPhotoPage(
          groupId: groupId,
          albumId: albumId,
          albumName: albumName,
        ),
      );
    },
  ),
  GoRoute(
    path: '/group/:groupId/album/:albumId/photo/:photoId',
    name: 'group_album_photo_detail',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      final albumId = state.pathParameters['albumId'] ?? '';
      final photoId = state.pathParameters['photoId'] ?? '';
      final albumName = state.uri.queryParameters['album_name'] ?? '';
      final extra = state.extra as Map<String, dynamic>? ?? {};
      final rawPhotoIds = extra['photo_ids'];
      final photoIds = rawPhotoIds is List
          ? rawPhotoIds
                .where((item) => item != null)
                .map((item) => item.toString().trim())
                .where((id) => id.isNotEmpty)
                .toList()
          : const <String>[];
      final rawIndex = extra['index'];
      final initialIndex = rawIndex is int
          ? rawIndex
          : int.tryParse(rawIndex?.toString() ?? '') ?? 0;
      return CupertinoPage(
        key: state.pageKey,
        child: GroupAlbumPhotoDetailPage(
          groupId: groupId,
          albumId: albumId,
          photoId: photoId,
          albumName: albumName,
          photoIds: photoIds,
          initialIndex: initialIndex,
        ),
      );
    },
  ),
];
