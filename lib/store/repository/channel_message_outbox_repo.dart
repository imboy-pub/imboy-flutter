import 'dart:convert';

import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/channel_message_model.dart';

/// 频道消息本地待同步 outbox。
///
/// 该队列只保存“服务端已成功、客户端本地缓存未完成”的消息快照，
/// 不承担服务端发布幂等；服务端发布请求仍由 ChannelApi 负责。
class ChannelMessageOutboxRepo {
  static const String tableName = 'channel_message_outbox';

  final SqliteService _db = SqliteService.to;
  final bool _enabled;

  ChannelMessageOutboxRepo() : _enabled = true;

  /// 测试用无副作用实现：ChannelService.forTest 默认使用它，避免单元测试依赖真实 SQLite。
  ChannelMessageOutboxRepo.noop() : _enabled = false;

  /// 保存或更新待同步消息。message_id 是主键，重复入队不会产生重复记录。
  Future<void> enqueue(ChannelMessageModel message, {String? error}) async {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(tableName, {
      'message_id': message.id,
      'channel_id': message.channelId,
      'payload': jsonEncode(message.toJson()),
      'attempts': 0,
      'next_attempt_at': now,
      'last_error': error,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 返回到期的待同步消息。
  Future<List<ChannelMessageModel>> pending({
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
      orderBy: 'next_attempt_at ASC, message_id ASC',
      limit: limit,
    );
    return rows
        .map(
          (row) => ChannelMessageModel.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// 本地消息成功落库后移除对应 outbox 记录。
  Future<void> remove(int messageId) async {
    if (!_enabled) return;
    await _db.delete(
      tableName,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// 本地重放失败时延迟重试，避免每次打开频道都立即打满数据库。
  Future<void> markRetry(int messageId, Object error) async {
    if (!_enabled) return;
    final row = await _db.query(
      tableName,
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (row.isEmpty) return;

    final attempts = (row.first['attempts'] as int? ?? 0) + 1;
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
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }
}
