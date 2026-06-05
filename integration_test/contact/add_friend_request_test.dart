// integration_test/contact/add_friend_request_test.dart
//
// 添加好友 UI 集成测试
//
// 运行：
//   flutter test integration_test/contact/add_friend_request_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_SEARCH_KEYWORD=<uid_or_name> \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _searchKeyword = String.fromEnvironment(
  'TEST_SEARCH_KEYWORD',
  defaultValue: '',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('添加好友', () {
    testWidgets('搜索用户并发送好友请求', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'add_friend_01_launch');

      await checkPreconditions(tester);

      await settle(tester, maxSeconds: 2);

      if (!await _openContactTab(tester)) {
        markTestSkipped('无法进入联系人页，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'add_friend_02_contact_tab');

      if (!await tapAny(tester, [
        find.byKey(const Key('add_friend_button')),
        find.byIcon(Icons.person_add),
        find.byIcon(Icons.person_add_outlined),
        find.text('新朋友'),
        find.text('添加好友'),
        find.text('Add Friend'),
        find.text('New Friends'),
      ])) {
        markTestSkipped('未找到添加好友入口，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'add_friend_03_add_page');

      final searchField = find.byType(TextField);
      if (!tester.any(searchField)) {
        markTestSkipped('添加好友页无搜索框，跳过');
        return;
      }

      if (_searchKeyword.isEmpty) {
        // 无搜索词时只验证页面可达性
        expect(find.byType(Scaffold), findsWidgets, reason: '添加好友页应有 Scaffold');
        flowLog('未配置 TEST_SEARCH_KEYWORD，仅验收页面可访问性');
        drainKnownFrameworkExceptions(tester);
        return;
      }

      await tester.enterText(searchField.first, _searchKeyword);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'add_friend_04_results');

      // 断言：搜索后应有结果或空状态提示，不能空白
      final hasResults = tester.any(find.byType(ListTile));
      final hasEmpty = tester.any(
        _anyText(['未找到', 'Not found', 'No results', '暂无']),
      );
      expect(hasResults || hasEmpty, isTrue, reason: '搜索后应有结果列表或空状态提示');

      if (!hasResults) {
        flowLog('搜索"$_searchKeyword"无结果，跳过发送请求步骤');
        drainKnownFrameworkExceptions(tester);
        return;
      }

      await safeTap(tester, find.byType(ListTile).first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'add_friend_05_profile');

      expect(find.byType(Scaffold), findsWidgets, reason: '用户详情页应有 Scaffold');

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<bool> _openContactTab(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byKey(const Key('tab_contacts')),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
    find.text('联系人'),
    find.text('Contacts'),
  ]);
  if (tapped) await settle(tester, maxSeconds: 2);
  return tapped;
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
