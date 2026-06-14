import 'package:imboy/service/message_conversation_utils.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class InsertedOfflineMessage {
  final String id;
  final String type;
  final String fromId;
  final String toId;
  final Map<String, dynamic> payload;
  final int createdAt;
  final int isAuthor;
  final int topicId;
  final String conversationUk3;
  final int status;
  final String peerId;
  final String msgType; // WebSocket API v2.0: 顶层 msg_type 字段

  const InsertedOfflineMessage({
    required this.id,
    required this.type,
    required this.fromId,
    required this.toId,
    required this.payload,
    required this.createdAt,
    required this.isAuthor,
    required this.topicId,
    required this.conversationUk3,
    required this.status,
    required this.peerId,
    required this.msgType, // WebSocket API v2.0
  });

  MessageModel toMessageModel() {
    return MessageModel(
      id,
      autoId: 0,
      type: type,
      fromId: parseModelInt(fromId),
      toId: parseModelInt(toId),
      payload: payload,
      createdAt: createdAt,
      isAuthor: isAuthor,
      topicId: topicId,
      conversationUk3: conversationUk3,
      status: status,
      msgType: msgType, // WebSocket API v2.0
    );
  }
}

class OfflineConversationAgg {
  final String type;
  final String peerId;
  final String currentUid; // C7-β: 判定消息是否 @ 当前用户
  InsertedOfflineMessage? latest;
  int unreadDelta = 0;
  int mentionDelta = 0; // C7-β

  OfflineConversationAgg({
    required this.type,
    required this.peerId,
    this.currentUid = '',
  });

  void observe(InsertedOfflineMessage msg, String currentConversationUk3) {
    if (latest == null || msg.createdAt >= (latest?.createdAt ?? 0)) {
      latest = msg;
    }
    if (msg.isAuthor == 0 && msg.conversationUk3 != currentConversationUk3) {
      unreadDelta += 1;
      // C7-β：离线批量路径对称累加 mention_unread
      final mentionIds = extractMentionIdsFromPayload(msg.payload);
      mentionDelta += computeMentionUnreadIncrement(
        isFromCurrentUser: false, // isAuthor == 0 保证非自己
        isUserInChat: false, // 路径前提保证不在当前会话
        mentionIds: mentionIds,
        currentUid: currentUid,
      );
    }
  }
}
