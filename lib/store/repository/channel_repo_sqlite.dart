import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 频道 Repository
///
/// 负责频道的本地数据库操作：
/// - 频道基础信息的 CRUD
/// - 订阅关系的管理
/// - 未读计数的更新
class ChannelRepo {
  static const String tableName = 'channel';
  static const String subscriptionTableName = 'channel_subscription';

  // 频道表字段
  static const String id = 'id';
  static const String name = 'name';
  static const String description = 'description';
  static const String avatar = 'avatar';
  static const String type = 'type';
  static const String customId = 'custom_id';
  static const String creatorId = 'creator_id';
  static const String subscriberCount = 'subscriber_count';
  static const String isVerified = 'is_verified';
  static const String tags = 'tags';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  // 订阅表字段
  static const String subChannelId = 'channel_id';
  static const String subscribedAt = 'subscribed_at';
  static const String lastReadAt = 'last_read_at';
  static const String lastMessageId = 'last_message_id';
  static const String unreadCount = 'unread_count';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String isPinned = 'is_pinned';
  static const String isMuted = 'is_muted';

  final SqliteService _db = SqliteService.to;

  // ==================== 频道基础信息 CRUD ====================

  /// 保存或更新频道信息
  Future<void> saveChannel(ChannelModel channel, {Transaction? txn}) async {
    final map = channel.toMap();
    if (txn != null) {
      await txn.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // SqliteService.insert 内部已使用 ConflictAlgorithm.replace
      await _db.insert(tableName, map);
    }
    iPrint('ChannelRepo: 保存频道 ${channel.id} - ${channel.name}');
  }

  /// 批量保存频道
  Future<void> saveChannels(
    List<ChannelModel> channels, {
    Transaction? txn,
  }) async {
    for (final channel in channels) {
      await saveChannel(channel, txn: txn);
    }
    iPrint('ChannelRepo: 批量保存 ${channels.length} 个频道');
  }

  /// 获取单个频道
  Future<ChannelModel?> getChannel(String channelId, {Transaction? txn}) async {
    final List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        tableName,
        where: '$id = ?',
        whereArgs: [channelId],
        limit: 1,
      );
    } else {
      maps = await _db.query(
        tableName,
        where: '$id = ?',
        whereArgs: [channelId],
        limit: 1,
      );
    }

    if (maps.isNotEmpty) {
      return ChannelModel.fromMap(maps.first);
    }
    return null;
  }

  /// 通过自定义 ID 获取频道
  Future<ChannelModel?> getChannelByCustomId(String customIdValue) async {
    final maps = await _db.query(
      tableName,
      where: '$customId = ?',
      whereArgs: [customIdValue],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ChannelModel.fromMap(maps.first);
    }
    return null;
  }

  /// 获取所有订阅的频道（带订阅信息）
  Future<List<Map<String, dynamic>>>
  getSubscribedChannelsWithSubscription() async {
    final results = await _db.rawQuery('''
      SELECT c.*, s.subscribed_at, s.last_read_at, s.last_message_id,
             s.unread_count, s.notifications_enabled, s.is_pinned, s.is_muted
      FROM $tableName c
      INNER JOIN $subscriptionTableName s ON c.$id = s.$subChannelId
      ORDER BY s.$isPinned DESC, s.$subscribedAt DESC
    ''');

    return results;
  }

  /// 获取所有订阅的频道
  Future<List<ChannelModel>> getSubscribedChannels() async {
    final results = await _db.rawQuery('''
      SELECT c.*
      FROM $tableName c
      INNER JOIN $subscriptionTableName s ON c.$id = s.$subChannelId
      ORDER BY s.$isPinned DESC, s.$subscribedAt DESC
    ''');

    return results.map((map) => ChannelModel.fromMap(map)).toList();
  }

  /// 搜索本地频道
  Future<List<ChannelModel>> searchChannels(
    String keyword, {
    int limit = 50,
  }) async {
    final results = await _db.query(
      tableName,
      where: '$name LIKE ? OR $description LIKE ? OR $customId LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      limit: limit,
      orderBy: '$subscriberCount DESC',
    );

    return results.map((map) => ChannelModel.fromMap(map)).toList();
  }

  /// 更新频道信息
  Future<int> updateChannel(String channelId, Map<String, dynamic> data) async {
    data.remove(id); // 移除主键
    return await _db.update(
      tableName,
      data,
      where: '$id = ?',
      whereArgs: [channelId],
    );
  }

  /// 删除频道
  Future<int> deleteChannel(String channelId) async {
    // 先删除订阅关系（由于外键约束，会级联删除）
    await _db.delete(
      subscriptionTableName,
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
    // 删除频道
    return await _db.delete(
      tableName,
      where: '$id = ?',
      whereArgs: [channelId],
    );
  }

  // ==================== 订阅关系管理 ====================

  /// 保存订阅关系
  Future<void> saveSubscription(
    ChannelSubscriptionModel subscription, {
    Transaction? txn,
  }) async {
    final map = subscription.toMap();
    if (txn != null) {
      await txn.insert(
        subscriptionTableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // SqliteService.insert 内部已使用 ConflictAlgorithm.replace
      await _db.insert(subscriptionTableName, map);
    }
    iPrint('ChannelRepo: 保存订阅关系 ${subscription.channelId}');
  }

  /// 获取订阅关系
  Future<ChannelSubscriptionModel?> getSubscription(String channelId) async {
    final maps = await _db.query(
      subscriptionTableName,
      where: '$subChannelId = ?',
      whereArgs: [channelId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ChannelSubscriptionModel.fromMap(maps.first);
    }
    return null;
  }

  /// 获取所有订阅关系
  Future<List<ChannelSubscriptionModel>> getAllSubscriptions() async {
    final maps = await _db.query(
      subscriptionTableName,
      orderBy: '$isPinned DESC, $subscribedAt DESC',
    );

    return maps.map((map) => ChannelSubscriptionModel.fromMap(map)).toList();
  }

  /// 检查是否已订阅
  Future<bool> isSubscribed(String channelId) async {
    final subscription = await getSubscription(channelId);
    return subscription != null;
  }

  /// 删除订阅关系
  Future<int> deleteSubscription(String channelId) async {
    return await _db.delete(
      subscriptionTableName,
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  // ==================== 未读计数管理 ====================

  /// 更新未读计数
  Future<int> updateUnreadCount(String channelId, int count) async {
    return await _db.update(
      subscriptionTableName,
      {unreadCount: count},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  /// 增加未读计数（原子操作）
  ///
  /// 使用 `UPDATE ... SET unread_count = unread_count + 1` 原子 SQL，
  /// 避免「先 SELECT 再 UPDATE」两步走造成的并发丢更新：当两条 S2C 推送
  /// 几乎同时到达时，旧实现读到相同的 unread_count=N，两次 UPDATE 都写 N+1，
  /// 实际只增加 1，而预期应该是 2。
  ///
  /// 返回值为 rawUpdate 受影响行数（0 表示订阅记录不存在）。
  Future<int> incrementUnreadCount(String channelId) async {
    return await _db.execute(
      'UPDATE $subscriptionTableName '
      'SET $unreadCount = $unreadCount + 1 '
      'WHERE $subChannelId = ?',
      [channelId],
    );
  }

  /// 清除未读计数
  Future<int> clearUnreadCount(String channelId) async {
    return await _db.update(
      subscriptionTableName,
      {unreadCount: 0, lastReadAt: DateTime.now().millisecondsSinceEpoch},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  /// 获取总未读数
  Future<int> getTotalUnreadCount() async {
    final result = await _db.rawQuery(
      'SELECT SUM($unreadCount) as total FROM $subscriptionTableName',
    );

    return result.isNotEmpty ? parseModelInt(result.first['total']) : 0;
  }

  /// 获取有未读消息的频道数量
  Future<int> getUnreadChannelCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $subscriptionTableName WHERE $unreadCount > 0',
    );

    return result.isNotEmpty ? parseModelInt(result.first['count']) : 0;
  }

  // ==================== 置顶和通知设置 ====================

  /// 设置频道置顶状态
  Future<int> setPinned(String channelId, bool pinned) async {
    return await _db.update(
      subscriptionTableName,
      {isPinned: pinned ? 1 : 0},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  /// 设置频道免打扰状态
  Future<int> setMuted(String channelId, bool muted) async {
    return await _db.update(
      subscriptionTableName,
      {isMuted: muted ? 1 : 0},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  /// 设置通知开关
  Future<int> setNotificationsEnabled(String channelId, bool enabled) async {
    return await _db.update(
      subscriptionTableName,
      {notificationsEnabled: enabled ? 1 : 0},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  // ==================== 更新最后消息信息 ====================

  /// 更新最后已读消息 ID
  Future<int> updateLastMessageId(String channelId, String messageId) async {
    return await _db.update(
      subscriptionTableName,
      {lastMessageId: messageId},
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  /// 标记已读（清除未读，更新最后阅读时间）
  Future<int> markAsRead(String channelId, String messageId) async {
    return await _db.update(
      subscriptionTableName,
      {
        unreadCount: 0,
        lastReadAt: DateTime.now().millisecondsSinceEpoch,
        lastMessageId: messageId,
      },
      where: '$subChannelId = ?',
      whereArgs: [channelId],
    );
  }

  // ==================== 清理操作 ====================

  /// 清理所有频道数据（慎用！）
  Future<void> clearAll() async {
    await _db.delete(subscriptionTableName);
    await _db.delete(tableName);
    iPrint('ChannelRepo: 清理所有频道数据');
  }

  /// 关闭数据库连接（空实现，由 SqliteService 统一管理）
  Future<void> close() async {
    // 由 SqliteService 统一管理
  }
}
