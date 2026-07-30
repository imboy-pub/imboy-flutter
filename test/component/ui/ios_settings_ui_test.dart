// IosPageTemplate useLargeTitle 契约测试
//
// 验证 useLargeTitle 参数真实生效（不再是无副作用死参数）：
//   - true 时标题字号 > false 时
//   - 两种模式均渲染标题文本
//   - user_collect_page.dart 的 `useLargeTitle: !widget.isSelect` 因此覆盖 true/false 两分支
//
// 运行 / How to run:
//   flutter test test/component/ui/ios_settings_ui_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';

double? _titleFontSize(WidgetTester tester, String title) {
  final widgets = tester.widgetList<Text>(find.text(title));
  if (widgets.isEmpty) return null;
  return widgets.first.style?.fontSize;
}

void main() {
  group('IosPageTemplate useLargeTitle', () {
    testWidgets('useLargeTitle=true 标题字号大于 false（参数真实生效）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IosPageTemplate(title: '设置')),
      );
      await tester.pump();
      final small = _titleFontSize(tester, '设置');

      await tester.pumpWidget(
        const MaterialApp(
          home: IosPageTemplate(title: '设置', useLargeTitle: true),
        ),
      );
      await tester.pump();
      final large = _titleFontSize(tester, '设置');

      expect(small, isNotNull);
      expect(large, isNotNull);
      expect(large! > small!, isTrue);
    });

    testWidgets('两种模式均渲染标题文本', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IosPageTemplate(title: '我的页面')),
      );
      await tester.pump();
      expect(find.text('我的页面'), findsWidgets);

      await tester.pumpWidget(
        const MaterialApp(
          home: IosPageTemplate(title: '我的页面', useLargeTitle: true),
        ),
      );
      await tester.pump();
      expect(find.text('我的页面'), findsWidgets);
    });

    testWidgets('默认 useLargeTitle=false（紧凑模式）', (tester) async {
      final w = IosPageTemplate(title: 'x');
      expect(w.useLargeTitle, isFalse);
    });
  });
}
