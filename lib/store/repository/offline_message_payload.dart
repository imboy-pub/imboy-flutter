import 'dart:convert';

import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/repository/message_repo_schema.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 离线信封的负载解码，保留密文及可信归档序号，不修改输入。
class OfflineMessagePayload {
  final Map<String, dynamic> payload;
  final String? rawCipher;
  final dynamic encryption;

  const OfflineMessagePayload(this.payload, this.rawCipher, this.encryption);

  static const replySourceWireKey = 'reply_source_id';
  static const localReplySourceKey = '_local_reply_source_id';

  static Map<String, dynamic> checkReplySource(
    Map<String, dynamic> payload,
    Map<String, dynamic>? authority,
    String key,
  ) {
    if (authority == null || !authority.containsKey(key)) return payload;
    final quote = payload['quote_msg'];
    final source = authority[key];
    return source is String &&
            source.isNotEmpty &&
            quote is Map &&
            quote['id'] == source
        ? payload
        : withoutQuoteSnapshot(payload);
  }

  static Map<String, Object?> deniedReplyUpdate(
    Map<String, Object?> stored,
    Map<String, dynamic> envelope,
  ) {
    if (!envelope.containsKey(replySourceWireKey) ||
        envelope[replySourceWireKey] != null ||
        stored[MessageColumns.type] != 'C2C' ||
        stored[MessageColumns.msgType] != 'quote' ||
        envelope['msg_type'] != 'quote' ||
        stored[MessageColumns.from]?.toString() !=
            envelope['from']?.toString() ||
        stored[MessageColumns.to]?.toString() != envelope['to']?.toString()) {
      return const {};
    }
    Map<String, dynamic>? decodeObject(Object? raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is! String || raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic> ? decoded : null;
      } on FormatException {
        return null;
      }
    }

    final payload = decodeObject(stored[MessageColumns.payload]);
    final encryption = decodeObject(stored[MessageColumns.e2ee]);
    return {
      if (payload != null &&
          (payload.containsKey('quote_msg') ||
              payload.containsKey('quote_msg_author_name')))
        MessageColumns.payload: jsonEncode(withoutQuoteSnapshot(payload)),
      if (encryption != null &&
          encryption.isNotEmpty &&
          (!encryption.containsKey(localReplySourceKey) ||
              encryption[localReplySourceKey] != null))
        MessageColumns.e2ee: jsonEncode({
          ...encryption,
          localReplySourceKey: null,
        }),
    };
  }

  static Future<Map<String, dynamic>> redactQuoteForStoredSource(
    DatabaseExecutor? database,
    Map<String, dynamic> payload,
    String conversationKey,
  ) async {
    final quote = payload['quote_msg'];
    final sourceId = quote is Map ? quote['id'] : null;
    if (sourceId is! String || sourceId.isEmpty) return payload;
    if (database == null) return withoutQuoteSnapshot(payload);
    final source = await database.query(
      MessageRepoSchema.c2cTable,
      columns: [MessageColumns.status],
      where: 'id = ? AND conversation_uk3 = ? AND status >= 30 AND status < 40',
      whereArgs: [sourceId, conversationKey],
      limit: 1,
    );
    if (source.isEmpty) return payload;
    return withoutQuoteSnapshot(payload);
  }

  static Map<String, dynamic> withoutQuoteSnapshot(
    Map<String, dynamic> payload,
  ) => Map<String, dynamic>.of(payload)
    ..remove('quote_msg')
    ..remove('quote_msg_author_name');

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
      ..remove('_archive_conv_seq')
      ..remove(localReplySourceKey);
    if (message['type']?.toString().toUpperCase() == 'C2C' &&
        message['msg_type'] == 'quote' &&
        message.containsKey(replySourceWireKey)) {
      normalized[localReplySourceKey] = message[replySourceWireKey];
    }
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
