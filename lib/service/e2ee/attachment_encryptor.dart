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

import 'dart:io';
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

/// [AttachmentEncryptor.sealToFile] 的产物：密文落盘文件 + descriptor。
class SealedAttachmentFile {
  /// 密文文件（写完 .part 原子 rename 后的最终路径；同 session 复用同文件）。
  final File cipherFile;

  /// 随 PFv3 加密 payload 一起发送的描述符（与内存版同构）。
  final AttachmentDescriptor descriptor;

  /// confirm 上报的**密文**哈希（连续真实字节的 full SHA-256）。
  final String ciphertextSha256Hex;

  /// confirm 上报的**密文**大小。
  final int ciphertextSize;

  const SealedAttachmentFile({
    required this.cipherFile,
    required this.descriptor,
    required this.ciphertextSha256Hex,
    required this.ciphertextSize,
  });
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
  /// [thumb]（E2EE-061 Slice 7）：**已封装好的缩略图** descriptor，挂进本 descriptor。
  /// 设计 §3.3：缩略图是独立对象，不加密 = 预览即泄漏，ATT-04 在缩略图上直接失败。
  /// 它必须有**独立的 content_key / base_nonce**——由
  /// [AttachmentDescriptor] 的构造校验强制，这里不重复判断。
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
    AttachmentDescriptor? thumb,
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
      thumb: thumb,
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

  // ===================================================================
  // 文件化 seal/open（step-9，协议 §5.2 / R04）：
  //   * 密文一次生成写入受控文件；对连续真实字节流增量 SHA（分块 hash
  //     不拼接冒充 full hash）；
  //   * 同 session 复用同密文文件：cipher 路径由调用方确定性给定，本层
  //     不重随机（key/nonce 由调用方传入，同 key 同 nonce 同输入逐字节
  //     等价于内存版）；
  //   * 解密写隔离临时文件，全部 tag/大小/full hash 通过后原子 rename
  //     暴露；失败前预览器拿不到未认证明文（协议 5.2）。
  // ===================================================================

  /// [seal] 的文件化版本：逐块流式加密写 [cipherFile]（明文不整读）。
  /// 输出与 [seal] 同输入下**逐字节等价**（同 chunk codec/块序/nonce 派生）。
  static Future<SealedAttachmentFile> sealToFile({
    required File plaintextFile,
    required File cipherFile,
    required Uint8List bindingHash,
    required String attachmentId,
    required String objectKey,
    required String mime,
    required String name,
    required Uint8List contentKey,
    required Uint8List baseNonce,
    int chunkSize = defaultChunkSize,
    AttachmentDescriptor? thumb,
  }) async {
    final int plainSize = plaintextFile.lengthSync();
    final chunkCount = AttachmentDescriptor.expectedChunkCount(
      plainSize,
      chunkSize,
    );
    final File tmp = File('${cipherFile.path}.part');

    final IOSink out = tmp.openWrite();
    // cipher full hash 写完后对流式复算（openRead 有界内存），保证是连续
    // 真实字节的 hash 而非分块 hash 拼接（协议 5.2）。
    int written = 0;
    try {
      for (var i = 0; i < chunkCount; i++) {
        final int start = i * chunkSize;
        final int end = (start + chunkSize) > plainSize
            ? plainSize
            : start + chunkSize;
        final Uint8List slice = _readSlice(plaintextFile, start, end);
        final Uint8List sealed = AttachmentChunkCodec.encryptChunk(
          plaintext: slice,
          contentKey: contentKey,
          baseNonce: baseNonce,
          bindingHash: bindingHash,
          attachmentId: attachmentId,
          chunkIndex: i,
          chunkCount: chunkCount,
        );
        out.add(sealed);
        written += sealed.length;
      }
      await out.flush();
      await out.close();
      final Digest cipherDigest = await _fileDigest(tmp);
      await tmp.rename(cipherFile.path);
      final descriptor = AttachmentDescriptor(
        attachmentId: attachmentId,
        objectKey: objectKey,
        contentKey: contentKey,
        cipher: AttachmentDescriptor.supportedCipher,
        chunkSize: chunkSize,
        chunkCount: chunkCount,
        baseNonce: baseNonce,
        plainSize: plainSize,
        plainSha256: Uint8List.fromList(
          (await _fileDigest(plaintextFile)).bytes,
        ),
        mime: mime,
        name: name,
        thumb: thumb,
      );
      return SealedAttachmentFile(
        cipherFile: cipherFile,
        descriptor: descriptor,
        ciphertextSha256Hex: cipherDigest.toString(),
        ciphertextSize: written,
      );
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
  }

  /// [open] 的文件化版本：流式解密到**隔离临时文件**，全部块 tag、
  /// 明文大小与 full hash 通过后原子 rename 到 [plaintextOut]。
  /// 任何一步失败：删除临时文件并抛出——预览器/业务拿不到未认证明文。
  static Future<void> openToFile({
    required File cipherFile,
    required File plaintextOut,
    required AttachmentDescriptor descriptor,
    required Uint8List bindingHash,
  }) async {
    final d = descriptor;
    final int sealedChunkLen = d.chunkSize + AttachmentChunkCodec.tagLength;
    final int fullChunks = d.chunkCount - 1;
    final int lastPlain = d.plainSize - fullChunks * d.chunkSize;
    if (lastPlain < 0 || lastPlain > d.chunkSize) {
      throw AttachmentSealException('descriptor 自身不自洽：末块明文长度 $lastPlain');
    }
    final int expectedLen =
        fullChunks * sealedChunkLen +
        lastPlain +
        AttachmentChunkCodec.tagLength;
    final int cipherLen = cipherFile.lengthSync();
    if (cipherLen != expectedLen) {
      throw AttachmentSealException(
        '密文长度 $cipherLen != 期望 $expectedLen（块被增删或截断）',
      );
    }

    final File tmp = File('${plaintextOut.path}.part');
    final RandomAccessFile raf = cipherFile.openSync();
    final IOSink out = tmp.openWrite();
    try {
      for (var i = 0; i < d.chunkCount; i++) {
        final int start = i * sealedChunkLen;
        final bool isLast = i == d.chunkCount - 1;
        final int end = isLast ? cipherLen : start + sealedChunkLen;
        raf.setPositionSync(start);
        final Uint8List sealedChunk = raf.readSync(end - start);
        final Uint8List plain;
        try {
          plain = AttachmentChunkCodec.decryptChunk(
            sealed: sealedChunk,
            contentKey: d.contentKey,
            baseNonce: d.baseNonce,
            bindingHash: bindingHash,
            attachmentId: d.attachmentId,
            chunkIndex: i,
            chunkCount: d.chunkCount,
          );
        } on AttachmentChunkException {
          // 不区分失败粒度（同 [open] 的对外语义）：哪一块失败不成为 oracle
          throw AttachmentSealException('第 $i 块认证失败');
        }
        out.add(plain);
      }
      await out.flush();
      await out.close();
      // full hash：对流式落盘的连续明文整体计算（非分块拼接）
      final Digest actual = await _fileDigest(tmp);
      if (actual.bytes.length != d.plainSha256.length ||
          !_constantTimeEquals(
            Uint8List.fromList(actual.bytes),
            d.plainSha256,
          )) {
        throw AttachmentSealException('明文 SHA-256 与 descriptor 声明不符');
      }
      if (tmp.lengthSync() != d.plainSize) {
        throw AttachmentSealException(
          '明文大小 ${tmp.lengthSync()} != 声明 ${d.plainSize}',
        );
      }
      tmp.renameSync(plaintextOut.path);
    } catch (_) {
      try {
        await out.close();
      } catch (_) {}
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    } finally {
      raf.closeSync();
    }
  }

  static Uint8List _readSlice(File f, int start, int end) {
    final RandomAccessFile raf = f.openSync();
    try {
      raf.setPositionSync(start);
      return raf.readSync(end - start);
    } finally {
      raf.closeSync();
    }
  }

  /// 连续真实字节的 full SHA-256（openRead 有界内存流式，非分块拼接）。
  static Future<Digest> _fileDigest(File f) => sha256.bind(f.openRead()).first;
}
