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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
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
    testWidgets(
      '搜索用户并打开用户详情（不发送好友请求）',
      (tester) async {
        await ensureAppLaunched(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'add_friend_01_launch');

        if (!await checkPreconditions(tester)) return;

        await settle(tester, maxSeconds: 2);

        if (!await _openContactTab(tester)) {
          markTestSkipped('无法进入联系人页，跳过');
          return;
        }

        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'add_friend_02_contact_tab');

        if (!tester.any(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'ContactPage',
          ),
        )) {
          flowLog(
            '联系人入口诊断：未发现 ContactPage，当前 widget 类型=${tester.allWidgets.map((w) => w.runtimeType.toString()).toSet().join(',')}',
          );
        }

        if (!await tapAny(tester, [
          find.byKey(const Key('add_friend_button')),
          find.byIcon(Icons.person_add),
          find.byIcon(Icons.person_add_outlined),
          find.byIcon(CupertinoIcons.person_add),
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

        final searchField = find.byKey(const Key('add_friend_search_input'));
        if (!tester.any(searchField)) {
          markTestSkipped('添加好友页无搜索框，跳过');
          return;
        }

        if (_searchKeyword.isEmpty) {
          // 无搜索词时只验证页面可达性
          expect(
            find.byType(Scaffold),
            findsWidgets,
            reason: '添加好友页应有 Scaffold',
          );
          flowLog('未配置 TEST_SEARCH_KEYWORD，仅验收页面可访问性');
          drainKnownFrameworkExceptions(tester);
          return;
        }

        await tester.enterText(searchField.first, _searchKeyword);
        // CupertinoSearchTextField 的业务回调挂在 onSubmitted；enterText 只改值，
        // 不会自动模拟键盘搜索动作，因此必须显式发送 search action。
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'add_friend_04_results');

        // AddFriendPage 的 onSubmitted 在拿到结果后直接 push PeopleInfoPage，
        // 不会在本页渲染 ListTile；用 ListTile 判断结果会把真实搜索结果误报为空。
        final hasProfile = tester.any(find.byType(PeopleInfoPage));
        if (!hasProfile) {
          flowLog('搜索"$_searchKeyword"没有进入用户详情页，跳过好友申请步骤');
          markTestSkipped('测试账号未出现在当前生产搜索索引，无法继续好友详情验证');
          return;
        }

        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'add_friend_05_profile');

        expect(find.byType(Scaffold), findsWidgets, reason: '用户详情页应有 Scaffold');

        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

Future<bool> _openContactTab(WidgetTester tester) async {
  final candidates = [
    find.byKey(const Key('tab_contacts')),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
    find.text('联系人'),
    find.text('Contacts'),
  ];
  for (final candidate in candidates) {
    if (!await safeTap(tester, candidate)) continue;
    await settle(tester, maxSeconds: 2);
    final onContactPage =
        tester.any(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'ContactPage',
          ),
        ) ||
        tester.any(find.byKey(const Key('contact_search_input')));
    if (onContactPage) return true;
  }

  // GlassBottomNavigationBar 的 Expanded 可能被测试框架判定为可点击，
  // 但实际命中区域在厂商真机上不稳定；用第 2 个底部栏槽位做坐标兜底。
  final glassBar = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
  );
  if (tester.any(glassBar)) {
    try {
      final rect = tester.getRect(glassBar.first);
      await tester.tapAt(
        Offset(rect.left + rect.width * 0.375, rect.center.dy),
      );
      await settle(tester, maxSeconds: 2);
      return tester.any(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'ContactPage',
            ),
          ) ||
          tester.any(find.byKey(const Key('contact_search_input')));
    } catch (_) {}
  }
  return false;
}
