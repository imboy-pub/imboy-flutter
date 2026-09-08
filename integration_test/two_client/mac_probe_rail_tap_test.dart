// integration_test/two_client/mac_probe_rail_tap_test.dart
//
// #17 mac ping 诊断探针（非验收用例）：验证 tablet NavigationRail 点击
// 联系人 tab 后 PageView 是否真正构建 ContactPage。
// 三种失败形态一次定性：
//   A selectedIndex 不变 → tap 落空（warnIfMissed=false 掩盖）
//   B selectedIndex 变了但树无 ContactPage → PageView 未跟随（hasClients 守卫吞掉 jumpToPage）
//   C ContactPage 挂载但列表空 → ContactPage 内部数据链问题

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('探针 · rail 点击联系人 tab 是否构建 ContactPage', (tester) async {
    await ensureAppLaunched(tester, maxSeconds: 5);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    if (!await waitForMainShell(tester)) {
      fail('登录成功但主 Shell 未挂载');
    }

    Future<void> dump(String phase) async {
      final rails = find.byType(NavigationRail);
      if (tester.any(rails)) {
        final NavigationRail rail = tester.widget(rails.first);
        flowLog('[$phase] rail.selectedIndex=${rail.selectedIndex}');
      } else {
        flowLog('[$phase] 树上无 NavigationRail');
      }
      flowLog(
        '[$phase] hasContactPage=${tester.any(find.byType(ContactPage))} '
        'hasBottomNavPage=${tester.any(find.byType(BottomNavigationPage))}',
      );
    }

    final width =
        tester.binding.window.physicalSize.width /
        tester.binding.window.devicePixelRatio;
    flowLog(
      '探针 · 窗口 logicalWidth=$width physical=${tester.binding.window.physicalSize.width} '
      'dpr=${tester.binding.window.devicePixelRatio}',
    );
    await dump('tap前');

    // 实测走移动端底栏（isTablet=false）：点 tab_contacts 后观察 ContactPage
    final tabContacts = find.byKey(const Key('tab_contacts'));
    if (tester.any(tabContacts)) {
      await tester.tap(tabContacts.first);
      await settle(tester, maxSeconds: 3);
      await dump('底栏tap后即时');
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      await dump('底栏tap后2s');
    } else {
      flowLog('探针结论：底栏 tab_contacts 也找不到');
    }
  });
}
