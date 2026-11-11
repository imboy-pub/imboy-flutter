// integration_test/two_client/mac_probe_rail_tap_test.dart
//
// #17 mac ping 诊断探针（非验收用例）：验证桌面侧栏点击联系人 tab 后
// PageView 是否真正构建 ContactPage。兼容可折叠 WebNavRail 与移动平板
// 仍保留的 Material NavigationRail。
// 三种失败形态一次定性：
//   A selectedIndex 不变 → tap 落空（warnIfMissed=false 掩盖）
//   B selectedIndex 变了但树无 ContactPage → PageView 未跟随
//   C ContactPage 挂载但列表空 → ContactPage 内部数据链问题

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';
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
      final collapsible = find.byType(WebNavRail);
      final material = find.byType(NavigationRail);
      if (tester.any(collapsible)) {
        final rail = tester.widget<WebNavRail>(collapsible.first);
        flowLog('[$phase] WebNavRail.currentIndex=${rail.currentIndex}');
      } else if (tester.any(material)) {
        final rail = tester.widget<NavigationRail>(material.first);
        flowLog('[$phase] NavigationRail.selectedIndex=${rail.selectedIndex}');
      } else {
        flowLog('[$phase] 树上无桌面/平板 rail');
      }
      flowLog(
        '[$phase] hasContactPage=${tester.any(find.byType(ContactPage))} '
        'hasBottomNavPage=${tester.any(find.byType(BottomNavigationPage))}',
      );
    }

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    flowLog(
      '探针 · 窗口 logicalWidth=$width physical=${tester.view.physicalSize.width} '
      'dpr=${tester.view.devicePixelRatio}',
    );
    await dump('tap前');

    final tabContacts = find.byKey(const Key('tab_contacts'));
    if (tester.any(tabContacts)) {
      await tester.tap(tabContacts.first);
      await settle(tester, maxSeconds: 3);
      await dump('侧栏/底栏tap后即时');
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      await dump('侧栏/底栏tap后2s');
    } else {
      flowLog('探针结论：tab_contacts 找不到');
    }
  });
}
