// 已有群详情页只读 UI 流程。
//
// 通过群列表 API 取得现有群的展示参数后进入详情页，只读取详情/成员，
// 不修改群名、备注、成员、公告、权限或危险操作。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '已有群详情页可访问',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final group = await _findExistingGroup();
      if (group == null) {
        markTestSkipped('当前测试账号没有可访问的群，跳过群详情');
        return;
      }

      final navigatorFinder = find.byType(Navigator);
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到根 Navigator，跳过群详情');
        return;
      }
      final navigator = Navigator.of(
        tester.element(navigatorFinder.first),
        rootNavigator: true,
      );
      final routeResult = navigator.push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => GroupDetailPage(
            groupId: group.id,
            title: group.title,
            memberCount: group.memberCount,
          ),
        ),
      );

      final mounted = await _waitFor(
        tester,
        () => tester.any(find.byType(GroupDetailPage)),
        maxAttempts: 40,
      );
      expect(mounted, isTrue, reason: '群详情页应成功挂载');
      expect(find.byType(Scaffold), findsWidgets);
      await settle(tester, maxSeconds: 4);
      flowLog('群详情页已挂载并触发详情/成员只读加载；未执行群管理写操作');

      if (navigator.canPop()) navigator.pop();
      await settle(tester, maxSeconds: 1);
      await routeResult;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _GroupSeed {
  const _GroupSeed({
    required this.id,
    required this.title,
    required this.memberCount,
  });

  final String id;
  final String title;
  final int memberCount;
}

Future<_GroupSeed?> _findExistingGroup() async {
  for (final attr in const ['join', 'manager', 'owner']) {
    final payload = await GroupApi().page(page: 1, size: 20, attr: attr);
    final rows = payload?['list'];
    if (rows is! List) continue;
    for (final row in rows) {
      if (row is! Map) continue;
      final rawId = row['group_id'] ?? row['id'] ?? row['gid'];
      final id = rawId?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final rawCount = row['member_count'] ?? row['memberCount'];
      final count = rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString() ?? '') ?? 0;
      return _GroupSeed(
        id: id,
        title: row['title']?.toString() ?? '',
        memberCount: count,
      );
    }
  }
  return null;
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
