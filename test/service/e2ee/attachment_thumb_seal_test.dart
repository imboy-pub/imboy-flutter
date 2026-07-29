/// E2EE-061 Slice 7 —— 缩略图加密
///
/// 设计 §3.3：缩略图是**独立对象**。只加密视频本体而让缩略图明文 =
/// **预览即泄漏** —— 拿到缩略图就看得到画面内容，ATT-04 在缩略图上直接失败。
/// 那种状态比两个都明文更坏：它看起来像"已加密"。
///
/// 本文件验收三件事：
/// 1. 缩略图有**独立** content_key / base_nonce，且随主 descriptor 一起送达；
/// 2. 两个对象都能被接收侧开封（登记表按各自 object_key 分别登记）；
/// 3. 「同生同灭」闸门：只封装其一时**两个都不封装**。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

const String kSender = '52278';
const String kReceiver = '53314';

Uint8List _bytes(int n, int seed) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * seed + 5) & 0xFF));

Uint8List _binding({String messageId = 'msg-v1'}) => AttachmentBinding.compute(
  messageId: messageId,
  conversationId: 'c2c:$kSender:$kReceiver',
  senderUid: kSender,
);

/// 模拟 uploadVideoViaPresign 的产物：先封缩略图，再把它挂进视频 descriptor
({SealedAttachment video, SealedAttachment thumb}) sealVideoWithThumb({
  String messageId = 'msg-v1',
}) {
  final thumb = AttachmentEncryptor.seal(
    plaintext: _bytes(48, 7),
    bindingHash: _binding(messageId: messageId),
    attachmentId: 'video_thumb',
    objectKey: 'u$kSender/2026/07/t.jpg',
    mime: 'image/jpeg',
    name: 't.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 32,
  );
  final video = AttachmentEncryptor.seal(
    plaintext: _bytes(100, 13),
    bindingHash: _binding(messageId: messageId),
    attachmentId: 'video',
    objectKey: 'u$kSender/2026/07/v.mp4',
    mime: 'video/mp4',
    name: 'v.mp4',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 32,
    thumb: thumb.descriptor,
  );
  return (video: video, thumb: thumb);
}

void main() {
  setUp(AttachmentOpenRegistry.resetForTest);

  group('1. 缩略图随主 descriptor 一起送达，且密钥独立', () {
    test('主 descriptor 带 thumb，且 content_key / base_nonce 与主体不同', () {
      final s = sealVideoWithThumb();
      final d = s.video.descriptor;
      expect(d.thumb, isNotNull);
      expect(d.thumb!.contentKey, isNot(equals(d.contentKey)));
      expect(d.thumb!.baseNonce, isNot(equals(d.baseNonce)));
      expect(d.thumb!.objectKey, equals('u$kSender/2026/07/t.jpg'));
    });

    test('canonical 往返后 thumb 仍在（它要随加密 payload 出网）', () {
      final s = sealVideoWithThumb();
      final back = AttachmentDescriptor.fromMap(s.video.descriptor.toMap());
      expect(back.thumb, isNotNull);
      expect(
        back.thumb!.contentKey,
        equals(s.video.descriptor.thumb!.contentKey),
      );
    });

    test('⚠️ 复用主体的 content_key 当缩略图密钥 → 构造期即拒', () {
      final main = sealVideoWithThumb().video.descriptor;
      expect(
        () => AttachmentEncryptor.seal(
          plaintext: _bytes(10, 3),
          bindingHash: _binding(),
          attachmentId: 'video',
          objectKey: 'u1/v2.mp4',
          mime: 'video/mp4',
          name: 'v2.mp4',
          contentKey: main.thumb!.contentKey, // 与 thumb 同一把
          baseNonce: AttachmentEncryptor.randomBaseNonce(),
          thumb: main.thumb,
        ),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });
  });

  group('2. 接收侧：两个对象都能开封', () {
    test('登记一条视频消息 → 视频与缩略图各自可开', () {
      final s = sealVideoWithThumb();
      final payload = <String, dynamic>{
        'uri': s.video.descriptor.objectKey,
        AttachmentSealPolicy.descriptorPayloadKey: s.video.descriptor.toMap(),
      };
      expect(
        AttachmentOpenRegistry.registerFromMessage(
          payload: payload,
          messageId: 'msg-v1',
          chatType: 'C2C',
          fromUid: kSender,
          toUid: kReceiver,
        ),
        isTrue,
      );

      expect(
        AttachmentOpenRegistry.materialize(
          s.video.descriptor.objectKey,
          s.video.ciphertext,
        ),
        equals(_bytes(100, 13)),
      );
      expect(
        AttachmentOpenRegistry.materialize(
          s.thumb.descriptor.objectKey,
          s.thumb.ciphertext,
        ),
        equals(_bytes(48, 7)),
        reason: '缩略图是独立对象，必须单独可开——否则预览不出来',
      );
    });

    test('⚠️ 缩略图密文搬到另一条消息 → 拒绝', () {
      final a = sealVideoWithThumb(messageId: 'msg-A');
      final b = sealVideoWithThumb(messageId: 'msg-B');
      AttachmentOpenRegistry.registerFromMessage(
        payload: <String, dynamic>{
          AttachmentSealPolicy.descriptorPayloadKey: a.video.descriptor.toMap(),
        },
        messageId: 'msg-A',
        chatType: 'C2C',
        fromUid: kSender,
        toUid: kReceiver,
      );
      // 用 A 的 spec 去开 B 的缩略图密文（object_key 相同，绑定值不同）
      expect(
        () => AttachmentOpenRegistry.materialize(
          a.thumb.descriptor.objectKey,
          b.thumb.ciphertext,
        ),
        throwsA(anything),
      );
    });
  });

  group('3. 同生同灭闸门', () {
    test('两个都有 / 两个都无 → 一致', () {
      expect(AttachmentSealPolicy.sealTogether('a', 'b'), isTrue);
      expect(AttachmentSealPolicy.sealTogether(null, null), isTrue);
    });

    test('⚠️ 只有其一 → 不一致（调用方须两个都不封装）', () {
      expect(
        AttachmentSealPolicy.sealTogether('a', null),
        isFalse,
        reason: '本体加密而缩略图明文 = 预览即泄漏，且看起来像已加密',
      );
      expect(AttachmentSealPolicy.sealTogether(null, 'b'), isFalse);
    });
  });
}
