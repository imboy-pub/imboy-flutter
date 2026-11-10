part of 'message.dart';

/// 当收到新消息且用户不在当前会话时，显示可以跳转到会话的系统通知。
/// 固定入站消息最初的会话，不能在异步处理后归到切换后的账号。
Future<void> _showMessageNotification(
  MessageService service, {
  required AuthSessionScope session,
  required AccountLocalTaskOwner owner,
  required MessageModel msg,
  required String senderName,
  required String conversationUk3,
  required String peerId,
  required String chatType,
}) async {
  try {
    if (!authSessionReader.isCurrent(session) ||
        AccountLocalTaskOwner.capture() != owner) {
      return;
    }
    final content = messagePreviewText(
      msg.msgType ?? '',
      msg.payloadMap,
      fallback: '[新消息]',
    );

    // FULL-05：企业托管消息的通知标题带来源前缀（Application 代发 /
    // 人工经应用），普通消息前缀为空串——通知面与会话/详情/搜索同一条
    // 判定（plan §3.3「一致」），且不静默把代发消息通知成普通消息。
    final rawPayload = msg.payload;
    final hostedPrefix = hostedMessageNotificationPrefix(
      rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : null,
      e2ee: msg.e2ee,
    );
    await service._notificationService.showMessageNotification(
      senderName: '$hostedPrefix$senderName',
      content: content,
      conversationUk3: conversationUk3,
      peerId: peerId,
      chatType: chatType,
      session: session,
      owner: owner,
    );
    iPrint(
      '🔔 [Notification] 消息通知已触发: '
      'sender=$senderName, uk3=$conversationUk3',
    );
  } on AccountLocalTaskCancelledException {
    // An earlier login's notification is intentionally discarded.
  } on Object catch (error) {
    iPrint('❌ [Notification] 显示消息通知失败: $error');
  }
}
