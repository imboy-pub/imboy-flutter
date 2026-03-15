import 'package:imboy/modules/messaging/domain/message_models.dart';
import 'package:imboy/service/message.dart';

/// Temporary adapter that exposes a stable module contract while delegating to
/// the legacy message services.
class MessageServiceAdapter {
  MessageServiceAdapter({MessageService? service})
    : _service = service ?? MessageService.instance;

  static final MessageServiceAdapter instance = MessageServiceAdapter();

  final MessageService _service;

  MessageRepo getMessageRepo(String type) => _service.getMessageRepo(type);

  bool get isOnline => _service.isOnline;

  Stream<bool> get onlineStatusStream => _service.onlineStatusStream;

  Future<void> processMessage(String type, Map data) =>
      _service.processMessage(type, data);

  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) => _service.addLocalMsg(
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
  }) => _service.changeLocalMsgState(
    msgId,
    state,
    startAt: startAt,
    endAt: endAt,
  );

  Future<bool> sendRevokeMessage(String messageId, String messageType) =>
      _service.sendRevokeMessage(messageId, messageType);

  Future<bool> sendEditMessage(
    String messageId,
    String messageType,
    String newContent,
  ) => _service.sendEditMessage(messageId, messageType, newContent);

  Future<bool> canRevokeMessage(MessageModel msg) =>
      _service.canRevokeMessage(msg);

  Future<bool> canEditMessage(MessageModel msg) => _service.canEditMessage(msg);

  Future<void> sendInputStatus({
    required String conversationUk3,
    required String toId,
    required String msgType,
    required TypingStatus status,
  }) => _service.sendInputStatus(
    conversationUk3: conversationUk3,
    toId: toId,
    msgType: msgType,
    status: status,
  );
}
