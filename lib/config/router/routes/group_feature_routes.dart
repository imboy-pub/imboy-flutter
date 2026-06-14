library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../barrel/pages_barrel.dart';

List<RouteBase> groupFeatureRoutes() => [
  // ==================== 群功能增强 ====================
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
  // 群投票
  GoRoute(
    path: '/group/:groupId/vote',
    name: 'group_vote',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupVotePage(groupId: groupId),
      );
    },
  ),
  GoRoute(
    path: '/group/:groupId/vote/:voteId',
    name: 'group_vote_detail',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      final voteId = state.pathParameters['voteId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupVoteDetailPage(groupId: groupId, voteId: voteId),
      );
    },
  ),
  // 群日程
  GoRoute(
    path: '/group/:groupId/schedule',
    name: 'group_schedule',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupSchedulePage(groupId: groupId),
      );
    },
  ),
  GoRoute(
    path: '/group/:groupId/schedule/:scheduleId',
    name: 'group_schedule_detail',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      final scheduleId = state.pathParameters['scheduleId'] ?? '';
      if (scheduleId.isEmpty) {
        return CupertinoPage(
          key: state.pageKey,
          child: const Scaffold(
            body: Center(child: Text('Invalid schedule id')),
          ),
        );
      }
      return CupertinoPage(
        key: state.pageKey,
        child: GroupScheduleDetailPage(
          groupId: groupId,
          scheduleId: scheduleId,
        ),
      );
    },
  ),
  // 群作业
  GoRoute(
    path: '/group/:groupId/task',
    name: 'group_task',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: GroupTaskPage(groupId: groupId),
      );
    },
  ),
  GoRoute(
    path: '/group/:groupId/task/:taskId',
    name: 'group_task_detail',
    pageBuilder: (context, state) {
      final groupId = state.pathParameters['groupId'] ?? '';
      final taskId = state.pathParameters['taskId'] ?? '';
      if (taskId.isEmpty) {
        return CupertinoPage(
          key: state.pageKey,
          child: const Scaffold(body: Center(child: Text('Invalid task id'))),
        );
      }
      return CupertinoPage(
        key: state.pageKey,
        child: GroupTaskDetailPage(groupId: groupId, taskId: taskId),
      );
    },
  ),
];
