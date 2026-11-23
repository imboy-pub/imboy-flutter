part of 'message.dart';

/// 在后台异步处理消息数据存储
/// Process message data storage asynchronously in background
Future<bool> _processMessageInBackground(
  MessageService service,
  Map<String, dynamic> data,
  Map<String, dynamic> payload,
  ConversationModel tempConv,
  MessageModel tempMsg,
  MessageRepo repo, {
  required AuthSessionScope notificationSession,
  required AccountLocalTaskOwner notificationOwner,
  required bool protectedHistorySource,
}) async {
  final msgId = parseModelString(data['id']);
  final chatType = parseModelString(data['type']); // 消息会话类型 (C2C/C2G/C2S)
  // WebSocket API v2.0: 从顶层读取消息内容类型
  final rawMsgType = data['msg_type']?.toString(); // voice/text/image 等

  // 【重构】使用 MessageTypeNormalizer 进行类型归一化
  // 仅做合法性校验与空白处理（不做旧命名兼容）
  final msgContentType = MessageTypeNormalizer.normalize(
    msgType: rawMsgType,
    payload: payload,
  );

  bool ownsNotification() =>
      _ownsMessageSession(notificationSession, notificationOwner);

  var committed = false;
  try {
    // 启动竞态治根：WS 消息可能先于 DB 初始化就绪到达（或初始化失败进入
    // 5s 冷却）。此处有限等待，让瞬时不可用在窗口内自愈；持久故障超时后
    // 继续走原逻辑，事务会抛出带原因的异常并走失败路径（不 ACK，服务端
    // 重推兜底）。详见 SqliteService.waitUntilReady。
    if (!await SqliteService.to.waitUntilReady(
      MessageService._dbReadyWaitTimeout,
    )) {
      iPrint('⏳ DB 等待超时仍未就绪，消息处理将失败: $msgId');
    }

    // 并行获取 peer 信息和检查用户状态
    // Parallel fetch peer info and check user status
    final results = await Future.wait([
      service._fetchPeerInfo(chatType, data),
      service._isUserCurrentlyInChat(tempConv),
    ]);

    final peerInfo = results[0] as Map<String, String>;
    final isUserInChat = parseModelBool(results[1]);

    // 更新会话信息
    // Update conversation with complete peer info
    // 与 _receiveMessage 中同款修复：C2G from 为 number、C2C 为 string，须归一化比较
    final isFromCurrentUser =
        parseModelString(data['from']) == UserRepoLocal.to.currentUid;
    final unreadIncrement = computeConversationUnreadIncrement(
      isFromCurrentUser: isFromCurrentUser,
      isUserInChat: isUserInChat,
    );
    // C7-β: 计算 @ 未读增量（与 unread 同短路条件 + mentionIds 判定）
    final mentionIncrement = computeMentionUnreadIncrement(
      isFromCurrentUser: isFromCurrentUser,
      isUserInChat: isUserInChat,
      mentionIds: extractMentionIdsFromPayload(payload),
      currentUid: UserRepoLocal.to.currentUid,
    );

    final conv = ConversationModel(
      peerId: peerInfo['peerId']!,
      avatar: peerInfo['avatar']!,
      title: peerInfo['title']!,
      subtitle: tempConv.subtitle,
      type: chatType,
      msgType: msgContentType, // 【修复】使用修正后的消息类型
      lastMsgId: msgId,
      lastTime: tempConv.lastTime,
      unreadNum: unreadIncrement,
      mentionUnread: mentionIncrement, // C7-β
      id: 0,
    );

    // uk3 由 type+currentUid+peerId 纯派生（不依赖插入后的 id），可在事务前确定
    final msg = MessageModel(
      parseModelString(msgId),
      autoId: 0,
      type: chatType, // 消息会话类型 (C2C/C2G/C2S)
      fromId: parseModelString(data['from']),
      toId: parseModelString(data['to']),
      payload: payload,
      // W8-A1：created_at 缺失/不可解析（如无 zone 串被 parseIsoZoned
      // 拒绝）落 0 哨兵，绝不回填 now 伪造发送时间；与离线写入侧
      // OfflineMessageWriter.parseCreatedAt 的"无 created_at=0"语义一致。
      createdAt: parseModelInt(data['created_at'], defaultValue: 0),
      isAuthor: tempMsg.isAuthor,
      topicId: parseModelInt(data['topic_id'], defaultValue: tempMsg.topicId),
      conversationUk3: conv.uk3,
      status: IMBoyMessageStatus.delivered,
      msgType: msgContentType, // WebSocket API v2.0: 从顶层读取消息内容类型
      e2ee: tempMsg.e2ee,
      senderDid: tempMsg.senderDid,
      // DEF-SYN01-ORDER-NOCONV-1（选项B切片，自 message.dart 并集合并移植）：
      // live 帧信封顶层 conv_seq 随落库行持久化（wire→模型映射伴生行）。
      // parseConvSeq 保真守卫，缺失/非法时为 null → 列保持 NULL（绝不本地伪造）。
      convSeq: MessageModel.parseConvSeq(data['conv_seq']),
    );

    // 保存消息到 sqlite
    // Persist message to local DB
    if (kDebugMode) {
      iPrint(
        '🔍 [DEBUG] 保存消息: msgId=$msgId, data[\'msg_type\']=${data['msg_type']}, msgContentType=$msgContentType',
      );
    }

    // 消息插入 + 会话 upsert + 未读自增放入同一排他事务。
    // 在事务内确认新行后才插入并增加未读，重复投递保留已存本地状态。
    // exclusive:true 走全局 _dbLock.synchronized，串行化所有并发 _processMessageInBackground。
    var historyQueued = false;
    final (ConversationModel savedConv, bool isNewRow) = await service
        ._conversationRepo
        .runInTransaction((txn) async {
          // The initial receive lookup is outside this transaction. Another
          // delivery may have committed since then; never overwrite its local
          // read/revoke/encryption state or its conversation preview.
          final existing = await repo.find(msgId, txn: txn);
          if (existing != null) {
            // A racing PFv3 placeholder still needs authenticated recovery
            // before the receive caller marks its crypto inbox complete.
            if (tempMsg.e2ee?['meta_version'] == 3 &&
                payload['_e2ee_v3_verified'] == true) {
              final recovered = await service._materializeExistingInbound(
                data,
                payload,
                repo,
                txn,
                () {
                  if (!authSessionReader.isCurrent(notificationSession)) {
                    throw StateError('inbound recovery session changed');
                  }
                },
              );
              if (recovered) {
                historyQueued = await service._queueRecoveredNativeHistory(
                  data,
                  repo,
                  txn,
                  notificationSession,
                  notificationOwner,
                );
              }
            }
            // Like the receive preflight's duplicate branch, no conversation
            // metadata or UI is emitted for an already-persisted message.
            return (conv, false);
          }
          await repo.insert(msg, txn: txn);
          if (chatType == 'C2C' && protectedHistorySource) {
            historyQueued = await recordAcceptedPersonalHistoryC2cText(
              transaction: txn,
              session: notificationSession,
              owner: notificationOwner,
              message: msg,
              sequence: msg.convSeq,
            );
          }

          // 会话元数据 upsert；未读计数交由下方的新消息增量更新。
          final convResult = await service._conversationRepo.save(
            conv,
            txn: txn,
            autoIncrement: false,
          );

          // 仅新消息增加未读 / @ 未读。
          if (unreadIncrement > 0 || mentionIncrement > 0) {
            await service._conversationRepo.incrementUnread(
              convResult.id,
              txn: txn,
              unreadDelta: unreadIncrement,
              mentionDelta: mentionIncrement,
            );
          }

          // convResult 可能因 upsert 更新了字段，重新读出最新快照供 UI 使用
          final fresh = await service._conversationRepo.findByPeerId(
            conv.type,
            conv.peerId.toString(),
            txn: txn,
          );
          return (fresh ?? convResult, true);
        });
    committed = true;
    if (kDebugMode) {
      iPrint('🔍 [DEBUG] 消息保存完成: msgType=${msg.msgType}, isNewRow=$isNewRow');
    }

    if (historyQueued) {
      await confirmAcceptedPersonalHistoryC2cText(
        notificationSession,
        notificationOwner,
      );
    }

    // 【修复】重复消息（非新行）跳过后续 UI/通知处理
    // 与原 existed>0 守卫语义一致，但更彻底：未读已不会自增，且连 fireData 都不发
    if (!isNewRow) {
      iPrint('⚠️ 消息已存在（数据库检查），跳过后续处理: $msgId');
      return true;
    }

    if (!ownsNotification()) return true;

    // 单一来源：以会话快照统一同步会话与提醒，避免局部字段漂移
    service._conversationNotifier.applyConversationSnapshot(savedConv);

    // 再次触发 UI 更新以显示完整的 peer 信息
    // Trigger UI update again to show complete peer info
    AppEventBus.fireData(savedConv);
    final tMsg = await msg.toTypeMessage();
    if (!ownsNotification()) return true;
    AppEventBus.fireData(tMsg);

    // BUG#148 接线：新消息 @ 当前用户时广播 NewMentionEvent，驱动
    // mention_list_page 自动刷新。此前唯一发射端 handleMentionMessage
    // 无任何调用方（死代码），监听端永远收不到事件。判定口径与 C7-β
    // mentionIncrement 一致：自己发的、或正在该会话页内不广播。
    if (mentionIncrement > 0) {
      unawaited(
        MentionService.to.handleMentionMessage({
          'id': 0,
          'group_id': data['to'],
          'msg_id': msgId,
          'mentions': extractMentionIdsFromPayload(payload) ?? <String>[],
        }),
      );
    }

    // 触发消息通知（如果需要）
    // 只有当用户不在当前会话且消息不是自己发送的时候才显示通知
    // C7-α-2：用户为该会话开启了免打扰（isMuted > 0）时也抑制通知
    // slice-8：DND 下 @ 当前用户时穿透抑制（对齐微信 / TG / Slack）
    // Q09/G1（AC22 免打扰）：C2G 群会话合并 KV 源（group_notice_disabled:
    // <gid>）——群详情页免打扰开关此前只落 KV，而本判定只读
    // conversation.is_muted 列，两套存储未打通导致群 DND 失效（断点）。
    // 合并后任一源命中即抑制；KV 读失败按未设置处理（不影响通知）。
    // 不变量：DND 只抑制通知弹窗，消息落库/未读/已读语义在上方已完成，
    // 不受此判定影响。
    final bool dndSuppressed = chatType == 'C2G'
        ? isGroupDndActive(
            isMutedColumn: savedConv.isMuted,
            kvNoticeDisabled: service._readGroupNoticeDisabledSafe(
              parseModelString(data['to']),
            ),
          )
        : savedConv.isMuted > 0;
    if (!isFromCurrentUser &&
        !isUserInChat &&
        !shouldSuppressNotification(
          isMuted: dndSuppressed ? 1 : 0,
          isMentioned: mentionIncrement > 0,
        )) {
      _showMessageNotification(
        service,
        session: notificationSession,
        owner: notificationOwner,
        msg: msg,
        senderName: peerInfo['title'] ?? '',
        conversationUk3: savedConv.uk3,
        peerId: peerInfo['peerId'] ?? '',
        chatType: chatType,
      );
    }

    iPrint('✅ 消息后台处理完成: $msgId');
    return true;
  } on Object catch (e) {
    AppLogger.error('消息后台处理失败 msgId=$msgId errType=${e.runtimeType}');

    // UI enrichment/notification is not part of the transaction. Once the
    // message is durable, avoid UI rollback and allow the transport ACK even
    // when a later presentation step fails.
    if (committed) return true;

    // A failed previous-account transaction cannot roll back current UI.
    if (ownsNotification()) {
      service._handleMessageProcessingFailure(msgId, chatType, tempConv, e);
    }
    return false;
  }
}

bool _ownsMessageSession(
  AuthSessionScope session,
  AccountLocalTaskOwner owner,
) =>
    authSessionReader.isCurrent(session) &&
    !authSessionReader.transitionFailed &&
    AccountLocalTaskOwner.capture(uid: session.uid) == owner;
