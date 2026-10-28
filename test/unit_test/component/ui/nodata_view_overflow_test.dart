import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/nodata_view.dart';

/// 真机实测：群内搜索的错误空态在键盘弹起时
/// `A RenderFlex overflowed by 91 pixels on the bottom.`
/// 空态整体约 200pt 高，键盘占掉屏幕后剩不到这个数，固定 Center 必溢出。
void main() {
  testWidgets('视口比空态内容矮时可滚动，不溢出', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            // 键盘弹起后典型剩余高度
            height: 120,
            child: NoDataView(
              text: '搜索错误',
              icon: Icons.error_outline,
              onTop: () => calls++,
            ),
          ),
        ),
      ),
    );

    // 溢出会让 pump 抛出 FlutterError；能走到这里即未溢出。
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final retry = find.byType(RoundedCupertinoButton);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(calls, 1);
    expect(tester.getSize(retry).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('错误正文可通知读屏，重试支持键盘且每次只调用一次', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.enter):
              const ButtonActivateIntent(),
        },
        home: Scaffold(
          body: NoDataView(
            text: '搜索失败',
            icon: Icons.error_outline,
            retryLabel: '重新加载',
            onTop: () => calls++,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('搜索失败')).flagsCollection.isLiveRegion,
      isTrue,
    );
    expect(find.bySemanticsLabel('重新加载'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('重新加载'))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, 2);
    await tester.tap(find.text('重新加载'));
    expect(calls, 3);
    await tester.tap(find.byIcon(Icons.error_outline));
    expect(calls, 4);
  });

  testWidgets('视口足够高时内容仍然居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: NoDataView(text: '暂无数据', icon: Icons.inbox),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.text('暂无数据'));
    expect(find.byType(RoundedCupertinoButton), findsNothing);
    // 垂直居中：文本中心应落在 800 高视口的中段
    expect(box.center.dy, greaterThan(300));
    expect(box.center.dy, lessThan(500));
  });
}
