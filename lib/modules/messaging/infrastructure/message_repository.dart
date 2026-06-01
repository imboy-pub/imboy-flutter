import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 消息仓储端口 / Message repository port（T4.4a，务实 port 方向 A）。
///
/// **架构决策（2026-06-01，T4.4 定方向 A 务实 port）**：本端口**有意允许**签名
/// 引用 `sqflite_sqlcipher.Transaction`——承认「事务是跨层现实」，以零行为变更、
/// 零调用方改动的最低风险增量抽出仓储契约。`MessageRepo` 原地 `implements` 本端口。
///
/// **Architecture decision (Direction A — pragmatic port)**: this port
/// intentionally references `sqflite_sqlcipher.Transaction` in its signatures,
/// acknowledging that the transaction boundary is a cross-layer reality. This
/// keeps the abstraction a zero-behavior-change, zero-caller-change increment.
///
/// 端口仅声明**核心可替换契约**（CRUD + 主查询）；实现方 `MessageRepo` 另持
/// 表名解析、ProviderContainer 注入等静态/扩展成员，不在本契约内。
abstract interface class MessageRepository {
  /// 当前仓储绑定的表名。
  String get tableName;

  /// 获取实际使用的表名。
  Future<String> getActualTableName();

  /// 插入一条消息（已存在则跳过）。
  Future<MessageModel> insert(MessageModel msg, {Transaction? txn});

  /// 按主键更新消息。
  Future<int> update(Map<String, dynamic> data, {Transaction? txn});

  /// 带条件的更新（CAS - Compare-And-Set）。
  Future<int> updateWithConditions(
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
    Transaction? txn,
  });

  /// 存在则更新，不存在则插入。
  Future<int?> save(MessageModel obj, {Transaction? txn});

  /// 会话分页（向旧翻页）。
  Future<List<MessageModel>> pageForConversation(
    String uk3,
    int nextAutoId,
    int size,
  );

  /// 会话分页（向新翻页，双向分页用）。
  Future<List<MessageModel>> pageNewerForConversation(
    String uk3,
    int prevAutoId,
    int size,
  );

  /// 高级过滤分页（关键词/类型/发送者/时间范围）。
  Future<List<MessageModel>> page({
    required int page,
    required int size,
    String? kwd,
    String? conversationUk3,
    String? orderBy,
    List<String>? messageTypes,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 创建搜索索引。
  Future<void> createSearchIndexes();

  /// 按消息 ID 查找。
  Future<MessageModel?> find(String id, {Transaction? txn});

  /// 按消息 ID 删除。
  Future<int> delete(String id);

  /// 按 UID（from 或 to）删除。
  Future<int> deleteByUid(String uid);

  /// 按状态查找消息。
  Future<List<MessageModel>> findByStatus(String conversationUk3, int status);

  /// 批量更新消息状态。
  Future<int> batchUpdateStatus(List<String> messageIds, int status);

  /// 删除整个会话的消息。
  Future<int> deleteByConversationId(String uk3);

  /// 当前用户最后一条消息。
  Future<MessageModel?> lastMsg();

  /// 批量插入离线消息。
  Future<List<String>?> batchInsertOfflineMessages(
    List<Map<String, dynamic>> messages, {
    Future<void> Function(Map<String, dynamic>)? onS2CMessage,
  });

  /// 计算与某用户的消息数量。
  Future<int> countMessagesWithUser(String peerId, {int? since});
}
