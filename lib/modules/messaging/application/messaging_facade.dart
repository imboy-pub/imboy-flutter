import 'package:imboy/modules/messaging/domain/message_models.dart';
import 'package:imboy/modules/messaging/infrastructure/message_service_adapter.dart';

/// Stable module entry for upper layers. Current implementation remains a thin
/// facade over the legacy message services until internal migration is done.
class MessagingFacade {
  MessagingFacade({MessageServiceAdapter? adapter})
    : _adapter = adapter ?? MessageServiceAdapter.instance;

  static final MessagingFacade instance = MessagingFacade();

  final MessageServiceAdapter _adapter;

  MessageRepo getMessageRepo(String type) => _adapter.getMessageRepo(type);

  bool get isOnline => _adapter.isOnline;

  Stream<bool> get onlineStatusStream => _adapter.onlineStatusStream;

  Future<void> processMessage(String type, Map<String, dynamic> data) =>
      _adapter.processMessage(type, data);

  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) => _adapter.addLocalMsg(
    media: media,
    caller: caller,
    msgId: msgId,
    peer: peer,
  );

  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) => _adapter.changeLocalMsgState(
    msgId,
    state,
    startAt: startAt,
    endAt: endAt,
  );

  Future<bool> sendRevokeMessage(String messageId, String messageType) =>
      _adapter.sendRevokeMessage(messageId, messageType);

  Future<bool> sendEditMessage(
    String messageId,
    String messageType,
    String newContent,
  ) => _adapter.sendEditMessage(messageId, messageType, newContent);

  Future<bool> canRevokeMessage(MessageModel msg) =>
      _adapter.canRevokeMessage(msg);

  Future<bool> canEditMessage(MessageModel msg) => _adapter.canEditMessage(msg);

  Future<void> sendInputStatus({
    required String conversationUk3,
    required String toId,
    required String chatType,
    required TypingStatus status,
  }) => _adapter.sendInputStatus(
    conversationUk3: conversationUk3,
    toId: toId,
    chatType: chatType,
    status: status,
  );

  /// 标记消息为已读（轻量版，适用于非 Widget 上下文）
  Future<bool> markAsRead(String type, String peerId, List<String> msgIds) =>
      _adapter.markAsRead(type, peerId, msgIds);
}
