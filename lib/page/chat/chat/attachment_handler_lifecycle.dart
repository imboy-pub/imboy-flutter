part of 'attachment_handler.dart';

extension _ChatAttachmentLifecycle on ChatAttachmentHandler {
  Future<void> _runOwned(
    Future<void> Function(void Function() check) work,
  ) async {
    final actor = UserRepoLocal.to;
    final generation = ownerGeneration ?? actor.sessionGeneration;
    final uid = currentUserOverride?.id ?? actor.currentUid;
    if (uid.isEmpty) return;
    final owner = AccountLocalTaskOwner.capture(uid: uid);
    try {
      await AccountLocalTaskRegistry.instance.run<void>(
        owner,
        operation: (task) async {
          void check() {
            task.throwIfCancelled();
            requireCurrent?.call();
            if (!actor.isCurrentSession(generation) ||
                (currentUserOverride == null &&
                    (actor.isAuthTransitioning || actor.currentUid != uid)) ||
                (currentEnv.isEmpty ? 'pro' : currentEnv) !=
                    owner.environment ||
                Env().apiBaseUrl != owner.endpoint) {
              throw const AccountLocalTaskCancelledException();
            }
          }

          check();
          await work(check);
          check();
        },
      );
    } on AccountLocalTaskCancelledException {
      // The old account no longer owns this preparation or its callback.
    }
  }

  /// 安全拦截：如果用户被禁言，直接拦截消息创建与发送，并弹出 EasyLoading 提示 (C13)
  Future<bool> _sendMessage(Message message) async {
    final ready = await _sendCurrentMessage(message);
    requireCurrent?.call();
    onUploadResult?.call(ready, null);
    return ready;
  }

  Future<bool> _sendCurrentMessage(Message message) async {
    requireCurrent?.call();
    if (isMutedCheck != null && isMutedCheck!()) {
      AppLoading.showError(t.chat.youAreMuted);
      return false;
    }
    if (currentUserOverride == null && (type == 'C2C' || type == 'C2G')) {
      final actor = UserRepoLocal.to;
      final generation = actor.sessionGeneration;
      final uid = actor.currentUid;
      if (message.authorId != uid ||
          actor.isAuthTransitioning ||
          (ownerGeneration != null &&
              !actor.isCurrentSession(ownerGeneration!))) {
        return false;
      }
      final repo = MessageRepo(tableName: MessageRepo.getTableName(type));
      final existing = await repo.find(message.id);
      final tasks = await AttachmentUploadTaskRepo().findByAnchor(
        message.id,
        uid,
      );
      final uncertain = tasks.any(
        (row) =>
            row.businessIntent != null &&
            (jsonDecode(row.businessIntent!) as Map)['state'] != 'uploading',
      );
      final ready =
          tasks.isNotEmpty &&
          tasks.every(
            (row) =>
                (jsonDecode(row.businessIntent!) as Map)['state'] ==
                'outbox_ready',
          );
      if (ready) return _presentPersisted(message, uid, generation);
      if (existing != null || uncertain) {
        final committed = await MsgApi().isCommitted(
          chatType: type.toLowerCase(),
          peerId: peerId,
          messageId: message.id,
        );
        if (!actor.isCurrentSession(generation) ||
            actor.currentUid != uid ||
            !committed) {
          return false;
        }
        return _presentPersisted(message, uid, generation);
      }
      if (tasks.isNotEmpty) {
        final uploader = _uploader();
        await uploader.recoverBusinessOutbox(uid, anchorMsgId: message.id);
        final refreshed = await uploader.repo.findByAnchor(message.id, uid);
        final ready =
            actor.isCurrentSession(generation) &&
            refreshed.isNotEmpty &&
            refreshed.every(
              (r) =>
                  (jsonDecode(r.businessIntent!) as Map)['state'] ==
                  'outbox_ready',
            );
        return ready && await _presentPersisted(message, uid, generation);
      }
    }
    return await onMessageCreated(message);
  }

  Future<bool> _presentPersisted(
    Message message,
    String uid,
    int generation,
  ) async {
    final present = onMessagePersisted;
    if (present == null) return true;
    return const ChatNetworkService().presentAttachmentOutbox(
      type: type,
      peerId: peerId,
      conversationUk3: conversationUk3,
      messageId: message.id,
      isCurrent: () {
        requireCurrent?.call();
        return UserRepoLocal.to.currentUid == uid &&
            UserRepoLocal.to.isCurrentSession(generation) &&
            (ownerGeneration == null || ownerGeneration == generation);
      },
      present: (canonical) async {
        requireCurrent?.call();
        return present(canonical);
      },
    );
  }
}
