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

/// 发送消息逻辑控制器
class SendToLogic {
  List<ConversationModel> _conversations = [];
  List<ConversationModel> _searchResults = [];
  final List<ConversationModel> _selectedContacts = [];

  List<ConversationModel> get conversations => _conversations;
  List<ConversationModel> get searchResults => _searchResults;
  List<ConversationModel> get selectedContacts => List.from(_selectedContacts);

  String _normalizeConversationType(String? type) {
    return MessageFlowType.normalize(type);
  }

  /// 最近聊天
  Future<void> conversationsList() async {
    _conversations = await (ConversationRepo()).list(limit: 100);
    _searchResults = List.from(_conversations);
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
    } catch (e) {
      debugPrint('[send_to_provider] block error: $e');
    }
    return false;
  }

  /// 搜索
  void search(String query) {
    if (query.isEmpty) {
      _searchResults = List.from(_conversations);
    } else {
      _searchResults = _conversations.where((contact) {
        return contact.title.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
  }

  /// 切换联系人选择
  void toggleContactSelection(ConversationModel contact) {
    if (_selectedContacts.any((element) => element.id == contact.id)) {
      _selectedContacts.removeWhere((element) => element.id == contact.id);
    } else {
      _selectedContacts.add(contact);
    }
  }
}

/// 发送消息 Provider
final sendToProvider = Provider<SendToLogic>((ref) {
  return SendToLogic();
});
