/// E2EE-061 Slice 2 —— 分块 AEAD 编解码器验收
///
/// 覆盖 ATT-02 的**密码学部分**（往返 + 篡改矩阵）。ATT-01/03 的端到端归 Slice 6。
///
/// ⚠️ **为什么不能只写篡改矩阵**：「一律拒绝」的实现在篡改矩阵上恒得满分。
/// 因此每一组都配了正向可用性用例（正确参数必须**原样**还原明文），
/// 且第 1 组是对照组——它红则后面全部结论都不成立。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:pointycastle/api.dart' as api;
import 'package:pointycastle/export.dart';

Uint8List _bytes(int fill, int len) =>
    Uint8List.fromList(List<int>.filled(len, fill));

final Uint8List _key = _bytes(0x11, 32);
final Uint8List _baseNonce = _bytes(0x22, 12);
final Uint8List _headerHash = _bytes(0x33, 32);
const String _attachmentId = 'att-0001';

Uint8List _plain(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('1. 对照组：底层 AEAD 原语按假设工作', () {
    // 本组不经过被测代码。它红 = harness 缺陷（pointycastle 的 AEADParameters
    // 没有真的把 AAD 纳入认证），后面所有"AAD 失配即拒收"的结论都不成立。
    Uint8List seal(Uint8List pt, Uint8List aad) {
      final c = GCMBlockCipher(AESEngine())
        ..init(
          true,
          api.AEADParameters(KeyParameter(_key), 128, _baseNonce, aad),
        );
      return c.process(pt);
    }

    Uint8List open(Uint8List sealed, Uint8List aad) {
      final c = GCMBlockCipher(AESEngine())
        ..init(
          false,
          api.AEADParameters(KeyParameter(_key), 128, _baseNonce, aad),
        );
      return c.process(sealed);
    }

    test('AAD 一致时可还原明文', () {
      final pt = _plain('control-group');
      final sealed = seal(pt, _bytes(0xAA, 8));
      expect(open(sealed, _bytes(0xAA, 8)), equals(pt));
    });

    test('AAD 变一个字节即拒收 —— AAD 确实被纳入认证', () {
      final sealed = seal(_plain('control-group'), _bytes(0xAA, 8));
      final wrongAad = _bytes(0xAA, 8)..[3] ^= 0x01;
      expect(() => open(sealed, wrongAad), throwsA(isA<Exception>()));
    });

    test('tag 变一个字节即拒收', () {
      final sealed = seal(_plain('control-group'), _bytes(0xAA, 8));
      sealed[sealed.length - 1] ^= 0x01;
      expect(() => open(sealed, _bytes(0xAA, 8)), throwsA(isA<Exception>()));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('2. nonce 派生：对 chunk_index 单射', () {
    test('index 0 时等于 base_nonce 本身', () {
      expect(
        AttachmentChunkCodec.deriveNonce(_baseNonce, 0),
        equals(_baseNonce),
      );
    });

    test('确定性：同输入恒同输出', () {
      expect(
        AttachmentChunkCodec.deriveNonce(_baseNonce, 7),
        equals(AttachmentChunkCodec.deriveNonce(_baseNonce, 7)),
      );
    });

    test('不同 index 派生出互不相同的 nonce（抽 1000 个）', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        final n = AttachmentChunkCodec.deriveNonce(_baseNonce, i);
        expect(
          seen.add(n.join(',')),
          isTrue,
          reason: 'index $i 的 nonce 与在先的重复',
        );
      }
    });

    // ⚠️ 本用例由空验证 E 补出：注释掉 `nonce[8] ^= (chunkIndex >> 24)` 后
    // 上面那条「抽 1000 个」**依然全绿**——1000 以内只碰得到末两个字节，
    // 高位字节被丢弃不会有任何测试变红。逐字节覆盖四个位置才钉得住。
    test('index 的四个字节位置全部进入 nonce（高位不得被丢弃）', () {
      final seen = <String, int>{};
      // 每个值只点亮 index 的一个字节位置，外加两端边界
      for (final i in [
        0,
        0x01,
        0x100,
        0x10000,
        0x1000000,
        0x01010101,
        0xFFFFFFFF,
      ]) {
        final k = AttachmentChunkCodec.deriveNonce(_baseNonce, i).join(',');
        expect(
          seen.containsKey(k),
          isFalse,
          reason:
              'index $i 与 index ${seen[k]} 派生出同一 nonce —— '
              '同 key 下 nonce 复用会摧毁 GCM 的认证性',
        );
        seen[k] = i;
      }
    });

    test('不修改传入的 base_nonce（避免调用方持有的数组被就地改坏）', () {
      final src = Uint8List.fromList(_baseNonce);
      AttachmentChunkCodec.deriveNonce(src, 12345);
      expect(src, equals(_baseNonce));
    });

    test('base_nonce 长度不对 → fail-closed', () {
      expect(
        () => AttachmentChunkCodec.deriveNonce(_bytes(0x22, 11), 0),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('index 超过 uint32 → fail-closed（否则不同块会撞同一 nonce）', () {
      expect(
        () => AttachmentChunkCodec.deriveNonce(_baseNonce, 0x100000000),
        throwsA(isA<AttachmentChunkException>()),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('3. 正向可用性：正确参数必须原样还原', () {
    Uint8List roundTrip(Uint8List pt, {int idx = 0, int count = 1}) {
      final sealed = AttachmentChunkCodec.encryptChunk(
        plaintext: pt,
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: idx,
        chunkCount: count,
      );
      return AttachmentChunkCodec.decryptChunk(
        sealed: sealed,
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: idx,
        chunkCount: count,
      );
    }

    test('单块往返', () {
      final pt = _plain('hello attachment');
      expect(roundTrip(pt), equals(pt));
    });

    test('空块往返（0 字节明文仍产出可验证的 tag）', () {
      expect(roundTrip(Uint8List(0)), isEmpty);
    });

    test('1 字节与 AES 分组边界（15/16/17 字节）往返', () {
      for (final n in [1, 15, 16, 17]) {
        final pt = Uint8List.fromList(List.generate(n, (i) => i & 0xFF));
        expect(roundTrip(pt), equals(pt), reason: '$n 字节明文往返失败');
      }
    });

    test('密文与明文不同（确实加密了，不是直通）', () {
      final pt = _plain('hello attachment');
      final sealed = AttachmentChunkCodec.encryptChunk(
        plaintext: pt,
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 0,
        chunkCount: 1,
      );
      expect(sealed.length, equals(pt.length + AttachmentChunkCodec.tagLength));
      expect(sealed.sublist(0, pt.length), isNot(equals(pt)));
    });

    test('多块流：3 块各自往返，拼接后等于原文', () {
      const count = 3;
      final parts = [_plain('AAAA'), _plain('BBBB'), _plain('CCCC')];
      final out = <int>[];
      for (var i = 0; i < count; i++) {
        out.addAll(roundTrip(parts[i], idx: i, count: count));
      }
      expect(out, equals([...parts[0], ...parts[1], ...parts[2]]));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('4. 篡改矩阵：AAD 四项各自绑定生效', () {
    const count = 3;
    late Uint8List sealed0;

    setUp(() {
      sealed0 = AttachmentChunkCodec.encryptChunk(
        plaintext: _plain('chunk-zero'),
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 0,
        chunkCount: count,
      );
    });

    Uint8List open({
      Uint8List? headerHash,
      String? attachmentId,
      Uint8List? contentKey,
      Uint8List? baseNonce,
      int idx = 0,
      int cnt = count,
      Uint8List? blob,
    }) {
      return AttachmentChunkCodec.decryptChunk(
        sealed: blob ?? sealed0,
        contentKey: contentKey ?? _key,
        baseNonce: baseNonce ?? _baseNonce,
        headerHash: headerHash ?? _headerHash,
        attachmentId: attachmentId ?? _attachmentId,
        chunkIndex: idx,
        chunkCount: cnt,
      );
    }

    test('参数全对 → 通过（本组的正向可用性锚点）', () {
      expect(open(), equals(_plain('chunk-zero')));
    });

    test('ATT-01 header_hash 变 → 拒收（密文块搬到另一条消息下打不开）', () {
      final other = Uint8List.fromList(_headerHash)..[0] ^= 0x01;
      expect(
        () => open(headerHash: other),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('attachment_id 变 → 拒收（同消息内两个附件不可互换）', () {
      expect(
        () => open(attachmentId: 'att-0002'),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('chunk_index 变 → 拒收（块重排）', () {
      expect(() => open(idx: 1), throwsA(isA<AttachmentChunkException>()));
    });

    test('chunk_count 变 → 拒收（块截断：声明少了几块）', () {
      expect(() => open(cnt: 2), throwsA(isA<AttachmentChunkException>()));
    });

    test('content key 变 → 拒收', () {
      expect(
        () => open(contentKey: _bytes(0x12, 32)),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('base_nonce 变 → 拒收', () {
      expect(
        () => open(baseNonce: _bytes(0x23, 12)),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('密文正文改一个字节 → 拒收，且不返回任何明文', () {
      final tampered = Uint8List.fromList(sealed0)..[0] ^= 0x01;
      expect(
        () => open(blob: tampered),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('tag 改一个字节 → 拒收', () {
      final tampered = Uint8List.fromList(sealed0)
        ..[sealed0.length - 1] ^= 0x01;
      expect(
        () => open(blob: tampered),
        throwsA(isA<AttachmentChunkException>()),
      );
    });

    test('两块整体对调 → 两块都拒收（重排不是"换个顺序读"就能绕过）', () {
      final a = AttachmentChunkCodec.encryptChunk(
        plaintext: _plain('AAAA'),
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 0,
        chunkCount: 2,
      );
      final b = AttachmentChunkCodec.encryptChunk(
        plaintext: _plain('BBBB'),
        contentKey: _key,
        baseNonce: _baseNonce,
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 1,
        chunkCount: 2,
      );
      // 把 1 号块当 0 号读、把 0 号块当 1 号读
      expect(
        () => open(blob: b, idx: 0, cnt: 2),
        throwsA(isA<AttachmentChunkException>()),
      );
      expect(
        () => open(blob: a, idx: 1, cnt: 2),
        throwsA(isA<AttachmentChunkException>()),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('5. AAD 编码无歧义', () {
    test('字段边界不可平移：拆分点不同的两组输入产出不同 AAD', () {
      // 字节拼接实现下，("ab","c") 与 ("a","bc") 会拼出同一串。
      final a = AttachmentChunkCodec.buildAad(
        headerHash: _headerHash,
        attachmentId: 'ab',
        chunkIndex: 0,
        chunkCount: 1,
      );
      final b = AttachmentChunkCodec.buildAad(
        headerHash: _headerHash,
        attachmentId: 'a',
        chunkIndex: 0,
        chunkCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('确定性：同输入恒产出同一串字节', () {
      Uint8List build() => AttachmentChunkCodec.buildAad(
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 2,
        chunkCount: 5,
      );
      expect(build(), equals(build()));
    });

    test('含域分隔串（防本 AAD 结构被复用到别的上下文）', () {
      final aad = AttachmentChunkCodec.buildAad(
        headerHash: _headerHash,
        attachmentId: _attachmentId,
        chunkIndex: 0,
        chunkCount: 1,
      );
      expect(
        utf8.decode(aad, allowMalformed: true),
        contains(AttachmentChunkCodec.aadContext),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('6. 参数边界 fail-closed', () {
    void expectRejected(void Function() f, String why) {
      expect(f, throwsA(isA<AttachmentChunkException>()), reason: why);
    }

    test('key 长度不对 → 拒绝（加密与解密两侧）', () {
      expectRejected(
        () => AttachmentChunkCodec.encryptChunk(
          plaintext: _plain('x'),
          contentKey: _bytes(0x11, 16),
          baseNonce: _baseNonce,
          headerHash: _headerHash,
          attachmentId: _attachmentId,
          chunkIndex: 0,
          chunkCount: 1,
        ),
        '16 字节 key 不是 AES-256',
      );
      expectRejected(
        () => AttachmentChunkCodec.decryptChunk(
          sealed: _bytes(0, 32),
          contentKey: _bytes(0x11, 16),
          baseNonce: _baseNonce,
          headerHash: _headerHash,
          attachmentId: _attachmentId,
          chunkIndex: 0,
          chunkCount: 1,
        ),
        '解密侧同样必须拒',
      );
    });

    test('header_hash 不是 32 字节 → 拒绝', () {
      expectRejected(
        () => AttachmentChunkCodec.buildAad(
          headerHash: _bytes(0x33, 31),
          attachmentId: _attachmentId,
          chunkIndex: 0,
          chunkCount: 1,
        ),
        'header_hash 必须是 SHA-256 全长',
      );
    });

    test('attachment_id 为空 → 拒绝', () {
      expectRejected(
        () => AttachmentChunkCodec.buildAad(
          headerHash: _headerHash,
          attachmentId: '',
          chunkIndex: 0,
          chunkCount: 1,
        ),
        '空 id 会让不同附件共用同一 AAD',
      );
    });

    test('chunk_count < 1 → 拒绝', () {
      expectRejected(
        () => AttachmentChunkCodec.buildAad(
          headerHash: _headerHash,
          attachmentId: _attachmentId,
          chunkIndex: 0,
          chunkCount: 0,
        ),
        '零块的附件没有意义',
      );
    });

    test('chunk_index >= chunk_count → 拒绝', () {
      expectRejected(
        () => AttachmentChunkCodec.buildAad(
          headerHash: _headerHash,
          attachmentId: _attachmentId,
          chunkIndex: 3,
          chunkCount: 3,
        ),
        '越界的块号',
      );
    });

    test('密文块短于 tag → 拒绝（不得进 GCM 让它自己崩）', () {
      expectRejected(
        () => AttachmentChunkCodec.decryptChunk(
          sealed: _bytes(0, 15),
          contentKey: _key,
          baseNonce: _baseNonce,
          headerHash: _headerHash,
          attachmentId: _attachmentId,
          chunkIndex: 0,
          chunkCount: 1,
        ),
        '15 字节装不下 16 字节 tag',
      );
    });
  });
}
