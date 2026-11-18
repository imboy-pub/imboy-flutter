import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/explicit_web_logout.dart';

/// LAY-05 DEF-LAY05-A/B（P3）弹层键盘行为回归。
///
/// 缺陷背景（runs/lay-sec06-residuals-20261116 run4 LAY-05）：
/// - A：退出登录确认 alertdialog 按 Esc 不关闭（after_esc dlgGone=false）——
///   CupertinoDialogRoute 框架层零 Escape 处理。
/// - B：Tab 焦点陷阱缺失——tab_cycle 在对话框与背景 INPUT×3 间循环。
///
/// 修复契约：Esc=取消（pop(false)）；autofocus 落「取消」；Tab/Shift+Tab
/// 在弹层内两动作间循环，永不交还引擎默认遍历。
Future<void> _pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) openDialog,
) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => openDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Esc 关闭弹窗并返回取消（false）', (tester) async {
    Future<bool?>? resolved;
    await _pumpHost(tester, (context) {
      resolved = confirmExplicitWebLogout(context);
    });
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(await resolved, isFalse, reason: 'Esc 语义=取消，不得误触发确认');
  });

  testWidgets('初始焦点落「取消」动作（autofocus 包装节点）', (tester) async {
    await _pumpHost(tester, (context) {
      confirmExplicitWebLogout(context);
    });

    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    // autofocus 落在包裹「取消」的 Focus 节点（弹层打开即有焦点，后续
    // Tab 遍历与 Esc 拦截都沿该焦点链工作）：当前焦点 widget 是
    // autofocus Focus，且它位于「取消」文案的祖先链上。
    expect(focused!.context!.widget, isA<Focus>());
    expect((focused.context!.widget as Focus).autofocus, isTrue);
    expect(
      find.ancestor(
        of: find.text(t.common.buttonCancel),
        matching: find.byWidget(focused.context!.widget),
      ),
      findsOneWidget,
    );
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  });

  testWidgets('Tab 在弹层内循环，Shift+Tab 反向，不逃逸到背景路由', (tester) async {
    await _pumpHost(tester, (context) {
      confirmExplicitWebLogout(context);
    });
    // 焦点节点 = 包裹动作按钮的 Focus 包装；断言比对其元素。
    // ancestor finder 由近及远枚举：first = 紧包动作按钮的 Focus 包装。
    final cancelFocusEl = tester.element(
      find
          .ancestor(
            of: find.text(t.common.buttonCancel),
            matching: find.byWidgetPredicate((widget) => widget is Focus),
          )
          .first,
    );
    final confirmFocusEl = tester.element(
      find
          .ancestor(
            of: find.text(t.common.buttonConfirm),
            matching: find.byWidgetPredicate((widget) => widget is Focus),
          )
          .first,
    );

    // 初始焦点=取消
    expect(FocusManager.instance.primaryFocus!.context, cancelFocusEl);

    // 取消 → Tab → 确认
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus!.context, confirmFocusEl);

    // 确认 → Tab →（组尾折返）取消：不逃出弹层
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus!.context,
      cancelFocusEl,
      reason: '组尾应循环回取消，不得交还背景路由遍历',
    );

    // 取消 → Shift+Tab →（组首折返）确认
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus!.context,
      confirmFocusEl,
      reason: 'Shift+Tab 组首折返到确认',
    );

    expect(
      find.byType(CupertinoAlertDialog),
      findsOneWidget,
      reason: '纯焦点移动不得关闭弹窗',
    );
  });

  testWidgets('确认按钮按下返回 true 且弹窗关闭（激活路径不变）', (tester) async {
    Future<bool?>? resolved;
    await _pumpHost(tester, (context) {
      resolved = confirmExplicitWebLogout(context);
    });

    await tester.tap(find.text(t.common.buttonConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(await resolved, isTrue);
  });
}
