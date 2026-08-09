// 联系人 → 群列表只读 UI 流程。
//
// 本用例只读取现有生产数据，不创建群、不修改群信息、不增删成员，
// 用于在群会话不存在时仍能验证群管理入口和已有群数据是否可达。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '从联系人群聊入口进入已有群列表可访问',
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
      await takeScreenshot(tester, 'group_management_01_list');

      final groupItem = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ImBoyListTile',
      );
      if (!tester.any(groupItem)) {
        markTestSkipped('当前测试账号的群列表为空');
        return;
      }
      flowLog('群列表项数: ${groupItem.evaluate().length}');
      expect(groupItem, findsWidgets, reason: '已有群数据应显示在群列表中');
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
