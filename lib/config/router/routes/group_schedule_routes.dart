import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/schedule/group_schedule_detail_page.dart';
import 'package:imboy/page/group/schedule/group_schedule_page.dart';

List<RouteBase> groupScheduleRoutes() => <RouteBase>[
  GoRoute(
    path: '/group/:groupId/schedule',
    name: 'group_schedule',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: GroupSchedulePage(
        groupId: state.pathParameters['groupId'] ?? '',
        autoCreate: state.uri.queryParameters['create'] == '1',
      ),
    ),
  ),
  GoRoute(
    path: '/group/:groupId/schedule/:scheduleId',
    name: 'group_schedule_detail',
    pageBuilder: (context, state) {
      final scheduleId = state.pathParameters['scheduleId'] ?? '';
      return CupertinoPage(
        key: state.pageKey,
        child: scheduleId.isEmpty
            ? CupertinoPageScaffold(
                child: Center(child: Text(t.common.dataNotFound)),
              )
            : GroupScheduleDetailPage(
                groupId: state.pathParameters['groupId'] ?? '',
                scheduleId: scheduleId,
              ),
      );
    },
  ),
];
