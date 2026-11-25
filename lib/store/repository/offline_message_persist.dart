part of 'offline_message_writer.dart';

/// 离线会话落库（自 OfflineMessageWriter 抽出的扩展，行为与调用方零变更）
extension OfflineMessageWriterPersist on OfflineMessageWriter {
  Future<List<ConversationModel>> _persistOfflineConversations(
    List<InsertedOfflineMessage> inserted,
    Transaction txn, {
    required bool historyImport,
  }) async {
    final conversations = <ConversationModel>[];
    final conversationRepo = ConversationRepo();
    final contactRepo = ContactRepo();
    final groupRepo = GroupRepo();

    // 获取当前会话 ID - 使用静态字段跟踪当前活动会话
    // 注意：如果没有打开的聊天页面，currentConversationUk3 将为空
    final String currentConversationUk3 = activeConversation() ?? '';

    final Map<String, OfflineConversationAgg> convAgg = {};
    final currentUid = UserRepoLocal.to.currentUid; // C7-β
    for (final msg in inserted) {
      final key = '${msg.type}::${msg.peerId}';
      final agg = convAgg.putIfAbsent(
        key,
        () => OfflineConversationAgg(
          type: msg.type,
          peerId: msg.peerId,
          currentUid: currentUid,
        ),
      );
      agg.observe(msg, currentConversationUk3);
    }

    for (final agg in convAgg.values) {
      final latest = agg.latest;
      if (latest == null) continue;

      String avatar = '';
      String title = '';
      try {
        if (agg.type == 'C2G') {
          final g = await groupRepo.findById(agg.peerId, txn: txn);
          avatar = g?.avatar ?? '';
          title = g?.title ?? '';
        } else {
          final ct = await contactRepo.findByUid(
            agg.peerId,
            autoFetch: false,
            txn: txn,
          );
          avatar = ct?.avatar ?? '';
          title = ct?.title ?? '';
        }
      } on Object catch (e, s) {
        AppLogger.error('[message_repo_sqlite] findByUid error', e, s);
      }

      final previewPayload = latest.payload is Map<String, dynamic>
          ? latest.payload as Map<String, dynamic>
          : <String, dynamic>{};

      // WebSocket API v2.0: 从顶层字段读取 msg_type 和 status
      if (kDebugMode) {
        func_helper.iPrint(
          '🔍 [DEBUG 会话同步] latest.msgType="${latest.msgType}", latest.status=${latest.status}, payload keys=${previewPayload.keys.toList()}',
        );
      }
      final preview = _derivePreview(
        latest.msgType,
        latest.status,
        previewPayload,
      );
      final existing = await conversationRepo.findByPeerId(
        agg.type,
        agg.peerId,
        txn: txn,
      );

      ConversationModel conv;
      if (existing == null) {
        // 创建新会话时确保设置所有必要字段
        conv = ConversationModel(
          id: 0,
          peerId: agg.peerId,
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: latest.id,
          lastTime: latest.createdAt,
          lastMsgStatus: latest.status, // 传递消息状态
          unreadNum: agg.unreadDelta, // 使用计算出的未读数
          mentionUnread: agg.mentionDelta, // C7-β
          payload: {},
          isShow: 1,
        );
        conv.id = await conversationRepo.insert(conv, txn: txn);
        func_helper.iPrint('创建新会话: type=${conv.type}, 未读数: ${agg.unreadDelta}');
      } else if (latest.createdAt < existing.lastTime) {
        // R06：本批最新比会话头更旧——典型为历史回填（trustedArchive）晚于
        // 实时/更晚批次到达。投影不做时间比较外的猜测：更旧的批次不得把
        // 会话头拉回过去，直接保持现有头（与去重跳过路径同一保护语义）。
        // W8-B2（审查 P2）：实时批次（historyImport=false）乱序投递时消息
        // 行是**新落库的未读消息**——会话头可以不回退，但未读/mention
        // 必须照常累加，否则乱序到达的新消息永久丢失角标。归档批次维持
        // 现状（历史导入是补齐过去，不重复计未读）。
        var head = existing;
        if (!historyImport && (agg.unreadDelta > 0 || agg.mentionDelta > 0)) {
          await conversationRepo.incrementUnread(
            existing.id,
            txn: txn,
            unreadDelta: agg.unreadDelta,
            mentionDelta: agg.mentionDelta,
          );
          head =
              await conversationRepo.findById(existing.id, txn: txn) ??
              existing;
        }
        conversations.add(head);
        func_helper.iPrint(
          '历史批次早于会话头，保持会话头不变: type=${existing.type}, '
          'batchLatest=${latest.createdAt}, headLastTime=${existing.lastTime}'
          '${historyImport ? '' : '（实时乱序批次：未读照常累加）'}',
        );
        continue;
      } else {
        // R06：更新现有会话。投影只在「本批最新不旧于会话头」时推进
        //（上面分支已拦截更旧批次），不能用"本批最新"无条件覆盖
        // "整个会话最新"——历史导入与新投递共用这一时间比较，而非用
        // trustedArchive 标志混控投影。
        // 未读/mention 语义按批次来源区分：历史导入是补齐过去消息，
        // 不是新投递，不重复累加（R06）；新投递照旧累加。
        final unreadDelta = historyImport ? 0 : agg.unreadDelta;
        final mentionDelta = historyImport ? 0 : agg.mentionDelta;
        int newUnreadNum = existing.unreadNum + unreadDelta;
        int newMentionUnread = existing.mentionUnread + mentionDelta; // C7-β
        await conversationRepo.updateById(existing.id, {
          ConversationRepo.avatar: avatar.isNotEmpty ? avatar : existing.avatar,
          ConversationRepo.title: title.isNotEmpty ? title : existing.title,
          ConversationRepo.subtitle: preview.subtitle,
          ConversationRepo.msgType: preview.msgType,
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.lastMsgStatus: latest.status, // 传递消息状态
          ConversationRepo.unreadNum: newUnreadNum,
          ConversationRepo.mentionUnread: newMentionUnread, // C7-β
          ConversationRepo.isShow: 1,
        }, txn: txn);

        // 重新获取更新后的会话
        conv =
            (await conversationRepo.findById(existing.id, txn: txn)) ??
            existing;
        func_helper.iPrint(
          '更新会话: type=${conv.type}, '
          '新增未读数: $unreadDelta, 总未读数: $newUnreadNum',
        );
      }

      conversations.add(conv);
    }
    return conversations;
  }
}
