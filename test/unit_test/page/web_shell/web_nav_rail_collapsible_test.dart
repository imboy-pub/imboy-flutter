import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';

const _items = [
  WebNavItem(
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    label: 'Messages',
  ),
  WebNavItem(
    icon: Icons.people_outline,
    activeIcon: Icons.people,
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
    label: 'Me',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  bool initiallyExpanded = true,
  ValueChanged<bool>? onExpandedChanged,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 720);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            WebNavRail(
              items: _items,
              currentIndex: 0,
              onTap: (_) {},
              initiallyExpanded: initiallyExpanded,
              persistExpandedState: false,
              onExpandedChanged: onExpandedChanged,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('展开态 176px 显示文案，收起态 72px 仅保留图标与 Tooltip', (
    tester,
  ) async {
    final changes = <bool>[];
    await _pump(tester, onExpandedChanged: changes.add);

    final rail = find.byKey(const ValueKey('desktop-navigation-rail'));
    expect(tester.getSize(rail).width, 176);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('desktop-navigation-collapse-toggle')),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(rail).width, 72);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Contacts'), findsNothing);
    expect(find.text('Channels'), findsNothing);
    expect(find.text('Me'), findsNothing);
    expect(find.byTooltip('Messages'), findsOneWidget);
    expect(find.byTooltip('Me'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('desktop-navigation-collapse-toggle')),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 176);
    expect(changes, [false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最后一个目的地固定到底部，不进入主导航滚动区', (tester) async {
    await _pump(tester);

    final scroll = find.byKey(
      const ValueKey('desktop-navigation-primary-scroll'),
    );
    expect(
      find.descendant(of: scroll, matching: find.byTooltip('Messages')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scroll, matching: find.byTooltip('Channels')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scroll, matching: find.byTooltip('Me')),
      findsNothing,
    );
    expect(
      tester.getCenter(find.byTooltip('Me')).dy,
      greaterThan(tester.getCenter(find.byTooltip('Channels')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('共享 scope 把展开状态提供给顶部空间入口', (tester) async {
    await _pump(tester, initiallyExpanded: true);
    final scope = tester.widget<DesktopNavigationScope>(
      find.byType(DesktopNavigationScope),
    );
    expect(scope.expanded, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('desktop-navigation-collapse-toggle')),
    );
    await tester.pumpAndSettle();
    final collapsedScope = tester.widget<DesktopNavigationScope>(
      find.byType(DesktopNavigationScope),
    );
    expect(collapsedScope.expanded, isFalse);
  });
}
