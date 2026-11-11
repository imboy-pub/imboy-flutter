/// 每目标构建独立性验收测试：独立 bundle 实例、禁止共享可变引用、
/// copy-on-write 写回互不影响、DTO 不可变防护。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_v1.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

HistoryBundleSourceMessage _msg(
  String type,
  int sentAtMs, {
  Map<String, dynamic> payload = const <String, dynamic>{},
  String? senderName,
}) {
  return HistoryBundleSourceMessage(
    msgType: type,
    sourceMessageId: 'src_$sentAtMs',
    sourceChatType: 'C2C',
    sourceFromUid: '1001',
    sourceToUid: '2002',
    senderName: senderName,
    sentAtMs: sentAtMs,
    payload: payload,
    status: MessageStatus.sent,
  );
}

HistoryBundleBuildSuccessResult _ok(Object r) =>
    r as HistoryBundleBuildSuccessResult;

void main() {
  final messages = <HistoryBundleSourceMessage>[
    _msg(
      MessageType.text,
      1000,
      payload: <String, dynamic>{'text': 'hello'},
      senderName: '张三',
    ),
    _msg(
      MessageType.location,
      2000,
      payload: <String, dynamic>{'title': 'T', 'latitude': '1.0'},
    ),
  ];

  test('两个目标各自构建：bundle 实例与全层 payload 均不共享引用', () {
    final a = _ok(HistoryBundleBuilder.buildForTarget('C2C_1_2', messages))
        .success;
    final b = _ok(HistoryBundleBuilder.buildForTarget('C2G_77', messages))
        .success;

    expect(identical(a.bundle, b.bundle), isFalse);
    expect(identical(a.bundle.entries, b.bundle.entries), isFalse);
    for (var i = 0; i < a.bundle.entries.length; i++) {
      expect(
        identical(a.bundle.entries[i].payload, b.bundle.entries[i].payload),
        isFalse,
        reason: 'entry[$i] payload 不得共享引用',
      );
    }
    // 内容等价（同源消息）
    expect(a.bundle.toJson(), equals(b.bundle.toJson()));
  });

  test('构建后修改源 payload 不影响已构建 bundle（深拷贝）', () {
    final sourcePayload = <String, dynamic>{
      'text': 'original',
      'nested': <String, dynamic>{'k': 'v'},
    };
    final msg = _msg(MessageType.text, 1000, payload: sourcePayload);
    final success = _ok(HistoryBundleBuilder.buildForTarget('C2C_1_2', [msg]))
        .success;

    sourcePayload['text'] = 'mutated';
    sourcePayload['nested'] = <String, dynamic>{'k': 'changed'};

    final payload = success.bundle.entries.single.payload;
    expect(payload['text'], 'original');
    expect((payload['nested'] as Map)['k'], 'v');
  });

  test('copy-on-write：withEntryPayload 只影响新 bundle', () {
    final a = _ok(HistoryBundleBuilder.buildForTarget('C2C_1_2', messages))
        .success;
    final b = _ok(HistoryBundleBuilder.buildForTarget('C2G_77', messages))
        .success;

    final rewritten = a.bundle.withEntryPayload(0, <String, dynamic>{
      'uri': 's3://new-object',
      'file_hash256': 'new-hash',
    });
    expect(rewritten.entries[0].payload['uri'], 's3://new-object');
    // 原 bundle 与另一目标 bundle 不受影响
    expect(a.bundle.entries[0].payload.containsKey('uri'), isFalse);
    expect(b.bundle.entries[0].payload.containsKey('uri'), isFalse);
    expect(identical(rewritten, a.bundle), isFalse);
  });

  test('DTO 不可变防护：entries 列表与顶层 payload map 拒绝修改', () {
    final success = _ok(
      HistoryBundleBuilder.buildForTarget('C2C_1_2', messages),
    ).success;
    expect(
      () => success.bundle.entries.add(
        HistoryBundleEntryV1(msgType: 'text', payload: <String, dynamic>{}),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => success.bundle.entries[0].payload['x'] = 1,
      throwsUnsupportedError,
    );
  });

  test('同目标重复构建同样产出独立实例（幂等内容、全新引用）', () {
    final a = _ok(HistoryBundleBuilder.buildForTarget('C2C_1_2', messages))
        .success;
    final b = _ok(HistoryBundleBuilder.buildForTarget('C2C_1_2', messages))
        .success;
    expect(a.bundle.toJson(), equals(b.bundle.toJson()));
    expect(
      identical(a.bundle.entries[0].payload, b.bundle.entries[0].payload),
      isFalse,
    );
  });

  test('附件任务列表不可变', () {
    final r = HistoryBundleBuilder.buildForTarget('C2C_1_2', [
      _msg(
        MessageType.image,
        1000,
        payload: <String, dynamic>{'name': 'x.png', 'uri': 's3://x'},
      ),
    ]);
    final success = _ok(r).success;
    expect(() => success.attachmentTasks.clear(), throwsUnsupportedError);
  });
}
