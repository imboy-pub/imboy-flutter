/// E2EE-061 —— 附件封装/开封的编排（纯函数，**尚未接线**）
///
/// 把 Slice 2 的分块 AEAD（[AttachmentChunkCodec]）与 Slice 3 的
/// [AttachmentDescriptor] 组合成整文件级的两个操作：
///
/// - [seal]：明文字节 → `ciphertext || 每块 tag` + descriptor；
/// - [open]：密文 + descriptor → 明文，**全部完整性校验通过后**才返回。
///
/// 这是 Slice 4（上传侧接线）与 Slice 6（下载侧完整性门）**共同的纯函数内核**：
/// 先把它单独做成可穷举验收的一块，接线那一刀就只剩「从哪儿拿字节、往哪儿写」。
///
/// ⚠️ **本模块不接线、不做网络 IO、不生成也不保管密钥的存储**。
/// `contentKey` / `baseNonce` 由调用方提供（[randomContentKey] / [randomBaseNonce]
/// 是便利构造，用 [Random.secure]）。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';

/// 开封失败。**不区分失败原因的对外粒度**：具体哪一步不过不应成为 oracle。
class AttachmentSealException implements Exception {
  final String message;
  AttachmentSealException(this.message);
  @override
  String toString() => 'AttachmentSealException: $message';
}

/// [AttachmentEncryptor.seal] 的产物。
class SealedAttachment {
  /// 直传对象的字节：各块 `ciphertext||tag` 顺序拼接。
  final Uint8List ciphertext;

  /// 随 PFv3 加密 payload 一起发送的描述符。
  final AttachmentDescriptor descriptor;

  const SealedAttachment(this.ciphertext, this.descriptor);

  /// confirm 上报的**密文**哈希（决定 ①：明文哈希不上报服务端）。
  String get ciphertextSha256Hex => sha256.convert(ciphertext).toString();

  /// confirm 上报的**密文**大小（密文大小 ≠ 明文大小）。
  int get ciphertextSize => ciphertext.length;
}

class AttachmentEncryptor {
  /// 分块大小。**已由人工拍板为 1 MiB**（设计 §6 决定 ③，2026-07-30）。
  /// 100MB 上限 → ≤100 块；descriptor 元数据小、单块峰值内存可控。
  /// 改动须重新拍板。
  static const int defaultChunkSize = 1024 * 1024;

  static final Random _rng = Random.secure();

  static Uint8List randomContentKey() =>
      _randomBytes(AttachmentChunkCodec.keyLength);

  static Uint8List randomBaseNonce() =>
      _randomBytes(AttachmentChunkCodec.nonceLength);

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  /// 封装整个附件。
  ///
  /// [bindingHash] 是 PFv3 protected header 的 SHA-256——**ATT-01 的锚点**：
  /// 密文块被搬到另一条消息下时 AAD 必然失配。
  static SealedAttachment seal({
    required Uint8List plaintext,
    required Uint8List bindingHash,
    required String attachmentId,
    required String objectKey,
    required String mime,
    required String name,
    required Uint8List contentKey,
    required Uint8List baseNonce,
    int chunkSize = defaultChunkSize,
  }) {
    final chunkCount = AttachmentDescriptor.expectedChunkCount(
      plaintext.length,
      chunkSize,
    );

    final out = BytesBuilder();
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      final end = start + chunkSize;
      final slice = Uint8List.sublistView(
        plaintext,
        start > plaintext.length ? plaintext.length : start,
        end > plaintext.length ? plaintext.length : end,
      );
      out.add(
        AttachmentChunkCodec.encryptChunk(
          plaintext: Uint8List.fromList(slice),
          contentKey: contentKey,
          baseNonce: baseNonce,
          bindingHash: bindingHash,
          attachmentId: attachmentId,
          chunkIndex: i,
          chunkCount: chunkCount,
        ),
      );
    }

    final descriptor = AttachmentDescriptor(
      attachmentId: attachmentId,
      objectKey: objectKey,
      contentKey: contentKey,
      cipher: AttachmentDescriptor.supportedCipher,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      baseNonce: baseNonce,
      plainSize: plaintext.length,
      plainSha256: Uint8List.fromList(sha256.convert(plaintext).bytes),
      mime: mime,
      name: name,
    );

    return SealedAttachment(out.toBytes(), descriptor);
  }

  /// 开封整个附件。**ADR 15 §9 的完整性门**：块数量、每块 tag、
  /// 明文大小与明文 hash **全部通过后**才把字节交给上层；任何一项不过即抛，
  /// **绝不返回部分明文**（未认证的字节交给预览器，等于加密白做）。
  static Uint8List open({
    required Uint8List ciphertext,
    required AttachmentDescriptor descriptor,
    required Uint8List bindingHash,
  }) {
    final d = descriptor;
    final sealedChunkLen = d.chunkSize + AttachmentChunkCodec.tagLength;

    // 密文总长必须与「chunk_count 个块、最后一块可短」精确吻合。
    // 这一条挡的是**块被增删**：多一块少一块，总长必然对不上。
    final fullChunks = d.chunkCount - 1;
    final lastPlain = d.plainSize - fullChunks * d.chunkSize;
    if (lastPlain < 0 || lastPlain > d.chunkSize) {
      throw AttachmentSealException('descriptor 自身不自洽：末块明文长度 $lastPlain');
    }
    final expectedLen =
        fullChunks * sealedChunkLen +
        lastPlain +
        AttachmentChunkCodec.tagLength;
    if (ciphertext.length != expectedLen) {
      throw AttachmentSealException(
        '密文长度 ${ciphertext.length} != 期望 $expectedLen（块被增删或截断）',
      );
    }

    final out = BytesBuilder();
    for (var i = 0; i < d.chunkCount; i++) {
      final start = i * sealedChunkLen;
      final isLast = i == d.chunkCount - 1;
      final end = isLast ? ciphertext.length : start + sealedChunkLen;
      final Uint8List plain;
      try {
        plain = AttachmentChunkCodec.decryptChunk(
          sealed: Uint8List.fromList(
            Uint8List.sublistView(ciphertext, start, end),
          ),
          contentKey: d.contentKey,
          baseNonce: d.baseNonce,
          bindingHash: bindingHash,
          attachmentId: d.attachmentId,
          chunkIndex: i,
          chunkCount: d.chunkCount,
        );
      } on AttachmentChunkException catch (e) {
        throw AttachmentSealException('第 $i 块认证失败: ${e.message}');
      }
      out.add(plain);
    }

    final plaintext = out.toBytes();
    if (plaintext.length != d.plainSize) {
      throw AttachmentSealException(
        '明文大小 ${plaintext.length} != 声明 ${d.plainSize}',
      );
    }
    final actual = Uint8List.fromList(sha256.convert(plaintext).bytes);
    if (!_constantTimeEquals(actual, d.plainSha256)) {
      throw AttachmentSealException('明文 SHA-256 与 descriptor 声明不符');
    }
    return plaintext;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
