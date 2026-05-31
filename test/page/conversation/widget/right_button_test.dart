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
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
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
}
