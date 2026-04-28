import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_confirm_dialog.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// `showMomentConfirmDialog` 契约：
/// - 渲染 title + message，两个按钮（cancel / confirm）
/// - cancel 点击 → Future 结算为 false
/// - confirm 点击 → Future 结算为 true
/// - `isDestructive = true` 时 confirm 按钮文字使用 `AppColors.iosRed`
///   （HIG: 破坏性操作用红色，区别于常规确认）
/// - barrier 点击 → 结算为 false（非阻塞关闭视为取消，防止点空白误删）
void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required bool isDestructive,
    String title = '删除',
    String message = '确定删除吗？',
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              captured = ctx;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    // 直接调用 helper，result 由测试各自断言
    // 传入显式标签避免测试依赖 TranslationProvider 的默认 locale（脆弱）
    // ignore: unawaited_futures
    showMomentConfirmDialog(
      captured,
      title: title,
      message: message,
      isDestructive: isDestructive,
      confirmLabel: 'OK',
      cancelLabel: 'NO',
    ).then((v) => _lastResult = v);
    await tester.pumpAndSettle();
  }

  testWidgets('renders title and message', (tester) async {
    await pumpHost(tester, isDestructive: false, title: 'T', message: 'M');
    expect(find.text('T'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('cancel tap resolves to false', (tester) async {
    _lastResult = null;
    await pumpHost(tester, isDestructive: false);
    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    expect(_lastResult, isFalse);
  });

  testWidgets('confirm tap resolves to true', (tester) async {
    _lastResult = null;
    await pumpHost(tester, isDestructive: false);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(_lastResult, isTrue);
  });

  testWidgets('destructive confirm button uses iosRed', (tester) async {
    await pumpHost(tester, isDestructive: true);
    final confirmText = tester.widget<Text>(find.text('OK'));
    expect(confirmText.style?.color, AppColors.iosRed);
  });

  testWidgets('non-destructive confirm button is NOT iosRed', (tester) async {
    await pumpHost(tester, isDestructive: false);
    final confirmText = tester.widget<Text>(find.text('OK'));
    expect(confirmText.style?.color, isNot(AppColors.iosRed));
  });

  testWidgets('renders 2 TextButton actions (cancel + confirm)',
      (tester) async {
    await pumpHost(tester, isDestructive: false);
    expect(find.byType(AlertDialog), findsOneWidget);
    final actions = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    expect(actions, findsNWidgets(2));
  });

  testWidgets('non-destructive confirm uses colorScheme.primary',
      (tester) async {
    await pumpHost(tester, isDestructive: false);
    final confirmText = tester.widget<Text>(find.text('OK'));
    final ctx = tester.element(find.byType(AlertDialog));
    final expectedColor = Theme.of(ctx).colorScheme.primary;
    expect(confirmText.style?.color, expectedColor);
  });

  testWidgets(
    'barrier dismiss → null result coerces to false',
    (tester) async {
      _lastResult = null;
      await pumpHost(tester, isDestructive: false);

      // barrier 点击在不同 Flutter 渲染版本下命中行为不稳定，
      // 用 navigator.maybePop() 模拟 barrierDismissible 路径：
      // showDialog 返回 null → helper 内部 `result ?? false` → false
      final navigator = Navigator.of(
        tester.element(find.byType(AlertDialog)),
        rootNavigator: true,
      );
      navigator.pop(); // pop 不带 result → showDialog 收到 null
      await tester.pumpAndSettle();

      expect(_lastResult, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'default labels fall back to i18n buttonCancel/confirm '
    'when confirmLabel/cancelLabel are null',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                captured = ctx;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      // ignore: unawaited_futures
      showMomentConfirmDialog(
        captured,
        title: 'T',
        message: 'M',
        // confirmLabel / cancelLabel 故意省略 → helper 走 i18n 兜底
      );
      await tester.pumpAndSettle();

      // i18n: buttonCancel = "取消"，confirm = "确认"
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    },
  );
}

bool? _lastResult;
