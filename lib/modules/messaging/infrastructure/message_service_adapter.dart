import 'package:imboy/modules/messaging/domain/message_models.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

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

  /// 标记消息为已读（轻量版，仅操作本地数据库，不触发 UI Provider 刷新）
  ///
  /// 适用于非 Widget 上下文（如 WebRTC 来电处理），避免 Riverpod 依赖。
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds,
  ) async {
    if (msgIds.isEmpty) return false;
    final db = await SqliteService.to.db;
    if (db == null) return false;

    final c = await ConversationRepo().findByPeerId(type, peerId);
    if (c == null) return false;

    final tb = MessageRepo.getTableName(c.type);
    final newUnread = c.unreadNum - msgIds.length;
    c.unreadNum = newUnread > 0 ? newUnread : 0;

    return db.transaction((txn) async {
      await txn.update(
        ConversationRepo.tableName,
        {ConversationRepo.unreadNum: c.unreadNum},
        where: '${ConversationRepo.id}=?',
        whereArgs: [c.id],
      );
      for (final id in msgIds) {
        await txn.update(
          tb,
          {MessageRepo.status: IMBoyMessageStatus.seen},
          where: '${MessageRepo.id}=?',
          whereArgs: [id],
        );
      }
      return true;
    });
  }
}
