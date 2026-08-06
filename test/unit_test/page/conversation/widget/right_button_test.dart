import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/widget/right_button.dart';

/// RightButton 纯 StatelessWidget 渲染契约测试（TypeA）。
///
/// RightButton 仅在 onPressed 回调里使用 go_router context.push，
/// 渲染本身不触发导航，故无需注入路由即可安全渲染。
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(appBar: AppBar(actions: [child])),
  );

  group('RightButton — 渲染', () {
    testWidgets('渲染两个 IconButton：搜索 + 添加', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      expect(find.byType(RightButton), findsOneWidget);
      expect(find.byType(IconButton), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.plus_circle), findsOneWidget);
    });

    testWidgets('深色主题下渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            appBar: null,
            body: Center(child: RightButton()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(IconButton), findsNWidgets(2));
    });
  });

  group('导航栏图标风格', () {
    testWidgets('用 CupertinoIcons，不混 Material 图标', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      // Material 图标笔画明显更重，摆在导航栏上又粗又脏；DESIGN.md 7.1
      // 规定 iOS 侧用 SF Symbols（CupertinoIcons）。
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(
          icon.icon?.fontFamily,
          'CupertinoIcons',
          reason: '${icon.icon} 不是 CupertinoIcons，和其他导航栏按钮不是一套',
        );
      }
    });

    testWidgets('尺寸与其他页导航栏按钮一致（22pt）', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.size, 22, reason: 'IconButton 默认 24，比其他页大一圈');
      }
    });
  });
}
