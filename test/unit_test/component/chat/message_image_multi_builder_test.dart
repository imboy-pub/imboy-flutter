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

  // ── 原始 bug 的直接回归断言 ──
  // 旧实现给每张图写死 width/height 100，而 3 列网格在窄屏下每格只有约 75px，
  // 且横竖图的高度公式（ar>1 ? 100/ar : 100*ar）两个分支都算出比格子更小的值。
  // 结果是格子里图片尺寸忽大忽小、边缘留白或被裁。修复后尺寸完全由网格决定，
  // 下面直接断言"每个瓦片的实际渲染尺寸 == 网格格子尺寸"。
  testWidgets('窄屏 3 列：每个瓦片铺满格子，不再是写死的 100px', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340); // 典型窄屏手机
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, 9);

    final gridSize = tester.getSize(find.byType(GridView));
    const spacing = 4.0;
    final expectedCell = (gridSize.width - spacing * 2) / 3;

    // 格子应显著小于旧实现写死的 100px —— 否则这个用例证明不了什么
    expect(
      expectedCell,
      lessThan(100.0),
      reason: '窄屏下格子必须比旧的写死 100px 更小，才复现得了原 bug',
    );

    final tiles = find.byType(ClipRRect);
    expect(tiles, findsNWidgets(9));
    for (var i = 0; i < 9; i++) {
      final size = tester.getSize(tiles.at(i));
      expect(
        size.width,
        moreOrLessEquals(expectedCell, epsilon: 0.5),
        reason: '第 $i 个瓦片宽度应等于格子宽度',
      );
      expect(
        size.height,
        moreOrLessEquals(expectedCell, epsilon: 0.5),
        reason: '第 $i 个瓦片高度应等于格子高度（正方形裁切）',
      );
    }
  });

  testWidgets('单图不做正方形裁切：按原始宽高比展示', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pump(tester, 1); // 素材是 800x600，宽高比 4:3
    final size = tester.getSize(find.byType(ClipRRect).first);
    expect(
      size.width / size.height,
      moreOrLessEquals(800 / 600, epsilon: 0.05),
      reason: '单图被压成正方形就丢信息了',
    );
  });
}
