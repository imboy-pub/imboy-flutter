import 'dart:convert';

/// 离线信封的负载解码，保留密文及可信归档序号，不修改输入。
class OfflineMessagePayload {
  final Map<String, dynamic> payload;
  final String? rawCipher;
  final dynamic encryption;

  const OfflineMessagePayload(this.payload, this.rawCipher, this.encryption);

  static OfflineMessagePayload decode(
    Map<String, dynamic> message, {
    required bool trustedArchive,
  }) {
    final encryption = _normalizeEncryption(message, trustedArchive);
    final hasEncryption =
        (encryption is Map && encryption.isNotEmpty) ||
        (encryption is String && encryption.isNotEmpty);
    final raw = message['payload'];
    if (raw is Map) {
      return OfflineMessagePayload(
        raw.cast<String, dynamic>(),
        null,
        encryption,
      );
    }
    if (raw is String) {
      if (raw.isEmpty && hasEncryption) {
        return OfflineMessagePayload({}, raw, encryption);
      }
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return OfflineMessagePayload(
              decoded.cast<String, dynamic>(),
              null,
              encryption,
            );
          }
        } on FormatException {
          // 非 JSON 密文必须逐字节保留，不能替换为空对象。
        }
        return OfflineMessagePayload({}, raw, encryption);
      }
    }
    return OfflineMessagePayload({}, null, encryption);
  }

  static dynamic _normalizeEncryption(
    Map<String, dynamic> message,
    bool trustedArchive,
  ) {
    final raw = message['e2ee'];
    if (raw is! Map) return raw;
    final normalized = Map<String, dynamic>.from(raw)
      ..remove('_archive_conv_seq');
    if (trustedArchive) {
      final rawSequence = message['conv_seq'];
      final sequence = rawSequence is int
          ? rawSequence
          : int.tryParse(rawSequence?.toString() ?? '');
      if (sequence != null && sequence > 0) {
        normalized['_archive_conv_seq'] = sequence;
      }
    }
    return normalized;
  }
}
