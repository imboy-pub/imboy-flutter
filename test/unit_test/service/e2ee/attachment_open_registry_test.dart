/// E2EE-061 Slice 6（下半）—— 「object_key → 开封材料」登记表
///
/// 下载漏斗 `IMBoyCacheManager.getSingleFile` 只收一个 URL，上面还压着
/// `IMBoyCachedImageProvider`（身份就是 url）与 9 个调用点；本表把 descriptor
/// 从**唯一**的消息转换入口 `toTypeMessage()` 接力给下载处。
///
/// ⚠️ 漏斗本身依赖网络与 path_provider，进不了单测；本文件验收的是
/// **登记与开封的逻辑**（纯内存），漏斗里的调用顺序只有真机能证。
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

Uint8List _plain(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 41 + 3) & 0xFF));

({Map<String, dynamic> payload, Uint8List cipher, String objectKey}) sealed({
  String messageId = 'msg-1',
  String objectKey = 'u52278/2026/07/a.bin',
  int size = 100,
}) {
  final s = AttachmentEncryptor.seal(
    plaintext: _plain(size),
    bindingHash: AttachmentBinding.compute(
      messageId: messageId,
      conversationId: 'c2c:$kSender:$kReceiver',
      senderUid: kSender,
    ),
    attachmentId: 'image',
    objectKey: objectKey,
    mime: 'image/jpeg',
    name: 'a.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 32,
  );
  return (
    payload: <String, dynamic>{
      'uri': objectKey,
      AttachmentSealPolicy.descriptorPayloadKey: s.descriptor.toMap(),
    },
    cipher: s.ciphertext,
    objectKey: objectKey,
  );
}

bool register(Map<String, dynamic> payload, {String messageId = 'msg-1'}) =>
    AttachmentOpenRegistry.registerFromMessage(
      payload: payload,
      messageId: messageId,
      chatType: 'C2C',
      fromUid: kSender,
      toUid: kReceiver,
    );

void main() {
  setUp(AttachmentOpenRegistry.resetForTest);

  group('1. 正向可用性：登记后能开封', () {
    test('登记 → materialize 还原明文', () {
      final s = sealed();
      expect(register(s.payload), isTrue);
      expect(
        AttachmentOpenRegistry.materialize(s.objectKey, s.cipher),
        equals(_plain(100)),
      );
    });

    test('登记键就是 descriptor 的 object_key（不是消息里的 uri 字段）', () {
      final s = sealed(objectKey: 'u1/real/key.bin');
      register(<String, dynamic>{
        ...s.payload,
        'uri': 'u1/DIFFERENT/uri.bin', // 消息 uri 被改花也不影响
      });
      expect(AttachmentOpenRegistry.lookup('u1/real/key.bin'), isNotNull);
      expect(AttachmentOpenRegistry.lookup('u1/DIFFERENT/uri.bin'), isNull);
    });
  });

  group('2. 明文对象与未登记对象：原样放行', () {
    test('payload 无 descriptor → 不登记，materialize 原样返回', () {
      expect(register(<String, dynamic>{'uri': 'u1/plain.jpg'}), isFalse);
      final bytes = _plain(20);
      expect(
        AttachmentOpenRegistry.materialize('u1/plain.jpg', bytes),
        same(bytes),
        reason: '历史明文附件必须逐字节原样通过',
      );
    });

    test('⚠️ 登记表未命中（冷启动/尚未转换）→ 原样返回，即坏图而非泄漏', () {
      final s = sealed();
      // 故意不登记
      expect(
        AttachmentOpenRegistry.materialize(s.objectKey, s.cipher),
        same(s.cipher),
        reason: '已知代价：查不到 spec 时密文会被当明文交给渲染器（坏图）',
      );
    });
  });

  group('3. fail-closed', () {
    test('descriptor 坏掉 → 登记失败但不抛（消息转换不该整条失败）', () {
      expect(
        register(<String, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: 'not-a-map',
        }),
        isFalse,
      );
    });

    test('推不出会话标识（C2S）→ 登记失败，不拿空串兜底', () {
      final s = sealed();
      expect(
        AttachmentOpenRegistry.registerFromMessage(
          payload: s.payload,
          messageId: 'msg-1',
          chatType: 'C2S',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        isFalse,
      );
      expect(AttachmentOpenRegistry.lookup(s.objectKey), isNull);
    });

    test('⚠️ 用错消息登记（绑定值不匹配）→ materialize 抛，绝不返回半截明文', () {
      final s = sealed(messageId: 'msg-1');
      register(s.payload, messageId: 'msg-OTHER');
      expect(
        () => AttachmentOpenRegistry.materialize(s.objectKey, s.cipher),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('密文被篡改 → materialize 抛', () {
      final s = sealed();
      register(s.payload);
      final tampered = Uint8List.fromList(s.cipher)..[3] ^= 0xFF;
      expect(
        () => AttachmentOpenRegistry.materialize(s.objectKey, tampered),
        throwsA(isA<AttachmentOpenException>()),
      );
    });
  });

  group('4. 容量上限：长会话不会无界增长', () {
    test('超过 maxEntries 后最早的被挤掉，最新的仍在', () {
      for (var i = 0; i < AttachmentOpenRegistry.maxEntries + 5; i++) {
        register(sealed(objectKey: 'u1/k$i.bin', size: 8).payload);
      }
      expect(AttachmentOpenRegistry.lookup('u1/k0.bin'), isNull);
      expect(
        AttachmentOpenRegistry.lookup(
          'u1/k${AttachmentOpenRegistry.maxEntries + 4}.bin',
        ),
        isNotNull,
      );
    });

    test('重复登记同一个 key 不撑大表', () {
      final s = sealed();
      for (var i = 0; i < 10; i++) {
        register(s.payload);
      }
      expect(AttachmentOpenRegistry.lookup(s.objectKey), isNotNull);
      expect(
        AttachmentOpenRegistry.materialize(s.objectKey, s.cipher),
        equals(_plain(100)),
      );
    });
  });
}
