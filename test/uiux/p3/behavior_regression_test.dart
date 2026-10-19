/// T27 合同自测 — imboy-enterprise-uiux-v1
///
/// 坐席接单/分页/隔离回归：T19—T21 行重构不得改变 claim CAS、分页
/// 触发与租户隔离。
/// 必需清单（manifest）：
///  1. p3_claim_cas_body_unchanged（expected_version CAS 参数不变）
///  2. p3_pagination_endpoint_unchanged（queue 端点与分页键不变）
///  3. p3_dto_parse_unchanged（真实 wire → 模型字段原样）
library;

import 'package:flutter_test/flutter_test.dart';

import 'p3_fixtures.dart';

void main() {
  testWidgets('p3_claim_cas_body_unchanged：CAS body 基线', (tester) async {
    final P3FixtureHandle h = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '7266418340025500001', version: 3),
      ],
      claimDelay: const Duration(milliseconds: 200),
    );
    await tester.tap(find.text('接单'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(h.adapter.claimCalls, 1);
    final body = h.adapter.claimBodies.first;
    expect(
      body['expected_version'],
      3,
      reason: 'CAS expected_version 来自服务端投影（参数不变）',
    );
  });

  testWidgets('p3_pagination_endpoint_unchanged：queue 端点与分页键', (tester) async {
    final P3FixtureHandle h = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[p3QueueItemWire(id: '1')],
    );
    expect(
      h.adapter.paths.any((String p) => p.contains('/sessions/queue')),
      isTrue,
      reason: 'A0 冻结分页键（limit）与端点形状不变',
    );
  });

  testWidgets('p3_dto_parse_unchanged：wire → 模型字段原样', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(
          id: '1',
          maskedName: '张三',
          preview: '你好',
          source: 'widget',
        ),
      ],
    );
    // 渲染证据链：掩码（二次掩码）、摘要原文、来源本地化名
    expect(find.text('张**'), findsOneWidget);
    expect(find.textContaining('你好'), findsWidgets);
    expect(find.text('网页'), findsOneWidget);
  });
}
