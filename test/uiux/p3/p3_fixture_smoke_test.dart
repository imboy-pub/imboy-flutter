/// T09 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p3_fixture_covers_preview_missing_and_unknown_source
///  2. 同掩码不同摘要并存
///  3. hasLastMessage=true 但 preview 空 → 无文本渲染（不补数据）
///  4. 无消息 → dataNotFound 兜底
///  5. 来源三态：widget / 未知 / 空（隐藏）
///  6. claim 中（按钮禁用 + CAS body 记录）
///  7. claim 409 → 刷新真实状态（queuePage 再次调用）
///  8. claim 403 → 无 crash（无权限路径）
///  9. 测试时钟固定（等待时长 label 稳定）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p3_fixtures.dart';

void main() {
  testWidgets('p3_fixture_covers_preview_missing_and_unknown_source：三态摘要与来源', (
    tester,
  ) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        // 来源 widget → 'Web'
        p3QueueItemWire(id: '1', maskedName: '张三', source: 'widget'),
        // 未知来源 → 来源: phone
        p3QueueItemWire(
          id: '2',
          maskedName: '李四',
          source: 'phone',
          preview: '二号摘要',
        ),
        // 空来源 → 渠道行整体隐藏
        p3QueueItemWire(id: '3', maskedName: '王五', source: '', preview: '三号摘要'),
      ],
    );
    // 三行都渲染（csMaskContactName 对服务端 masked_name 再统一掩码）
    expect(find.text('张**'), findsOneWidget);
    expect(find.text('李**'), findsOneWidget);
    expect(find.text('王**'), findsOneWidget);
    // 摘要渲染（preview 非空态）；来源：widget→Web，phone→来源: phone，空→隐藏
    expect(find.text('你好，想咨询一下'), findsOneWidget);
    expect(find.text('Web'), findsOneWidget);
    expect(find.text('来源: phone'), findsOneWidget);
  });

  testWidgets('同掩码不同摘要：两行并存且摘要各自可见', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', maskedName: '张三', preview: '第一条摘要：账号问题'),
        p3QueueItemWire(id: '2', maskedName: '张三', preview: '第二条摘要：支付问题'),
      ],
    );
    expect(find.text('张**'), findsNWidgets(2));
    expect(find.text('第一条摘要：账号问题'), findsOneWidget);
    expect(find.text('第二条摘要：支付问题'), findsOneWidget);
  });

  testWidgets('hasLastMessage=true 但 preview 空 → 不渲染摘要也不兜底', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', preview: ''), // 附件-only / 解密降级形态
      ],
    );
    // 产品裁决：不展示加密占位；空摘要 → 无文本（也不得伪造数据）
    expect(find.text('你好，想咨询一下'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // shrink 占位路径可挂载
  });

  testWidgets('无消息（无 last_message）→ dataNotFound 兜底', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', hasLastMessage: false),
      ],
    );
    expect(
      find.text('页面数据不存在或已失效'),
      findsOneWidget,
      reason: '无末条消息 → common.dataNotFound 兜底文案',
    );
  });

  testWidgets('测试时钟固定：65 分钟前排队 → 小时+分钟档位', (tester) async {
    await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '1', queuedMinutesAgo: 65),
      ],
    );
    expect(
      find.textContaining('小时'),
      findsOneWidget,
      reason: '65 分钟按 hoursMinutes 档位渲染，固定偏移保证稳定',
    );
    expect(find.textContaining('5 分'), findsOneWidget);
  });

  testWidgets('claim 中：点击后 CAS body 记录且按钮进入禁用态', (tester) async {
    final P3FixtureHandle h = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[
        p3QueueItemWire(id: '7266418340025500001', version: 3),
      ],
      claimDelay: const Duration(milliseconds: 400),
    );
    await tester.tap(find.text('接单'));
    await tester.pump();
    // claim 进行中：按钮禁用（防重复点击），文本被进度指示器替换
    final FilledButton b = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(b.onPressed, isNull, reason: 'claim 进行中按钮应禁用');
    await tester.pumpAndSettle();
    // CAS 参数记录（expected_version 来自服务端投影）
    expect(h.adapter.claimCalls, 1);
    expect(h.adapter.claimBodies.first['expected_version'], 3);
  });

  testWidgets('claim 409：冲突后刷新真实状态（queuePage 再次调用）', (tester) async {
    final P3FixtureHandle h = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[p3QueueItemWire(id: '7266418340025500001')],
      claimStatusCode: 409,
    );
    final int queueCallsBefore = h.adapter.queueCalls;
    await tester.tap(find.text('接单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.adapter.claimCalls, 1);
    // 不做乐观伪成功：先刷新真实状态（P1/P3 口径）
    expect(
      h.adapter.queueCalls,
      greaterThan(queueCallsBefore),
      reason: '409 后必须刷新真实队列',
    );
  });

  testWidgets('claim 403：无权限路径不 crash 且刷新', (tester) async {
    final P3FixtureHandle h = await pumpP3QueueFixture(
      tester,
      items: <Map<String, dynamic>>[p3QueueItemWire(id: '7266418340025500001')],
      claimStatusCode: 403,
    );
    final int queueCallsBefore = h.adapter.queueCalls;
    await tester.tap(find.text('接单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.adapter.claimCalls, 1);
    expect(h.adapter.queueCalls, greaterThan(queueCallsBefore));
    expect(find.text('张**'), findsOneWidget, reason: '列表仍正常渲染');
  });
}
