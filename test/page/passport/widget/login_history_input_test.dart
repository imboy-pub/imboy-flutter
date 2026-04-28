import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/passport/widget/login_history_input.dart';

/// LoginHistoryInput widget test
///
/// 覆盖：
///   - hintText / prefixIcon 渲染
///   - historyList 非空时显示下拉箭头 suffix
///   - historyList 空时不显示 suffix
///   - 自定义 suffixIcon 覆盖默认下拉箭头
///   - obscureText / keyboardType 透传 TextField
///   - tap 下拉箭头 → Overlay 出现 + 列出 historyList 项
///   - tap 列表项 → onSelect 回调 + controller.text 同步
///   - tap 列表项 close icon → onDelete 回调 + Overlay 关闭
///   - dispose 清理 Overlay（不泄漏）
Future<void> _pump(
  WidgetTester tester, {
  required TextEditingController controller,
  required List<String> history,
  required void Function(String) onSelect,
  required void Function(String) onDelete,
  bool obscureText = false,
  Widget? suffixIcon,
  TextInputType keyboardType = TextInputType.text,
  String hintText = 'Email',
  IconData prefixIcon = Icons.email,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: LoginHistoryInput(
              controller: controller,
              hintText: hintText,
              prefixIcon: prefixIcon,
              historyList: history,
              onSelect: onSelect,
              onDelete: onDelete,
              obscureText: obscureText,
              suffixIcon: suffixIcon,
              keyboardType: keyboardType,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('LoginHistoryInput layout', () {
    testWidgets('renders hintText + prefixIcon', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const [],
        onSelect: (_) {},
        onDelete: (_) {},
        hintText: 'PleaseEmail',
        prefixIcon: Icons.email_outlined,
      );

      expect(find.text('PleaseEmail'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('history 空 → 无 suffix（无下拉箭头）', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const [],
        onSelect: (_) {},
        onDelete: (_) {},
      );

      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('history 非空 → 显示下拉箭头 suffix', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const ['a@b.com', 'c@d.com'],
        onSelect: (_) {},
        onDelete: (_) {},
      );

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('自定义 suffixIcon 覆盖默认下拉箭头', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      const customIcon = Icon(Icons.qr_code, key: Key('custom_suffix'));
      await _pump(
        tester,
        controller: ctrl,
        history: const ['a@b.com'], // 即便有历史，也用自定义
        onSelect: (_) {},
        onDelete: (_) {},
        suffixIcon: customIcon,
      );

      expect(find.byKey(const Key('custom_suffix')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing,
          reason: '自定义 suffix 应覆盖默认下拉箭头');
    });

    testWidgets('obscureText + keyboardType 透传 TextField', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const [],
        onSelect: (_) {},
        onDelete: (_) {},
        obscureText: true,
        keyboardType: TextInputType.emailAddress,
      );

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.obscureText, isTrue);
      expect(tf.keyboardType, TextInputType.emailAddress);
    });
  });

  group('LoginHistoryInput overlay interactions', () {
    testWidgets('tap 下拉箭头 → Overlay 出现 + ListTile 渲染所有 history',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      const items = ['alice@example.com', 'bob@example.com'];

      await _pump(
        tester,
        controller: ctrl,
        history: items,
        onSelect: (_) {},
        onDelete: (_) {},
      );

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      // Overlay 内 ListTile 数 == history 长度
      expect(find.byType(ListTile), findsNWidgets(items.length));
      for (final item in items) {
        expect(find.text(item), findsOneWidget);
      }
    });

    testWidgets('tap ListTile → onSelect 回调 + controller.text 同步 + Overlay 关闭',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      String? selected;

      await _pump(
        tester,
        controller: ctrl,
        history: const ['alice@example.com', 'bob@example.com'],
        onSelect: (v) => selected = v,
        onDelete: (_) {},
      );

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      await tester.tap(find.text('bob@example.com'));
      await tester.pumpAndSettle();

      expect(selected, 'bob@example.com');
      expect(ctrl.text, 'bob@example.com',
          reason: 'controller.text 必须同步选中项');
      // Overlay 关闭：ListTile 不再可见
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('tap close icon → onDelete 回调 + Overlay 关闭',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      String? deleted;

      await _pump(
        tester,
        controller: ctrl,
        history: const ['alice@example.com', 'bob@example.com'],
        onSelect: (_) {},
        onDelete: (v) => deleted = v,
      );

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      // close icon 在 ListTile.trailing 中（IconButton + Icons.close）
      // 找第一个 close 即对应 alice 行
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsNWidgets(2));

      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      expect(deleted, 'alice@example.com');
      expect(ctrl.text, '',
          reason: 'onDelete 不应改 controller.text，仅触发回调');
      // 当前实现：tap 删除即关闭 Overlay
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('再次 tap 下拉箭头 (Overlay 已开) → 关闭 Overlay (toggle)',
        (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const ['x@y.com'],
        onSelect: (_) {},
        onDelete: (_) {},
      );

      // 第一次 tap：开
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);

      // 第二次 tap：关
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('LoginHistoryInput cleanup', () {
    testWidgets('dispose 清理 Overlay 不泄漏', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);

      await _pump(
        tester,
        controller: ctrl,
        history: const ['a@b.com'],
        onSelect: (_) {},
        onDelete: (_) {},
      );

      // 打开 Overlay
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);

      // 替换整个 widget 树触发 dispose
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(find.byType(LoginHistoryInput), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
