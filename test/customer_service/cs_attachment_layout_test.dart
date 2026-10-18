import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_attachment_views.dart';
import 'package:imboy/modules/customer_service/presentation/cs_message_bubble.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/theme/default/app_colors.dart';

import '../ux_matrix/ux_harness.dart';
import '../golden_baseline_guard.dart';

const _captureKey = ValueKey('t17-attachments');

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
    for (final status in ['active', 'unavailable']) {
      testWidgets(
        'golden: T17 $status $label',
        skip: !goldenBaselineExists(
          'test/customer_service/goldens/t17_${status}_$label.png',
        ),
        (tester) async {
          await pumpUxCombo(
            tester,
            RepaintBoundary(
              key: _captureKey,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      CsMessageBubble(
                        message: const EnterpriseMessage(
                          id: '7266418340025468961',
                          conversationId: '7266418340025468950',
                          organizationId: '7266418340025468901',
                          content: '请帮我核对这份附件，文本和多个附件保持同一条消息。',
                        ),
                        isSeat: false,
                        actorLabel: '客户',
                        assets: [
                          CsMessageAsset(
                            id: '7266418340025468971',
                            fileName: '合同.pdf',
                            mime: 'application/pdf',
                            sizeBytes: 1048576,
                            status: status,
                          ),
                          CsMessageAsset(
                            id: '7266418340025468972',
                            fileName: '很长的文件名-离线合成附件-订单状态说明.pdf',
                            mime: 'application/pdf',
                            sizeBytes: 1024,
                            status: status,
                          ),
                          const CsMessageAsset(
                            id: '7266418340025468973',
                            mime: 'image/png',
                            status: 'active',
                          ),
                        ],
                        bytesLoader: (_) async => null,
                        onView: (_) {},
                      ),
                      CsMessageBubble(
                        message: const EnterpriseMessage(
                          id: '7266418340025468962',
                          conversationId: '7266418340025468950',
                          organizationId: '7266418340025468901',
                          senderType: EnterpriseSenderType.businessIdentity,
                          content: '已收到，我来核对。',
                        ),
                        isSeat: true,
                        actorLabel: '坐席',
                        assets: const [],
                        bytesLoader: (_) async => null,
                        onView: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
            combo,
          );
          final layoutError = tester.takeException();
          await expectLater(
            find.byKey(_captureKey),
            matchesGoldenFile('goldens/t17_${status}_$label.png'),
          );
          expect(layoutError, isNull);
          expect(find.text('合同.pdf'), findsOneWidget);
          expect(find.byType(CsAssetImageThumb), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          for (final row in find.byType(CsAssetFileRow).evaluate()) {
            final size = tester.getSize(find.byWidget(row.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
        },
      );
    }
  }

  for (final status in ['active', 'deleted']) {
    testWidgets('文件$status 保留名称、状态和原预览回调', (tester) async {
      var views = 0;
      await tester.pumpWidget(
        uxHost(
          Scaffold(
            body: CsAssetFileRow(
              asset: CsMessageAsset(
                id: '7266418340025468971',
                fileName: 'fixture.pdf',
                sizeBytes: 1024,
                status: status,
              ),
              onView: () => views++,
            ),
          ),
          UxCombo(const Size(360, 800)),
        ),
      );
      expect(find.text('fixture.pdf'), findsOneWidget);
      expect(find.textContaining('1.0KB'), findsOneWidget);
      await tester.tap(find.byType(CsAssetFileRow));
      expect(views, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('文件按钮保留会话继承的文字颜色与行高', (tester) async {
    await tester.pumpWidget(
      uxHost(
        const Scaffold(
          body: DefaultTextStyle(
            style: TextStyle(color: AppColors.iosRed, height: 2),
            child: CsAssetFileRow(
              asset: CsMessageAsset(
                id: '7266418340025468971',
                fileName: 'fixture.pdf',
              ),
            ),
          ),
        ),
        UxCombo(const Size(360, 800)),
      ),
    );
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.text('fixture.pdf'),
        matching: find.byType(RichText),
      ),
    );
    expect(text.text.style?.color, AppColors.iosRed);
    expect(text.text.style?.height, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺失文件名使用原占位文案；空回调保持禁用', (tester) async {
    await tester.pumpWidget(
      uxHost(
        const Scaffold(
          body: CsAssetFileRow(
            asset: CsMessageAsset(id: '7266418340025468971'),
          ),
        ),
        UxCombo(const Size(360, 800)),
      ),
    );
    expect(find.text(t.customerService.attachUnnamedFile), findsOneWidget);
    expect(
      tester.widget<CupertinoButton>(find.byType(CupertinoButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
