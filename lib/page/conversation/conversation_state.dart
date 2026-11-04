import 'package:imboy/store/model/conversation_model.dart';

// Riverpod State for Conversation Logic
class ConversationState {
  final bool isLoading;
  final Map<String, ConversationModel> conversationMap;
  final String connectDesc;
  final Map<String, int> conversationRemind;

  /// W09.a（§6.7/J17.c）：人工待处理（服务端 user_setting 元数据的
  /// 本地投影）。独立于真实 unread——「标未读」不再写 unreadNum=1。
  final Map<String, bool> manualPending;

  ConversationState({
    this.isLoading = true,
    this.conversationMap = const {},
    this.connectDesc = '',
    this.conversationRemind = const {},
    this.manualPending = const {},
  });

  ConversationState copyWith({
    bool? isLoading,
    Map<String, ConversationModel>? conversationMap,
    String? connectDesc,
    Map<String, int>? conversationRemind,
    Map<String, bool>? manualPending,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      conversationMap: conversationMap ?? this.conversationMap,
      connectDesc: connectDesc ?? this.connectDesc,
      conversationRemind: conversationRemind ?? this.conversationRemind,
      manualPending: manualPending ?? this.manualPending,
    );
  }

  // Cached sorted list — recomputed only when conversationMap changes (via copyWith)
  List<ConversationModel>? _cachedConversations;

  // Get sorted conversations list
  List<ConversationModel> get conversations {
    return _cachedConversations ??= _buildSorted();
  }

  List<ConversationModel> _buildSorted() {
    final list = conversationMap.values.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastTime.compareTo(a.lastTime);
    });
    return list;
  }

  // Get total remind counter
  int get chatMsgRemindCounter {
    return conversationMap.values.fold(0, (sum, cm) {
      if (cm.isMuted > 0) return sum;
      return sum + (conversationRemind[cm.uk3] ?? 0);
    });
  }
}
