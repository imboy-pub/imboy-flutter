/// C04（附件完整覆盖与卫生）—— 每对象独立 content key / nonce 与替换攻击负例
///
/// ## 三组负例（计划 C04 任务 2/3）
///
/// 1. **独立性**：同会话两个附件对象 key 不同；重试路径 key/nonce 稳定但
///    nonce 从不跨对象复用；生产生成器（Random.secure 96bit）跨对象碰撞不可达。
/// 2. **nonce 复用灾难演示**：手工构造「同 key + 同 nonce 加密两份明文」，
///    实证 CTR keystream 相同 ⇒ `c1 ⊕ c2 = p1 ⊕ p2`——这正是生产代码
///    必须保证每对象独立 key/nonce 的原因；并证明descriptor 构造层对
///    thumb/主体复用的直接拒绝。
/// 3. **替换攻击**：descriptor（含 key 的认证容器）被整体或交叉替换 ⇒
///    解密拒绝；跨会话替换（conversation_ref 绑定）⇒ 拒绝。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';

Uint8List _plain(int n, int seed) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + seed) & 0xFF));

final Uint8List _hh = Uint8List.fromList(List<int>.filled(32, 0x33));

Uint8List _bindingOf(String messageId, String conv) =>
    AttachmentBinding.compute(
      messageId: messageId,
      conversationId: conv,
      senderUid: '1001',
    );

SealedAttachment _sealWith({
  required Uint8List plaintext,
  required String attachmentId,
  required String objectKey,
  Uint8List? key,
  Uint8List? nonce,
  AttachmentDescriptor? thumb,
}) => AttachmentEncryptor.seal(
  plaintext: plaintext,
  bindingHash: _hh,
  attachmentId: attachmentId,
  objectKey: objectKey,
  mime: 'application/octet-stream',
  name: '$attachmentId.bin',
  contentKey: key ?? AttachmentEncryptor.randomContentKey(),
  baseNonce: nonce ?? AttachmentEncryptor.randomBaseNonce(),
  chunkSize: 32,
  thumb: thumb,
);

/// 构造与 [src] 字段相同、仅替换个别字段的 descriptor（替换攻击的道具）。
AttachmentDescriptor _copyWith(
  AttachmentDescriptor src, {
  Uint8List? contentKey,
  Uint8List? baseNonce,
  AttachmentDescriptor? thumb,
}) => AttachmentDescriptor(
  attachmentId: src.attachmentId,
  objectKey: src.objectKey,
  contentKey: contentKey ?? src.contentKey,
  cipher: src.cipher,
  chunkSize: src.chunkSize,
  chunkCount: src.chunkCount,
  baseNonce: baseNonce ?? src.baseNonce,
  plainSize: src.plainSize,
  plainSha256: src.plainSha256,
  mime: src.mime,
  name: src.name,
  thumb: thumb ?? src.thumb,
);

void main() {
  group('1. 每对象独立 content key / nonce', () {
    test('⚠️ 同会话、同消息、同 attachmentId 的两个附件对象 key 不同', () {
      final a = _sealWith(
        plaintext: _plain(100, 1),
        attachmentId: 'image',
        objectKey: 'u1/a.bin',
      );
      final b = _sealWith(
        plaintext: _plain(100, 1),
        attachmentId: 'image',
        objectKey: 'u1/b.bin',
      );
      expect(a.descriptor.contentKey, isNot(equals(b.descriptor.contentKey)));
      expect(a.descriptor.baseNonce, isNot(equals(b.descriptor.baseNonce)));
      // 密文随之不同：服务端无法把两个对象关联成同一内容
      expect(a.ciphertext, isNot(equals(b.ciphertext)));
    });

    test('⚠️ 同 key 下换 nonce、同 nonce 下换 key → 密文都不同（无确定性复现）', () {
      final pt = _plain(64, 7);
      final base = _sealWith(
        plaintext: pt,
        attachmentId: 'file',
        objectKey: 'u1/base.bin',
      );
      final sameKey = _sealWith(
        plaintext: pt,
        attachmentId: 'file',
        objectKey: 'u1/base.bin',
        key: base.descriptor.contentKey,
      );
      final sameNonce = _sealWith(
        plaintext: pt,
        attachmentId: 'file',
        objectKey: 'u1/base.bin',
        nonce: base.descriptor.baseNonce,
      );
      expect(sameKey.ciphertext, isNot(equals(base.ciphertext)));
      expect(sameNonce.ciphertext, isNot(equals(base.ciphertext)));
    });

    test('生产生成器跨对象碰撞不可达（Random.secure 抽样 64 次全互异）', () {
      final nonces = <Uint8List>[
        for (var i = 0; i < 64; i++) AttachmentEncryptor.randomBaseNonce(),
      ];
      final keys = <Uint8List>[
        for (var i = 0; i < 64; i++) AttachmentEncryptor.randomContentKey(),
      ];
      expect(nonces.toSet().length, equals(64));
      expect(keys.toSet().length, equals(64));
    });

    test('块内 nonce 派生对 index 单射（同对象内不同块永不撞 nonce）', () {
      final base = AttachmentEncryptor.randomBaseNonce();
      final seen = <String>{};
      for (var i = 0; i < 4096; i++) {
        seen.add(
          String.fromCharCodes(AttachmentChunkCodec.deriveNonce(base, i)),
        );
      }
      expect(seen.length, equals(4096));
    });
  });

  group('2. nonce 复用是灾难（演示为什么必须独立）', () {
    test('⚠️ 同 key+同 nonce 加密两份明文 → c1⊕c2 = p1⊕p2（keystream 重放）', () {
      final key = AttachmentEncryptor.randomContentKey();
      final nonce = AttachmentEncryptor.randomBaseNonce();
      final p1 = _plain(48, 11);
      final p2 = _plain(48, 22);
      final c1 = AttachmentChunkCodec.encryptChunk(
        plaintext: p1,
        contentKey: key,
        baseNonce: nonce,
        bindingHash: _hh,
        attachmentId: 'att-a',
        chunkIndex: 0,
        chunkCount: 1,
      );
      final c2 = AttachmentChunkCodec.encryptChunk(
        plaintext: p2,
        contentKey: key,
        baseNonce: nonce,
        bindingHash: _hh,
        attachmentId: 'att-b',
        chunkIndex: 0,
        chunkCount: 1,
      );
      // GCM 即 CTR：密文段 = 明文 ⊕ keystream。nonce 复用 ⇒ keystream 相同
      // ⇒ 攻击者无需密钥即可算出两份明文的异或（经典 two-time pad）。
      // 注：AAD 不同只保护 tag，不改变密文段的 XOR 性质。
      final tagLen = AttachmentChunkCodec.tagLength;
      for (var i = 0; i < p1.length; i++) {
        final x = (c1[i] ^ c2[i]);
        final y = (p1[i] ^ p2[i]);
        expect(x, equals(y), reason: '偏移 $i 处密文异或不等于明文异或');
        // 排除 tag 段（tag 不参与本论证）
        expect(i, lessThan(c1.length - tagLen));
      }
    });

    test('⚠️ descriptor 构造层直接拒绝：thumb 与主体同 base_nonce → 抛', () {
      final key = AttachmentEncryptor.randomContentKey();
      final nonce = AttachmentEncryptor.randomBaseNonce();
      final thumb = _sealWith(
        plaintext: _plain(16, 2),
        attachmentId: 'video_thumb',
        objectKey: 'u1/t.bin',
        // 独立 key，但**复用主体的 base_nonce** → 构造期必须拒绝
        nonce: nonce,
      );
      expect(
        () => _sealWith(
          plaintext: _plain(64, 1),
          attachmentId: 'video',
          objectKey: 'u1/v2.bin',
          key: key,
          nonce: nonce,
          thumb: thumb.descriptor,
        ),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('⚠️ descriptor 构造层直接拒绝：thumb 与主体同 content_key → 抛', () {
      final key = AttachmentEncryptor.randomContentKey();
      final nonce = AttachmentEncryptor.randomBaseNonce();
      final thumb = _sealWith(
        plaintext: _plain(16, 2),
        attachmentId: 'video_thumb',
        objectKey: 'u1/t.bin',
        // 独立 nonce，但**复用主体的 content_key** → 构造期必须拒绝
        key: key,
      );
      expect(
        () => _sealWith(
          plaintext: _plain(64, 1),
          attachmentId: 'video',
          objectKey: 'u1/v2.bin',
          key: key,
          nonce: nonce,
          thumb: thumb.descriptor,
        ),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });
  });

  group('3. descriptor 替换攻击（认证容器的整体/交叉替换）', () {
    late SealedAttachment a;
    late SealedAttachment b;

    setUp(() {
      a = _sealWith(
        plaintext: _plain(100, 1),
        attachmentId: 'att-a',
        objectKey: 'u1/a.bin',
      );
      b = _sealWith(
        plaintext: _plain(100, 2),
        attachmentId: 'att-b',
        objectKey: 'u1/b.bin',
      );
    });

    test('⚠️ 对象 A 的密文 + 对象 B 的 descriptor → open 拒绝', () {
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: a.ciphertext,
          descriptor: b.descriptor,
          bindingHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });

    test('⚠️ 经接收侧消息面替换（payload 挂 B 的 descriptor、下载到 A 的密文）', () {
      final payload = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: b.descriptor.toMap(),
      };
      expect(
        () => AttachmentOpener.openForMessage(
          payload: payload,
          objectBytes: a.ciphertext,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '2002',
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('⚠️ B 的 descriptor 字段逐项伪装成 A（仅保留 key/nonce）→ 仍拒绝', () {
      // 攻击者知道 A 的密文结构，构造「object_key/attachment_id 都对、
      // 但 key/nonce 是 B 的」descriptor：tag 校验必然失败。
      final forged = AttachmentDescriptor(
        attachmentId: a.descriptor.attachmentId,
        objectKey: a.descriptor.objectKey,
        contentKey: b.descriptor.contentKey,
        cipher: a.descriptor.cipher,
        chunkSize: a.descriptor.chunkSize,
        chunkCount: a.descriptor.chunkCount,
        baseNonce: b.descriptor.baseNonce,
        plainSize: a.descriptor.plainSize,
        plainSha256: a.descriptor.plainSha256,
        mime: a.descriptor.mime,
        name: a.descriptor.name,
      );
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: a.ciphertext,
          descriptor: forged,
          bindingHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });

    test('⚠️ 缩略图 descriptor 交叉替换（A.thumb 换成 B.thumb）→ 拒绝', () {
      final thumbA = _sealWith(
        plaintext: _plain(16, 3),
        attachmentId: 'video_thumb',
        objectKey: 'u1/ta.bin',
      );
      final videoA = _sealWith(
        plaintext: _plain(96, 1),
        attachmentId: 'video',
        objectKey: 'u1/va.bin',
        thumb: thumbA.descriptor,
      );
      final thumbB = _sealWith(
        plaintext: _plain(16, 4),
        attachmentId: 'video_thumb',
        objectKey: 'u1/tb.bin',
      );
      // 主体 descriptor 的 thumb 字段被替换成 B 的缩略图 descriptor，
      // 却试图打开 A 的缩略图密文：key/nonce/plainSha256 全失配。
      final tampered = _copyWith(videoA.descriptor, thumb: thumbB.descriptor);
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: thumbA.ciphertext,
          descriptor: tampered.thumb!,
          bindingHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });

    test('对照组：未替换时主体与缩略图各自可开（防恒抛）', () {
      final thumbA = _sealWith(
        plaintext: _plain(16, 3),
        attachmentId: 'video_thumb',
        objectKey: 'u1/ta.bin',
      );
      final videoA = _sealWith(
        plaintext: _plain(96, 1),
        attachmentId: 'video',
        objectKey: 'u1/va.bin',
        thumb: thumbA.descriptor,
      );
      expect(
        AttachmentEncryptor.open(
          ciphertext: videoA.ciphertext,
          descriptor: videoA.descriptor,
          bindingHash: _hh,
        ),
        equals(_plain(96, 1)),
      );
      expect(
        AttachmentEncryptor.open(
          ciphertext: thumbA.ciphertext,
          descriptor: videoA.descriptor.thumb!,
          bindingHash: _hh,
        ),
        equals(_plain(16, 3)),
      );
    });
  });

  group('4. 跨会话替换（conversation_ref 绑定拒绝）', () {
    late SealedAttachment sealed;

    setUp(() {
      // 用接收侧重算得到的同一个 binding 封装（对照组锚点的前提）：
      // C2C from=1001 to=2002 → conv=c2c:1001:2002，messageId=msg-1。
      sealed = AttachmentEncryptor.seal(
        plaintext: _plain(100, 5),
        bindingHash: _bindingOf('msg-1', 'c2c:1001:2002'),
        attachmentId: 'image',
        objectKey: 'u1/x.bin',
        mime: 'application/octet-stream',
        name: 'x.bin',
        contentKey: AttachmentEncryptor.randomContentKey(),
        baseNonce: AttachmentEncryptor.randomBaseNonce(),
        chunkSize: 32,
      );
    });

    Uint8List openInSession({
      required String messageId,
      required String chatType,
      required String fromUid,
      required String toUid,
    }) => AttachmentOpener.openForMessage(
      payload: <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: sealed.descriptor.toMap(),
      },
      objectBytes: sealed.ciphertext,
      messageId: messageId,
      chatType: chatType,
      fromUid: fromUid,
      toUid: toUid,
    )!;

    test('⚠️ 同一密文搬到另一个 C2C 会话（对端换人）→ 拒绝', () {
      expect(
        () => openInSession(
          messageId: 'msg-2',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '3003',
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('⚠️ C2C 密文被搬进 C2G 会话（类型替换）→ 拒绝', () {
      expect(
        () => openInSession(
          messageId: 'msg-2',
          chatType: 'C2G',
          fromUid: '1001',
          toUid: 'g-9',
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('⚠️ 冒充另一个发送者 → 拒绝', () {
      expect(
        () => openInSession(
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '9999',
          toUid: '2002',
        ),
        throwsA(isA<AttachmentOpenException>()),
      );
    });

    test('对照组：原会话原消息 → 可开（本组正向锚点）', () {
      expect(
        openInSession(
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '2002',
        ),
        equals(_plain(100, 5)),
      );
    });
  });

  group('5. 截断与换块（矩阵补格：跨对象块替换）', () {
    test('⚠️ 跨对象换块：A 的第 0 块被换成 B 的第 0 块（同长）→ 拒绝', () {
      final a = _sealWith(
        plaintext: _plain(96, 1),
        attachmentId: 'att-a',
        objectKey: 'u1/a.bin',
      );
      final b = _sealWith(
        plaintext: _plain(96, 2),
        attachmentId: 'att-b',
        objectKey: 'u1/b.bin',
      );
      const sealedChunkLen = 32 + 16;
      final spliced = Uint8List.fromList(a.ciphertext);
      for (var i = 0; i < sealedChunkLen; i++) {
        spliced[i] = b.ciphertext[i];
      }
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: spliced,
          descriptor: a.descriptor,
          bindingHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
        reason: '跨对象换块必须因 AAD（attachment_id）失配被拒',
      );
    });

    test('⚠️ 截断中间块（保留总长拼接）→ 末块长度校验拒绝', () {
      final a = _sealWith(
        plaintext: _plain(96, 1),
        attachmentId: 'att-a',
        objectKey: 'u1/a.bin',
      );
      // 删掉中间一整块（48 字节）：总长对不上任何合法布局
      final truncated = Uint8List.fromList(
        a.ciphertext.sublist(0, 48) + a.ciphertext.sublist(96),
      );
      expect(truncated.length, equals(a.ciphertext.length - 48));
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: truncated,
          descriptor: a.descriptor,
          bindingHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });
  });

  // 绑定值直接参与的会话维度回归（binding 层与 open 层的接缝）
  group('6. binding 输入的会话维度', () {
    test('conversation_id 不同 → 绑定值不同（跨会话替换的另一面）', () {
      final x = _bindingOf('msg-1', 'c2c:1001:2002');
      final y = _bindingOf('msg-1', 'c2c:1001:3003');
      final z = _bindingOf('msg-1', 'g-9');
      expect(x, isNot(equals(y)));
      expect(x, isNot(equals(z)));
      expect(y, isNot(equals(z)));
    });
  });
}
