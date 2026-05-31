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

  testWidgets('渲染默认贴图网格（6 个 GridView 项不崩溃）', (tester) async {
    await pump(tester, (_) {});
    expect(find.byType(StickerPicker), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    // 内置 6 个贴图，文本标签可见
    expect(find.text('[微笑]'), findsOneWidget);
    expect(find.text('[点赞]'), findsOneWidget);
  });

  testWidgets('点击贴图 → 触发 onStickerSelected 回调', (tester) async {
    StickerItem? selected;
    await pump(tester, (s) => selected = s);
    await tester.tap(find.text('[微笑]'));
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.text, '[微笑]');
  });
}
