import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_action_confirmation.dart';

import '../ux_matrix/ux_harness.dart';
import 'cs_session_action_confirmation_test.dart' as fixture;
import '../golden_baseline_guard.dart';

void main() {
  // await + setUpAll：setLocale 的异步补发若在上一用例卸载后才抵达，
  // 会对 defunct 的 _TranslationProviderState setState（CI 间歇挂）。
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  for (final (label, combo) in [
    ('390_1_light', UxCombo(const Size(390, 844))),
    ('360_1_light', UxCombo(const Size(360, 800))),
    (
      '360_2_dark',
      UxCombo(const Size(360, 800), textScale: 2, brightness: Brightness.dark),
    ),
    (
      '1280_1_dark',
      UxCombo(const Size(1280, 900), brightness: Brightness.dark),
    ),
    ('1280_2_light', UxCombo(const Size(1280, 900), textScale: 2)),
  ]) {
    for (final transfer in [false, true]) {
      final action = transfer ? 'transfer' : 'close';
      testWidgets(
        'golden: T18 $action $label',
        skip: !goldenBaselineExists(
          'test/customer_service/goldens/t18_${action}_$label.png',
        ),
        (tester) async {
          tester.view.physicalSize = combo.viewport;
          tester.view.devicePixelRatio = 1;
          if (combo.viewport.width == 360) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          }
          addTearDown(() {
            tester.view.resetViewInsets();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          late BuildContext context;
          await tester.pumpWidget(
            uxHost(
              Builder(
                builder: (current) {
                  context = current;
                  return const Scaffold();
                },
              ),
              combo,
            ),
          );
          final api = fixture.ActionApi();
          final flow = fixture.flow(api);
          final actions = CsSessionActionConfirmation(api: api);
          const risks = CsActionRisks(
            draft: true,
            sending: true,
            uploading: true,
            unconfirmed: true,
          );
          final pending = transfer
              ? actions.transfer(
                  context: context,
                  flow: flow,
                  isCurrent: () => true,
                  risks: () => risks,
                )
              : actions.close(
                  context: context,
                  flow: flow,
                  isCurrent: () => true,
                  risks: () => risks,
                );
          try {
            await tester.pumpAndSettle();
            if (transfer) {
              expect(api.targets, 1);
              expect(api.writes, 0);
              await tester.tap(find.byType(SimpleDialogOption));
              await tester.pumpAndSettle();
            }
            final layoutError = tester.takeException();
            await expectLater(
              find.byType(AlertDialog),
              matchesGoldenFile('goldens/t18_${action}_$label.png'),
            );
            expect(layoutError, isNull);
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNull,
            );
            final cancel = find.widgetWithText(
              TextButton,
              t.common.buttonCancel,
            );
            expect(
              tester.getRect(cancel).bottom,
              lessThanOrEqualTo(
                combo.viewport.height - tester.view.viewInsets.bottom,
              ),
            );
            if (transfer) {
              expect(find.textContaining('Real target'), findsOneWidget);
            } else {
              await tester.ensureVisible(find.byType(TextField));
              await tester.enterText(find.byType(TextField), '合成结束原因');
            }
            expect(api.writes, 0);
            await tester.tap(cancel);
            await tester.pumpAndSettle();
            expect(await pending, isNull);
            expect(api.writes, 0);
            expect(tester.takeException(), isNull);
          } finally {
            actions.invalidate();
            await tester.pumpAndSettle();
            await pending;
            actions.dispose();
            flow.dispose();
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          }
        },
      );
    }
  }
}
