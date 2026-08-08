import 'dart:convert';

import 'package:imboy/service/sqlite.dart';

/// 频道发布请求的本地持久化队列项。
class ChannelPublishOutboxItem {
  final String requestId;
  final String channelId;
  final String content;
  final String msgType;
  final Map<String, dynamic>? payload;
  final int attempts;

  const ChannelPublishOutboxItem({
    required this.requestId,
    required this.channelId,
    required this.content,
    required this.msgType,
    required this.payload,
    required this.attempts,
  });
}

/// 频道消息发布 outbox。
///
/// 队列中的 request_id 会原样重放给服务端。服务端以该值做幂等键，
/// 因此网络超时后重试不会因为客户端不知道首次请求是否已落库而重复发消息。
class ChannelPublishOutboxRepo {
  static const String tableName = 'channel_publish_outbox';

  final SqliteService _db = SqliteService.to;
  final bool _enabled;

  ChannelPublishOutboxRepo() : _enabled = true;

  /// 测试用无副作用实现。
  ChannelPublishOutboxRepo.noop() : _enabled = false;

  Future<void> enqueue({
    required String requestId,
    required String channelId,
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
    String? error,
  }) async {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(tableName, {
      'request_id': requestId,
      'channel_id': channelId,
      'content': content,
      'msg_type': msgType,
      'payload': payload == null ? null : jsonEncode(payload),
      'attempts': 0,
      'next_attempt_at': now,
      'last_error': error,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<ChannelPublishOutboxItem>> pending({
    String? channelId,
    int limit = 20,
  }) async {
    if (!_enabled) return [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final whereParts = <String>['next_attempt_at <= ?'];
    final args = <Object?>[now];
    if (channelId != null) {
      whereParts.add('channel_id = ?');
      args.add(channelId);
    }

    final rows = await _db.query(
      tableName,
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'next_attempt_at ASC, created_at ASC',
      limit: limit,
    );
    return rows.map((row) {
      final rawPayload = row['payload'] as String?;
      return ChannelPublishOutboxItem(
        requestId: row['request_id'] as String,
        channelId: row['channel_id'] as String,
        content: row['content'] as String,
        msgType: row['msg_type'] as String,
        payload: rawPayload == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(rawPayload) as Map),
        attempts: row['attempts'] as int? ?? 0,
      );
    }).toList();
  }

  Future<void> remove(String requestId) async {
    if (!_enabled) return;
    await _db.delete(
      tableName,
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }

  Future<void> markRetry(String requestId, Object error) async {
    if (!_enabled) return;
    final rows = await _db.query(
      tableName,
      where: 'request_id = ?',
      whereArgs: [requestId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final attempts = (rows.first['attempts'] as int? ?? 0) + 1;
    final cappedAttempts = attempts > 8 ? 8 : attempts;
    final delaySeconds = 1 << cappedAttempts;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      tableName,
      {
        'attempts': attempts,
        'next_attempt_at': now + delaySeconds * 1000,
        'last_error': error.toString(),
        'updated_at': now,
      },
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }
}
