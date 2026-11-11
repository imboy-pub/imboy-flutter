import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

Future<void> _pump(WidgetTester tester, {required bool expanded}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel(uid: '1', account: 'synthetic', nickname: '合成用户'),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: expanded ? 176 : 72,
                child: DesktopNavigationScope(
                  expanded: expanded,
                  child: SpaceSwitcherButton(inRail: true, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('空间入口在展开和收起动画每帧均不溢出 $brightness', (tester) async {
      var expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWithValue(null)],
          child: TranslationProvider(
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Scaffold(
                    body: DesktopNavigationRail(
                      items: const [
                        DesktopNavigationItem(
                          icon: Icons.chat,
                          activeIcon: Icons.chat,
                          label: '消息',
                        ),
                        DesktopNavigationItem(
                          icon: Icons.person,
                          activeIcon: Icons.person,
                          label: '我',
                        ),
                      ],
                      selectedIndex: 0,
                      onSelected: (_) {},
                      expanded: expanded,
                      onToggleExpanded: () {},
                      collapseLabel: '收起',
                      expandLabel: '展开',
                      leading: SpaceSwitcherButton(inRail: true, onTap: () {}),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (final next in [true, false, true]) {
        update(() => expanded = next);
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('展开态横向展示当前空间，收起态隐藏文案但保留完整语义', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester, expanded: true);
      expect(
        find.text(t.organization.experienceUi.personalSpace),
        findsOneWidget,
      );
      final expandedButton = find.bySemanticsLabel(
        t.organization.experienceUi.switchSpace,
      );
      expect(
        tester.getSemantics(expandedButton).getSemanticsData().value,
        t.organization.experienceUi.personalSpace,
      );

      await _pump(tester, expanded: false);
      expect(
        find.text(t.organization.experienceUi.personalSpace),
        findsNothing,
      );
      final collapsedButton = find.bySemanticsLabel(
        t.organization.experienceUi.switchSpace,
      );
      expect(
        tester.getSemantics(collapsedButton).getSemanticsData().value,
        t.organization.experienceUi.personalSpace,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
