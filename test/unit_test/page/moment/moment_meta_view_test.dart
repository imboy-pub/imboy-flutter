/// 朋友圈"所在位置 + @提醒"展示层（方案 E2）测试。
///
/// 覆盖：
///   - `momentAtNames`：优先 at_names（enrich 阶段解析的昵称），回退裸 at_uids
///   - `MomentLocationLabel`：有 location.name 才渲染地名，无则不显示
///   - `MomentAtSummary`：1 人「提醒了 X」/ 多人「提醒了 X 等N人」/ 无则不显示
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_meta_view.dart';
import 'package:imboy/page/moment/moment_utils.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('momentAtNames', () {
    test('优先取 enrich 写入的 at_names', () {
      final out = momentAtNames(<String, dynamic>{
        'at_names': ['张三', '李四'],
        'at_uids': [2002, 2003],
      });
      expect(out, ['张三', '李四']);
    });

    test('缺 at_names 时回退裸 at_uids（转 String）', () {
      final out = momentAtNames(<String, dynamic>{
        'at_uids': [2002, 2003],
      });
      expect(out, ['2002', '2003']);
    });

    test('at_names 为空列表 → 回退 at_uids', () {
      final out = momentAtNames(<String, dynamic>{
        'at_names': <String>[],
        'at_uids': [9],
      });
      expect(out, ['9']);
    });

    test('两者皆无 → 空列表', () {
      expect(momentAtNames(<String, dynamic>{}), isEmpty);
    });
  });

  group('MomentLocationLabel', () {
    testWidgets('有 location.name → 渲染地名', (tester) async {
      await _pump(
        tester,
        const MomentLocationLabel(
          rawLocation: {'name': '星巴克', 'lng': 121.4, 'lat': 31.2},
        ),
      );
      expect(find.text('星巴克'), findsOneWidget);
    });

    testWidgets('location 为 null → 不渲染任何文本', (tester) async {
      await _pump(tester, const MomentLocationLabel(rawLocation: null));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('脏数据（无 name）→ 不渲染', (tester) async {
      await _pump(tester, const MomentLocationLabel(rawLocation: {'lng': 1.0}));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('MomentAtSummary', () {
    testWidgets('单人 → 提醒了 张三', (tester) async {
      await _pump(
        tester,
        const MomentAtSummary(
          item: {
            'at_names': ['张三'],
          },
        ),
      );
      expect(find.text('提醒了 张三'), findsOneWidget);
    });

    testWidgets('多人 → 提醒了 X 等N人', (tester) async {
      await _pump(
        tester,
        const MomentAtSummary(
          item: {
            'at_names': ['张三', '李四', '王五'],
          },
        ),
      );
      expect(find.text('提醒了 张三 等3人'), findsOneWidget);
    });

    testWidgets('无 @提醒 → 不渲染任何文本', (tester) async {
      await _pump(tester, const MomentAtSummary(item: {}));
      expect(find.byType(Text), findsNothing);
    });
  });
}
