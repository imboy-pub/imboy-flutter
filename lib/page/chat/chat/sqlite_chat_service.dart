import 'dart:async';

import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';

/// 基于SQLite的聊天服务
/// 负责消息的本地存储和管理，与UI层通过Stream通信
///
/// 迁移说明:
/// 1. 移除了 ProviderContainer 依赖，改用 Ref
/// 2. 创建了 Riverpod Provider 来管理服务生命周期
/// 3. 保持了所有业务逻辑不变
class SqliteChatService
    with UploadProgressMixin, ScrollToMessageMixin
    implements ChatController {
  final StreamController<ChatOperation> _operationsController =
      StreamController<ChatOperation>.broadcast();
  final List<Message> _messages = [];
  bool _isDisposed = false;
  final Ref _ref;

  SqliteChatService(this._ref);

  /// 检查服务是否已释放
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

    final index = _messages.indexWhere((m) => m.id == id);
    iPrint('removeMessageById: 消息ID: $id, 在列表中的索引: $index');

    if (index == -1) {
      iPrint('removeMessageById: 警告 - 消息未在UI列表中找到，但继续执行删除操作');
      // 即使消息不在当前UI列表中，我们仍然需要通知UI层可能有变化
      // 这对于分页加载的消息特别重要

      // Persistence belongs to MessageActions/MessageRepo. A message outside
      // the loaded window only requires a refresh of the current projection.
      _operationsController.add(
        ChatOperation.set(List.unmodifiable(_messages)),
      );

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

  static const _quoteSnapshotHidden = '_quote_snapshot_hidden';

  static CustomMessage hideQuoteSnapshot(CustomMessage message) {
    final metadata = <String, dynamic>{...?message.metadata}
      ..remove('quote_msg')
      ..remove('quote_msg_author_name')
      ..[_quoteSnapshotHidden] = true;
    return message.copyWith(metadata: metadata);
  }

  /// 更新消息
  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    if (_isDisposed) return;
    final index = _messages.indexWhere((m) => m.id == oldMessage.id);
    if (index == -1) return;
    final stored = _messages[index];
    final replacement =
        stored.metadata?[_quoteSnapshotHidden] == true &&
            newMessage is CustomMessage &&
            newMessage.metadata?['msg_type'] == 'quote'
        ? hideQuoteSnapshot(newMessage)
        : newMessage;
    if (stored == replacement) return;
    _messages[index] = replacement;
    _operationsController.add(ChatOperation.update(stored, replacement, index));
  }

  /// 设置/重置消息列表（自动去重，按传入顺序覆盖）
  @override
  Future<void> setMessages(
    List<Message> messages, {
    bool animated = true,
  }) async {
    if (_isDisposed) {
      iPrint('setMessages: ChatService 已释放，跳过设置 ${messages.length} 条消息');
      return;
    }
    iPrint('setMessages: 开始设置 ${messages.length} 条消息');
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
    iPrint(
      'setMessages: 发送 ChatOperation.set 事件，消息数: ${_messages.length}, animated: $useAnimation',
    );
    _operationsController.add(
      ChatOperation.set(List.unmodifiable(_messages), animated: useAnimation),
    );
    iPrint('setMessages: 完成，共 ${_messages.length} 条消息');
  }

  /// 清空所有消息（同时推送set操作）
  Future<void> clearMessages() async {
    if (_isDisposed) return;
    _messages.clear();
    _operationsController.add(ChatOperation.set([]));
  }

  /// 重置服务状态（清空消息并重置相关状态）
  Future<void> reset() async {
    if (_isDisposed) return;
    iPrint('SqliteChatService: 重置服务状态');
    await clearMessages();
    // 这里可以添加其他需要重置的状态
  }

  /// 滚动到底部（转发到滚动管理器）
  /// animated: 是否使用动画滚动
  Future<void> scrollToBottom({bool animated = true}) async {
    try {
      await _ref
          .read(messageScrollManagerProvider.notifier)
          .scrollToBottom(animated: animated);
    } catch (e) {
      iPrint('[sqlite_chat_service] scrollToBottom error: $e');
    }
  }

  @override
  Future<void> scrollToMessage(
    String messageId, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linearToEaseOut,
    double alignment = 0,
    double offset = 80.0,
  }) async {
    await super.scrollToMessage(
      messageId,
      duration: duration,
      curve: curve,
      alignment: alignment,
      offset: offset,
    );
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

/// Riverpod Provider for SqliteChatService
///
/// 使用说明：
/// ```dart
/// // 在 Widget 中使用
/// final chatService = ref.watch(sqliteChatServiceProvider);
///
/// // 或者在 Notifier 中使用
/// final chatService = ref.read(sqliteChatServiceProvider);
/// ```
///
/// 注意：这个 Provider 会在需要时自动创建实例，
/// 并在 Ref 释放时自动调用 dispose() 方法
final sqliteChatServiceProvider = Provider<SqliteChatService>((ref) {
  final service = SqliteChatService(ref);

  // 当 provider 被释放时，自动清理资源
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
