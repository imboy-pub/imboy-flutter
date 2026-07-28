/// S2.1 Protected Frame v3 — Canonical CBOR Codec + Frame Builder
///
/// ADR 15 §3: RFC 8949 deterministic CBOR encoding for protected_header.
/// ADR 15 §7: Resource bounds (10 MiB envelope, 8 KiB header, depth 16, 128 entries).
///
/// Design:
/// - [CanonicalCbor] — minimal RFC 8949 encoder/decoder with deterministic guarantees.
/// - [ProtectedFrameV3] — builds/verifies the outer envelope per ADR 15 §3.3.
///
/// NOT a general-purpose CBOR library. Only supports the subset needed for
/// protected_header: uint, text, map, array, bool, null, bytes.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// CBOR 解析/编码违规
class CborParseException implements Exception {
  final String message;
  CborParseException(this.message);
  @override
  String toString() => 'CborParseException: $message';
}

/// 信封资源边界违规（PF3-08）
class FrameBoundsException implements Exception {
  final String message;
  FrameBoundsException(this.message);
  @override
  String toString() => 'FrameBoundsException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Canonical CBOR Codec (RFC 8949 §4.2 Deterministic Encoding)
// ─────────────────────────────────────────────────────────────────────────────

/// 最小 RFC 8949 deterministic CBOR 编解码器。
///
/// 编码规则：
/// - Map keys 按编码后字节字典序排列
/// - 整数使用最短形式
/// - 禁止 indefinite-length
/// - 最大嵌套深度 16，map 最大 128 entries，array 最大 4096 entries
class CanonicalCbor {
  static const int maxDepth = 16;
  static const int maxMapEntries = 128;
  static const int maxArrayEntries = 4096;

  // ─── Encode ───────────────────────────────────────────────────────────────

  /// 将 Dart 值编码为 canonical CBOR bytes。
  static Uint8List encode(dynamic value) {
    final builder = BytesBuilder();
    _encodeValue(builder, value, 0);
    return builder.toBytes();
  }

  static void _encodeValue(BytesBuilder out, dynamic value, int depth) {
    if (depth > maxDepth) {
      throw CborParseException('max nesting depth $maxDepth exceeded');
    }

    if (value == null) {
      out.addByte(0xF6); // null
    } else if (value is bool) {
      out.addByte(value ? 0xF5 : 0xF4);
    } else if (value is int) {
      _encodeUint(out, value);
    } else if (value is String) {
      _encodeText(out, value);
    } else if (value is Uint8List) {
      _encodeBytes(out, value);
    } else if (value is List) {
      _encodeArray(out, value, depth);
    } else if (value is Map<String, dynamic>) {
      _encodeMap(out, value, depth);
    } else {
      throw CborParseException('unsupported type: ${value.runtimeType}');
    }
  }

  static void _encodeUint(BytesBuilder out, int value) {
    if (value < 0) {
      // 负整数用 major type 1
      final n = -1 - value;
      _encodeHead(out, 1, n);
    } else {
      _encodeHead(out, 0, value);
    }
  }

  /// 编码 CBOR head（major type + argument），使用最短形式。
  static void _encodeHead(BytesBuilder out, int majorType, int argument) {
    final mt = majorType << 5;
    if (argument < 24) {
      out.addByte(mt | argument);
    } else if (argument < 0x100) {
      out.addByte(mt | 24);
      out.addByte(argument);
    } else if (argument < 0x10000) {
      out.addByte(mt | 25);
      out.addByte((argument >> 8) & 0xFF);
      out.addByte(argument & 0xFF);
    } else if (argument < 0x100000000) {
      out.addByte(mt | 26);
      out.addByte((argument >> 24) & 0xFF);
      out.addByte((argument >> 16) & 0xFF);
      out.addByte((argument >> 8) & 0xFF);
      out.addByte(argument & 0xFF);
    } else {
      out.addByte(mt | 27);
      out.addByte((argument >> 56) & 0xFF);
      out.addByte((argument >> 48) & 0xFF);
      out.addByte((argument >> 40) & 0xFF);
      out.addByte((argument >> 32) & 0xFF);
      out.addByte((argument >> 24) & 0xFF);
      out.addByte((argument >> 16) & 0xFF);
      out.addByte((argument >> 8) & 0xFF);
      out.addByte(argument & 0xFF);
    }
  }

  static void _encodeText(BytesBuilder out, String value) {
    final utf8Bytes = utf8.encode(value);
    _encodeHead(out, 3, utf8Bytes.length);
    out.add(utf8Bytes);
  }

  static void _encodeBytes(BytesBuilder out, Uint8List value) {
    _encodeHead(out, 2, value.length);
    out.add(value);
  }

  static void _encodeArray(BytesBuilder out, List<dynamic> value, int depth) {
    if (value.length > maxArrayEntries) {
      throw CborParseException(
        'array entries ${value.length} > max $maxArrayEntries',
      );
    }
    _encodeHead(out, 4, value.length);
    for (final item in value) {
      _encodeValue(out, item, depth + 1);
    }
  }

  static void _encodeMap(
    BytesBuilder out,
    Map<String, dynamic> value,
    int depth,
  ) {
    if (value.length > maxMapEntries) {
      throw CborParseException(
        'map entries ${value.length} > max $maxMapEntries',
      );
    }

    // RFC 8949 §4.2.1: keys sorted by their encoded byte representation
    final entries = value.entries.toList();
    final encodedKeys = <String, Uint8List>{};
    for (final e in entries) {
      final kb = BytesBuilder();
      _encodeText(kb, e.key);
      encodedKeys[e.key] = kb.toBytes();
    }
    entries.sort(
      (a, b) => _compareBytes(encodedKeys[a.key]!, encodedKeys[b.key]!),
    );

    _encodeHead(out, 5, value.length);
    for (final e in entries) {
      out.add(encodedKeys[e.key]!);
      _encodeValue(out, e.value, depth + 1);
    }
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final cmp = a[i].compareTo(b[i]);
      if (cmp != 0) return cmp;
    }
    return a.length.compareTo(b.length);
  }

  // ─── Decode ───────────────────────────────────────────────────────────────

  /// 解码 CBOR bytes。[strict] 为 true 时额外验证 key 排序（canonical order）。
  static dynamic decode(Uint8List data, {bool strict = false}) {
    final reader = _CborReader(data, strict: strict);
    final value = reader.readValue(0);
    if (reader.offset < data.length) {
      throw CborParseException('trailing bytes after CBOR value');
    }
    return value;
  }
}

class _CborReader {
  final Uint8List _data;
  final bool _strict;
  int _offset = 0;

  _CborReader(this._data, {bool strict = false}) : _strict = strict;

  int get offset => _offset;

  dynamic readValue(int depth) {
    if (depth > CanonicalCbor.maxDepth) {
      throw CborParseException('max nesting depth exceeded');
    }
    if (_offset >= _data.length) {
      throw CborParseException('unexpected end of data');
    }

    final initial = _data[_offset++];
    final majorType = initial >> 5;
    final additionalInfo = initial & 0x1F;

    // 拒绝 indefinite-length (additionalInfo == 31)
    if (additionalInfo == 31) {
      throw CborParseException('indefinite-length encoding not allowed');
    }

    switch (majorType) {
      case 0: // unsigned int
        return _readArgument(additionalInfo, shortest: true);
      case 1: // negative int
        final n = _readArgument(additionalInfo, shortest: true);
        return -1 - n;
      case 2: // byte string
        final len = _readArgument(additionalInfo, shortest: true);
        return _readBytes(len);
      case 3: // text string
        final len = _readArgument(additionalInfo, shortest: true);
        final bytes = _readBytes(len);
        return utf8.decode(bytes);
      case 4: // array
        final count = _readArgument(additionalInfo, shortest: true);
        if (count > CanonicalCbor.maxArrayEntries) {
          throw CborParseException('array entries $count > max');
        }
        return List.generate(count, (_) => readValue(depth + 1));
      case 5: // map
        final count = _readArgument(additionalInfo, shortest: true);
        if (count > CanonicalCbor.maxMapEntries) {
          throw CborParseException('map entries $count > max');
        }
        return _readMap(count, depth);
      case 7: // simple/float
        if (additionalInfo == 20) return false;
        if (additionalInfo == 21) return true;
        if (additionalInfo == 22) return null;
        throw CborParseException('unsupported simple value: $additionalInfo');
      default:
        throw CborParseException('unsupported major type: $majorType');
    }
  }

  Map<String, dynamic> _readMap(int count, int depth) {
    final map = <String, dynamic>{};
    Uint8List? prevKeyBytes;

    for (var i = 0; i < count; i++) {
      final keyStart = _offset;
      final key = readValue(depth + 1);
      final keyBytes = Uint8List.sublistView(_data, keyStart, _offset);

      if (key is! String) {
        throw CborParseException('map key must be text string');
      }
      if (map.containsKey(key)) {
        throw CborParseException('duplicate map key: "$key"');
      }

      // strict: 验证 key 按编码字节排序
      if (_strict && prevKeyBytes != null) {
        if (CanonicalCbor._compareBytes(prevKeyBytes, keyBytes) >= 0) {
          throw CborParseException('map keys not in canonical order at "$key"');
        }
      }
      prevKeyBytes = keyBytes;

      map[key] = readValue(depth + 1);
    }
    return map;
  }

  int _readArgument(int additionalInfo, {required bool shortest}) {
    if (additionalInfo < 24) {
      return additionalInfo;
    }

    int value;
    int byteCount;
    if (additionalInfo == 24) {
      value = _readByte();
      byteCount = 1;
    } else if (additionalInfo == 25) {
      value = (_readByte() << 8) | _readByte();
      byteCount = 2;
    } else if (additionalInfo == 26) {
      value =
          (_readByte() << 24) |
          (_readByte() << 16) |
          (_readByte() << 8) |
          _readByte();
      byteCount = 4;
    } else if (additionalInfo == 27) {
      // 64-bit — Dart int 在 64-bit 平台上足够
      value = 0;
      for (var i = 0; i < 8; i++) {
        value = (value << 8) | _readByte();
      }
      byteCount = 8;
    } else {
      throw CborParseException('invalid additional info: $additionalInfo');
    }

    // 最短形式检查：值必须不能用更少的字节表示
    if (shortest) {
      if (byteCount == 1 && value < 24) {
        throw CborParseException(
          'non-shortest integer encoding: $value in $byteCount byte(s)',
        );
      }
      if (byteCount == 2 && value < 0x100) {
        throw CborParseException(
          'non-shortest integer encoding: $value in $byteCount byte(s)',
        );
      }
      if (byteCount == 4 && value < 0x10000) {
        throw CborParseException(
          'non-shortest integer encoding: $value in $byteCount byte(s)',
        );
      }
      if (byteCount == 8 && value < 0x100000000) {
        throw CborParseException(
          'non-shortest integer encoding: $value in $byteCount byte(s)',
        );
      }
    }

    return value;
  }

  int _readByte() {
    if (_offset >= _data.length) {
      throw CborParseException('unexpected end of data');
    }
    return _data[_offset++];
  }

  Uint8List _readBytes(int length) {
    if (_offset + length > _data.length) {
      throw CborParseException('byte string length exceeds data');
    }
    final bytes = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(bytes);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Protected Frame v3
// ─────────────────────────────────────────────────────────────────────────────

/// 消息作用域
enum FrameScope { c2c, group, control }

/// 构造 protected_header 所需的完整上下文
class FrameContext {
  final String messageId;
  final FrameScope scope;
  final String conversationId;
  final String senderUid;
  final String senderDid;
  final String destination;
  final String messageType;
  final String action;
  final int createdAtMs;
  final String protocol;
  final int protocolVersion;
  final String sessionRef;
  final int epochOrCounter;

  const FrameContext({
    required this.messageId,
    required this.scope,
    required this.conversationId,
    required this.senderUid,
    required this.senderDid,
    required this.destination,
    required this.messageType,
    required this.action,
    required this.createdAtMs,
    required this.protocol,
    required this.protocolVersion,
    required this.sessionRef,
    required this.epochOrCounter,
  });

  /// 从解码后的 header map 重建（用于 inner/outer 比对）
  factory FrameContext.fromHeader(Map<String, dynamic> h) {
    return FrameContext(
      messageId: h['message_id'] as String,
      scope: FrameScope.values.firstWhere((s) => s.name == h['scope']),
      conversationId: h['conversation_id'] as String,
      senderUid: h['sender_uid'] as String,
      senderDid: h['sender_did'] as String,
      destination: h['destination'] as String,
      messageType: h['message_type'] as String,
      action: h['action'] as String,
      createdAtMs: h['created_at_ms'] as int,
      protocol: h['protocol'] as String,
      protocolVersion: h['protocol_version'] as int,
      sessionRef: h['session_ref'] as String,
      epochOrCounter: h['epoch_or_counter'] as int,
    );
  }
}

/// 信封验证结果
class EnvelopeVerification {
  final bool isValid;
  final String? reason;
  final Map<String, dynamic>? decodedHeader;

  const EnvelopeVerification.valid(this.decodedHeader)
    : isValid = true,
      reason = null;
  const EnvelopeVerification.invalid(this.reason)
    : isValid = false,
      decodedHeader = null;
}

/// ADR 15 Protected Frame v3 构造与验证。
///
/// 外层信封格式（§3.3）：
/// ```json
/// {
///   "meta_version": 3,
///   "protected_header": "<base64url canonical CBOR>",
///   "header_hash": "<base64url SHA-256>",
///   "ciphertext": "<base64url protocol ciphertext>",
///   "protocol_metadata": { ... }
/// }
/// ```
class ProtectedFrameV3 {
  /// 信封最大 10 MiB（base64 解码后）
  static const int maxEnvelopeBytes = 10 * 1024 * 1024;

  /// protected_header 最大 8 KiB（CBOR bytes）
  static const int maxHeaderBytes = 8 * 1024;

  /// 构造 protected_header map（ADR 15 §3.1，字段冻结）
  ///
  /// [ctx.sessionRef] 必须非空：ADR 15 §3.1 把 `session_ref` 定义为
  /// `text, 1..256 字节`。这条守卫放在**构造处**而不是各调用点——E2EE-025
  /// 的事故正是某个调用点传了空串（`chat_network_service.dart` 曾写
  /// `sessionRef: ''` 并注释「OlmProtocol 内部填充」，而该填充并不存在），
  /// 导致接收侧 `_validateContextBinding` 判 `context_mismatch_session_id`，
  /// 整条 C2C v3 消息不可读，且**发送侧毫无察觉**。
  /// 在此 fail-closed，任何新调用点漏传都会立刻炸而不是静默产出废密文。
  static Map<String, dynamic> buildProtectedHeader(FrameContext ctx) {
    if (ctx.sessionRef.isEmpty) {
      throw ArgumentError.value(
        ctx.sessionRef,
        'sessionRef',
        'ADR 15 §3.1: session_ref 必须为 1..256 字节的非空文本；'
            '空串会让接收侧 context binding 比对失败，消息永久不可读',
      );
    }
    return {
      'v': 3,
      'message_id': ctx.messageId,
      'scope': ctx.scope.name,
      'conversation_id': ctx.conversationId,
      'sender_uid': ctx.senderUid,
      'sender_did': ctx.senderDid,
      'destination': ctx.destination,
      'message_type': ctx.messageType,
      'action': ctx.action,
      'created_at_ms': ctx.createdAtMs,
      'protocol': ctx.protocol,
      'protocol_version': ctx.protocolVersion,
      'session_ref': ctx.sessionRef,
      'epoch_or_counter': ctx.epochOrCounter,
      'content_encoding': 'cbor',
    };
  }

  /// 计算 header_hash = SHA-256(canonical_cbor(protected_header))
  static List<int> computeHeaderHash(FrameContext ctx) {
    final header = buildProtectedHeader(ctx);
    final canonical = CanonicalCbor.encode(header);
    return sha256.convert(canonical).bytes;
  }

  /// 编码外层信封（发送侧）
  static Map<String, dynamic> encodeOuterEnvelope({
    required FrameContext context,
    required Uint8List ciphertext,
    required Map<String, dynamic> protocolMetadata,
  }) {
    final header = buildProtectedHeader(context);
    final canonicalHeader = CanonicalCbor.encode(header);
    final headerHash = sha256.convert(canonicalHeader).bytes;

    return {
      'meta_version': 3,
      'protected_header': base64Url.encode(canonicalHeader),
      'header_hash': base64Url.encode(headerHash),
      'ciphertext': base64Url.encode(ciphertext),
      'protocol_metadata': protocolMetadata,
    };
  }

  /// 验证外层信封（接收侧第一步：结构 + hash 校验）
  static EnvelopeVerification verifyOuterEnvelope(
    Map<String, dynamic> envelope,
  ) {
    // meta_version 必须为 3
    final metaVersion = envelope['meta_version'];
    if (metaVersion != 3) {
      return EnvelopeVerification.invalid(
        'meta_version must be 3, got $metaVersion',
      );
    }

    // 必填字段
    final headerB64 = envelope['protected_header'];
    final hashB64 = envelope['header_hash'];
    if (headerB64 is! String || hashB64 is! String) {
      return EnvelopeVerification.invalid(
        'missing protected_header or header_hash',
      );
    }

    // 解码 header
    Uint8List headerBytes;
    try {
      headerBytes = Uint8List.fromList(base64Url.decode(headerB64));
    } catch (_) {
      return EnvelopeVerification.invalid(
        'protected_header base64 decode failed',
      );
    }

    // 验证 header_hash
    final expectedHash = sha256.convert(headerBytes).bytes;
    Uint8List actualHash;
    try {
      actualHash = Uint8List.fromList(base64Url.decode(hashB64));
    } catch (_) {
      return EnvelopeVerification.invalid('header_hash base64 decode failed');
    }

    if (!_constantTimeEquals(expectedHash, actualHash)) {
      return EnvelopeVerification.invalid('header_hash mismatch');
    }

    // 解码并验证 CBOR 结构
    Map<String, dynamic> decodedHeader;
    try {
      final decoded = CanonicalCbor.decode(headerBytes, strict: true);
      if (decoded is! Map<String, dynamic>) {
        return EnvelopeVerification.invalid('protected_header is not a map');
      }
      decodedHeader = decoded;
    } on CborParseException catch (e) {
      return EnvelopeVerification.invalid(
        'protected_header CBOR invalid: ${e.message}',
      );
    }

    // v 必须为 3
    if (decodedHeader['v'] != 3) {
      return EnvelopeVerification.invalid('header v != 3');
    }

    return EnvelopeVerification.valid(decodedHeader);
  }

  /// 比对 inner/outer header（接收侧解密后）
  /// 返回 null 表示一致，否则返回第一个不匹配的字段名。
  static String? compareHeaders({
    required FrameContext outerContext,
    required FrameContext innerContext,
  }) {
    if (outerContext.messageId != innerContext.messageId) {
      return 'message_id';
    }
    if (outerContext.scope != innerContext.scope) {
      return 'scope';
    }
    if (outerContext.conversationId != innerContext.conversationId) {
      return 'conversation_id';
    }
    if (outerContext.senderUid != innerContext.senderUid) {
      return 'sender_uid';
    }
    if (outerContext.senderDid != innerContext.senderDid) {
      return 'sender_did';
    }
    if (outerContext.destination != innerContext.destination) {
      return 'destination';
    }
    if (outerContext.messageType != innerContext.messageType) {
      return 'message_type';
    }
    if (outerContext.action != innerContext.action) {
      return 'action';
    }
    if (outerContext.createdAtMs != innerContext.createdAtMs) {
      return 'created_at_ms';
    }
    if (outerContext.protocol != innerContext.protocol) {
      return 'protocol';
    }
    if (outerContext.protocolVersion != innerContext.protocolVersion) {
      return 'protocol_version';
    }
    if (outerContext.sessionRef != innerContext.sessionRef) {
      return 'session_ref';
    }
    if (outerContext.epochOrCounter != innerContext.epochOrCounter) {
      return 'epoch_or_counter';
    }
    return null;
  }

  /// 资源边界验证（PF3-08）：在 base64 全量分配前检查
  static void validateEnvelopeBounds(Map<String, dynamic> envelope) {
    final headerB64 = envelope['protected_header'];
    final ciphertextB64 = envelope['ciphertext'];

    if (headerB64 is String) {
      // base64 解码后大小 ≈ strlen * 3/4
      final headerSize = (headerB64.length * 3) ~/ 4;
      if (headerSize > maxHeaderBytes) {
        throw FrameBoundsException(
          'protected_header ${headerSize}B > max ${maxHeaderBytes}B',
        );
      }
    }

    // 总信封大小估算
    var totalSize = 0;
    for (final v in envelope.values) {
      if (v is String) totalSize += (v.length * 3) ~/ 4;
    }
    if (totalSize > maxEnvelopeBytes) {
      throw FrameBoundsException(
        'envelope ~${totalSize}B > max ${maxEnvelopeBytes}B',
      );
    }

    // ciphertext 单独检查
    if (ciphertextB64 is String) {
      final ctSize = (ciphertextB64.length * 3) ~/ 4;
      if (ctSize > maxEnvelopeBytes) {
        throw FrameBoundsException(
          'ciphertext ${ctSize}B > max ${maxEnvelopeBytes}B',
        );
      }
    }
  }

  /// 常量时间比较（避免 timing oracle）
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
