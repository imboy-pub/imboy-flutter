/// E2EE-061 Slice 3 —— `attachment_descriptor` 结构 / canonical 编码 / 严格 parser
///
/// 对齐 `27-e2ee-061-attachment-encryption-design.md` §2.1。**纯函数，尚未接线**。
///
/// descriptor 本身住在**加密的** payload 里，随 PFv3 一起被认证——因此它不需要
/// 自带签名。本模块的职责是**严格性**：descriptor 的每个字段都是 [AttachmentChunkCodec]
/// 的输入，一个被静默接受的坏字段会直接变成解密侧的洞或一堆看不懂的失败。
/// 因此 parser 一律 fail-closed，**不做任何强制转换、不填任何默认值**。
///
/// ⚠️ **`chunk_size` 的取值不在本模块**：它是设计 §6 三项人工拍板之一。
/// 本模块只校验「≥1 且不超过单次上传上限」，**不设默认值、不建议取值**。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';
import 'package:imboy/store/api/attachment_api.dart';

/// descriptor 解析违规。
class AttachmentDescriptorException implements Exception {
  final String message;
  AttachmentDescriptorException(this.message);
  @override
  String toString() => 'AttachmentDescriptorException: $message';
}

/// 单个附件的加密描述符。缩略图是同结构的独立实例（独立 content key）。
class AttachmentDescriptor {
  /// 本模块唯一支持的套件。**不做协商**：多一个可选值就多一条降级路径。
  static const String supportedCipher = 'AES-256-GCM';

  /// 明文大小上限，对齐 `AttachmentApi.maxUploadBytes`（不另立一套数字）。
  static const int maxPlainSize = AttachmentApi.maxUploadBytes;

  /// SHA-256 摘要长度。**不再借用 [AttachmentChunkCodec] 的绑定值长度常量**——
  /// 二者恰好都是 32 字节，但语义无关（一个是明文哈希，一个是 AAD 绑定值），
  /// 借用会让将来任一方改长度时另一方被无声带偏。
  static const int sha256Length = 32;

  final String attachmentId;
  final String objectKey;
  final Uint8List contentKey;
  final String cipher;
  final int chunkSize;
  final int chunkCount;
  final Uint8List baseNonce;
  final int plainSize;
  final Uint8List plainSha256;
  final String mime;
  final String name;

  /// 缩略图描述符。**必须有独立 content key**（设计 §3.3：缩略图不加密 = 预览即泄漏）。
  final AttachmentDescriptor? thumb;

  AttachmentDescriptor({
    required this.attachmentId,
    required this.objectKey,
    required this.contentKey,
    required this.cipher,
    required this.chunkSize,
    required this.chunkCount,
    required this.baseNonce,
    required this.plainSize,
    required this.plainSha256,
    required this.mime,
    required this.name,
    this.thumb,
  }) {
    _validate(this);
  }

  /// 按 [plainSize] 与 [chunkSize] 算出**唯一合法**的 chunk_count。
  ///
  /// 空文件取 1 而非 0：0 块意味着**一个字节都没有被认证**，
  /// 那样一个空附件的 AEAD 保护形同虚设。
  static int expectedChunkCount(int plainSize, int chunkSize) {
    if (chunkSize < 1) {
      throw AttachmentDescriptorException('chunk_size 必须 ≥1，实际 $chunkSize');
    }
    if (plainSize <= 0) return 1;
    return (plainSize + chunkSize - 1) ~/ chunkSize;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 严格校验
  // ───────────────────────────────────────────────────────────────────────────

  static void _validate(AttachmentDescriptor d) {
    void reject(String why) => throw AttachmentDescriptorException(why);

    if (d.attachmentId.isEmpty) reject('attachment_id 不得为空');
    if (d.objectKey.isEmpty) reject('object_key 不得为空');
    if (d.mime.isEmpty) reject('mime 不得为空');
    if (d.name.isEmpty) reject('name 不得为空');

    if (d.cipher != supportedCipher) {
      reject('cipher 只支持 $supportedCipher，实际 "${d.cipher}"');
    }
    if (d.contentKey.length != AttachmentChunkCodec.keyLength) {
      reject(
        'content_key 必须 ${AttachmentChunkCodec.keyLength} 字节，'
        '实际 ${d.contentKey.length}',
      );
    }
    if (d.baseNonce.length != AttachmentChunkCodec.nonceLength) {
      reject(
        'base_nonce 必须 ${AttachmentChunkCodec.nonceLength} 字节，'
        '实际 ${d.baseNonce.length}',
      );
    }
    if (d.plainSha256.length != sha256Length) {
      reject(
        'plain_sha256 必须 $sha256Length 字节，'
        '实际 ${d.plainSha256.length}',
      );
    }

    if (d.plainSize < 0 || d.plainSize > maxPlainSize) {
      reject('plain_size 越界：${d.plainSize} 不在 [0, $maxPlainSize]');
    }
    if (d.chunkSize < 1 || d.chunkSize > maxPlainSize) {
      reject('chunk_size 越界：${d.chunkSize} 不在 [1, $maxPlainSize]');
    }
    if (d.chunkCount < 1 || d.chunkCount > AttachmentChunkCodec.maxChunkCount) {
      reject(
        'chunk_count 越界：${d.chunkCount} 不在 '
        '[1, ${AttachmentChunkCodec.maxChunkCount}]',
      );
    }

    // 这一条是「谎报块数以截断」的直接闸门：chunk_count 进每块 AAD，
    // 但 AAD 只保证「发送方当初声明的那个数」，不保证那个数与文件本身自洽。
    final expected = expectedChunkCount(d.plainSize, d.chunkSize);
    if (d.chunkCount != expected) {
      reject(
        'chunk_count 与 plain_size/chunk_size 不自洽：'
        '声明 ${d.chunkCount}，由 ${d.plainSize}/${d.chunkSize} 应为 $expected',
      );
    }

    // 缩略图必须是独立密钥，且不得再套一层缩略图（防无界嵌套）。
    final t = d.thumb;
    if (t != null) {
      if (t.thumb != null) reject('thumb 不得再嵌套 thumb');
      if (_sameBytes(t.contentKey, d.contentKey)) {
        reject('thumb 必须使用独立的 content_key，不得与主体复用');
      }
      if (_sameBytes(t.baseNonce, d.baseNonce)) {
        // 同 key 才致命，但复用 nonce 是明确的错误信号，一并拒。
        reject('thumb 必须使用独立的 base_nonce');
      }
    }
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 编解码
  // ───────────────────────────────────────────────────────────────────────────

  static const Set<String> _keys = {
    'attachment_id',
    'object_key',
    'content_key',
    'cipher',
    'chunk_size',
    'chunk_count',
    'base_nonce',
    'plain_size',
    'plain_sha256',
    'mime',
    'name',
    'thumb',
  };

  Map<String, dynamic> toMap() => {
    'attachment_id': attachmentId,
    'object_key': objectKey,
    'content_key': base64Url.encode(contentKey),
    'cipher': cipher,
    'chunk_size': chunkSize,
    'chunk_count': chunkCount,
    'base_nonce': base64Url.encode(baseNonce),
    'plain_size': plainSize,
    'plain_sha256': base64Url.encode(plainSha256),
    'mime': mime,
    'name': name,
    if (thumb != null) 'thumb': thumb!.toMap(),
  };

  /// 严格 parser。**未知字段一律拒收**——静默忽略未知字段等于给未来的降级
  /// 字段留了一条无人看守的入口。
  factory AttachmentDescriptor.fromMap(Map<String, dynamic> m) {
    for (final k in m.keys) {
      if (!_keys.contains(k)) {
        throw AttachmentDescriptorException('未知字段 "$k"');
      }
    }

    T req<T>(String k) {
      if (!m.containsKey(k)) {
        throw AttachmentDescriptorException('缺少必填字段 "$k"');
      }
      final v = m[k];
      if (v is! T) {
        throw AttachmentDescriptorException(
          '字段 "$k" 类型应为 $T，实际 ${v.runtimeType}',
        );
      }
      return v;
    }

    Uint8List b64(String k) {
      final s = req<String>(k);
      try {
        return Uint8List.fromList(base64Url.decode(s));
      } on FormatException catch (e) {
        throw AttachmentDescriptorException('字段 "$k" 不是合法 base64url: $e');
      }
    }

    AttachmentDescriptor? thumb;
    if (m.containsKey('thumb')) {
      final raw = m['thumb'];
      if (raw is! Map<String, dynamic>) {
        throw AttachmentDescriptorException('thumb 必须是 map');
      }
      thumb = AttachmentDescriptor.fromMap(raw);
    }

    return AttachmentDescriptor(
      attachmentId: req<String>('attachment_id'),
      objectKey: req<String>('object_key'),
      contentKey: b64('content_key'),
      cipher: req<String>('cipher'),
      chunkSize: req<int>('chunk_size'),
      chunkCount: req<int>('chunk_count'),
      baseNonce: b64('base_nonce'),
      plainSize: req<int>('plain_size'),
      plainSha256: b64('plain_sha256'),
      mime: req<String>('mime'),
      name: req<String>('name'),
      thumb: thumb,
    );
  }

  /// canonical CBOR 字节（确定性：同一 descriptor 恒产出同一串）。
  /// 复用 PFv3 已在产的编码器，不引入第三套。
  Uint8List toCanonicalBytes() => CanonicalCbor.encode(toMap());

  static AttachmentDescriptor fromCanonicalBytes(Uint8List bytes) {
    final dynamic decoded;
    try {
      decoded = CanonicalCbor.decode(bytes, strict: true);
    } on CborParseException catch (e) {
      throw AttachmentDescriptorException('CBOR 非法: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw AttachmentDescriptorException('顶层不是 map');
    }
    return AttachmentDescriptor.fromMap(decoded);
  }

  /// ⚠️ **刻意不包含 `content_key` 与 `base_nonce`**。
  /// HOTFIX-01 的教训是日志/异常里不得出现消息正文；descriptor 里躺着的是
  /// **能解开整个附件的密钥**，一次 `'$descriptor'` 就足以把它写进日志。
  @override
  String toString() =>
      'AttachmentDescriptor(attachment_id: $attachmentId, '
      'object_key: $objectKey, cipher: $cipher, '
      'chunk_size: $chunkSize, chunk_count: $chunkCount, '
      'plain_size: $plainSize, mime: $mime, '
      'has_thumb: ${thumb != null}, content_key: <redacted>, '
      'base_nonce: <redacted>)';
}
