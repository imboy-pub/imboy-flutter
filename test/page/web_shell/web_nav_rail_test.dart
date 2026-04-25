/// Phase 1.1.e — Web Nav Rail widget 测试
///
/// 覆盖：
/// - 必传 items / currentIndex / onTap 渲染契约
/// - 选中态：activeIcon 切换 + primary 高亮
/// - 角标：count=0 隐藏 / 1-99 直显 / >99 显示 99+
/// - onTap 回调正确触发
/// - 默认/自定义 width
/// - assert 防御边界
/// - WebNavItem 相等性
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';

const _kSampleItems = [
  WebNavItem(
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    label: 'Messages',
  ),
  WebNavItem(
    icon: Icons.people_alt_outlined,
    activeIcon: Icons.people_alt,
    label: 'Contacts',
  ),
  WebNavItem(
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
    label: 'Channels',
  ),
  WebNavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Mine',
  ),
];

Future<void> _pumpRail(
  WidgetTester tester, {
  required List<WebNavItem> items,
  required int currentIndex,
  required ValueChanged<int> onTap,
  double? width,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: Row(
          children: [
            WebNavRail(
              items: items,
              currentIndex: currentIndex,
              onTap: onTap,
              width: width ?? 72,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('WebNavRail — 基础渲染', () {
    testWidgets('渲染 4 个 items', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      // 4 个 InkWell（每个 item 一个）
      expect(find.byType(InkWell), findsNWidgets(4));
    });

    testWidgets('默认 width=72', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      final rail = tester.widget<WebNavRail>(find.byType(WebNavRail));
      expect(rail.width, 72);
    });

    testWidgets('自定义 width 生效', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
        width: 96,
      );
      final rail = tester.widget<WebNavRail>(find.byType(WebNavRail));
      expect(rail.width, 96);
    });

    testWidgets('label 通过 Tooltip 暴露（无障碍）', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      // 4 个 Tooltip，每个 item 一个
      expect(find.byType(Tooltip), findsNWidgets(4));
      expect(
        find.byTooltip('Messages'),
        findsOneWidget,
      );
      expect(find.byTooltip('Contacts'), findsOneWidget);
    });
  });

  group('WebNavRail — 选中态切换', () {
    testWidgets('currentIndex=0: 第一个 item 用 activeIcon', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      // Tab 0 选中 → 看到 chat_bubble (filled)
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      // 其他 3 个 outline
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('currentIndex=2: 第三个 item 用 activeIcon', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 2,
        onTap: (_) {},
      );
      expect(find.byIcon(Icons.campaign), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      // 其他 3 个 outline
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('选中 item 图标颜色用 primary', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      final BuildContext ctx =
          tester.element(find.byIcon(Icons.chat_bubble));
      final cs = Theme.of(ctx).colorScheme;
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.chat_bubble));
      expect(iconWidget.color, cs.primary);
    });

    testWidgets('未选中 item 图标颜色用 onSurfaceVariant', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      final BuildContext ctx =
          tester.element(find.byIcon(Icons.people_alt_outlined));
      final cs = Theme.of(ctx).colorScheme;
      final iconWidget =
          tester.widget<Icon>(find.byIcon(Icons.people_alt_outlined));
      expect(iconWidget.color, cs.onSurfaceVariant);
    });
  });

  group('WebNavRail — 角标', () {
    testWidgets('badgeCount=0 不显示角标', (tester) async {
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (_) {},
      );
      // 默认 4 个 item 都 badgeCount=0，应无 badge 文本
      expect(find.text('1'), findsNothing);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('badgeCount=5 显示 "5"', (tester) async {
      const itemsWithBadge = [
        WebNavItem(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: 'M',
          badgeCount: 5,
        ),
        WebNavItem(
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt,
          label: 'C',
        ),
      ];
      await _pumpRail(
        tester,
        items: itemsWithBadge,
        currentIndex: 0,
        onTap: (_) {},
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('badgeCount=99 显示 "99"（未触发省略）', (tester) async {
      const itemsWith99 = [
        WebNavItem(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: 'M',
          badgeCount: 99,
        ),
        WebNavItem(
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt,
          label: 'C',
        ),
      ];
      await _pumpRail(
        tester,
        items: itemsWith99,
        currentIndex: 0,
        onTap: (_) {},
      );
      expect(find.text('99'), findsOneWidget);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('badgeCount=100 显示 "99+"（省略）', (tester) async {
      const itemsWith100 = [
        WebNavItem(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: 'M',
          badgeCount: 100,
        ),
        WebNavItem(
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt,
          label: 'C',
        ),
      ];
      await _pumpRail(
        tester,
        items: itemsWith100,
        currentIndex: 0,
        onTap: (_) {},
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('badgeCount=999 仍显示 "99+"', (tester) async {
      const itemsWith999 = [
        WebNavItem(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: 'M',
          badgeCount: 999,
        ),
        WebNavItem(
          icon: Icons.people_alt_outlined,
          activeIcon: Icons.people_alt,
          label: 'C',
        ),
      ];
      await _pumpRail(
        tester,
        items: itemsWith999,
        currentIndex: 0,
        onTap: (_) {},
      );
      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('WebNavRail — onTap 回调', () {
    testWidgets('点击第 2 个 item 回调 index=1', (tester) async {
      var lastTap = -1;
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (i) => lastTap = i,
      );
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      expect(lastTap, 1);
    });

    testWidgets('点击第 4 个 item 回调 index=3', (tester) async {
      var lastTap = -1;
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 0,
        onTap: (i) => lastTap = i,
      );
      await tester.tap(find.byType(InkWell).at(3));
      await tester.pump();
      expect(lastTap, 3);
    });

    testWidgets('点击当前选中 item 仍回调（由调用方决定是否短路）', (tester) async {
      var lastTap = -1;
      await _pumpRail(
        tester,
        items: _kSampleItems,
        currentIndex: 1,
        onTap: (i) => lastTap = i,
      );
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pump();
      expect(lastTap, 1);
    });
  });

  group('WebNavRail — assert 防御', () {
    testWidgets('items 长度 < 2 应触发 assert', (tester) async {
      expect(
        () => WebNavRail(
          items: const [
            WebNavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'M',
            ),
          ],
          currentIndex: 0,
          onTap: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('currentIndex 越界负数应触发 assert', (tester) async {
      expect(
        () => WebNavRail(
          items: _kSampleItems,
          currentIndex: -1,
          onTap: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('currentIndex 越界正数应触发 assert', (tester) async {
      expect(
        () => WebNavRail(
          items: _kSampleItems,
          currentIndex: 4,
          onTap: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('WebNavItem — 相等性', () {
    test('同字段相等', () {
      const a = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
        badgeCount: 5,
      );
      const b = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
        badgeCount: 5,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('不同 label 不相等', () {
      const a = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
      );
      const b = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'C',
      );
      expect(a, isNot(equals(b)));
    });

    test('不同 badgeCount 不相等', () {
      const a = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
        badgeCount: 0,
      );
      const b = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
        badgeCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('badgeCount 默认值 0', () {
      const item = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
      );
      expect(item.badgeCount, 0);
    });
  });
}
