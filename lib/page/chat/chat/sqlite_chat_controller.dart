import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 基于SQLite的聊天控制器
/// 负责消息的本地存储和管理，与UI层通过Stream通信
class SqliteChatController
    with UploadProgressMixin, ScrollToMessageMixin
    implements ChatController {
  final StreamController<ChatOperation> _operationsController =
      StreamController<ChatOperation>.broadcast();
  final List<Message> _messages = [];
  bool _isDisposed = false;
  final ProviderContainer container;

  SqliteChatController(this.container);

  /// 检查控制器是否已释放
  bool get isDisposed => _isDisposed;

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
  Future<void> insertMessage(
    Message message, {
    int? index,
    bool animated = true,
  }) async {
    if (_isDisposed) return;
    iPrint('Inserting message: ${message.id}, animated: $animated');
    if (!_isMessageIdUnique(message.id)) return; // 已有则忽略
    final insertIndex = index ?? 0; // 默认插到顶部
    _messages.insert(insertIndex, message);
    iPrint('Inserting message: ${message.id} $insertIndex');
    _operationsController.add(
      ChatOperation.insert(message, insertIndex, animated: animated),
    );
  }

  /// 批量插入多条消息（自动判重），可指定插入位置
  @override
  Future<void> insertAllMessages(
    List<Message> messages, {
    int? index,
    bool animated = true,
  }) async {
    if (_isDisposed) return;
    if (messages.isEmpty) return;
    final seen = <String>{..._messages.map((m) => m.id)};
    final unique = messages.where((m) => !seen.contains(m.id)).toList();
    if (unique.isEmpty) return;
    final insertIndex = index ?? 0;
    _messages.insertAll(insertIndex, unique);
    _operationsController.add(
      ChatOperation.insertAll(unique, insertIndex, animated: animated),
    );
  }

  /// 移除消息（通过id定位）
  @override
  Future<void> removeMessage(Message message, {bool animated = true}) async {
    if (_isDisposed) return;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    _messages.removeAt(index);
    _operationsController.add(
      ChatOperation.remove(message, index, animated: animated),
    );
  }

  /// 通过id移除消息
  Future<void> removeMessageById(String id) async {
    if (_isDisposed) return;
    iPrint('removeMessageById: 开始删除消息, ID: $id, 当前消息数量: ${_messages.length}');

    // 打印所有消息ID以便调试
    if (kDebugMode) {
      final messageIds = _messages.map((m) => m.id).toList();
    }

    final index = _messages.indexWhere((m) => m.id == id);
    iPrint('removeMessageById: 消息ID: $id, 在列表中的索引: $index');

    if (index == -1) {
      iPrint('removeMessageById: 警告 - 消息未在UI列表中找到，但继续执行删除操作');
      // 即使消息不在当前UI列表中，我们仍然需要通知UI层可能有变化
      // 这对于分页加载的消息特别重要

      // 尝试从数据库中查找消息，确认消息是否存在
      try {
        // 尝试从不同的消息表中查找消息
        final tables = [
          'message',
          'group_message',
          'c2s_message',
          's2c_message',
        ];
        bool messageExistsInDb = false;

        for (final tableName in tables) {
          final mRepo = MessageRepo(tableName: tableName);
          final dbMsg = await mRepo.find(id);
          if (dbMsg != null) {
            messageExistsInDb = true;
            iPrint('removeMessageById: 数据库查询结果 - 消息存在于表 $tableName: $id');
            break;
          }
        }

        // 如果消息存在于数据库但不在UI列表中，我们仍然触发一个刷新事件
        if (messageExistsInDb) {
          iPrint('removeMessageById: 消息存在于数据库但不在UI列表中，触发刷新事件');
          // 创建一个虚拟的删除操作，通知UI层可能需要刷新
          if (!_isDisposed) {
            _operationsController.add(
              ChatOperation.set(List.unmodifiable(_messages)),
            );
          }
        } else {
          iPrint('removeMessageById: 消息在数据库中也不存在，可能已被删除');
          // 即使消息在数据库中不存在，我们也触发一个刷新事件，确保UI同步
          if (!_isDisposed) {
            _operationsController.add(
              ChatOperation.set(List.unmodifiable(_messages)),
            );
          }
        }
      } catch (e) {
        iPrint('removeMessageById: 数据库查询异常: $e');
        // 即使查询异常，我们也触发一个刷新事件，确保UI同步
        if (!_isDisposed) {
          _operationsController.add(
            ChatOperation.set(List.unmodifiable(_messages)),
          );
        }
      }

      return;
    }

    final msg = _messages[index];
    iPrint('removeMessageById: 准备从UI列表移除消息: ${msg.id}, 类型: ${msg.runtimeType}');

    try {
      _messages.removeAt(index);
      if (!_isDisposed) {
        _operationsController.add(ChatOperation.remove(msg, index));
      }
      iPrint(
        'removeMessageById: UI列表移除消息完成: ${msg.id}, 剩余消息数量: ${_messages.length}',
      );
    } catch (e) {
      iPrint('removeMessageById: UI列表移除消息异常: $e');
    }
  }

  /// 更新消息
  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    if (_isDisposed) return;
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
  Future<void> setMessages(
    List<Message> messages, {
    bool animated = true,
  }) async {
    if (_isDisposed) return;
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
    // 如果消息为空，则不使用动画，避免奇怪的视觉效果
    final useAnimation = animated && messages.isNotEmpty;
    _operationsController.add(
      ChatOperation.set(List.unmodifiable(_messages), animated: useAnimation),
    );
  }

  /// 清空所有消息（同时推送set操作）
  Future<void> clearMessages() async {
    if (_isDisposed) return;
    _messages.clear();
    _operationsController.add(ChatOperation.set([]));
  }

  /// 重置控制器状态（清空消息并重置相关状态）
  Future<void> reset() async {
    if (_isDisposed) return;
    iPrint('SqliteChatController: 重置控制器状态');
    await clearMessages();
    // 这里可以添加其他需要重置的状态
  }

  /// 滚动到底部（转发到滚动管理器）
  /// animated: 是否使用动画滚动
  Future<void> scrollToBottom({bool animated = true}) async {
    try {
      await container
          .read(messageScrollManagerProvider.notifier)
          .scrollToBottom(animated: animated);
    } catch (e) {
      iPrint('[sqlite_chat_controller] scrollToBottom error: $e');
    }
  }

  /// 滚动到指定消息（优化版）
  @override
  Future<void> scrollToMessage(
    String messageId, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linearToEaseOut,
    double alignment = 0,
    double offset = 80.0,
  }) async {
    try {
      // 1. 优先尝试使用 ChatAnimatedList 提供的滚动能力 (ScrollToMessageMixin)
      // 这是最准确的方式，因为它基于列表的实际索引和布局
      await super.scrollToMessage(
        messageId,
        duration: duration,
        curve: curve,
        alignment: alignment,
        offset: offset,
      );

      // 2. 触发高亮
      container
          .read(messageScrollManagerProvider.notifier)
          .highlightMessage(messageId);

      // 注意：我们不再优先使用 MessageScrollManager.scrollToMessage
      // 因为对于新加载的历史消息，它的位置缓存通常是估算的，很不准确。
      // 而 super.scrollToMessage 依赖于 ChatAnimatedList 的实现，更为可靠。
      // 如果 super.scrollToMessage 因为未 attach 而未执行，外部的重试机制会再次调用。
    } catch (e) {
      iPrint('滚动到消息失败: $messageId, 错误: $e');
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _isDisposed = true;
    _operationsController.close();
    disposeUploadProgress();
    disposeScrollMethods();
  }
}
