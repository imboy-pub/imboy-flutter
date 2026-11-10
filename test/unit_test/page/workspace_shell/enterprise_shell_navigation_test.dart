/// 企业壳全局空间入口、导航迁移与矮窗口可达性回归。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_top_bar.dart';

import 'enterprise_shell_test_fixtures.dart';

void main() {
  registerEnterpriseShellFixture();
  for (final width in [750.0, 1440.0]) {
    testWidgets('$width 宽侧栏空间入口跨四个 tab 保留且消息头不重复', (tester) async {
      final api = EnterpriseOaApi();
      await pumpEnterpriseShell(tester, api, size: Size(width, 900));
      api.completeFirst([]);
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('enterprise-shell-rail'));
      final entry = find.byKey(
        const ValueKey('enterprise-shell-space-switcher'),
      );
      expect(find.descendant(of: rail, matching: entry), findsOneWidget);
      expect(
        find.byKey(const ValueKey('enterprise-shell-bottom-nav')),
        findsNothing,
      );
      expect(
        tester.widget<WorkspaceTopBar>(find.byType(WorkspaceTopBar)).leading,
        isNull,
      );

      for (final label in ['通讯录', '工作台', '我']) {
        await tester.tap(find.descendant(of: rail, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(entry, findsOneWidget);
        expect(
          find.byKey(const ValueKey('enterprise-shell-menu-button')),
          findsNothing,
        );
      }
      // 缩矮窗口后目的地仍可滚动触达，全局空间入口保持在顶部。
      tester.view.physicalSize = Size(width, 320);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(of: rail, matching: find.text('我')),
      );
      await tester.pumpAndSettle();
      expect(entry.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 在「我」tab 也能直接打开，不必回消息页。
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('space-switcher-popover')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('space-switcher-sheet')), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      await tester.tapAt(Offset(width - 20, 300));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceDrawerMenu), findsNothing);
      expect(tester.widget<NavigationRail>(rail).selectedIndex, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
