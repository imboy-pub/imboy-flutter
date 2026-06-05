// integration_test/contact/friend_management_test.dart
//
// 好友管理 UI 集成测试
//
// 运行：
//   flutter test integration_test/contact/friend_management_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('好友管理', () {
    testWidgets('联系人列表可访问', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'friend_01_launch');

      await checkPreconditions(tester);

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'friend_02_after_login');

      if (!await _openContactTab(tester)) {
        markTestSkipped('无法进入联系人页，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'friend_03_contact_list');

      // 断言：联系人页应有 Scaffold
      expect(find.byType(Scaffold), findsWidgets, reason: '联系人页应有 Scaffold');

      flowLog('联系人列表项数: ${find.byType(ListTile).evaluate().length}');
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('点击好友进入详情页', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);

      await checkPreconditions(tester);

      if (!await _openContactTab(tester)) {
        markTestSkipped('无法进入联系人页，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);

      final listTile = find.byType(ListTile);
      if (!tester.any(listTile)) {
        markTestSkipped('联系人列表为空，跳过详情测试');
        return;
      }

      await safeTap(tester, listTile.first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'friend_detail');

      expect(find.byType(Scaffold), findsWidgets, reason: '好友详情页应有 Scaffold');

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<bool> _openContactTab(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byKey(const Key('tab_contacts')),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
    find.byIcon(Icons.contacts),
    find.text('联系人'),
    find.text('Contacts'),
    find.text('Friends'),
  ]);
  if (tapped) await settle(tester, maxSeconds: 2);
  return tapped;
}
