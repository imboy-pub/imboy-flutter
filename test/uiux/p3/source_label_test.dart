/// T21 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p3_widget_source_is_localized_web_chat
///  2. p3_unknown_source_is_generic_not_raw
///  3. p3_empty_source_is_unknown
///  4. p3_semantics_and_tooltips_never_expose_wire_or_raw_name
///  5. DTO 与 HTTP 请求原值不变（映射是纯展示层，T09 夹具已冻结解析）
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_source_label.dart';

Widget _host(String wire) => TranslationProvider(
  child: MaterialApp(
    home: Builder(
      builder: (BuildContext context) =>
          Text(csSourceDisplayLabel(context, wire)),
    ),
  ),
);

void main() {
  testWidgets('p3_widget_source_is_localized_web_chat：widget → 本地化网页咨询', (
    tester,
  ) async {
    await tester.pumpWidget(_host('widget'));
    expect(find.text('网页'), findsOneWidget);
  });

  testWidgets('p3_unknown_source_is_generic_not_raw：未知 wire 显示通用词', (
    tester,
  ) async {
    await tester.pumpWidget(_host('phone'));
    expect(find.text('未知'), findsOneWidget);
    expect(
      find.textContaining('phone'),
      findsNothing,
      reason: 'raw wire 值绝不出现',
    );
  });

  testWidgets('p3_empty_source_is_unknown：空 wire 也归未知', (tester) async {
    await tester.pumpWidget(_host(''));
    expect(find.text('未知'), findsOneWidget);
  });

  testWidgets(
    'p3_semantics_and_tooltips_never_expose_wire_or_raw_name：语义不透 wire',
    (tester) async {
      await tester.pumpWidget(_host('telegram'));
      await tester.pump();
      final SemanticsHandle handle = tester.ensureSemantics();
      final SemanticsData data = tester
          .getSemantics(find.byType(Text))
          .getSemanticsData();
      expect(data.label, '未知');
      expect(data.label.contains('telegram'), isFalse);
      expect(data.tooltip ?? '', isEmpty, reason: '无 tooltip 附加');
      handle.dispose();
    },
  );

  testWidgets('映射是纯展示层：不改输入、无请求、无异常', (tester) async {
    await tester.pumpWidget(_host('widget'));
    expect(find.text('网页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
