/// T20 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p3_same_safe_preview_in_all_statuses
///  2. p3_has_message_without_preview_renders_no_placeholder
///  3. p3_no_message_keeps_documented_fallback
///  4. p3_preview_never_fetches_message_body
///  5. scale2 最多 2 行
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p3_fixtures.dart';

void main() {
  testWidgets('p3_same_safe_preview_in_all_statuses：同一摘要函数驱动所有状态', (
    tester,
  ) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', maskedName: '张三', preview: '你好'),
        p3QueueItemWire(id: '2', maskedName: '李四', preview: '在吗'),
      ],
    );
    // 两行摘要均渲染（同一 csQueuePreviewText 产物，队列/会话列表共用）
    expect(find.text('你好'), findsOneWidget);
    expect(find.text('在吗'), findsOneWidget);
  });

  testWidgets('p3_has_message_without_preview_renders_no_placeholder', (
    tester,
  ) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', preview: ''), // hasLastMessage=true 无摘要
      ],
    );
    expect(
      find.textContaining('加密'),
      findsNothing,
      reason: '不渲染加密占位（2026-10-02 产品裁决）',
    );
    expect(find.textContaining('摘要'), findsNothing);
  });

  testWidgets('p3_no_message_keeps_documented_fallback：无消息走既有兜底', (
    tester,
  ) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', hasLastMessage: false),
      ],
    );
    expect(find.text('页面数据不存在或已失效'), findsOneWidget);
  });

  testWidgets('p3_preview_never_fetches_message_body：渲染不发消息体请求', (
    tester,
  ) async {
    final handle = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[p3QueueItemWire(id: '1')],
    );
    final int messageFetches = handle.adapter.paths
        .where((String p) => p.contains('/messages') || p.contains('message'))
        .length;
    expect(messageFetches, 0, reason: '摘要渲染不得触发消息正文拉取');
  });

  testWidgets('scale2 最多 2 行：摘要行数上限', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', preview: '超长摘要' * 40),
      ],
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final Text preview = tester.widget<Text>(find.textContaining('超长摘要'));
    expect(preview.maxLines, lessThanOrEqualTo(2));
  });
}
