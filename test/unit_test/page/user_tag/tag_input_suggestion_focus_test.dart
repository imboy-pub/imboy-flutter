import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';

/// 建议标签可见性回归测试（批次28 真机死循环）。
///
/// 旧实现把建议区显示绑死在 `_focusNode.hasFocus`：输入框在页面底部，
/// 聚焦时键盘盖住下方建议区，滚动查看又失焦收起 —— 建议标签用户根本点不到。
/// 修复后建议区常驻、与焦点无关。任一用例回退到旧逻辑都会变红。
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('TagInput 建议标签可见性', () {
    testWidgets('未聚焦时建议标签可见，可直接点击加入', (tester) async {
      List<String>? changed;
      await _pump(
        tester,
        TagInput(
          initialTags: const ['同事'],
          suggestedTags: const ['qa-tag'],
          onTagsChanged: (tags) => changed = tags,
        ),
      );

      // 不聚焦输入框，建议标签也应可见
      final suggestion = find.text('qa-tag');
      expect(suggestion, findsOneWidget);

      // 直接点击建议标签快速加入当前标签
      await tester.tap(suggestion);
      // 等 _controller.clear() 触发的防抖定时器结束，避免测试结束时有挂起定时器
      await tester.pump(const Duration(milliseconds: 350));

      expect(changed, isNotNull);
      expect(changed, contains('qa-tag'));
    });

    testWidgets('失焦不收起建议区（焦点死循环回归）', (tester) async {
      await _pump(
        tester,
        TagInput(
          initialTags: const ['同事'],
          suggestedTags: const ['qa-tag'],
          onTagsChanged: (_) {},
        ),
      );

      // 聚焦输入框，建议区展开
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text('qa-tag'), findsOneWidget);

      // 模拟「滚动查看建议区时输入框失焦」—— 建议区不得随之收起
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('qa-tag'), findsOneWidget);
    });
  });
}
