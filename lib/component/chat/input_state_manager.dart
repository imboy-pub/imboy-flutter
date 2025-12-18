import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/service/websocket.dart';

/// 输入状态管理器
/// 处理对方正在输入状态的显示和隐藏
class InputStateManager extends GetxController {
  static InputStateManager get to => Get.find();
  
  // 正在输入的用户列表 {userId: username}
  final Map<String, String> _typingUsers = {};
  
  // 正在输入状态的可观察值
  final RxBool isSomeoneTyping = false.obs;
  final RxString typingUsername = ''.obs;
  
  // 输入状态定时器
  Timer? _typingTimer;
  
  @override
  void onInit() {
    super.onInit();
    _listenToTypingEvents();
  }
  
  @override
  void onClose() {
    _typingTimer?.cancel();
    super.onClose();
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
    _typingUsers[userId] = username;
    _updateTypingState();
    
    // 3秒后自动移除
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _removeTypingUser(userId);
    });
  }
  
  /// 移除正在输入的用户
  void _removeTypingUser(String userId) {
    _typingUsers.remove(userId);
    _updateTypingState();
  }
  
  /// 更新输入状态
  void _updateTypingState() {
    if (_typingUsers.isEmpty) {
      isSomeoneTyping.value = false;
      typingUsername.value = '';
    } else {
      isSomeoneTyping.value = true;
      // 显示第一个正在输入的用户
      typingUsername.value = _typingUsers.values.first;
    }
  }
  
  /// 发送自己正在输入的状态
  void sendTypingStatus(String conversationId, bool isTyping) {
    if (WebSocketService.to.status.value == SocketStatus.connected) {
      final message = {
        'type': 'typing',
        'conversation_id': conversationId,
        'is_typing': isTyping,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      WebSocketService.to.sendMessage(jsonEncode(message), null);
    }
  }
  
  /// 清理指定会话的输入状态
  void clearConversationTyping(String conversationId) {
    // 清理与该会话相关的输入状态
    _typingUsers.clear();
    _updateTypingState();
  }
}

/// 输入状态指示器组件
class InputStatusIndicator extends StatelessWidget {
  const InputStatusIndicator({
    super.key,
    required this.conversationId,
  });
  
  final String conversationId;
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<InputStateManager>(
      init: InputStateManager.to,
      builder: (controller) {
        if (!controller.isSomeoneTyping.value) {
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
                  '${controller.typingUsername.value} 正在输入...',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}