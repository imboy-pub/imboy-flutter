/// A4FIX 复审 F3 —— chat_history_bundle wrapper 的出网/重发终检闸测试。
///
/// 缺口：`AttachmentSealPolicy.carriesContentKey` 只看 payload 顶层 +
/// images[]，而 bundle wrapper 顶层是合同字段（bundle_version/title/entries），
/// 重封装产生的新 descriptor 嵌在 entries[].payload 内。compose 期闸
/// （bundle_forward_dispatcher）放行后，若 MessageRetry 派发前部署策略翻成
/// 明文，出网终检（chat_network_service 明文分支）与重发守卫
/// （message_retry → shouldBlockPlaintextRetry）都看不见嵌套密钥 →
/// 带新 descriptor 的 bundle 明文出网。
///
/// 修复：`AttachmentSealPolicy.isSealedPayloadDeep` —— msgType 为
/// chat_history_bundle（或 payload 自带 entries 结构的脏行）时递归扫描
/// entries[].payload（含 images[] 与假想嵌套 bundle）；出网/重试终检
/// 一律换用该谓词（下方源码契约钉住，无旁路）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

Map<String, dynamic> _descriptor(String tag) => <String, dynamic>{
  'attachment_id': tag,
  'binding_hash': 'bh-$tag',
};

/// 合法形态的 bundle wrapper：顶层只有合同字段 + entries[]。
Map<String, dynamic> _wrapper(List<Map<String, dynamic>> entries) =>
    <String, dynamic>{
      'bundle_version': HistoryBundleContract.bundleVersion,
      'entries': [
        for (final e in entries)
          <String, dynamic>{
            'msg_type': 'file',
            'sent_at': 1760000000000,
            'payload': e,
          },
      ],
    };

void main() {
  group('isSealedPayloadDeep：bundle wrapper 的嵌套密钥终检（F3）', () {
    test('⚠️ 顶层干净但 entries[].payload 带顶层 descriptor → 拦（旧谓词漏判=缺口本体）', () {
      final wrapper = _wrapper(<Map<String, dynamic>>[
        <String, dynamic>{
          'uri': 'obj/new-key',
          'attachment_descriptor': _descriptor('e0'),
        },
      ]);
      expect(
        AttachmentSealPolicy.carriesContentKey(wrapper),
        isFalse,
        reason: '旧谓词对 bundle wrapper 漏判（正是 F3 缺口，钉住不回退）',
      );
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          wrapper,
          msgType: HistoryBundleContract.msgType,
        ),
        isTrue,
      );
    });

    test('⚠️ 密钥嵌在 entries[].payload.images[] → 拦（多图嵌套层）', () {
      final wrapper = _wrapper(<Map<String, dynamic>>[
        <String, dynamic>{
          'images': [
            <String, dynamic>{'uri': 'obj/plain'},
            <String, dynamic>{
              'uri': 'obj/new-1',
              'attachment_descriptor': _descriptor('img1'),
            },
          ],
        },
      ]);
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          wrapper,
          msgType: HistoryBundleContract.msgType,
        ),
        isTrue,
      );
    });

    test('entry payload 又是 bundle wrapper（假想嵌套合并）→ 拦（递归纵深）', () {
      final nested = _wrapper(<Map<String, dynamic>>[
        <String, dynamic>{
          'uri': 'obj/deep',
          'attachment_descriptor': _descriptor('deep'),
        },
      ]);
      final wrapper = <String, dynamic>{
        'bundle_version': 1,
        'entries': [
          <String, dynamic>{
            'msg_type': 'chat_history_bundle',
            'payload': nested,
          },
        ],
      };
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          wrapper,
          msgType: HistoryBundleContract.msgType,
        ),
        isTrue,
      );
    });

    test('干净 bundle（纯文本 entries）→ 放行（不误伤正常合并转发）', () {
      final wrapper = _wrapper(<Map<String, dynamic>>[
        <String, dynamic>{'text': 'hello'},
        <String, dynamic>{'uri': 'obj/plain', 'file_hash256': 'aa'},
      ]);
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          wrapper,
          msgType: HistoryBundleContract.msgType,
        ),
        isFalse,
      );
    });

    test('msgType 非 bundle 的单条 payload → 与 carriesContentKey 同口径', () {
      final single = <String, dynamic>{
        'uri': 'obj/x',
        'attachment_descriptor': _descriptor('s'),
      };
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(single, msgType: 'file'),
        isTrue,
      );
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(<String, dynamic>{
          'text': 'hi',
        }, msgType: 'text'),
        isFalse,
      );
      // msgType 缺失：维持顶层口径（不因缺 msgType 变宽误伤）
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(<String, dynamic>{
          'images': [
            <String, dynamic>{'attachment_descriptor': _descriptor('i')},
          ],
        }),
        isTrue,
        reason: '顶层/images 口径仍生效',
      );
    });

    test('msgType 缺失但结构带 entries → 结构触发递归（脏行 fail-closed）', () {
      final dirty = _wrapper(<Map<String, dynamic>>[
        <String, dynamic>{
          'uri': 'obj/new-key',
          'attachment_descriptor': _descriptor('dirty'),
        },
      ]);
      expect(AttachmentSealPolicy.isSealedPayloadDeep(dirty), isTrue);
      // 只有 entries 键、其中无密钥 → 放行
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          _wrapper([
            <String, dynamic>{'text': 'ok'},
          ]),
        ),
        isFalse,
      );
    });

    test('DB 读出的 Map<dynamic, dynamic> 同样认得（强转失败不静默放行）', () {
      final fromDb = <dynamic, dynamic>{
        'bundle_version': 1,
        'entries': <dynamic>[
          <dynamic, dynamic>{
            'msg_type': 'file',
            'payload': <dynamic, dynamic>{
              'uri': 'obj/new-key',
              'attachment_descriptor': <dynamic, dynamic>{'k': 'v'},
            },
          },
        ],
      };
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          fromDb,
          msgType: HistoryBundleContract.msgType,
        ),
        isTrue,
      );
    });

    test('null / 非 Map / 空 wrapper → false', () {
      expect(AttachmentSealPolicy.isSealedPayloadDeep(null), isFalse);
      expect(AttachmentSealPolicy.isSealedPayloadDeep('not-a-map'), isFalse);
      expect(
        AttachmentSealPolicy.isSealedPayloadDeep(
          <String, dynamic>{},
          msgType: HistoryBundleContract.msgType,
        ),
        isFalse,
      );
    });
  });

  group('出网/重试终检接线（源码契约：三处全换 deep 谓词，无旁路）', () {
    test('chat_network_service 明文分支不再直接用 carriesContentKey', () {
      final src = File('lib/page/chat/chat/services/chat_network_service.dart')
          .readAsStringSync();
      expect(
        src.contains('AttachmentSealPolicy.carriesContentKey('),
        isFalse,
        reason:
            '出网终检（prepareAttachmentOutboxMessage/sendWsMsg/sendMessage '
            '明文分支）必须全部走 bundle 感知的 isSealedPayloadDeep，'
            '否则 chat_history_bundle 的嵌套 descriptor 可在策略翻明文'
            '窗口内明文出网',
      );
      expect(
        RegExp(r'isSealedPayloadDeep\(').allMatches(src).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('message_retry 重发守卫换用 isSealedPayloadDeep', () {
      final src = File('lib/service/message_retry.dart').readAsStringSync();
      expect(
        src.contains('AttachmentSealPolicy.carriesContentKey('),
        isFalse,
        reason:
            '重发守卫（shouldBlockPlaintextRetry 的 carriesContentKey 入参）'
            '对 bundle 行必须做 entries 递归检测',
      );
      expect(src.contains('isSealedPayloadDeep('), isTrue);
    });
  });
}
