import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 验证 run.dart 同款包装栈（MaterialApp + AppLoading(EasyLoading) +
/// 透明 Material）下，文本输入框长按/双击能正常弹出复制粘贴工具条。
/// 背景：真机 adb 截图被 EMUI 密码域安全显示挡成黑屏，无法目测确认，
/// 用语义树断言代替肉眼。
void main() {
  Widget buildApp(Widget field) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocaleUtils.supportedLocales,
      locale: const Locale('zh', 'CN'),
      // 与 lib/run.dart 完全一致的 builder 组合
      builder: (context, child) => AppLoading.init()(
        context,
        Material(type: MaterialType.transparency, child: child),
      ),
      home: Scaffold(body: Center(child: field)),
    );
  }

  testWidgets('material TextField 长按显示复制粘贴工具条', (tester) async {
    await tester.pumpWidget(buildApp(const TextField()));
    await tester.enterText(find.byType(TextField), 'hello_clipboard');
    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    // 选中词后工具条至少给出 全选/复制/剪切 之一（有剪贴板内容前不显示粘贴）
    final toolbarActions = find.byWidgetPredicate(
      (w) => w is Text && (w.data == '复制' || w.data == '剪切' || w.data == '全选'),
    );
    expect(toolbarActions, findsAtLeastNWidgets(1));
  });

  testWidgets('CupertinoTextField 长按显示复制粘贴工具条', (tester) async {
    await tester.pumpWidget(buildApp(const CupertinoTextField()));
    await tester.enterText(find.byType(CupertinoTextField), 'hello_clipboard');
    await tester.longPress(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();

    final toolbarActions = find.byWidgetPredicate(
      (w) => w is Text && (w.data == '复制' || w.data == '剪切' || w.data == '全选'),
    );
    expect(toolbarActions, findsAtLeastNWidgets(1));
  });
}
