/// 面聊记录（talk_record）T09 —— 录音段加密（复用现有 AES-256-GCM 设施）。
///
/// 密钥模型（T09 卡：段文件加密落盘，密钥每记录派生，存 secure storage）：
/// - 每个本地录音会话一条 256-bit `recordKey`（Random.secure）；
/// - 段 `baseNonce` 由 recordKey 经 HMAC-SHA256 PRF 按段序号确定性派生
///   （同 key 下不同段 nonce 单射——避免跨段 nonce 复用摧毁 GCM 认证性，
///   与 [AttachmentChunkCodec.deriveNonce] 的单射论证同构）；
/// - AAD 绑定值 bindingHash = SHA-256(域分隔串 + sessionId)，
///   段被搬到别的会话目录下必然解封失败；
/// - 加密封块复用 [AttachmentEncryptor.sealToFile]/[openToFile]
///   （AES-256-GCM 分块 AEAD、密文 full SHA-256、原子 rename、
///   解封前全量完整性门——与附件上传链同一套冻结套件）。
///
/// recordKey 只进 secure storage（经 [TalkRecordKeyStore] 抽象），
/// 绝不进 manifest/SQLite。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';

/// recordKey 安全存取抽象（生产 secure storage / 测试内存实现）。
abstract class TalkRecordKeyStore {
  Future<void> writeRecordKey(String sessionId, Uint8List key);
  Future<Uint8List?> readRecordKey(String sessionId);
  Future<void> deleteRecordKey(String sessionId);
}

/// 段加解密失败统一出口（不区分粒度，防 oracle）。
class TalkRecordSegmentCryptoException implements Exception {
  final String message;
  TalkRecordSegmentCryptoException(this.message);
  @override
  String toString() => 'TalkRecordSegmentCryptoException: $message';
}

/// 段加密元数据（manifest 落盘项，重建 descriptor 用）。
class TalkRecordSegmentCipherInfo {
  final int plainSize;
  final String plainSha256Hex;
  final int cipherSize;
  final String cipherSha256Hex;

  const TalkRecordSegmentCipherInfo({
    required this.plainSize,
    required this.plainSha256Hex,
    required this.cipherSize,
    required this.cipherSha256Hex,
  });
}

class TalkRecordSegmentCrypto {
  TalkRecordSegmentCrypto._();

  static const String _bindingDomain = 'imboy/talk-record/binding/v1';
  static const String _nonceDomain = 'imboy/talk-record/segment-nonce/v1';

  /// 生成每记录 256-bit 密钥。
  static Uint8List generateRecordKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  }

  /// 会话 AAD 绑定值：SHA-256(域分隔 | sessionId)。
  static Uint8List bindingHashFor(String sessionId) {
    return Uint8List.fromList(
      sha256.convert(utf8.encode('$_bindingDomain|$sessionId')).bytes,
    );
  }

  /// 段 baseNonce：HMAC-SHA256(recordKey, 域分隔|sessionId|seq) 截 12 字节。
  ///
  /// PRF 输出在 seq 上单射（概率意义），同 recordKey 下跨段无 nonce 复用；
  /// 确定性派生 → 恢复时只需 secure storage 里的一条 recordKey。
  static Uint8List segmentBaseNonce(
    Uint8List recordKey,
    String sessionId,
    int seq,
  ) {
    final mac = Hmac(sha256, recordKey);
    final digest = mac.convert(utf8.encode('$_nonceDomain|$sessionId|$seq'));
    return Uint8List.fromList(digest.bytes.sublist(0, 12));
  }

  /// 加密一段：明文段文件 → 密文段文件（原子落盘），返回密文元数据。
  ///
  /// attachmentId/objectKey 按 sessionId+seq 确定性生成，AAD 域内唯一。
  static Future<TalkRecordSegmentCipherInfo> sealSegment({
    required File plainFile,
    required File cipherFile,
    required Uint8List recordKey,
    required String sessionId,
    required int seq,
    required String mime,
  }) async {
    try {
      final sealed = await AttachmentEncryptor.sealToFile(
        plaintextFile: plainFile,
        cipherFile: cipherFile,
        bindingHash: bindingHashFor(sessionId),
        attachmentId: attachmentIdFor(sessionId, seq),
        objectKey: objectKeyFor(sessionId, seq),
        mime: mime,
        name: plainFileNameFor(seq),
        contentKey: recordKey,
        baseNonce: segmentBaseNonce(recordKey, sessionId, seq),
      );
      return TalkRecordSegmentCipherInfo(
        plainSize: sealed.descriptor.plainSize,
        plainSha256Hex: _hex(sealed.descriptor.plainSha256),
        cipherSize: sealed.ciphertextSize,
        cipherSha256Hex: sealed.ciphertextSha256Hex,
      );
    } on TalkRecordSegmentCryptoException {
      rethrow;
    } catch (e) {
      throw TalkRecordSegmentCryptoException('段加密失败: $e');
    }
  }

  /// 解封一段（全量完整性门通过后原子写出明文；失败不产出部分明文）。
  static Future<void> openSegment({
    required File cipherFile,
    required File plainOutFile,
    required Uint8List recordKey,
    required String sessionId,
    required int seq,
    required TalkRecordSegmentCipherInfo info,
    required String mime,
  }) async {
    try {
      await AttachmentEncryptor.openToFile(
        cipherFile: cipherFile,
        plaintextOut: plainOutFile,
        bindingHash: bindingHashFor(sessionId),
        descriptor: _descriptorFor(
          recordKey: recordKey,
          sessionId: sessionId,
          seq: seq,
          info: info,
          mime: mime,
        ),
      );
    } on TalkRecordSegmentCryptoException {
      rethrow;
    } catch (e) {
      throw TalkRecordSegmentCryptoException('段解封失败: $e');
    }
  }

  /// 校验一段密文（不写明文）：大小与 full SHA-256 对 manifest 记录。
  static Future<bool> verifySegment({
    required File cipherFile,
    required TalkRecordSegmentCipherInfo info,
  }) async {
    if (!cipherFile.existsSync()) return false;
    if (cipherFile.lengthSync() != info.cipherSize) return false;
    final digest = await sha256.bind(cipherFile.openRead()).first;
    return digest.toString() == info.cipherSha256Hex;
  }

  static AttachmentDescriptor _descriptorFor({
    required Uint8List recordKey,
    required String sessionId,
    required int seq,
    required TalkRecordSegmentCipherInfo info,
    required String mime,
  }) {
    return AttachmentDescriptor(
      attachmentId: attachmentIdFor(sessionId, seq),
      objectKey: objectKeyFor(sessionId, seq),
      contentKey: recordKey,
      cipher: AttachmentDescriptor.supportedCipher,
      chunkSize: AttachmentEncryptor.defaultChunkSize,
      chunkCount: AttachmentDescriptor.expectedChunkCount(
        info.plainSize,
        AttachmentEncryptor.defaultChunkSize,
      ),
      baseNonce: segmentBaseNonce(recordKey, sessionId, seq),
      plainSize: info.plainSize,
      plainSha256: _bytes(info.plainSha256Hex),
      mime: mime,
      name: plainFileNameFor(seq),
    );
  }

  static String attachmentIdFor(String sessionId, int seq) =>
      '$sessionId/seg/$seq';

  static String objectKeyFor(String sessionId, int seq) =>
      'talk_record/$sessionId/seg_${seq.toString().padLeft(6, '0')}.aac';

  static String plainFileNameFor(int seq) =>
      'seg_${seq.toString().padLeft(6, '0')}.aac';

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _bytes(String hex) => Uint8List.fromList(
    List<int>.generate(
      hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
}
