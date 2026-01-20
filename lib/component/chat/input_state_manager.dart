import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/events/events.dart';

/// 输入状态数据模型
class InputState {
  final Map<String, String> typingUsers;
  final bool isSomeoneTyping;
  final String typingUsername;

  const InputState({
    this.typingUsers = const {},
    this.isSomeoneTyping = false,
    this.typingUsername = '',
  });

  InputState copyWith({
    Map<String, String>? typingUsers,
    bool? isSomeoneTyping,
    String? typingUsername,
  }) {
    return InputState(
      typingUsers: typingUsers ?? this.typingUsers,
      isSomeoneTyping: isSomeoneTyping ?? this.isSomeoneTyping,
      typingUsername: typingUsername ?? this.typingUsername,
    );
  }
}

/// 输入状态管理器 Provider
/// 处理对方正在输入状态的显示和隐藏
final inputStateManagerProvider =
    NotifierProvider<InputStateManager, InputState>(() {
      return InputStateManager();
    });

class InputStateManager extends Notifier<InputState> {
  Timer? _typingTimer;

  @override
  InputState build() {
    // 初始化时监听输入状态事件
    _listenToTypingEvents();
    return const InputState();
  }

  // dispose 方法需要手动调用
  void dispose() {
    _typingTimer?.cancel();
  }

  /// 监听输入状态事件
  void _listenToTypingEvents() {
    // 监听WebSocket的输入状态事件
    // WebSocketService.to.onTyping.listen(_handleTypingEvent);
  }

  /// 处理输入状态事件
  void handleTypingEvent(Map<String, dynamic> data) {
    final userId = data['user_id'] as String;
    final username = data['username'] as String;
    final isTyping = data['is_typing'] as bool;

    if (isTyping) {
      _addTypingUser(userId, username);
    } else {
      _removeTypingUser(userId);
    }
  }

  /// 添加正在输入的用户
  void _addTypingUser(String userId, String username) {
    final newTypingUsers = Map<String, String>.from(state.typingUsers);
    newTypingUsers[userId] = username;
    _updateTypingState(newTypingUsers);

    // 3秒后自动移除
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _removeTypingUser(userId);
    });
  }

  /// 移除正在输入的用户
  void _removeTypingUser(String userId) {
    final newTypingUsers = Map<String, String>.from(state.typingUsers);
    newTypingUsers.remove(userId);
    _updateTypingState(newTypingUsers);
  }

  /// 更新输入状态
  void _updateTypingState(Map<String, String> typingUsers) {
    if (typingUsers.isEmpty) {
      state = state.copyWith(
        typingUsers: typingUsers,
        isSomeoneTyping: false,
        typingUsername: '',
      );
    } else {
      state = state.copyWith(
        typingUsers: typingUsers,
        isSomeoneTyping: true,
        typingUsername: typingUsers.values.first,
      );
    }
  }

  /// 发送自己正在输入的状态
  void sendTypingStatus(String conversationId, bool isTyping) {
    // 解耦：使用 MessageService 的在线状态
    if (!MessageService.to.isOnline) {
      return;
    }

    final message = {
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
      'timestamp': DateTimeHelper.millisecond(),
    };

    // 解耦：通过事件总线发送消息
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(message: jsonEncode(message)),
    );
  }

  /// 清理指定会话的输入状态
  void clearConversationTyping(String conversationId) {
    state = const InputState();
  }
}

/// 输入状态指示器组件
class InputStatusIndicator extends ConsumerWidget {
  const InputStatusIndicator({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputState = ref.watch(inputStateManagerProvider);

    if (!inputState.isSomeoneTyping) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${inputState.typingUsername} 正在输入...',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
