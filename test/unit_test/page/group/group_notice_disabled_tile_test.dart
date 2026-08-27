/// 钉住 `GroupNoticeDisabledTile` 的交互契约 —— slice-7 (C6 UI) RED-22。
///
/// 受控模式：父组件持有 `value` + `onChanged`，Widget 本身无状态。
///   1. value=true  → CupertinoSwitch 处于选中态
///   2. value=false → CupertinoSwitch 处于未选中态
///   3. tap CupertinoSwitch    → onChanged(!value)
///   4. tap ListTile  → onChanged(!value)（整行 44pt 触达）
///   5. onChanged=null → 整行禁用，tap 无反应
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_detail/group_notice_disabled_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('GroupNoticeDisabledTile — 渲染', () {
    testWidgets('value=true → CupertinoSwitch 选中', (tester) async {
      await tester.pumpWidget(
        wrap(
          GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(sw.value, isTrue);
    });

    testWidgets('value=false → CupertinoSwitch 未选中', (tester) async {
      await tester.pumpWidget(
        wrap(
          GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(sw.value, isFalse);
    });

    testWidgets('label 文案显示在 ListTile 中', (tester) async {
      await tester.pumpWidget(
        wrap(
          const GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: false,
            onChanged: null,
          ),
        ),
      );
      expect(find.text('消息免打扰'), findsOneWidget);
    });
  });

  group('GroupNoticeDisabledTile — 交互', () {
    testWidgets('tap CupertinoSwitch → onChanged 收到 !value', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        wrap(
          GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: false,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(calls, [true]);
    });

    testWidgets('tap ListTile 整行 → onChanged 收到 !value', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        wrap(
          GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: true,
            onChanged: calls.add,
          ),
        ),
      );
      // 避开 CupertinoSwitch 精确区域，点标题文字以验证整行可点
      await tester.tap(find.text('消息免打扰'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
    });

    testWidgets('onChanged=null → 整行 disabled（tap 不抛错且无状态变化）', (tester) async {
      await tester.pumpWidget(
        wrap(
          const GroupNoticeDisabledTile(
            label: '消息免打扰',
            value: true,
            onChanged: null,
          ),
        ),
      );
      // 点击不应抛异常
      await tester.tap(find.text('消息免打扰'));
      await tester.pumpAndSettle();
      // CupertinoListTile.onTap 应为 null（禁用态整行不可点）
      final tile = tester.widget<CupertinoListTile>(
        find.byType(CupertinoListTile),
      );
      expect(tile.onTap, isNull);
      // CupertinoSwitch.onChanged 应为 null（禁用态）
      final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(sw.onChanged, isNull);
    });
  });
}
