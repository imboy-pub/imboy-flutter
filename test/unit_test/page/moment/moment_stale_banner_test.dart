import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_feed_page.dart';

/// MomentStaleBanner widget 行为测试。
///
/// 约束：
/// - isStale=false 时完全不渲染（返回 SizedBox.shrink 或等价物），
///   避免占位符影响 ListView 的首项滚动偏移。
/// - isStale=true 时渲染提示文案 + 重试按钮，点击按钮回调 onRetry。
/// - i18n 文案来自 momentsFeedStale / buttonRetry。
void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required bool isStale,
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: MomentStaleBanner(
              isStale: isStale,
              onRetry: onRetry ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides banner when isStale is false', (tester) async {
    await pumpBanner(tester, isStale: false);
    expect(find.textContaining('cached'), findsNothing);
    expect(find.textContaining('缓存'), findsNothing);
  });

  testWidgets('shows banner text + retry action when stale', (tester) async {
    await pumpBanner(tester, isStale: true);
    // 文案来自 momentsFeedStale；当前默认 locale 为 zh-CN。
    final textFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data?.contains('缓存') == true ||
              w.data?.contains('cached') == true),
    );
    expect(textFinder, findsOneWidget);
    // 重试按钮：使用 buttonRetry 文案。
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('tapping retry fires onRetry callback', (tester) async {
    var tapped = 0;
    await pumpBanner(tester, isStale: true, onRetry: () => tapped++);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
