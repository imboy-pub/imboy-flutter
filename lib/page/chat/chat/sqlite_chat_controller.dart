import 'dart:async';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/helper/func.dart';

/// 基于SQLite的聊天控制器
/// 负责消息的本地存储和管理，与UI层通过Stream通信
class SqliteChatController
    with UploadProgressMixin, ScrollToMessageMixin
    implements ChatController {

  final StreamController<ChatOperation> _operationsController =
      StreamController<ChatOperation>.broadcast();
  final List<Message> _messages = [];
  // bool _isInitialized = false;

  SqliteChatController();

  /// 保证消息唯一性：同id消息不会重复插入
  bool _isMessageIdUnique(String id) => !_messages.any((m) => m.id == id);

  /// 对外暴露只读消息列表
  @override
  List<Message> get messages => List.unmodifiable(_messages);

  /// 消息流推送，外部可监听此流做UI响应
  @override
  Stream<ChatOperation> get operationsStream => _operationsController.stream;

  /// 插入单条消息（自动判重），如果 index 未指定则插到顶部
  @override
  Future<void> insertMessage(Message message, {int? index}) async {
    iPrint('Inserting message: ${message.id}');
    if (!_isMessageIdUnique(message.id)) return; // 已有则忽略
    final insertIndex = index ?? 0; // 默认插到顶部
    _messages.insert(insertIndex, message);
    iPrint('Inserting message: ${message.id} $insertIndex');
    _operationsController.add(ChatOperation.insert(message, insertIndex));
  }

  /// 批量插入多条消息（自动判重），可指定插入位置
  @override
  Future<void> insertAllMessages(List<Message> messages, {int? index}) async {
    if (messages.isEmpty) return;
    final seen = <String>{..._messages.map((m) => m.id)};
    final unique = messages.where((m) => !seen.contains(m.id)).toList();
    if (unique.isEmpty) return;
    final insertIndex = index ?? 0;
    _messages.insertAll(insertIndex, unique);
    _operationsController.add(ChatOperation.insertAll(unique, insertIndex));
  }

  /// 移除消息（通过id定位）
  @override
  Future<void> removeMessage(Message message) async {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    _messages.removeAt(index);
    _operationsController.add(ChatOperation.remove(message, index));
  }

  /// 通过id移除消息
  Future<void> removeMessageById(String id) async {
    final index = _messages.indexWhere((m) => m.id == id);
    iPrint('removeMessageById: $id, index: $index');
    if (index == -1) return;
    final msg = _messages[index];
    _messages.removeAt(index);
    _operationsController.add(ChatOperation.remove(msg, index));
  }

  /// 更新消息
  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    final index = _messages.indexWhere((m) => m.id == oldMessage.id);
    if (index == -1) return;
    if (_messages[index] == newMessage) return;
    _messages[index] = newMessage;
    _operationsController.add(
      ChatOperation.update(oldMessage, newMessage, index),
    );
  }

  /// 设置/重置消息列表（自动去重，按传入顺序覆盖）
  @override
  Future<void> setMessages(List<Message> messages) async {
    final seen = <String>{};
    final unique = <Message>[];
    for (final m in messages) {
      if (!seen.contains(m.id)) {
        seen.add(m.id);
        unique.add(m);
      }
    }
    _messages
      ..clear()
      ..addAll(unique);
    _operationsController.add(ChatOperation.set(List.unmodifiable(_messages)));
  }

  /// 清空所有消息（同时推送set操作）
  Future<void> clearMessages() async {
    _messages.clear();
    _operationsController.add(ChatOperation.set([]));
  }

  /// 释放资源
  @override
  void dispose() {
    _operationsController.close();
    disposeUploadProgress();
    disposeScrollMethods();
  }
}
