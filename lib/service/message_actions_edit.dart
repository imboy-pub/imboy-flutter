part of 'message_actions.dart';

/// 编辑 action 接收处理（自 MessageActions 抽出的扩展，行为与调用方零变更）。
extension MessageActionsEdit on MessageActions {
  /// Handle edit action messages
  /// 处理编辑action消息
  Future<void> _handleEditAction(
    Map<String, dynamic> data, {
    required bool isAck,
  }) async {
    final session = UserRepoLocal.to;
    final ownerUid = session.currentUid;
    final generation = session.sessionGeneration;
    void requireCurrent() {
      if (ownerUid.isEmpty ||
          session.currentUid != ownerUid ||
          !session.isCurrentSession(generation) ||
          session.isClearingSession) {
        throw StateError('edit action session changed');
      }
    }

    requireCurrent();
    final msgType = parseModelString(data['type']);
    final msgId = parseModelString(data['id']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final originalMsgId = parseModelString(payload['original_msg_id']);
    final newContent = parseModelString(payload['content']);

    if (_hasEncryptedEnvelope(data) && !isAck) {
      final metadata = parseModelJsonMap(data['e2ee']) ?? {};
      final editOf = parseModelString(metadata['edit_of']);
      if (editOf.isEmpty || originalMsgId.isEmpty || editOf != originalMsgId) {
        throw const FormatException('encrypted edit target mismatch');
      }
    }

    iPrint(
      "🔄 处理编辑action: isAck=$isAck, msgType=$msgType, msgId=$msgId, originalMsgId=$originalMsgId",
    );

    if (isAck) {
      // 处理编辑确认
      await _processEditAck(data, originalMsgId, newContent, requireCurrent);
    } else {
      // 处理编辑请求
      await _processEditRequest(
        data,
        originalMsgId,
        newContent,
        requireCurrent,
      );
    }
  }

  /// Process edit acknowledgment
  /// 处理编辑确认
  Future<void> _processEditAck(
    Map<String, dynamic> data,
    String originalMsgId,
    String newContent,
    void Function() requireCurrent,
  ) async {
    final msgType = parseModelString(data['type']);
    final payload = parseModelJsonMap(data['payload']) ?? {};
    final currentUid = UserRepoLocal.to.currentUid;
    final generation = UserRepoLocal.to.sessionGeneration;

    final editMsgId = parseModelString(data['id']);

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('edit ACK target missing');
    }

    // 检查是否是我们自己编辑的
    final isMyEdit = originalMsg.fromId.toString() == currentUid;

    if (isMyEdit) {
      if (parseModelString(data['from']) != currentUid ||
          parseModelString(data['to']) != originalMsg.toId.toString()) {
        throw StateError('edit ACK sender or target mismatch');
      }
      // 自己编辑的确认
      final updatedRows = await _updateEditForSession(
        repo,
        originalMsg,
        newContent,
        payload['edited_at'],
        requireCurrent,
      );
      requireCurrent();
      if (updatedRows != 1) throw StateError('edit target update failed');

      final updatedMsg = await repo.find(originalMsgId);
      requireCurrent();
      if (updatedMsg == null) throw StateError('edited message missing');
      final updatedMessage = await updatedMsg.toTypeMessage();
      requireCurrent();
      AppEventBus.fireData([updatedMessage], 'List<Message>');
    } else {
      final fromId = parseModelString(data['from']);
      final toId = parseModelString(data['to']);
      if (fromId != originalMsg.fromId.toString() ||
          toId != originalMsg.toId.toString() ||
          (msgType == 'C2C' && toId != currentUid)) {
        throw StateError('edit ACK sender or target mismatch');
      }
      await _processPeerEdit(
        originalMsg,
        repo,
        data,
        newContent,
        requireCurrent,
      );
    }
    requireCurrent();
    if (isMyEdit && editMsgId.isNotEmpty) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: editMsgId,
          messageType: msgType,
          reason: 'edited',
          ownerUid: currentUid,
          sessionGeneration: generation,
        ),
      );
    }
  }

  /// Process edit request
  /// 处理编辑请求
  Future<void> _processEditRequest(
    Map<String, dynamic> data,
    String originalMsgId,
    String newContent,
    void Function() requireCurrent,
  ) async {
    final msgType = parseModelString(data['type']);
    final fromId = parseModelString(data['from']);
    final currentUid = UserRepoLocal.to.currentUid;

    // 只有消息接收者才需要处理编辑请求
    if (fromId == currentUid) {
      // E2EE 编辑由服务端原样回显给发送者，外层 action 仍为
      // message_edit 以保持 PFv3 header binding；把它按本地 ACK 应用。
      if (_hasEncryptedEnvelope(data)) {
        await _processEditAck(data, originalMsgId, newContent, requireCurrent);
      } else {
        iPrint('🔄 这是自己发送的编辑请求，无需处理');
      }
      return;
    }

    // 查找原始消息
    final repo = MessageService.to.getMessageRepo(msgType);
    final originalMsg = await repo.find(originalMsgId);
    requireCurrent();

    if (originalMsg == null) {
      throw StateError('edit target missing');
    }
    final toId = parseModelString(data['to']);
    if (originalMsg.fromId.toString() != fromId ||
        originalMsg.toId.toString() != toId ||
        (msgType == 'C2C' && toId != currentUid)) {
      throw StateError('edit sender or target mismatch');
    }

    // 处理对方编辑
    await _processPeerEdit(originalMsg, repo, data, newContent, requireCurrent);
    requireCurrent();

    // E2EE 编辑的服务端回显已经同时作为发送者/接收者的确认，
    // 不再发送一个包含正文的明文 ACK。
    if (_hasEncryptedEnvelope(data)) return;

    // 发送编辑确认 (v2.0 格式)
    final ackMessage = {
      'id': data['id'],
      'type': msgType,
      'from': currentUid,
      'to': fromId,
      // v2.0: 字段提升到顶层
      'msg_type': 'text',
      'action': C2SAction.messageEditAck,
      'e2ee': '',
      'payload': {
        'original_msg_id': originalMsgId,
        'content': newContent,
        'edited_at': DateTimeHelper.millisecond(),
      },
    };

    iPrint(
      '🔄 发送编辑确认ACK (v2.0): msgId=${data['id']}, action=message_edit_ack, original_msg_id=$originalMsgId',
    );
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(ackMessage),
        messageId: data['id'] as String,
      ),
    );
  }

  /// Process peer edit
  /// 处理对方编辑
  Future<void> _processPeerEdit(
    MessageModel msg,
    MessageRepo repo,
    Map<String, dynamic> data,
    String newContent,
    void Function() requireCurrent,
  ) async {
    try {
      final payload = parseModelJsonMap(data['payload']) ?? {};

      iPrint('🔄 处理对方编辑消息: msgId=${msg.id}');

      // 更新数据库
      final updateResult = await _updateEditForSession(
        repo,
        msg,
        newContent,
        payload['edited_at'],
        requireCurrent,
      );
      requireCurrent();
      if (updateResult != 1) throw StateError('edit target update failed');

      iPrint('🔄 对方编辑更新数据库结果: $updateResult, msgId=${msg.id}');

      // 重新获取更新后的消息
      final updatedMsg = await repo.find(msg.id.toString());
      requireCurrent();
      if (updatedMsg == null) throw StateError('edited message missing');
      iPrint('🔄 重新获取更新后的消息成功: msgId=${updatedMsg.id}');

      final updatedMessage = await updatedMsg.toTypeMessage();
      requireCurrent();
      iPrint('🔄 触发编辑消息更新事件: msgId=${updatedMsg.id}');

      AppEventBus.fireData([updatedMessage], 'List<Message>');
    } on Object catch (e) {
      iPrint('❌ 处理对方编辑消息异常: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<int> _updateEditForSession(
    MessageRepo repo,
    MessageModel original,
    String content,
    dynamic editedAt,
    void Function() requireCurrent,
  ) async {
    final database = await SqliteService.to.db;
    requireCurrent();
    if (database == null) throw StateError('edit database unavailable');
    final updatedConv = await database.transaction((txn) async {
      requireCurrent();
      final current = await repo.find(original.id.toString(), txn: txn);
      requireCurrent();
      if (current == null ||
          current.fromId != original.fromId ||
          current.toId != original.toId ||
          current.type != original.type ||
          current.msgType != original.msgType ||
          current.status == IMBoyMessageStatus.peerRevoked ||
          current.status == IMBoyMessageStatus.myRevoked) {
        throw StateError('edit target changed or revoked');
      }
      final payload = Map<String, dynamic>.from(current.payloadMap);
      // FL-03（LOCAL:01 反序/旧设备重放、LOCAL:03 时间倒挂）：
      // edited_at 是编辑版本的权威时戳（服务端回执字段优先）。旧版本编辑
      // 晚到（incoming < existing）不得回退正文——保持权威最新状态，按
      // 已处理收敛（幂等确认，不触发第二次会话刷新/未读联动）。
      final existingEditedAt = parseModelInt(payload['edited_at']);
      final incomingEditedAt = parseModelInt(editedAt);
      if (existingEditedAt > 0 &&
          incomingEditedAt > 0 &&
          incomingEditedAt < existingEditedAt) {
        iPrint(
          '🟡 [FL-03] 旧版本编辑到达，保持权威最新状态: msgId=${current.id}, '
          'incoming_edited_at=$incomingEditedAt < existing_edited_at=$existingEditedAt',
        );
        return 1;
      }
      payload['text'] = content;
      payload['edited_at'] = editedAt ?? DateTimeHelper.millisecond();
      payload['is_edited'] = true;
      final rows = await repo.update({
        'id': current.id,
        'payload': json.encode(payload),
      }, txn: txn);
      requireCurrent();
      if (rows != 1) throw StateError('edit target update failed');
      final peerId =
          current.type == 'C2C' &&
              current.fromId.toString() != UserRepoLocal.to.currentUid
          ? current.fromId.toString()
          : current.toId.toString();
      if (peerId.isEmpty || current.type == null) return null;
      final conv = await _conversationRepo.findByPeerId(
        current.type!,
        peerId,
        txn: txn,
      );
      requireCurrent();
      if (conv == null || conv.lastMsgId != current.id) return null;
      final conversationRows = await _conversationRepo.updateById(conv.id, {
        ConversationRepo.msgType: 'text',
        ConversationRepo.subtitle: content,
      }, txn: txn);
      requireCurrent();
      if (conversationRows != 1) {
        throw StateError('edit conversation update failed');
      }
      final updated = await _conversationRepo.findById(conv.id, txn: txn);
      requireCurrent();
      if (updated == null) throw StateError('edit conversation missing');
      return updated;
    });
    requireCurrent();
    SqliteService.to.clearQueryCache(repo.tableName);
    if (updatedConv != null) AppEventBus.fireData(updatedConv);
    return 1;
  }
}
