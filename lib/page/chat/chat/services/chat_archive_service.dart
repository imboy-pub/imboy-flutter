import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

/// 消息历史 / 定位 / 双向分页服务
///
/// 负责从服务端拉取归档消息、加载指定消息附近的上下文以及
/// 加载较新消息（双向分页）等功能。
/// 从 ChatNotifier 提取，保持公共方法签名不变。
class ChatArchiveService {
  const ChatArchiveService();

  // ===== 消息定位 =====

  /// 加载指定消息及其前后的消息（用于搜索跳转定位）
  Future<void> loadMessagesAround({
    required SqliteChatService chatService,
    required MessageScrollManager scrollManager,
    required ConversationModel conversation,
    required String msgId,
    required Future<void> Function(ConversationModel, {bool isInitial})
    loadMoreMessages,
    required void Function({
      required int nextAutoId,
      required int prevAutoId,
      required String currentConversationId,
    })
    updateState,
    int count = 20,
  }) async {
    final String tb = MessageRepo.getTableName(conversation.type);
    final MessageRepo repo = MessageRepo(tableName: tb);

    final MessageModel? targetMsgModel = await repo.find(msgId);
    if (targetMsgModel == null) {
      await loadMoreMessages(conversation, isInitial: true);
      return;
    }

    final olderMessages = await repo.pageForConversation(
      conversation.uk3,
      targetMsgModel.autoId,
      count,
    );

    final newerMessages = await repo.pageNewerForConversation(
      conversation.uk3,
      targetMsgModel.autoId,
      count,
    );

    final List<MessageModel> allModels = [
      ...olderMessages,
      targetMsgModel,
      ...newerMessages,
    ];

    final messages = await Future.wait(
      allModels.map((item) async => await item.toTypeMessage()),
    );

    final int nextAutoId = olderMessages.isNotEmpty
        ? olderMessages.first.autoId
        : targetMsgModel.autoId;

    final int prevAutoId = newerMessages.isNotEmpty
        ? newerMessages.last.autoId
        : targetMsgModel.autoId;

    updateState(
      nextAutoId: nextAutoId,
      prevAutoId: prevAutoId,
      currentConversationId: conversation.uk3,
    );

    chatService.setMessages(messages.toList(), animated: false);

    cacheMessagePositionsForConversation(
      scrollManager: scrollManager,
      conversationUk3: conversation.uk3,
      messages: messages,
      targetMsgId: msgId,
    );
  }

  /// 缓存会话的消息位置，供后续滚动定位使用
  void cacheMessagePositionsForConversation({
    required MessageScrollManager scrollManager,
    required String conversationUk3,
    required List<Message> messages,
    required String targetMsgId,
  }) {
    try {
      final int targetIndex = messages.indexWhere((m) => m.id == targetMsgId);
      if (targetIndex == -1) return;

      const double averageMessageHeight = 80.0;

      for (int i = 0; i < messages.length; i++) {
        final Message message = messages[i];
        final double offsetFromTarget =
            (i - targetIndex) * averageMessageHeight;
        final double estimatedPosition =
            (targetIndex * averageMessageHeight) + offsetFromTarget;
        final double position = estimatedPosition.clamp(0.0, double.infinity);
        scrollManager.cacheMessagePosition(
          conversationUk3,
          message.id,
          position,
        );
      }

      iPrint('缓存了 ${messages.length} 条消息的位置，目标消息索引: $targetIndex');
    } catch (e) {
      iPrint('缓存消息位置失败: $e');
    }
  }

  // ===== 双向分页：加载较新消息 =====

  /// 加载较新的消息（双向分页向上滚动时调用）
  Future<List<Message>> loadNewerMessages({
    required SqliteChatService? chatService,
    required ConversationModel conversation,
    required int prevAutoId,
    required int pageSize,
    required bool Function(Map<String, dynamic> payload, int nowMs)
    isBurnExpired,
    required Future<bool> Function(ConversationModel, Message) onRemoveMessage,
    required Future<void> Function({
      required ConversationModel conversation,
      required MessageRepo repo,
      required MessageModel item,
      required int nowMs,
    })
    ensureBurnTimer,
    required Future<void> Function(MessageModel) onSendWsMsg,
    required void Function(int prevAutoId) updatePrevAutoId,
  }) async {
    final String tb = MessageRepo.getTableName(conversation.type);
    final MessageRepo repo = MessageRepo(tableName: tb);

    iPrint(
      'loadNewerMessages: uk3=${conversation.uk3}, prevAutoId=$prevAutoId, pageSize=$pageSize',
    );

    final items = await repo.pageNewerForConversation(
      conversation.uk3,
      prevAutoId,
      pageSize,
    );

    if (items.isEmpty) {
      iPrint('loadNewerMessages: 没有较新的消息');
      return [];
    }

    final int nowMs = DateTimeHelper.millisecond();
    final List<MessageModel> kept = [];
    for (final item in items) {
      final payload = item.payload as Map<String, dynamic>;
      if (isBurnExpired(payload, nowMs)) {
        await onRemoveMessage(conversation, await item.toTypeMessage());
        continue;
      }
      await ensureBurnTimer(
        conversation: conversation,
        repo: repo,
        item: item,
        nowMs: nowMs,
      );
      kept.add(item);
    }

    final messages = await Future.wait(
      kept.map((item) async {
        if (item.status == IMBoyMessageStatus.sending) {
          await onSendWsMsg(item);
        }
        return await item.toTypeMessage();
      }),
    );

    final Set<String> currentIds =
        chatService?.messages.map((e) => e.id).toSet() ?? <String>{};
    final List<Message> newItems = messages
        .where((msg) => !currentIds.contains(msg.id))
        .toList();

    if (newItems.isNotEmpty) {
      chatService?.insertAllMessages(newItems);
      updatePrevAutoId(
        newItems.last.metadata?['auto_id'] as int? ?? prevAutoId,
      );
    }

    return newItems;
  }

  // ===== 服务端归档历史（conv_seq 正向增量同步）=====

  /// 拉取一页归档历史并落 SQLite（P1-2 conv_seq 正向增量同步）
  ///
  /// 归档 payload 与离线队列消息形状高度一致，复用已验证的
  /// [MessageRepo.batchInsertOfflineMessages]（内含 id 去重），仅做形状适配，
  /// 不发送 ACK（归档消息不在投递队列里）。
  /// 返回本页拉取条数、下一游标、是否还有更多。
  Future<({int fetched, int nextSeq, bool hasMore})>
  fetchAndPersistHistoryPage({
    required String chatType,
    required String peerId,
    required int afterSeq,
    int limit = 50,
  }) async {
    final result = await MsgApi().history(
      chatType: chatType.toLowerCase(),
      peerId: peerId,
      afterSeq: afterSeq,
      limit: limit,
    );
    if (result == null) {
      return (fetched: 0, nextSeq: afterSeq, hasMore: false);
    }

    final rows =
        (result['messages'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final int nextSeq = (result['next_seq'] as num?)?.toInt() ?? afterSeq;
    final bool hasMore = (result['has_more'] as bool?) ?? false;

    if (rows.isEmpty) {
      return (fetched: 0, nextSeq: nextSeq, hasMore: hasMore);
    }

    // c2c/c2g 落不同表，按 type 分组插入
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final shaped = archiveRowToOfflineShape(row);
      (byType[shaped['type'] as String] ??= []).add(shaped);
    }
    for (final entry in byType.entries) {
      await MessageRepo(
        tableName: MessageRepo.getTableName(entry.key),
      ).batchInsertOfflineMessages(entry.value);
    }

    return (fetched: rows.length, nextSeq: nextSeq, hasMore: hasMore);
  }

  // ===== 撤回后更新会话 =====

  /// 更新会话信息（撤回消息后调用）
  Future<void> updateConversationAfterRevoke(
    ConversationModel conversation,
    String msgId,
  ) async {
    try {
      final ConversationRepo repo = ConversationRepo();
      final String tb = MessageRepo.getTableName(conversation.type);
      final MessageRepo mRepo = MessageRepo(tableName: tb);

      final items = await mRepo.page(
        conversationUk3: conversation.uk3,
        page: 1,
        size: 1,
      );

      if (items.isEmpty) {
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.subtitle: '',
        });
      } else {
        final lastMsg = items[0];
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: lastMsg.id,
          ConversationRepo.lastMsgStatus: lastMsg.status,
          ConversationRepo.lastTime: lastMsg.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgTypeFromModel(
            lastMsg,
          ),
          ConversationRepo.subtitle: MessageModel.conversationSubtitleFromModel(
            lastMsg,
          ),
        });
      }

      final ConversationModel? updated = await repo.findById(conversation.id);
      if (updated != null) {
        AppEventBus.fireData(updated);
      }
    } catch (e) {
      iPrint('更新会话信息失败: $e');
    }
  }
}

/// 归档历史行 → [MessageRepo.batchInsertOfflineMessages] 期望形状（P1-2）
///
/// 后端 encode_history_msg 已把 from_id/to_id → from/to，chat_type 为
/// 'c2c'/'c2g'。此处只补两点：① chat_type → type（C2C/C2G）；② C2G 行的
/// to 为 null，用 group_id 兜底作群会话键。其余（msg_type/e2ee/payload/
/// created_at 等）原样透传。纯函数，供单测覆盖字段映射正确性。
Map<String, dynamic> archiveRowToOfflineShape(Map<String, dynamic> row) {
  final chatType = (row['chat_type'] ?? '').toString().toLowerCase();
  final type = chatType == 'c2g' ? 'C2G' : 'C2C';
  final out = Map<String, dynamic>.from(row);
  out['type'] = type;
  if (type == 'C2G') {
    final to = out['to'];
    if (to == null || to.toString().isEmpty) {
      final gid = row['group_id'];
      if (gid != null) {
        out['to'] = gid;
      }
    }
  }
  return out;
}
