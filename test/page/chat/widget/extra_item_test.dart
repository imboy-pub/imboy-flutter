import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/extra_item.dart';

/// ExtraItem 渲染 + 点击契约测试（TypeA 纯 StatelessWidget）
///
/// 仅覆盖 ExtraItem（无 i18n/平台依赖）。ExtraItems 依赖
/// location/webrtc/Riverpod，属重依赖，不在此测。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String title,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExtraItem(
            title: title,
            image: const Icon(Icons.image),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  testWidgets('渲染标题与图标不崩溃', (tester) async {
    await pump(tester, title: '相册', onPressed: () {});
    expect(find.text('相册'), findsOneWidget);
    expect(find.byIcon(Icons.image), findsOneWidget);
  });

  testWidgets('点击 → 触发 onPressed 回调', (tester) async {
    var tapped = false;
    await pump(tester, title: '拍摄', onPressed: () => tapped = true);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
