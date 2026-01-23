import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';

part 'active_conversation_notifier.g.dart';

/// 活跃会话状态
class ActiveConversationState {
  final String activeConversationUk3;
  final DateTime lastActiveTime;

  const ActiveConversationState({
    this.activeConversationUk3 = '',
    required this.lastActiveTime,
  });

  ActiveConversationState copyWith({
    String? activeConversationUk3,
    DateTime? lastActiveTime,
  }) {
    return ActiveConversationState(
      activeConversationUk3:
          activeConversationUk3 ?? this.activeConversationUk3,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveConversationState &&
          runtimeType == other.runtimeType &&
          activeConversationUk3 == other.activeConversationUk3 &&
          lastActiveTime == other.lastActiveTime;

  @override
  int get hashCode => activeConversationUk3.hashCode ^ lastActiveTime.hashCode;
}

/// 活跃会话管理器（全局单例）
///
/// 用于跟踪用户当前正在查看的会话，以便正确计算未读数
/// - 当用户进入聊天页面时，设置活跃会话
/// - 当用户离开聊天页面时，清除活跃会话
/// - 5分钟内的会话视为活跃
@Riverpod(keepAlive: true)
class ActiveConversationNotifier extends _$ActiveConversationNotifier {
  @override
  ActiveConversationState build() {
    return ActiveConversationState(lastActiveTime: DateTime.now());
  }

  /// 设置活跃会话
  void setActiveConversation(String conversationUk3) {
    iPrint('📍 [ACTIVE_CONVERSATION] 设置活跃会话: $conversationUk3');
    state = state.copyWith(
      activeConversationUk3: conversationUk3,
      lastActiveTime: DateTime.now(),
    );
  }

  /// 清除活跃会话
  void clearActiveConversation() {
    iPrint('📍 [ACTIVE_CONVERSATION] 清除活跃会话');
    state = state.copyWith(
      activeConversationUk3: '',
      lastActiveTime: DateTime.now(),
    );
  }

  /// 检查会话是否活跃
  ///
  /// 判断条件：
  /// 1. 会话UK3匹配
  /// 2. 最后活跃时间在5分钟内
  bool isConversationActive(String conversationUk3) {
    // 5分钟内的会话视为活跃
    const activeDuration = Duration(minutes: 5);
    final isActive =
        state.activeConversationUk3 == conversationUk3 &&
        DateTime.now().difference(state.lastActiveTime) < activeDuration;

    if (isActive) {
      iPrint('📍 [ACTIVE_CONVERSATION] 会话 $conversationUk3 处于活跃状态');
    }

    return isActive;
  }

  /// 更新活跃时间（用于保持会话活跃状态）
  void updateActiveTime() {
    if (state.activeConversationUk3.isNotEmpty) {
      state = state.copyWith(lastActiveTime: DateTime.now());
    }
  }
}
