import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  WebNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Me'),
];

Future<void> _pump(WidgetTester tester) async {
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
              persistExpandedState: false,
              leading: const SizedBox(
                key: ValueKey('space-switcher'),
                height: 48,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    '导航轨使用背景和留白分组，不绘制描边或横向分隔线',
    (tester) async {
      await _pump(tester);

      final railFinder = find.byKey(
        const ValueKey('desktop-navigation-rail'),
      );
      final rail = tester.widget<AnimatedContainer>(railFinder);
      final decoration = rail.decoration! as BoxDecoration;

      expect(decoration.border, isNull);

      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: railFinder,
          matching: find.byType(AnimatedContainer),
        ),
      );
      final hairlines = animatedContainers.where((widget) {
        final constraints = widget.constraints;
        return constraints != null &&
            constraints.minHeight == 0.5 &&
            constraints.maxHeight == 0.5;
      });

      expect(hairlines, isEmpty);
      expect(find.byKey(const ValueKey('space-switcher')), findsOneWidget);
      expect(find.byTooltip('Me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
