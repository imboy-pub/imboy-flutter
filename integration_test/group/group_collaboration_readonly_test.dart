// 已有群 → 群日程 / 群任务 / 群投票列表页的只读 UI 流程。
//
// 只读取现有生产数据，不创建日程、任务或投票，也不确认参加或提交选项。
// 目的：验证群协作入口和三个列表页能够挂载，数据为空时也必须正常显示空态。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/schedule/group_schedule_page.dart';
import 'package:imboy/page/group/task/group_task_page.dart';
import 'package:imboy/page/group/vote/group_vote_page.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '已有群可访问日程任务投票列表页',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final groupId = await _findExistingGroupId();
      if (groupId == null) {
        markTestSkipped('当前测试账号没有可访问的群，跳过群协作列表页');
        return;
      }

      final navigator = find.byType(Navigator).first;
      if (!tester.any(navigator)) {
        markTestSkipped('App 未找到 Navigator，跳过群协作列表页');
        return;
      }

      final navigatorState = Navigator.of(
        tester.element(navigator),
        rootNavigator: true,
      );
      final pages = <({String name, String path, Type type})>[
        (
          name: '群日程',
          path: '/group/$groupId/schedule',
          type: GroupSchedulePage,
        ),
        (name: '群任务', path: '/group/$groupId/task', type: GroupTaskPage),
        (name: '群投票', path: '/group/$groupId/vote', type: GroupVotePage),
      ];

      for (final page in pages) {
        flowLog('只读进入${page.name}: ${page.path}');
        final routeResult = navigatorState.push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => _buildPage(page.name, groupId),
          ),
        );
        final mounted = await _waitFor(
          tester,
          () => tester.any(find.byType(page.type)),
          maxAttempts: 30,
        );
        expect(mounted, isTrue, reason: '${page.name}页面应成功挂载');
        expect(find.byType(Scaffold), findsWidgets);
        await settle(tester, maxSeconds: 3);
        flowLog('${page.name}列表页已挂载；本轮未执行写操作');

        if (navigatorState.canPop()) navigatorState.pop();
        await settle(tester, maxSeconds: 1);
        await routeResult;
      }

      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<String?> _findExistingGroupId() async {
  final seen = <String>{};
  for (final attr in const ['join', 'manager', 'owner']) {
    final payload = await GroupApi().page(page: 1, size: 20, attr: attr);
    final rows = payload?['list'];
    if (rows is! List) continue;
    for (final row in rows) {
      if (row is! Map) continue;
      final raw = row['group_id'] ?? row['id'] ?? row['gid'];
      final id = raw?.toString().trim() ?? '';
      if (id.isNotEmpty && seen.add(id)) return id;
    }
  }
  return null;
}

Widget _buildPage(String name, String groupId) {
  switch (name) {
    case '群日程':
      return GroupSchedulePage(groupId: groupId);
    case '群任务':
      return GroupTaskPage(groupId: groupId);
    case '群投票':
      return GroupVotePage(groupId: groupId);
    default:
      return const SizedBox.shrink();
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}
