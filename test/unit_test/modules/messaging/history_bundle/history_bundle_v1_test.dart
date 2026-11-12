/// HistoryBundleV1 DTO 验收测试：JSON 形态冻结（与后端合同 §2 对齐）、
/// 可选字段省略语义、bundle_version 恒 1。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_v1.dart';

void main() {
  test('最小形态：bundle_version + entries（title/exported_at 缺省省略）', () {
    final bundle = HistoryBundleV1(
      entries: <HistoryBundleEntryV1>[
        HistoryBundleEntryV1(
          msgType: 'text',
          payload: <String, dynamic>{'text': 'hi'},
        ),
      ],
    );
    expect(bundle.toJson(), <String, dynamic>{
      'bundle_version': 1,
      'entries': <dynamic>[
        <String, dynamic>{
          'msg_type': 'text',
          'payload': <String, dynamic>{'text': 'hi'},
        },
      ],
    });
  });

  test('完整形态：title/exported_at/sender_name/sent_at 全字段', () {
    final bundle = HistoryBundleV1(
      title: '与张三的聊天记录',
      exportedAt: 1760000000000,
      entries: <HistoryBundleEntryV1>[
        HistoryBundleEntryV1(
          msgType: 'text',
          senderName: '张三',
          sentAt: 1760000001000,
          payload: <String, dynamic>{'text': '正文'},
        ),
      ],
    );
    expect(bundle.toJson(), <String, dynamic>{
      'bundle_version': 1,
      'title': '与张三的聊天记录',
      'exported_at': 1760000000000,
      'entries': <dynamic>[
        <String, dynamic>{
          'msg_type': 'text',
          'sender_name': '张三',
          'sent_at': 1760000001000,
          'payload': <String, dynamic>{'text': '正文'},
        },
      ],
    });
  });

  test('bundle_version 恒为 1（其他值/缺失后端拒绝）', () {
    final bundle = HistoryBundleV1(entries: <HistoryBundleEntryV1>[]);
    expect(bundle.bundleVersion, HistoryBundleContract.bundleVersion);
    expect(bundle.bundleVersion, 1);
  });

  test('空 senderName 条目序列化省略 sender_name 键', () {
    final entry = HistoryBundleEntryV1(
      msgType: 'text',
      senderName: null,
      payload: <String, dynamic>{'text': 'x'},
    );
    expect(entry.toJson().containsKey('sender_name'), isFalse);
  });

  test('entries 空列表允许构造（条数校验由 builder 负责）', () {
    final bundle = HistoryBundleV1(entries: <HistoryBundleEntryV1>[]);
    expect((bundle.toJson()['entries'] as List), isEmpty);
  });

  test('withEntryPayload 越界抛 ArgumentError（携带 index/length）', () {
    final bundle = HistoryBundleV1(
      entries: <HistoryBundleEntryV1>[
        HistoryBundleEntryV1(
          msgType: 'text',
          payload: <String, dynamic>{'text': 'x'},
        ),
      ],
    );
    // 越界正数下标
    Object? caught;
    try {
      bundle.withEntryPayload(3, <String, dynamic>{'uri': 'u'});
    } on ArgumentError catch (e) {
      caught = e;
    }
    expect(caught, isA<ArgumentError>());
    final message = caught.toString();
    expect(message, contains('index=3'));
    expect(message, contains('length=1'));
    // 负下标同样拒绝
    expect(
      () => bundle.withEntryPayload(-1, <String, dynamic>{'uri': 'u'}),
      throwsArgumentError,
    );
    // 原 bundle 不受影响
    expect(bundle.entries.single.payload['text'], 'x');
  });

  test('serializedByteLength 深度前置闸：超深 payload 不栈溢出、按超限失败', () {
    Object deep = <dynamic>[1];
    for (var i = 0; i < 5000; i++) {
      deep = <dynamic>[deep];
    }
    final bundle = HistoryBundleV1(
      entries: <HistoryBundleEntryV1>[
        HistoryBundleEntryV1(
          msgType: 'text',
          payload: <String, dynamic>{'deep': deep},
        ),
      ],
    );
    // 深度超限 → 保守返回超限字节值（走 payloadTooLarge 尺寸守护，
    // 稳定失败；jsonEncode 不跑，绝不栈溢出）
    expect(
      bundle.serializedByteLength,
      greaterThan(HistoryBundleContract.maxPayloadBytes),
    );

    // 边界内（16 层）正常序列化不受影响
    Object nest16 = <String, dynamic>{'text': 'leaf'};
    for (var i = 1; i < 16; i++) {
      nest16 = <String, dynamic>{'nested': nest16};
    }
    final ok = HistoryBundleV1(
      entries: <HistoryBundleEntryV1>[
        HistoryBundleEntryV1(
          msgType: 'text',
          payload: <String, dynamic>{'deep': nest16},
        ),
      ],
    );
    expect(
      ok.serializedByteLength,
      lessThan(HistoryBundleContract.maxPayloadBytes),
    );
  });
}
