import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';

/// TagInput 纯 StatefulWidget 渲染 + 回调测试。
///
/// 无单例 / SQLite 依赖；initState 仅初始化 controller/focus。
/// build 用 t.contact.*，需包 TranslationProvider。
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('TagInput', () {
    testWidgets('TI-1 渲染初始标签芯片', (tester) async {
      await _pump(
        tester,
        TagInput(
          initialTags: const ['同学', '同事'],
          suggestedTags: const ['家人'],
          onTagsChanged: (_) {},
        ),
      );

      expect(find.text('同学'), findsOneWidget);
      expect(find.text('同事'), findsOneWidget);
      // 输入框存在
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('TI-2 点击标签删除图标触发 onTagsChanged 回调', (tester) async {
      List<String>? changed;
      await _pump(
        tester,
        TagInput(
          initialTags: const ['vip'],
          suggestedTags: const [],
          onTagsChanged: (tags) => changed = tags,
        ),
      );

      expect(find.text('vip'), findsOneWidget);
      // 选中标签芯片自带关闭图标，点击触发移除回调
      final closeIcon = find.byIcon(Icons.close);
      expect(closeIcon, findsWidgets);
      await tester.tap(closeIcon.first);
      await tester.pump();

      expect(changed, isNotNull);
      expect(changed, isNot(contains('vip')));
    });
  });
}
