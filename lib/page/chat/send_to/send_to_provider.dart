import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:xid/xid.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/message_type_constants.dart';

import 'package:imboy/service/events/events.dart';

/// 发送给 页面状态
class SendToState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> searchResults;
  final List<ConversationModel> selectedContacts;

  const SendToState({
    this.conversations = const [],
    this.searchResults = const [],
    this.selectedContacts = const [],
  });

  SendToState copyWith({
    List<ConversationModel>? conversations,
    List<ConversationModel>? searchResults,
    List<ConversationModel>? selectedContacts,
  }) {
    return SendToState(
      conversations: conversations ?? this.conversations,
      searchResults: searchResults ?? this.searchResults,
      selectedContacts: selectedContacts ?? this.selectedContacts,
    );
  }
}

/// 发送消息逻辑控制器
class SendToNotifier extends Notifier<SendToState> {
  @override
  SendToState build() => const SendToState();

  String _normalizeConversationType(String? type) {
    return MessageFlowType.normalize(type);
  }

  /// 最近聊天
  Future<void> conversationsList() async {
    final conversations = await (ConversationRepo()).list(limit: 100);
    state = state.copyWith(
      conversations: conversations,
      searchResults: List.from(conversations),
    );
  }

  /// 发送消息
  Future<bool> sendMsg(ConversationModel conversation, Message msg) async {
    try {
      // 构造 payload
      final payload = <String, dynamic>{
        'text': msg is TextMessage ? msg.text : '',
        'peer_id': conversation.peerId,
        if (msg.metadata != null) ...msg.metadata!,
      };

      // 获取并归一化会话类型，历史脏值统一按 C2C 处理
      final chatType = _normalizeConversationType(conversation.type);

      // 创建 MessageModel
      final msgModel = MessageModel(
        Xid().toString(),
        autoId: 0,
        type: chatType,
        status: 10, // 发送中
        fromId: int.tryParse(UserRepoLocal.to.currentUid) ?? 0,
        toId: conversation.peerId,
        payload: payload,
        createdAt: DateTimeHelper.millisecond(),
        isAuthor: 1,
        conversationUk3: conversation.uk3,
      );

      // 添加消息到数据库
      final msgRepo = MessageRepo(
        tableName: MessageRepo.getTableName(chatType),
      );
      await msgRepo.insert(msgModel);

      // 通过事件总线触发消息发送
      AppEventBus.fire(
        MessageSendRequestedEvent(
          message: msgModel,
          conversationUk3: conversation.uk3,
        ),
      );

      return true;
    } on Exception catch (e) {
      debugPrint('[send_to_provider] block error: $e');
    }
    return false;
  }

  /// 转发给所有已选联系人，返回失败数量
  Future<int> sendToSelected(Message msg) async {
    final targets = state.selectedContacts;
    var failCount = 0;
    for (final contact in targets) {
      final ok = await sendMsg(contact, msg);
      if (!ok) failCount++;
    }
    return failCount;
  }

  /// 搜索
  void search(String query) {
    final results = query.isEmpty
        ? List<ConversationModel>.from(state.conversations)
        : state.conversations
              .where(
                (contact) =>
                    contact.title.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    state = state.copyWith(searchResults: results);
  }

  /// 切换联系人选择
  void toggleContactSelection(ConversationModel contact) {
    final selected = List<ConversationModel>.from(state.selectedContacts);
    final exists = selected.any((element) => element.id == contact.id);
    if (exists) {
      selected.removeWhere((element) => element.id == contact.id);
    } else {
      selected.add(contact);
    }
    state = state.copyWith(selectedContacts: selected);
  }
}

/// 发送消息 Provider
final sendToProvider = NotifierProvider<SendToNotifier, SendToState>(
  SendToNotifier.new,
);
