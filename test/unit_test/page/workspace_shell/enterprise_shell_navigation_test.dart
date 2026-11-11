/// 企业壳全局空间入口、导航迁移与矮窗口可达性回归。
library;

import 'package:flutter/material.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';
import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_top_bar.dart';

import 'enterprise_shell_test_fixtures.dart';

void main() {
  registerEnterpriseShellFixture();
  for (final brightness in Brightness.values) {
    testWidgets('企业手机复用个人底栏并保留角标和选中图标 $brightness', (tester) async {
      final api = EnterpriseOaApi();
      await pumpEnterpriseShell(
        tester,
        api,
        brightness: brightness,
        size: const Size(360, 800),
        conversations: [
          WorkspaceConversationModel(
            group: GroupModel.fromJson({'id': '200', 'name': '合成群'}),
            memberStartSeq: 1,
            unreadCount: 7,
          ),
        ],
      );
      api.completeFirst([]);
      await tester.pumpAndSettle();
      final nav = find.byKey(const ValueKey('enterprise-shell-bottom-nav'));
      final bar = tester.widget<GlassBottomNavigationBar>(nav);
      expect(bar.items.map((item) => item.label), ['消息', '通讯录', '工作台', '我']);
      final messages = find.byKey(
        const ValueKey('enterprise-shell-nav-messages'),
      );
      expect(
        find.descendant(of: messages, matching: find.text('7')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: messages,
          matching: find.byIcon(bar.items.first.activeIcon!),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('enterprise-shell-nav-contacts')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<GlassBottomNavigationBar>(nav).currentIndex, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '移动平板继续使用原导航布局',
    (tester) async {
      final api = EnterpriseOaApi();
      await pumpEnterpriseShell(tester, api, size: const Size(750, 900));
      api.completeFirst([]);
      await tester.pumpAndSettle();
      expect(find.byType(WebNavRail), findsNothing);
      final rail = tester.widget<NavigationRail>(
        find.byKey(const ValueKey('enterprise-shell-rail')),
      );
      expect(rail.destinations, hasLength(4));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    '各桌面平台使用共享导航与紧凑宽度规则',
    (tester) async {
      final api = EnterpriseOaApi();
      await pumpEnterpriseShell(tester, api, size: const Size(750, 900));
      if (api.calls.isNotEmpty) api.completeFirst([]);
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('desktop-navigation-rail'));
      expect(
        tester.getSize(rail).width,
        kCompactDesktopNavigationExpandedWidth,
      );
      expect(find.byType(NavigationRail), findsNothing);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, kDesktopNavigationExpandedWidth);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  for (final brightness in Brightness.values) {
    testWidgets('企业桌面复用主题、展开偏好和角标，收起后仍可导航 $brightness', (tester) async {
      final api = EnterpriseOaApi();
      await pumpEnterpriseShell(
        tester,
        api,
        brightness: brightness,
        size: const Size(1440, 900),
        conversations: [
          WorkspaceConversationModel(
            group: GroupModel.fromJson({'id': '200', 'name': '合成群'}),
            memberStartSeq: 1,
            unreadCount: 7,
          ),
        ],
      );
      api.completeFirst([]);
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('enterprise-shell-rail'));
      final surface = find.byKey(const ValueKey('desktop-navigation-rail'));
      final mine = find.byKey(const ValueKey('enterprise-shell-nav-mine'));
      final messages = find.byKey(
        const ValueKey('enterprise-shell-nav-messages'),
      );
      expect(tester.getSize(surface).width, kDesktopNavigationExpandedWidth);
      final decoration =
          tester.widget<AnimatedContainer>(surface).decoration!
              as BoxDecoration;
      expect(
        decoration.color,
        brightness == Brightness.dark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightAppBarBackground,
      );
      expect(tester.widget<WebNavRail>(rail).items.first.badgeCount, 7);
      expect(
        find.descendant(of: messages, matching: find.text('7')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('desktop-navigation-primary-scroll')),
          matching: mine,
        ),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('desktop-navigation-collapse-toggle')),
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      expect(tester.getSize(surface).width, kDesktopNavigationCollapsedWidth);
      expect(
        StorageService.to.getBool(kDesktopNavigationExpandedPreferenceKey),
        isFalse,
      );
      expect(
        find.descendant(of: messages, matching: find.text('7')),
        findsOneWidget,
      );
      await tester.tap(mine);
      await tester.pumpAndSettle();
      expect(tester.widget<WebNavRail>(rail).currentIndex, 3);
      await tester.tap(
        find.byKey(const ValueKey('desktop-navigation-collapse-toggle')),
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      expect(tester.getSize(surface).width, kDesktopNavigationExpandedWidth);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

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
      expect(tester.widget<WebNavRail>(rail).currentIndex, 3);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }
}
