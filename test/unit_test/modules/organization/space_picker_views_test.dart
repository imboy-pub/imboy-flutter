import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/space_picker_views.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'picker stays simple and operable at 320 $brightness $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var joined = 0;
          var created = 0;
          await tester.pumpWidget(
            TranslationProvider(
              child: MaterialApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.getDarkTheme()
                    : AppTheme.getLightTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      SpacePickerSection(
                        children: [
                          ListTile(
                            title: Text(
                              t.organization.experienceUi.personalSpace,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SpacePickerActions(
                        onJoin: () => joined++,
                        onCreate: () => created++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(
            find.text(t.organization.experienceUi.personalSpace),
            findsOneWidget,
          );
          final section = tester.widget<CupertinoListSection>(
            find.byType(CupertinoListSection),
          );
          expect(section.header, isNull);
          expect(
            section.decoration!.color,
            isNot(AppColors.getSurfaceGrouped(brightness)),
          );
          for (final key in [
            'org-picker-join-entry',
            'org-picker-create-entry',
          ]) {
            final button = find.byKey(ValueKey(key));
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            await tester.tap(button);
          }
          expect((joined, created), (1, 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
