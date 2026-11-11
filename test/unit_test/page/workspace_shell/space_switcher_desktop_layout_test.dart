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
