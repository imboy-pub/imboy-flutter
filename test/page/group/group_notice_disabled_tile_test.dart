/// 钉住 `GroupNoticeDisabledTile` 的交互契约 —— slice-7 (C6 UI) RED-22。
///
/// 受控模式：父组件持有 `value` + `onChanged`，Widget 本身无状态。
///   1. value=true  → Switch 处于选中态
///   2. value=false → Switch 处于未选中态
///   3. tap Switch    → onChanged(!value)
///   4. tap ListTile  → onChanged(!value)（整行 44pt 触达）
///   5. onChanged=null → 整行禁用，tap 无反应
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_detail/group_notice_disabled_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('GroupNoticeDisabledTile — 渲染', () {
    testWidgets('value=true → Switch 选中', (tester) async {
      await tester.pumpWidget(wrap(
        GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: true,
          onChanged: (_) {},
        ),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('value=false → Switch 未选中', (tester) async {
      await tester.pumpWidget(wrap(
        GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: false,
          onChanged: (_) {},
        ),
      ));
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('label 文案显示在 ListTile 中', (tester) async {
      await tester.pumpWidget(wrap(
        const GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: false,
          onChanged: null,
        ),
      ));
      expect(find.text('消息免打扰'), findsOneWidget);
    });
  });

  group('GroupNoticeDisabledTile — 交互', () {
    testWidgets('tap Switch → onChanged 收到 !value', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(wrap(
        GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: false,
          onChanged: calls.add,
        ),
      ));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, [true]);
    });

    testWidgets('tap ListTile 整行 → onChanged 收到 !value', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(wrap(
        GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: true,
          onChanged: calls.add,
        ),
      ));
      // 避开 Switch 精确区域，点标题文字以验证整行可点
      await tester.tap(find.text('消息免打扰'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
    });

    testWidgets('onChanged=null → 整行 disabled（tap 不抛错且无状态变化）', (tester) async {
      await tester.pumpWidget(wrap(
        const GroupNoticeDisabledTile(
          label: '消息免打扰',
          value: true,
          onChanged: null,
        ),
      ));
      // 点击不应抛异常
      await tester.tap(find.text('消息免打扰'));
      await tester.pumpAndSettle();
      // ListTile.enabled 应为 false
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      // Switch.onChanged 应为 null（禁用态）
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull);
    });
  });
}
