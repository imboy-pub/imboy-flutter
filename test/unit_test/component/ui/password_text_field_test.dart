import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/password.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

Widget _wrap(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return TranslationProvider(
    child: MaterialApp(
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: mode,
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );
}

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  testWidgets('实际亮暗主题切换后默认正文、提示与图标保持可读', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(
        _wrap(
          PasswordTextField(
            obscureText: true,
            hintText: t.account.pleaseEnterPassword,
            onTap: () {},
          ),
          mode: mode,
        ),
      );
      await tester.pumpAndSettle();
      final isDark = mode == ThemeMode.dark;
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final background = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .fillColor!;
      final hint = tester.renderObject<RenderParagraph>(
        find.text(t.account.pleaseEnterPassword),
      );
      final eye = tester.widget<Icon>(find.byIcon(CupertinoIcons.eye));
      expect(
        background,
        isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainer,
      );
      expect(
        editable.style.color,
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );
      final textColors = [editable.style.color!, hint.text.style!.color!];
      for (final foreground in textColors) {
        expect(foreground.a, 1);
        expect(background.a, 1);
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(eye.color!, background), greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('显式输入、提示、图标和光标样式仍优先于主题默认值', (tester) async {
    const inputStyle = TextStyle(color: Colors.amber, fontSize: 19);
    const hintStyle = TextStyle(color: Colors.lightBlueAccent, fontSize: 15);
    await tester.pumpWidget(
      _wrap(
        const PasswordTextField(
          obscureText: true,
          hintText: '自定义提示',
          style: inputStyle,
          hintStyle: hintStyle,
          iconColor: Colors.lightGreenAccent,
          cursorColor: Colors.orangeAccent,
        ),
        mode: ThemeMode.dark,
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.color, inputStyle.color);
    expect(editable.style.fontSize, inputStyle.fontSize);
    expect(editable.cursorColor, Colors.orangeAccent);
    final hint = tester.renderObject<RenderParagraph>(find.text('自定义提示'));
    expect(hint.text.style!.color, hintStyle.color);
    expect(hint.text.style!.fontSize, hintStyle.fontSize);
    for (final icon in [CupertinoIcons.lock, CupertinoIcons.eye]) {
      expect(
        tester.widget<Icon>(find.byIcon(icon)).color,
        Colors.lightGreenAccent,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab 与 Enter 操作具名显隐按钮，保留密码和原输入回调', (tester) async {
    final semantics = tester.ensureSemantics();
    final changes = <String>[];
    var obscure = true;
    var toggleCalls = 0;
    var nextCalls = 0;
    try {
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PasswordTextField(
                  obscureText: obscure,
                  onChanged: changes.add,
                  onTap: () {
                    setState(() => obscure = !obscure);
                    toggleCalls++;
                  },
                ),
                TextButton(
                  onPressed: () => nextCalls++,
                  child: const Text('下一项'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'example-secret');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final label in [t.common.showPassword, t.common.hidePassword]) {
        final toggle = find.bySemanticsLabel(label);
        expect(toggle, findsOneWidget);
        final node = tester.getSemantics(toggle);
        expect(node.label, label);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isFocused.toBoolOrNull(), isTrue);
        final target = tester.getRect(toggle);
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.obscureText, label == t.common.hidePassword);
        expect(editable.controller.text, 'example-secret');
        expect(changes, ['example-secret']);
      }
      expect(toggleCalls, 2);
      expect(nextCalls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.text('下一项'))
            .flagsCollection
            .isFocused
            .toBoolOrNull(),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(nextCalls, 1);
      expect(toggleCalls, 2);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
