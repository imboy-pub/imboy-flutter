/// Mock服务类
///
/// 用于测试环境中模拟数据库和存储服务
library;

import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

/// Mock Conversation Repository
///
/// 在内存中模拟会话存储，无需真实数据库
class MockConversationRepository {
  final Map<int, ConversationModel> _storage = {};
  int _nextId = 1;

  /// 插入会话
  Future<int> insert(ConversationModel conversation) async {
    final id = _nextId++;
    final newConv = ConversationModel.fromJson({
      ...conversation.toJson(),
      'id': id,
    });
    _storage[id] = newConv;
    return id;
  }

  /// 根据ID查找会话
  Future<ConversationModel?> findById(int id) async {
    return _storage[id];
  }

  /// 根据peerId查找会话
  Future<ConversationModel?> findByPeerId(String type, String peerId) async {
    try {
      return _storage.values.firstWhere(
        (conv) => conv.type == type && conv.peerId.toString() == peerId,
      );
    } catch (_) {
      return null;
    }
  }

  /// 更新会话
  Future<int> updateById(int id, Map<String, dynamic> data) async {
    final existing = _storage[id];
    if (existing == null) return 0;

    final updatedJson = existing.toJson();
    updatedJson.addAll(data);

    _storage[id] = ConversationModel.fromJson(updatedJson);
    return 1;
  }

  /// 删除会话
  Future<int> delete(int id) async {
    return _storage.remove(id) != null ? 1 : 0;
  }

  /// 根据peerId删除会话
  Future<int> deleteByPeerId(String type, String peerId) async {
    final conv = await findByPeerId(type, peerId);
    if (conv == null) return 0;
    return delete(conv.id);
  }

  /// 清空所有数据
  void clear() {
    _storage.clear();
    _nextId = 1;
  }

  /// 获取所有会话
  List<ConversationModel> getAll() {
    return _storage.values.toList();
  }
}

/// Mock Message Repository
///
/// 在内存中模拟消息存储
class MockMessageRepository {
  final Map<String, List<MessageModel>> _storage = {};
  int _nextAutoId = 1;

  String _getTableKey(String type) {
    return 'msg_${type.toLowerCase()}';
  }

  /// 插入消息
  Future<int> insert(MessageModel message) async {
    final tableKey = _getTableKey(message.type!);
    _storage[tableKey] ??= [];

    final newMsg = MessageModel(
      message.id,
      autoId: _nextAutoId++,
      type: message.type,
      status: message.status,
      fromId: message.fromId,
      toId: message.toId,
      payload: message.payload,
      isAuthor: message.isAuthor,
      conversationUk3: message.conversationUk3,
      createdAt: message.createdAt,
      msgType: message.msgType,
    );

    _storage[tableKey]!.add(newMsg);
    return newMsg.autoId;
  }

  /// 根据conversationUk3查找消息
  Future<List<MessageModel>> findByConversationUk3(
    String type,
    String conversationUk3,
  ) async {
    final tableKey = _getTableKey(type);
    final messages = _storage[tableKey] ?? [];

    return messages
        .where((msg) => msg.conversationUk3 == conversationUk3)
        .toList();
  }

  /// 获取最后一条消息
  Future<MessageModel?> findLastByConversationUk3(
    String type,
    String conversationUk3,
  ) async {
    final messages = await findByConversationUk3(type, conversationUk3);
    if (messages.isEmpty) return null;

    // 按autoId排序，返回最大的
    messages.sort((a, b) => b.autoId.compareTo(a.autoId));
    return messages.first;
  }

  /// 统计消息数量
  Future<int> count(
    String type, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final tableKey = _getTableKey(type);
    final messages = _storage[tableKey] ?? [];

    if (where == null) return messages.length;

    // 简单的where子句解析
    // 只支持 "column = ? AND column = ?" 格式
    final conditions = where.split(' AND ');
    int count = 0;

    for (final msg in messages) {
      bool match = true;
      for (
        int i = 0;
        i < conditions.length && i < (whereArgs?.length ?? 0);
        i++
      ) {
        final condition = conditions[i].trim();
        final parts = condition.split(' = ');
        if (parts.length != 2) continue;

        final column = parts[0].trim();
        final value = whereArgs![i];

        // 简化版：只检查auto_id和conversation_uk3
        if (column.contains('auto_id')) {
          if (msg.autoId != value) match = false;
        } else if (column.contains('conversation_uk3')) {
          if (msg.conversationUk3 != value) match = false;
        }
      }
      if (match) count++;
    }

    return count;
  }

  /// 清空所有数据
  void clear() {
    _storage.clear();
    _nextAutoId = 1;
  }

  /// 获取所有消息
  List<MessageModel> getAll(String type) {
    final tableKey = _getTableKey(type);
    return _storage[tableKey] ?? [];
  }
}

/// Mock Storage Service
///
/// 在内存中模拟键值存储
class MockStorageService {
  static final Map<String, dynamic> _storage = {};

  static String? getString(String key) {
    return _storage[key] as String?;
  }

  static Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  static Future<void> remove(String key) async {
    _storage.remove(key);
  }

  static void clear() {
    _storage.clear();
  }

  static int? getInt(String key) {
    return _storage[key] as int?;
  }

  static Future<void> setInt(String key, int value) async {
    _storage[key] = value;
  }
}
