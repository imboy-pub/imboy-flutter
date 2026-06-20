import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/sticker_picker.dart';

/// StickerPicker 渲染契约测试（TypeA 纯 StatelessWidget）
void main() {
  Future<void> pump(
    WidgetTester tester,
    void Function(StickerItem) onSelected,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: StickerPicker(onStickerSelected: onSelected),
          ),
        ),
      ),
    );
  }

  testWidgets('渲染默认贴图网格（16 个 GridView 项不崩溃）', (tester) async {
    await pump(tester, (_) {});
    expect(find.byType(StickerPicker), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    // 内置贴图，表情字符可见
    expect(find.text('😊'), findsOneWidget);
    expect(find.text('👍'), findsOneWidget);
  });

  testWidgets('点击贴图 → 触发 onStickerSelected 回调', (tester) async {
    StickerItem? selected;
    await pump(tester, (s) => selected = s);
    await tester.tap(find.text('😊'));
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.text, '😊');
  });
}
