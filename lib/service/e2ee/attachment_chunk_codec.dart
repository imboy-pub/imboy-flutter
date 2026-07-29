/// E2EE-061 Slice 2 —— 附件分块 AEAD 编解码器（**纯函数，尚未接线**）
///
/// 对齐 `27-e2ee-061-attachment-encryption-design.md` §2.1：
/// - 每块用同一条 content key，nonce 由 `base_nonce` 与 `chunk_index` 派生；
/// - 每块 AAD 绑定 `header_hash + attachment_id + chunk_index + chunk_count`，
///   这是 ATT-01 的直接依据：换一条消息 → header_hash 变 → AAD 失配 → 拒绝打开。
///
/// **本刀不接线**：不碰上传/下载路径、不碰 presign/confirm 契约、不碰协议版本。
/// 接线分别是 Slice 4（上传侧）与 Slice 6（下载侧完整性门）。
///
/// ## 两处「二选一取安全那个」的裁决（理由见 evidence）
///
/// 1. **nonce 派生用 XOR 而非截断拼接**。
///    `base_nonce[0..7] || uint32(index)` 会丢掉 32 bit 随机性；
///    `base_nonce XOR uint32_be(index)`（对齐末 4 字节，RFC 8446 §5.3 的构造）
///    对固定 base_nonce 在 index 上单射，且保留全部 96 bit 熵。
/// 2. **AAD 用已在产的 canonical CBOR 而非字节拼接**。
///    `header_hash || attachment_id || ...` 拼接存在歧义（不同字段切分可拼出同一串），
///    CBOR 每项自带长度前缀，天然无歧义；且 [CanonicalCbor] 已被 PFv3 用于生产并有测试，
///    不引入第三套编码。
library;

import 'dart:typed_data';

import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:pointycastle/api.dart' as api;
import 'package:pointycastle/export.dart';

/// 分块 AEAD 违规。**任何**参数越界、AAD 失配、tag 校验失败都走这里。
///
/// 刻意不区分「tag 错」与「参数错」的对外措辞粒度：解密失败的具体原因
/// 不应成为 oracle。诊断信息只在 [message] 内给开发者看，不进 UI。
class AttachmentChunkException implements Exception {
  final String message;
  AttachmentChunkException(this.message);
  @override
  String toString() => 'AttachmentChunkException: $message';
}

/// 附件分块 AEAD 编解码器。
class AttachmentChunkCodec {
  /// content key 长度：AES-256
  static const int keyLength = 32;

  /// base nonce 长度：GCM 标准 96 bit
  static const int nonceLength = 12;

  /// GCM auth tag 长度：128 bit
  static const int tagLength = 16;

  /// header_hash 长度：SHA-256
  static const int headerHashLength = 32;

  /// 分块数上限。来自 nonce 派生只在末 4 字节叠加计数器——
  /// 超过 uint32 会让不同 index 派生出同一 nonce，**同 key 下 nonce 复用会直接
  /// 摧毁 GCM 的认证性**，因此这是硬边界而非性能建议。
  static const int maxChunkCount = 0xFFFFFFFF;

  /// AAD 的域分隔串。防止本 AAD 结构被复用到别的上下文里仍然验得过。
  static const String aadContext = 'imboy/e2ee/attachment-chunk/v1';

  // ───────────────────────────────────────────────────────────────────────────
  // nonce 派生
  // ───────────────────────────────────────────────────────────────────────────

  /// 由 [baseNonce] 与 [chunkIndex] 派生本块 nonce。
  ///
  /// 构造：`base_nonce XOR (0^8 || uint32_be(chunk_index))`。
  /// 对固定 [baseNonce] 在 [chunkIndex] 上单射 —— 这正是「同 key 不复用 nonce」
  /// 的依据。
  static Uint8List deriveNonce(Uint8List baseNonce, int chunkIndex) {
    if (baseNonce.length != nonceLength) {
      throw AttachmentChunkException(
        'base_nonce 必须为 $nonceLength 字节，实际 ${baseNonce.length}',
      );
    }
    if (chunkIndex < 0 || chunkIndex > maxChunkCount) {
      throw AttachmentChunkException(
        'chunk_index 越界：$chunkIndex 不在 [0, $maxChunkCount]',
      );
    }

    final nonce = Uint8List.fromList(baseNonce);
    nonce[8] ^= (chunkIndex >> 24) & 0xFF;
    nonce[9] ^= (chunkIndex >> 16) & 0xFF;
    nonce[10] ^= (chunkIndex >> 8) & 0xFF;
    nonce[11] ^= chunkIndex & 0xFF;
    return nonce;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AAD 构造
  // ───────────────────────────────────────────────────────────────────────────

  /// 构造本块 AAD（canonical CBOR，确定性编码）。
  ///
  /// 绑定四项 + 域分隔串：
  /// - [headerHash]：PFv3 protected header 的 SHA-256 —— **ATT-01**，
  ///   密文块被搬到另一条消息下必然失配；
  /// - [attachmentId]：同一条消息内多个附件之间不可互换；
  /// - [chunkIndex]：**块重排**必然失配；
  /// - [chunkCount]：**块截断**必然失配（少几块 ⇒ 声明的总数对不上）。
  static Uint8List buildAad({
    required Uint8List headerHash,
    required String attachmentId,
    required int chunkIndex,
    required int chunkCount,
  }) {
    if (headerHash.length != headerHashLength) {
      throw AttachmentChunkException(
        'header_hash 必须为 $headerHashLength 字节，实际 ${headerHash.length}',
      );
    }
    if (attachmentId.isEmpty) {
      throw AttachmentChunkException('attachment_id 不得为空');
    }
    if (chunkCount < 1 || chunkCount > maxChunkCount) {
      throw AttachmentChunkException(
        'chunk_count 越界：$chunkCount 不在 [1, $maxChunkCount]',
      );
    }
    if (chunkIndex < 0 || chunkIndex >= chunkCount) {
      throw AttachmentChunkException(
        'chunk_index 越界：$chunkIndex 不在 [0, $chunkCount)',
      );
    }

    return CanonicalCbor.encode({
      'ctx': aadContext,
      'header_hash': headerHash,
      'attachment_id': attachmentId,
      'chunk_index': chunkIndex,
      'chunk_count': chunkCount,
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 加密 / 解密
  // ───────────────────────────────────────────────────────────────────────────

  /// 加密一块。返回 `ciphertext || tag`（GCM 惯例，tag 在尾部 16 字节）。
  ///
  /// [plaintext] 允许为空（0 字节块仍产出 16 字节 tag），由调用方决定是否分出空块。
  static Uint8List encryptChunk({
    required Uint8List plaintext,
    required Uint8List contentKey,
    required Uint8List baseNonce,
    required Uint8List headerHash,
    required String attachmentId,
    required int chunkIndex,
    required int chunkCount,
  }) {
    _requireKey(contentKey);
    final nonce = deriveNonce(baseNonce, chunkIndex);
    final aad = buildAad(
      headerHash: headerHash,
      attachmentId: attachmentId,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        api.AEADParameters(KeyParameter(contentKey), tagLength * 8, nonce, aad),
      );
    return cipher.process(plaintext);
  }

  /// 解密一块。[sealed] 为 `ciphertext || tag`。
  ///
  /// 失败一律抛 [AttachmentChunkException]，**绝不返回部分明文**：
  /// GCM 的明文只有在 tag 校验通过后才可信，提前返回等于把未认证字节交给上层。
  static Uint8List decryptChunk({
    required Uint8List sealed,
    required Uint8List contentKey,
    required Uint8List baseNonce,
    required Uint8List headerHash,
    required String attachmentId,
    required int chunkIndex,
    required int chunkCount,
  }) {
    _requireKey(contentKey);
    if (sealed.length < tagLength) {
      throw AttachmentChunkException(
        '密文块长度 ${sealed.length} < tag 长度 $tagLength',
      );
    }
    final nonce = deriveNonce(baseNonce, chunkIndex);
    final aad = buildAad(
      headerHash: headerHash,
      attachmentId: attachmentId,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        api.AEADParameters(KeyParameter(contentKey), tagLength * 8, nonce, aad),
      );
    try {
      return cipher.process(sealed);
    } on Object catch (e) {
      // InvalidCipherTextException 及任何其他失败都收敛成同一个异常类型。
      throw AttachmentChunkException('块认证失败（AAD/nonce/密钥/密文不匹配）: $e');
    }
  }

  static void _requireKey(Uint8List key) {
    if (key.length != keyLength) {
      throw AttachmentChunkException(
        'content key 必须为 $keyLength 字节，实际 ${key.length}',
      );
    }
  }
}
