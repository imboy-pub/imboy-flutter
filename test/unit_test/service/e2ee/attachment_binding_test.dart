/// E2EE-061 —— 块 AAD 绑定值（方案甲）验收
///
/// ⚠️ 本组存在的**理由**是一条已实证的阻塞：原设计要绑 PFv3 `header_hash`，
/// 但一条消息对 N 台收件设备有 N 个 header，而附件对象只有一份。
/// 见 `evidence/E2EE-061-slice4-blocked-header-hash-binding.md`。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';

Uint8List b({String m = 'msg-1', String c = 'c2c:1:2', String s = '1001'}) =>
    AttachmentBinding.compute(messageId: m, conversationId: c, senderUid: s);

void main() {
  group('1. 形状与确定性', () {
    test('长度正好是 codec 要求的绑定值长度', () {
      expect(b().length, equals(AttachmentChunkCodec.bindingLength));
    });

    test('确定性：同输入恒同输出', () {
      expect(b(), equals(b()));
    });

    test('含域分隔串（防结构被别的上下文复用）', () {
      // 域分隔串进的是 CBOR 明文，故直接出现在被 hash 的输入里；
      // 这里断言常量本身存在且非空，真正的隔离由 hash 输入包含它保证。
      expect(AttachmentBinding.domain, isNotEmpty);
      expect(AttachmentBinding.domain, contains('attachment-binding'));
    });
  });

  group('2. 三项各自生效（ATT-01 的依据）', () {
    test('换 message_id → 绑定值变（附件搬到另一条消息打不开）', () {
      expect(b(m: 'msg-2'), isNot(equals(b())));
    });

    test('换 conversation_id → 绑定值变', () {
      expect(b(c: 'c2c:1:3'), isNot(equals(b())));
    });

    test('换 sender_uid → 绑定值变', () {
      expect(b(s: '1002'), isNot(equals(b())));
    });

    test('字段边界不可平移（CBOR 长度前缀，非字节拼接）', () {
      // 拼接实现下 ("ab","c") 与 ("a","bc") 会撞同一串
      expect(
        AttachmentBinding.compute(
          messageId: 'ab',
          conversationId: 'c',
          senderUid: '1',
        ),
        isNot(
          equals(
            AttachmentBinding.compute(
              messageId: 'a',
              conversationId: 'bc',
              senderUid: '1',
            ),
          ),
        ),
      );
    });
  });

  group('3. fail-closed：任一项为空即拒', () {
    // 空 message_id 会让同一会话内所有附件共用同一绑定值，ATT-01 直接失效。
    // 这与 E2EE-025 的 `sessionRef: ''` 事故同类，故守卫放在构造处。
    test('message_id 为空 → 抛', () {
      expect(() => b(m: ''), throwsA(isA<AttachmentBindingException>()));
    });

    test('conversation_id 为空 → 抛', () {
      expect(() => b(c: ''), throwsA(isA<AttachmentBindingException>()));
    });

    test('sender_uid 为空 → 抛', () {
      expect(() => b(s: ''), throwsA(isA<AttachmentBindingException>()));
    });
  });

  group('4. 与封装链路对接（端到端）', () {
    test('正向可用性：用绑定值封装后可原样开封', () {
      final pt = Uint8List.fromList(List<int>.generate(100, (i) => i & 0xFF));
      final s = AttachmentEncryptor.seal(
        plaintext: pt,
        bindingHash: b(),
        attachmentId: 'att-1',
        objectKey: 'u1/a.bin',
        mime: 'application/octet-stream',
        name: 'a.bin',
        contentKey: AttachmentEncryptor.randomContentKey(),
        baseNonce: AttachmentEncryptor.randomBaseNonce(),
        chunkSize: 32,
      );
      expect(
        AttachmentEncryptor.open(
          ciphertext: s.ciphertext,
          descriptor: s.descriptor,
          bindingHash: b(),
        ),
        equals(pt),
      );
    });

    test('ATT-01：换 message_id 后同一份密文打不开', () {
      final pt = Uint8List.fromList(List<int>.filled(50, 7));
      final key = AttachmentEncryptor.randomContentKey();
      final nonce = AttachmentEncryptor.randomBaseNonce();
      final s = AttachmentEncryptor.seal(
        plaintext: pt,
        bindingHash: b(),
        attachmentId: 'att-1',
        objectKey: 'u1/a.bin',
        mime: 'application/octet-stream',
        name: 'a.bin',
        contentKey: key,
        baseNonce: nonce,
        chunkSize: 32,
      );
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: s.ciphertext,
          descriptor: s.descriptor,
          bindingHash: b(m: 'msg-2'),
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });
  });
}
