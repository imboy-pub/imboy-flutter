part of 'web_chat_input.dart';

extension _WebChatInputSend on _WebChatInputState {
  /// FL-06：引用消息构建（与 mobile chat_page._sendQuoteMessage 同合同）。
  CustomMessage _quoteMessageFor(WebComposerIntent intent, String text) {
    final quoted = intent.quoteMessage!;
    return CustomMessage(
      authorId: widget.currentUserId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: {
        'msg_type': 'quote',
        'peer_id': widget.selection.peerId,
        'quote_msg': quoted.toJson(),
        'quote_msg_author_name': resolveQuoteAuthorName(
          quoteAuthorId: quoted.authorId,
          currentUid: widget.currentUserId,
          myNickname: UserRepoLocal.to.current.nickname,
          peerTitle: widget.selection.peerId,
        ),
        'quote_text': text,
      },
    );
  }

  TextMessage _messageFor(String text) {
    _pendingMessage = _pendingMessage?.text == text
        ? _pendingMessage
        : TextMessage(
            authorId: widget.currentUserId,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              DateTimeHelper.millisecond(),
              isUtc: true,
            ),
            id: Xid().toString(),
            text: text,
            metadata: {'peer_id': widget.selection.peerId},
          );
    return _pendingMessage!;
  }

  Future<bool> _dispatch(
    TextMessage message,
    bool Function() current,
    bool animateInsert,
  ) async {
    final notifier = ref.read(chatProvider.notifier);
    final service = notifier.chatService;
    final type = widget.selection.chatType;
    final peer = widget.selection.peerId;
    return dispatchPendingTextSend(
      message: message,
      type: type,
      peerId: peer,
      repository:
          widget.messageRepository ??
          MessageRepo(tableName: MessageRepo.getTableName(type)),
      isCurrent: current,
      retry: notifier.retryMessage,
      sendNew: (message) async {
        final sent = await notifier.addMessage(
          message.authorId,
          peer,
          _peerAvatar,
          peer,
          type,
          message,
        );
        if (!current()) return false;
        if (identical(service, notifier.chatService)) {
          await service?.insertMessage(
            message,
            index: 0,
            animated: animateInsert,
          );
        }
        return current() && sent;
      },
    );
  }
}
