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
      if (ready) return true;
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
        if (existing != null) {
          await repo.update({
            'id': message.id,
            'status': IMBoyMessageStatus.sent,
          });
        }
        return true;
      }
      if (tasks.isNotEmpty) {
        final uploader = ResumableAttachmentUploader();
        await uploader.recoverBusinessOutbox(uid);
        final refreshed = await uploader.repo.findByAnchor(message.id, uid);
        return actor.isCurrentSession(generation) &&
            refreshed.every(
              (r) =>
                  (jsonDecode(r.businessIntent!) as Map)['state'] ==
                  'outbox_ready',
            );
      }
    }
    return await onMessageCreated(message);
  }
}
