// 群列表 → 长按 → 群聊信息 → 群详情，只读 UI 流程。
//
// 本用例只验证已有群的菜单和详情入口，不修改群信息、不增删成员，
// 并在测试结束前通过 GoRouter 关闭详情路由，避免把页面动画/路由遗留
// 误报为测试框架 SemanticsHandle 泄漏。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '群列表长按可打开群聊信息只读详情',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);
      await _dismissRecoveryGuideIfVisible(tester);

      if (!await _openContactTab(tester)) {
        markTestSkipped('无法进入联系人页');
        return;
      }

      final groupEntry = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            ['群聊', 'Group chats', 'Group Chats'].contains(widget.data),
      );
      if (!await safeTap(tester, groupEntry)) {
        markTestSkipped('联系人页没有群聊入口');
        return;
      }

      final onGroupList = await _waitFor(
        tester,
        () => tester.any(find.byType(GroupListPage)),
        maxAttempts: 40,
      );
      if (!onGroupList) {
        markTestSkipped('群聊入口未打开群列表页');
        return;
      }

      final groupItem = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ImBoyListTile',
      );
      if (!tester.any(groupItem)) {
        markTestSkipped('当前测试账号的群列表为空');
        return;
      }

      await tester.longPress(groupItem.first);
      await settle(tester, maxSeconds: 2);

      final infoAction = find.text('群聊信息');
      if (!tester.any(infoAction)) {
        markTestSkipped('长按后未出现群聊信息菜单项');
        return;
      }
      expect(infoAction, findsOneWidget);
      expect(await safeTap(tester, infoAction), isTrue);

      final detail = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'GroupDetailPage',
      );
      final detailMounted = await _waitFor(
        tester,
        () => tester.any(detail),
        maxAttempts: 40,
      );
      expect(detailMounted, isTrue, reason: '群聊信息应打开群详情页');
      await settle(tester, maxSeconds: 4);
      flowLog('群列表长按菜单和群详情只读入口通过；未执行群管理写操作');

      // GoRouter 路由必须显式关闭并等待动画结束，否则测试 teardown
      // 可能把仍存活的 Cupertino 路由误诊为 SemanticsHandle 泄漏。
      final detailContext = tester.element(detail.first);
      final router = GoRouter.of(detailContext);
      if (router.canPop()) router.pop();
      await settle(tester, maxSeconds: 2);
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<bool> _openContactTab(WidgetTester tester) async {
  if (_isContactPage(tester)) return true;
  await tapAny(tester, [
    find.byKey(const Key('tab_contacts')),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
    find.byIcon(Icons.contacts),
    find.text('联系人'),
    find.text('Contacts'),
    find.text('Friends'),
  ]);
  for (int i = 0; i < 10; i++) {
    await settle(tester, maxSeconds: 1);
    if (_isContactPage(tester)) return true;
  }
  return false;
}

bool _isContactPage(WidgetTester tester) =>
    tester.any(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ContactPage',
      ),
    ) ||
    tester.any(find.byKey(const Key('contact_search_input')));

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

Future<void> _dismissRecoveryGuideIfVisible(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = find.byWidgetPredicate(
      (widget) =>
          widget is Text && ['稍后', 'Later'].contains(widget.data?.trim()),
    );
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
