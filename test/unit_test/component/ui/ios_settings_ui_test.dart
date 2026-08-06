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

    testWidgets('字重也随之切换：true→w700 / false→w600', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IosPageTemplate(title: '设置')),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('设置')).style?.fontWeight,
        FontWeight.w600,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: IosPageTemplate(title: '设置', useLargeTitle: true),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('设置')).style?.fontWeight,
        FontWeight.w700,
      );
    });

    testWidgets('大标题不撑破导航栏（本项目 largeTitle=24pt，非 iOS 的 34pt 折叠大标题）', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IosPageTemplate(title: '设置', useLargeTitle: true),
        ),
      );
      await tester.pump();

      // 标题塞在 CupertinoNavigationBar.middle 里，超过 44pt 会被裁切。
      // 若日后把 largeTitle token 调大，这条会先报警。
      expect(
        tester.getRect(find.text('设置')).height,
        lessThanOrEqualTo(44),
        reason: '标题高度超过导航栏高度会被裁切',
      );
    });
  });

  // Task 5 第 2/3 条：user_collect_page 传的是 `useLargeTitle: !widget.isSelect`，
  // 不是字面量 true。语义是「多选态收紧标题给操作让位，浏览态才用大标题」，
  // 这里按调用方的两个实际分支钉死最终样式。
  group('调用方意图：user_collect 的 !isSelect', () {
    Future<double?> pumpForIsSelect(WidgetTester tester, bool isSelect) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IosPageTemplate(title: '我的收藏', useLargeTitle: !isSelect),
        ),
      );
      await tester.pump();
      return tester.widget<Text>(find.text('我的收藏')).style?.fontSize;
    }

    testWidgets('浏览态 isSelect=false → 大标题', (tester) async {
      final size = await pumpForIsSelect(tester, false);
      expect(
        tester.widget<Text>(find.text('我的收藏')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(size, isNotNull);
    });

    testWidgets('多选态 isSelect=true → 紧凑标题，且确实比浏览态小', (tester) async {
      final browsing = await pumpForIsSelect(tester, false);
      final selecting = await pumpForIsSelect(tester, true);

      expect(
        tester.widget<Text>(find.text('我的收藏')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        selecting!,
        lessThan(browsing!),
        reason: '多选态标题必须收紧，否则给操作按钮让位的设计意图落空',
      );
    });
  });

  group('ImBoySettingsSection 空 children 守卫', () {
    // CupertinoListSection.insetGrouped 断言 children 非空或 header 非空。
    // 钱包页在"加载中且流水为空"那一帧正好同时给出空 children + 无 header，
    // 整个流水区被 ErrorWidget 替换成红屏（批次 22 BUG#110）。
    testWidgets('空 children 且无 header → 收敛成空盒子，不抛断言', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ImBoySettingsSection(children: <Widget>[])),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('空 children 但有 header → 仍照常渲染 header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImBoySettingsSection(
              header: Text('流水记录'),
              children: <Widget>[],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('流水记录'), findsOneWidget);
    });
  });
}
