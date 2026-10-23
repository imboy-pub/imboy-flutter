/// 多图（imageMulti）E2EE 闸门与接收侧契约测试
///
/// 1. [AttachmentSealPolicy.carriesContentKey]：`images[i]` 嵌套 descriptor 必须
///    被识别为"带 content key"——出网 / 重发 / 出站箱 / 转发四处闸门共用此谓词，
///    漏判嵌套钥匙与漏判顶层钥匙是同级别失效；
/// 2. [AttachmentOpener.descriptorsFrom] / [AttachmentOpener.descriptorFrom]：
///    全量取 vs 仅顶层；嵌套非法 descriptor fail-closed 抛异常，不静默跳过；
/// 3. [AttachmentOpenRegistry.registerFromMessage]：N 张图逐个登记，各自可开封；
///    任一坏项 → 整条不登记（无半登记）。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

const String kSender = '52278';
const String kReceiver = '53314';
const String kMsg = 'msg-multi-1';

Uint8List _plain(int n, int seed) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 41 + seed) & 0xFF));

Uint8List _binding({String messageId = kMsg}) => AttachmentBinding.compute(
  messageId: messageId,
  conversationId: 'c2c:$kSender:$kReceiver',
  senderUid: kSender,
);

/// 发送侧视角封装第 [index] 张图：attachmentId 逐图区分（image_i）。
({Map<String, dynamic> item, Uint8List cipher, Uint8List plain}) _sealImage(
  int index,
) {
  final pt = _plain(90 + index, index);
  final s = AttachmentEncryptor.seal(
    plaintext: pt,
    bindingHash: _binding(),
    attachmentId: 'image_$index',
    objectKey: 'u$kSender/2026/10/img_$index.bin',
    mime: 'image/jpeg',
    name: 'img_$index.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 32,
  );
  return (
    item: <String, dynamic>{
      'uri': s.descriptor.objectKey,
      'width': 640,
      'height': 480,
      AttachmentSealPolicy.descriptorPayloadKey: s.descriptor.toMap(),
    },
    cipher: s.ciphertext,
    plain: pt,
  );
}

Map<String, dynamic> _multiPayload(List<Map<String, dynamic>> items) => {
  'peer_id': kReceiver,
  AttachmentSealPolicy.imagesPayloadKey: items,
  'total': items.length,
};

bool _register(Map<String, dynamic> payload, {String messageId = kMsg}) =>
    AttachmentOpenRegistry.registerFromMessage(
      payload: payload,
      messageId: messageId,
      chatType: 'C2C',
      fromUid: kSender,
      toUid: kReceiver,
    );

void main() {
  setUp(AttachmentOpenRegistry.resetForTest);

  group('1. carriesContentKey 识别嵌套 descriptor', () {
    test('images[i] 带 descriptor → true（顶层无 descriptor）', () {
      final p = _multiPayload([_sealImage(0).item, _sealImage(1).item]);
      expect(p.containsKey(AttachmentSealPolicy.descriptorPayloadKey), isFalse);
      expect(AttachmentSealPolicy.carriesContentKey(p), isTrue);
    });

    test('明文多图（元素无 descriptor）→ false', () {
      final p = _multiPayload([
        {'uri': 'a', 'width': 1, 'height': 1},
        {'uri': 'b', 'width': 1, 'height': 1},
      ]);
      expect(AttachmentSealPolicy.carriesContentKey(p), isFalse);
    });

    test('images 非列表 / 元素非 map / payload 非 map → false', () {
      expect(AttachmentSealPolicy.carriesContentKey({'images': 'x'}), isFalse);
      expect(
        AttachmentSealPolicy.carriesContentKey({
          'images': [1, 'a'],
        }),
        isFalse,
      );
      expect(AttachmentSealPolicy.carriesContentKey('images'), isFalse);
      expect(AttachmentSealPolicy.carriesContentKey(null), isFalse);
    });

    test('Map<dynamic, dynamic>（JSON 解码产物）同样识别', () {
      final Map<dynamic, dynamic> p = <dynamic, dynamic>{
        'images': <dynamic>[
          <dynamic, dynamic>{
            'uri': 'a',
            'attachment_descriptor': <dynamic, dynamic>{'k': 1},
          },
        ],
      };
      expect(AttachmentSealPolicy.carriesContentKey(p), isTrue);
    });

    test('顶层 descriptor 仍识别（单附件行为不变）', () {
      expect(
        AttachmentSealPolicy.carriesContentKey({
          AttachmentSealPolicy.descriptorPayloadKey: {'k': 1},
        }),
        isTrue,
      );
    });
  });

  group('2. AttachmentOpener 全量 / 顶层取 descriptor', () {
    test('descriptorsFrom：N 张图按序返回，attachmentId / objectKey 互异', () {
      final p = _multiPayload([
        _sealImage(0).item,
        _sealImage(1).item,
        _sealImage(2).item,
      ]);
      final ds = AttachmentOpener.descriptorsFrom(p);
      expect(ds.map((d) => d.attachmentId), ['image_0', 'image_1', 'image_2']);
      expect(ds.map((d) => d.objectKey).toSet(), hasLength(3));
    });

    test('descriptorFrom 仅看顶层：多图 payload → null（不抛）', () {
      expect(
        AttachmentOpener.descriptorFrom(_multiPayload([_sealImage(0).item])),
        isNull,
      );
    });

    test('顶层 + 嵌套同时在场 → 全部返回', () {
      final top = _sealImage(9).item;
      final p = <String, dynamic>{
        ..._multiPayload([_sealImage(0).item]),
        AttachmentSealPolicy.descriptorPayloadKey:
            top[AttachmentSealPolicy.descriptorPayloadKey],
      };
      expect(AttachmentOpener.descriptorsFrom(p), hasLength(2));
      expect(AttachmentOpener.descriptorFrom(p)?.attachmentId, 'image_9');
    });

    test('嵌套 descriptor 非法（不是 map）→ 抛异常，不静默跳过', () {
      final p = _multiPayload([
        _sealImage(0).item,
        {'uri': 'bad', AttachmentSealPolicy.descriptorPayloadKey: 'not-map'},
      ]);
      expect(
        () => AttachmentOpener.descriptorsFrom(p),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('嵌套 descriptor 字段不过严格 parser → 抛异常', () {
      final p = _multiPayload([
        {
          'uri': 'bad',
          AttachmentSealPolicy.descriptorPayloadKey: {'attachment_id': ''},
        },
      ]);
      expect(
        () => AttachmentOpener.descriptorsFrom(p),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('纯明文 payload / null → 空列表', () {
      expect(AttachmentOpener.descriptorsFrom({'uri': 'a'}), isEmpty);
      expect(AttachmentOpener.descriptorsFrom(null), isEmpty);
    });
  });

  group('3. 注册表逐图登记，各自可开封', () {
    test('登记一条多图消息 → 每张图 materialize 还原各自明文', () {
      final a = _sealImage(0);
      final b = _sealImage(1);
      final c = _sealImage(2);
      expect(_register(_multiPayload([a.item, b.item, c.item])), isTrue);
      for (final x in [a, b, c]) {
        final key = x.item['uri'] as String;
        expect(AttachmentOpenRegistry.lookup(key), isNotNull);
        expect(AttachmentOpenRegistry.materialize(key, x.cipher), x.plain);
      }
    });

    test('一张图的 descriptor 坏掉 → 整条不登记（false），无半登记', () {
      final a = _sealImage(0);
      final payload = _multiPayload([
        a.item,
        {'uri': 'bad', AttachmentSealPolicy.descriptorPayloadKey: 'nope'},
      ]);
      expect(_register(payload), isFalse);
      expect(AttachmentOpenRegistry.lookup(a.item['uri'] as String), isNull);
    });

    test('明文多图 → 不登记（false），materialize 原样返回', () {
      final payload = _multiPayload([
        {'uri': 'p1'},
        {'uri': 'p2'},
      ]);
      expect(_register(payload), isFalse);
      final bytes = _plain(10, 1);
      expect(AttachmentOpenRegistry.materialize('p1', bytes), same(bytes));
    });

    test('按另一条消息 id 登记 → 绑定失配，开封失败（ATT-01 锚点仍在）', () {
      final a = _sealImage(0);
      expect(_register(_multiPayload([a.item]), messageId: 'other'), isTrue);
      expect(
        () => AttachmentOpenRegistry.materialize(
          a.item['uri'] as String,
          a.cipher,
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });
  });
}
