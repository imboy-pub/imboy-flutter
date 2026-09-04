import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/task/group_task_detail_page.dart';
import 'package:imboy/page/group/task/group_task_page.dart';

List<RouteBase> groupTaskRoutes() => <RouteBase>[
  GoRoute(
    path: '/group/:groupId/task',
    name: 'group_task',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: GroupTaskPage(
        groupId: state.pathParameters['groupId'] ?? '',
        autoCreate: state.uri.queryParameters['create'] == '1',
      ),
    ),
  ),
  GoRoute(
    path: '/group/:groupId/task/:taskId',
    name: 'group_task_detail',
    pageBuilder: (context, state) {
      final taskId = state.pathParameters['taskId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: taskId.isEmpty
            ? CupertinoPageScaffold(
                child: Center(child: Text(t.common.dataNotFound)),
              )
            : GroupTaskDetailPage(
                groupId: state.pathParameters['groupId'] ?? '',
                taskId: taskId,
              ),
      );
    },
  ),
];
