import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 聊天背景逻辑控制器
class ChatBackgroundLogic {
  // 聊天背景相关的业务逻辑可以在这里添加
}

/// 聊天背景 Provider
final chatBackgroundProvider = Provider<ChatBackgroundLogic>((ref) {
  return ChatBackgroundLogic();
});
