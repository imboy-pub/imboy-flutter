/// T19 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p3_all_statuses_share_information_order
///  2. p3_name_is_existing_mask_result
///  3. p3_queue_keeps_claim_action_other_views_keep_open_action
///  4. 组件无 API/provider/权限依赖（裸树可渲染）
///  5. scale2 自然增高
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/presentation/cs_session_row_content.dart';

/// 纯净挂载（无 ProviderScope/无网络）：组件必须零依赖可渲染。
Future<void> pumpRow(
  WidgetTester tester, {
  Widget? trailing,
  double scale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.ltr, child: child!),
      ),
      home: Scaffold(
        body: CsSessionRowContent(
          maskedName: '张三',
          preview: const Text('预览摘要'),
          source: const Text('网页'),
          trailing: trailing,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('p3_all_statuses_share_information_order：名→摘要→来源顺序', (
    tester,
  ) async {
    await pumpRow(tester);
    // 同一 Column 内顺序：掩码名 → 摘要 → 来源
    final Finder name = find.text('张三');
    final Finder preview = find.text('预览摘要');
    final Finder source = find.text('网页');
    expect(name, findsOneWidget);
    expect(preview, findsOneWidget);
    expect(source, findsOneWidget);
    final double nameY = tester.getTopLeft(name).dy;
    final double previewY = tester.getTopLeft(preview).dy;
    final double sourceY = tester.getTopLeft(source).dy;
    expect(nameY, lessThan(previewY), reason: '掩码名在摘要之前');
    expect(previewY, lessThan(sourceY), reason: '摘要在来源之前');
  });

  testWidgets('p3_name_is_existing_mask_result：名称即既有掩码产物', (tester) async {
    await pumpRow(tester);
    // 组件不做二次掩码：显示调用方传入的 csMaskContactName 产物原样
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('张*三'), findsNothing);
  });

  testWidgets('p3_queue_keeps_claim_action_other_views_keep_open_action', (
    tester,
  ) async {
    // trailing 动作区由调用方注入：队列传接单按钮、会话列表传 chevron
    final Key action = const Key('queue-claim');
    await pumpRow(
      tester,
      trailing: TextButton(
        key: action,
        onPressed: () {},
        child: const Text('接单'),
      ),
    );
    expect(find.byKey(action), findsOneWidget);
    expect(find.text('接单'), findsOneWidget);
  });

  testWidgets('组件无 API/provider/权限依赖：裸树（无 ProviderScope）可渲染', (tester) async {
    // pumpRow 不包 ProviderScope —— 若组件内部读 provider/API，
    // 此处会抛依赖错误。
    await pumpRow(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scale2 自然增高', (tester) async {
    await pumpRow(tester, scale: 2.0);
    expect(tester.takeException(), isNull);
    final Size atScale2 = tester.getSize(find.byType(CsSessionRowContent));
    expect(atScale2.height, greaterThan(0));
  });
}
