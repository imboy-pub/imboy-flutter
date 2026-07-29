/// E2EE-061 —— 附件封装/开封编排的验收（ATT-01/02/03 的纯函数部分）
///
/// ⚠️ 恒抛的 open() 在篡改矩阵上满分，故每组都配正向可用性锚点。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';

Uint8List _bytes(int fill, int len) =>
    Uint8List.fromList(List<int>.filled(len, fill));

Uint8List _plain(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 37 + 11) & 0xFF));

final Uint8List _key = _bytes(0x11, 32);
final Uint8List _nonce = _bytes(0x22, 12);
final Uint8List _hh = _bytes(0x33, 32);

SealedAttachment seal(Uint8List pt, {int chunkSize = 32, Uint8List? hh}) =>
    AttachmentEncryptor.seal(
      plaintext: pt,
      headerHash: hh ?? _hh,
      attachmentId: 'att-0001',
      objectKey: 'u1/abc.bin',
      mime: 'application/octet-stream',
      name: 'abc.bin',
      contentKey: _key,
      baseNonce: _nonce,
      chunkSize: chunkSize,
    );

void main() {
  group('1. 拍板值', () {
    // 设计 §6 决定 ③（2026-07-30 人工拍板）。改动须重新拍板，故钉死。
    test('chunk_size 默认 1 MiB', () {
      expect(AttachmentEncryptor.defaultChunkSize, equals(1024 * 1024));
    });

    test('100MB 上限下块数 ≤ 100（拍板时的依据）', () {
      final n = AttachmentDescriptor.expectedChunkCount(
        AttachmentDescriptor.maxPlainSize,
        AttachmentEncryptor.defaultChunkSize,
      );
      expect(n, lessThanOrEqualTo(100));
    });

    test('随机密钥/nonce 长度正确且不恒定', () {
      final k1 = AttachmentEncryptor.randomContentKey();
      final k2 = AttachmentEncryptor.randomContentKey();
      expect(k1.length, equals(32));
      expect(AttachmentEncryptor.randomBaseNonce().length, equals(12));
      expect(k1, isNot(equals(k2)));
    });
  });

  group('2. 正向可用性：封装后必须能原样开封', () {
    test('各种长度往返（含空、单块、跨块、恰好整除）', () {
      for (final n in [0, 1, 31, 32, 33, 64, 100, 257]) {
        final s = seal(_plain(n));
        expect(
          AttachmentEncryptor.open(
            ciphertext: s.ciphertext,
            descriptor: s.descriptor,
            headerHash: _hh,
          ),
          equals(_plain(n)),
          reason: '$n 字节往返失败',
        );
      }
    });

    test('默认 1 MiB 分块下的大文件往返（跨 3 块）', () {
      final pt = _plain(2 * 1024 * 1024 + 7);
      final s = seal(pt, chunkSize: AttachmentEncryptor.defaultChunkSize);
      expect(s.descriptor.chunkCount, equals(3));
      expect(
        AttachmentEncryptor.open(
          ciphertext: s.ciphertext,
          descriptor: s.descriptor,
          headerHash: _hh,
        ),
        equals(pt),
      );
    });

    test('密文与明文不同，且每块多出 16 字节 tag', () {
      final pt = _plain(100);
      final s = seal(pt);
      expect(s.descriptor.chunkCount, equals(4));
      expect(s.ciphertextSize, equals(100 + 4 * 16));
      expect(s.ciphertext.sublist(0, 32), isNot(equals(pt.sublist(0, 32))));
    });

    test('descriptor 自洽且携带明文哈希（决定 ①：明文哈希只在此处）', () {
      final pt = _plain(100);
      final s = seal(pt);
      expect(s.descriptor.plainSize, equals(100));
      expect(
        s.descriptor.plainSha256,
        equals(Uint8List.fromList(sha256.convert(pt).bytes)),
      );
    });
  });

  group('3. 决定 ①：confirm 只上报密文哈希与密文大小', () {
    test('上报的哈希是密文哈希，且与明文哈希不同', () {
      final pt = _plain(100);
      final s = seal(pt);
      expect(
        s.ciphertextSha256Hex,
        equals(sha256.convert(s.ciphertext).toString()),
      );
      // 关键断言：上报值绝不能等于明文哈希——否则服务端仍可做已知文件识别
      expect(
        s.ciphertextSha256Hex,
        isNot(equals(sha256.convert(pt).toString())),
      );
    });

    test('上报的大小是密文大小，不是明文大小', () {
      final s = seal(_plain(100));
      expect(s.ciphertextSize, equals(s.ciphertext.length));
      expect(s.ciphertextSize, isNot(equals(s.descriptor.plainSize)));
    });

    test('同一明文换一把 key → 上报的密文哈希不同（服务端无法据此去重）', () {
      final pt = _plain(100);
      final a = seal(pt);
      final b = AttachmentEncryptor.seal(
        plaintext: pt,
        headerHash: _hh,
        attachmentId: 'att-0001',
        objectKey: 'u1/abc.bin',
        mime: 'application/octet-stream',
        name: 'abc.bin',
        contentKey: _bytes(0x99, 32),
        baseNonce: _nonce,
        chunkSize: 32,
      );
      expect(a.ciphertextSha256Hex, isNot(equals(b.ciphertextSha256Hex)));
    });
  });

  group('4. 完整性门：任何一项不过都不得返回明文', () {
    late SealedAttachment s;
    setUp(() => s = seal(_plain(100)));

    Uint8List open({Uint8List? ct, AttachmentDescriptor? d, Uint8List? hh}) =>
        AttachmentEncryptor.open(
          ciphertext: ct ?? s.ciphertext,
          descriptor: d ?? s.descriptor,
          headerHash: hh ?? _hh,
        );

    test('参数全对 → 通过（本组正向锚点）', () {
      expect(open(), equals(_plain(100)));
    });

    test('ATT-01：换一条消息的 header_hash → 拒绝', () {
      expect(
        () => open(hh: _bytes(0x34, 32)),
        throwsA(isA<AttachmentSealException>()),
      );
    });

    test('截断：砍掉最后一块 → 拒绝', () {
      final cut = Uint8List.sublistView(
        s.ciphertext,
        0,
        s.ciphertext.length - 48,
      );
      expect(
        () => open(ct: Uint8List.fromList(cut)),
        throwsA(isA<AttachmentSealException>()),
      );
    });

    test('追加：多塞一块的字节 → 拒绝', () {
      final more = Uint8List.fromList([...s.ciphertext, ..._bytes(0, 48)]);
      expect(() => open(ct: more), throwsA(isA<AttachmentSealException>()));
    });

    test('块重排：把第 0 块与第 1 块对调 → 拒绝', () {
      const len = 48; // 32 + 16
      final b = Uint8List.fromList(s.ciphertext);
      for (var i = 0; i < len; i++) {
        final t = b[i];
        b[i] = b[len + i];
        b[len + i] = t;
      }
      expect(() => open(ct: b), throwsA(isA<AttachmentSealException>()));
    });

    test('任一字节被翻转 → 拒绝（逐块各抽一处）', () {
      for (final pos in [0, 48, 96, s.ciphertext.length - 1]) {
        final b = Uint8List.fromList(s.ciphertext)..[pos] ^= 0x01;
        expect(
          () => open(ct: b),
          throwsA(isA<AttachmentSealException>()),
          reason: '偏移 $pos 被翻转仍被接受',
        );
      }
    });

    test('descriptor 谎报明文哈希 → 拒绝（块全过也要拦）', () {
      final bad = AttachmentDescriptor(
        attachmentId: s.descriptor.attachmentId,
        objectKey: s.descriptor.objectKey,
        contentKey: s.descriptor.contentKey,
        cipher: s.descriptor.cipher,
        chunkSize: s.descriptor.chunkSize,
        chunkCount: s.descriptor.chunkCount,
        baseNonce: s.descriptor.baseNonce,
        plainSize: s.descriptor.plainSize,
        plainSha256: _bytes(0xAB, 32),
        mime: s.descriptor.mime,
        name: s.descriptor.name,
      );
      expect(() => open(d: bad), throwsA(isA<AttachmentSealException>()));
    });

    test('换一把 content key → 拒绝', () {
      final bad = AttachmentDescriptor(
        attachmentId: s.descriptor.attachmentId,
        objectKey: s.descriptor.objectKey,
        contentKey: _bytes(0x99, 32),
        cipher: s.descriptor.cipher,
        chunkSize: s.descriptor.chunkSize,
        chunkCount: s.descriptor.chunkCount,
        baseNonce: s.descriptor.baseNonce,
        plainSize: s.descriptor.plainSize,
        plainSha256: s.descriptor.plainSha256,
        mime: s.descriptor.mime,
        name: s.descriptor.name,
      );
      expect(() => open(d: bad), throwsA(isA<AttachmentSealException>()));
    });

    test('空文件也走完整门（1 块、16 字节密文）', () {
      final e = seal(Uint8List(0));
      expect(e.descriptor.chunkCount, equals(1));
      expect(e.ciphertextSize, equals(16));
      expect(
        AttachmentEncryptor.open(
          ciphertext: e.ciphertext,
          descriptor: e.descriptor,
          headerHash: _hh,
        ),
        isEmpty,
      );
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: Uint8List.fromList(e.ciphertext)..[0] ^= 0x01,
          descriptor: e.descriptor,
          headerHash: _hh,
        ),
        throwsA(isA<AttachmentSealException>()),
      );
    });
  });
}
