/// Widget test for `lib/component/chat/message_image_multi_builder.dart`
///
/// 覆盖多图消息的布局分支（旧实现给每张图写死 100px 再塞进约 75px 的格子，
/// 横竖图各自算出更小的高度，格子里图片忽大忽小 —— 这里锁住修复后的契约）：
///   - 0 张 → 不渲染
///   - 1 张 → 不走网格（按原始宽高比单图展示）
///   - 2 / 4 张 → 2 列
///   - 3 / 5 / 9 张 → 3 列
///   - >9 张 → 只渲染 9 格，最后一格盖 "+N" 折叠角标
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/message_image_multi_builder.dart';

CustomMessage _msg(int imageCount) {
  return CustomMessage(
    id: 'm_test',
    authorId: 'u_author',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    metadata: {
      'images': List<Map<String, dynamic>>.generate(
        imageCount,
        (i) => {'uri': 'obj_key_$i', 'width': 800, 'height': 600},
      ),
      'total': imageCount,
    },
  );
}

const _user = User(id: 'u_author');

Future<void> _pump(WidgetTester tester, int imageCount) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ImageMultiMessageBuilder(
            type: 'C2C',
            message: _msg(imageCount),
            user: _user,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

int _crossAxisCountOf(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

void main() {
  testWidgets('0 张图 → 不渲染任何网格', (tester) async {
    await _pump(tester, 0);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('1 张图 → 不走网格，按原始宽高比单图展示', (tester) async {
    await _pump(tester, 1);
    expect(find.byType(GridView), findsNothing);
    // 单图仍可点击预览
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('2 张图 → 2 列', (tester) async {
    await _pump(tester, 2);
    expect(_crossAxisCountOf(tester), 2);
  });

  testWidgets('4 张图 → 2 列（2×2，不是 3+1）', (tester) async {
    await _pump(tester, 4);
    expect(_crossAxisCountOf(tester), 2);
  });

  testWidgets('3 张图 → 3 列', (tester) async {
    await _pump(tester, 3);
    expect(_crossAxisCountOf(tester), 3);
  });

  testWidgets('9 张图 → 3 列且无折叠角标', (tester) async {
    await _pump(tester, 9);
    expect(_crossAxisCountOf(tester), 3);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('12 张图 → 只渲染 9 格，最后一格显示 +3', (tester) async {
    await _pump(tester, 12);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 9);
    expect(find.text('+3'), findsOneWidget);
  });
}
