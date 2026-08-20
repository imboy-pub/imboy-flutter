import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/wallet/alipay_simulator.dart';

Widget _buildTestApp(double amountYuan, String? merchantName) {
  return TranslationProvider(
    child: MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                child: const Text('Show Pay'),
                onPressed: () {
                  AlipaySimulator.show(
                    context,
                    amountYuan: amountYuan,
                    merchantName: merchantName,
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('AlipaySimulator full 5-screen interactive flow test', (
    WidgetTester tester,
  ) async {
    // 1. Render test app and tap to open simulator
    await tester.pumpWidget(_buildTestApp(24.80, '信息科技旗舰店'));
    await tester.pumpAndSettle();

    final showPayBtn = find.text('Show Pay');
    expect(showPayBtn, findsOneWidget);
    await tester.tap(showPayBtn);
    await tester.pumpAndSettle();

    // --- STEP 1: Select Payment Method ---
    // Verify title and radio buttons are shown
    expect(find.text(t.account.alipaySim.selectMethod), findsOneWidget);
    expect(find.text(t.account.payMethodAlipay), findsOneWidget);
    expect(find.text(t.account.alipaySim.huabei), findsOneWidget);

    // Tap Red "确认" (Confirm) button to move to Step 2
    final confirmBtn = find.text(t.common.confirm);
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // --- STEP 2: Confirm Payment ---
    // Verify Store Name, Amount and Green energy banner
    expect(find.text('信息科技旗舰店'), findsOneWidget);
    expect(find.text('¥ 24.80'), findsOneWidget);
    expect(find.text(t.account.alipaySim.energy), findsOneWidget);

    // Tap "确认付款" (Confirm Payment) button to move to Step 3
    final confirmPayBtn = find.text(t.account.alipaySim.confirmPay);
    expect(confirmPayBtn, findsOneWidget);
    await tester.tap(confirmPayBtn);
    await tester.pumpAndSettle();

    // --- STEP 3: Enter Payment Password ---
    // Verify title
    expect(find.text(t.account.alipaySim.enterPassword), findsOneWidget);

    // Tap custom keypad digits 1, 2, 3, 4, 5, 6
    for (var i = 1; i <= 6; i++) {
      final digitBtn = find.text('$i');
      expect(digitBtn, findsOneWidget);
      await tester.tap(digitBtn);
      await tester.pump();
    }
    // Wait for mock processing transition delay
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // --- STEP 4: Alipay Success ---
    // Verify Alipay success text and large success amount
    expect(find.text(t.account.alipaySim.alipaySuccess), findsOneWidget);
    expect(
      find.text('¥ 24.80'),
      findsNWidgets(2),
    ); // Total amount + detail row amount

    // Tap "完成" (Done) to move to Step 5
    final doneStep4Btn = find.text('完成');
    expect(doneStep4Btn, findsOneWidget);
    await tester.tap(doneStep4Btn);
    await tester.pumpAndSettle();

    // --- STEP 5: Merchant APP Success ---
    // Verify merchant payment success info and red done button
    expect(find.textContaining('交易剩余时间'), findsOneWidget);
    expect(find.text('支付成功  ¥ 24.80'), findsOneWidget);

    final doneStep5Btn = find.text('完成');
    expect(doneStep5Btn, findsOneWidget);
    await tester.tap(doneStep5Btn);
    await tester.pumpAndSettle();

    // Verify returning to home screen (Simulator popped successfully)
    expect(find.text('Show Pay'), findsOneWidget);
  });
}
