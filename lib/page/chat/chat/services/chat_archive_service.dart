import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

/// 历史回填 API 请求失败（与「服务端确认无数据」严格区分）。
///
/// BUG#119：旧实现把 API 失败（result == null）读成「无数据」返回
/// (fetched: 0, hasMore: false)，调用方同步历史失败时被完全静默，
/// 用户看到误导性的「暂无数据」且无重试入口。抛本异常让
/// [ChatNotifier.syncHistoryBackfill] 能显式标记失败并保持可重试。
class HistoryFetchException implements Exception {
  const HistoryFetchException();

  @override
  String toString() => 'HistoryFetchException: 归档历史接口请求失败';
}

/// R01/R02 同步计划（[ChatArchiveService.planHistorySync] 输出）。
///
/// - [advanceTo]：本轮允许持久化的游标（已按 safe_head 钳制、只进不退）。
/// - [backfillRanges]：需要 [ChatArchiveService.backfillMissing] 的区间
///   列表（gaps 补齐 / 过冲恢复），按 (afterSeq, targetSeq] 语义。
/// - [blocked]：true=服务端要求等待，游标不动、不补齐。
class HistorySyncPlan {
  const HistorySyncPlan({
    required this.advanceTo,
    required this.backfillRanges,
    required this.blocked,
  });

  final int advanceTo;
  final List<({int fromSeq, int toSeq})> backfillRanges;
  final bool blocked;
}

/// 消息历史 / 定位 / 双向分页服务
///
/// 负责从服务端拉取归档消息、加载指定消息附近的上下文以及
/// 加载较新消息（双向分页）等功能。
/// 从 ChatNotifier 提取，保持公共方法签名不变。
class ChatArchiveService {
  const ChatArchiveService({this.api});

  /// 可注入的 API 客户端（测试用）；为 null 时用默认 [MsgApi]。
  final MsgApi? api;

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
    // BUG#139：接收方按已读时间、发送方按发送时间（fallbackStartMs）判定过期，
    // 故改为传完整 item 而非仅 payload
    required bool Function(MessageModel item, int nowMs) isBurnExpired,
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
      if (isBurnExpired(item, nowMs)) {
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
        parseModelInt(
          newItems.last.metadata?['auto_id'],
          defaultValue: prevAutoId,
        ),
      );
    }

    return newItems;
  }

  // ===== 服务端归档历史（conv_seq 正向增量同步）=====

  /// history 响应合同字段（R01/R02，字段名以 BE messaging_logic.erl:284-289 为准）：
  /// - `safe_head`：安全推进边界 B；客户端游标推进不得越过。
  /// - `blocked`：true=正式表已有高于 B 的行（被非终态 staging 行钳住），
  ///   客户端应等待下一轮，**禁止自行推断 gap**。
  /// - `gaps`：`[{from_seq,to_seq,reason}]`，reason ∈
  ///   terminal_failure / authorization；用 [backfillMissing] 有界补齐。
  static const _kSafeHead = 'safe_head';
  static const _kBlocked = 'blocked';
  static const _kGaps = 'gaps';

  /// 解析服务端 gaps 数组（messaging_logic.erl:270-279 形状）。
  /// 纯函数，供单测守护字段名与容错。
  static List<({int fromSeq, int toSeq, String reason})> parseGaps(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    final out = <({int fromSeq, int toSeq, String reason})>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final from = (item['from_seq'] as num?)?.toInt();
      final to = (item['to_seq'] as num?)?.toInt();
      if (from == null || to == null) continue;
      out.add((
        fromSeq: from,
        toSeq: to,
        reason: (item['reason'] ?? '').toString(),
      ));
    }
    return out;
  }

  /// R01/R02 同步决策纯函数：给定当前游标与 history 响应合同字段，
  /// 输出下一步动作。纯函数（无 IO），供单测覆盖 blocked/gaps/过冲矩阵。
  ///
  /// 规则：
  /// - `blocked=true` → 等待（advance=0），不推进、不补齐。
  /// - `safeHead > 0` 时持久化游标钳制 `min(nextSeq, safeHead)`（只进不退
  ///   由调用方保证）。
  /// - 过冲（`seq > safeHead && safeHead > 0`，存量库游标越过新 B）→
  ///   不回退游标，从 0 有界补扫至 safeHead（缺失低序号在其中）。
  /// - `gaps` 非空且未 blocked → 逐段 [backfillMissing]。
  static HistorySyncPlan planHistorySync({
    required int currentSeq,
    required int nextSeq,
    required int safeHead,
    required bool blocked,
    required List<({int fromSeq, int toSeq, String reason})> gaps,
  }) {
    if (blocked) {
      // blocked：等待，禁止自行推断 gap（BE 明确下发 blocked 时不给 gaps 语义）
      return HistorySyncPlan(
        advanceTo: currentSeq,
        backfillRanges: const [],
        blocked: true,
      );
    }
    final effectiveHead = safeHead > 0 ? safeHead : nextSeq;
    // 持久化目标：不越过 safe_head；只进不退
    final advanceTo = currentSeq > effectiveHead
        ? currentSeq
        : (nextSeq > effectiveHead
              ? effectiveHead
              : (nextSeq > currentSeq ? nextSeq : currentSeq));
    final ranges = <({int fromSeq, int toSeq})>[];
    if (currentSeq > effectiveHead && effectiveHead > 0) {
      // R02-5 过冲恢复：游标已越过新 B，不回退；从 0 有界补扫至 safe_head
      ranges.add((fromSeq: 0, toSeq: effectiveHead));
    }
    for (final g in gaps) {
      if (g.toSeq >= g.fromSeq) {
        ranges.add((
          fromSeq: g.fromSeq - 1 < 0 ? 0 : g.fromSeq - 1,
          toSeq: g.toSeq,
        ));
      }
    }
    return HistorySyncPlan(
      advanceTo: advanceTo,
      backfillRanges: ranges,
      blocked: false,
    );
  }

  /// 拉取一页归档历史并落 SQLite（P1-2 conv_seq 正向增量同步）
  ///
  /// 归档 payload 与离线队列消息形状高度一致，复用已验证的
  /// [MessageRepo.batchInsertOfflineMessages]（内含 id 去重），仅做形状适配，
  /// 不发送 ACK（归档消息不在投递队列里）。
  /// 返回本页拉取条数、下一游标、是否还有更多，以及 R01/R02 合同字段
  /// （safeHead/blocked/gaps，字段名见 BE messaging_logic.erl:284-289）。
  Future<
    ({
      int fetched,
      int nextSeq,
      bool hasMore,
      int safeHead,
      bool blocked,
      List<({int fromSeq, int toSeq, String reason})> gaps,
    })
  >
  fetchAndPersistHistoryPage({
    required String chatType,
    required String peerId,
    required int afterSeq,
    int limit = 50,
  }) async {
    final result = await (api ?? MsgApi()).history(
      chatType: chatType.toLowerCase(),
      peerId: peerId,
      afterSeq: afterSeq,
      limit: limit,
      // 发生率压降路径2：携带本机 DID，服务端不下发 per_device fan-out
      // 信封不含本机的收件消息（该类消息恢复密钥也永远解不开）。
      // 与 /msg/offline 的 did 同源（config/init.dart 全局，启动时取自 DeviceExt）
      did: deviceId,
    );
    if (result == null) {
      // BUG#119：API 失败（401/5xx/超时/解析失败）与「服务端确认无数据」
      // 必须区分。返回 (fetched: 0, hasMore: false) 会让上层把失败当成
      // 「没有历史可同步」，游标不推进、UI 显示误导性「暂无数据」且失败
      // 完全不可见。抛异常由 syncHistoryBackfill 显式标记失败（可重试）。
      throw const HistoryFetchException();
    }

    final rows =
        (result['messages'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    final int nextSeq = (result['next_seq'] as num?)?.toInt() ?? afterSeq;
    final bool hasMore = (result['has_more'] as bool?) ?? false;
    final int safeHead = (result[_kSafeHead] as num?)?.toInt() ?? 0;
    final bool blocked = (result[_kBlocked] as bool?) ?? false;
    final gaps = parseGaps(result[_kGaps]);

    if (rows.isEmpty) {
      return (
        fetched: 0,
        nextSeq: nextSeq,
        hasMore: hasMore,
        safeHead: safeHead,
        blocked: blocked,
        gaps: gaps,
      );
    }

    // c2c/c2g 落不同表，按 type 分组插入
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final shaped = archiveRowToOfflineShape(row);
      (byType[shaped['type'] as String] ??= []).add(shaped);
    }
    for (final entry in byType.entries) {
      await MessageRepo(tableName: MessageRepo.getTableName(entry.key))
          .batchInsertOfflineMessages(entry.value, trustedArchive: true);
    }

    return (
      fetched: rows.length,
      nextSeq: nextSeq,
      hasMore: hasMore,
      safeHead: safeHead,
      blocked: blocked,
      gaps: gaps,
    );
  }

  /// R01/R02：有界范围补取（history_backfill），恢复 (afterSeq, targetSeq]
  /// 内的晚到低序号 / 过冲缺失行。
  ///
  /// - 按 `next_seq`/`has_more` 分批续扫直至 >= targetSeq，尊重服务端
  ///   range_limit；批次数上限 [maxPages] 兜底（可中断续跑：调用方重入
  ///   时从持久化游标重新计划，不无限从 0 重拉——补齐按 msg_id 幂等去重）。
  /// - 落库复用 [MessageRepo.batchInsertOfflineMessages]（msg_id 去重）。
  /// 返回实际补齐条数。
  Future<int> backfillMissing({
    required String chatType,
    required String peerId,
    required int afterSeq,
    required int targetSeq,
    int limit = 50,
    int maxPages = 40,
  }) async {
    if (targetSeq <= afterSeq) return 0;
    var cursor = afterSeq;
    var restored = 0;
    for (var page = 0; page < maxPages && cursor < targetSeq; page++) {
      final result = await (api ?? MsgApi()).historyBackfill(
        chatType: chatType.toLowerCase(),
        peerId: peerId,
        afterSeq: cursor,
        limit: limit,
        did: deviceId,
      );
      if (result == null) {
        // 单批失败即中断（可续跑）：游标停在已恢复位置，下次重入继续
        throw const HistoryFetchException();
      }
      final rows =
          (result['messages'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];
      final int nextSeq = (result['next_seq'] as num?)?.toInt() ?? cursor;
      final bool hasMore = (result['has_more'] as bool?) ?? false;
      if (rows.isNotEmpty) {
        final byType = <String, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          final shaped = archiveRowToOfflineShape(row);
          (byType[shaped['type'] as String] ??= []).add(shaped);
        }
        for (final entry in byType.entries) {
          await MessageRepo(tableName: MessageRepo.getTableName(entry.key))
              .batchInsertOfflineMessages(entry.value, trustedArchive: true);
        }
        restored += rows.length;
      }
      // 有界性：next_seq 不前进说明服务端异常，避免死循环
      if (nextSeq <= cursor) break;
      cursor = nextSeq;
      if (!hasMore) break;
    }
    return restored;
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
/// to 为 null，用 group_id 兜底作群会话键。完整信封仅解包正文，其余（msg_type/e2ee/
/// created_at 等）原样透传。纯函数，供单测覆盖字段映射正确性。
Map<String, dynamic> archiveRowToOfflineShape(Map<String, dynamic> row) {
  final chatType = (row['chat_type'] ?? '').toString().toLowerCase();
  final type = chatType == 'c2g' ? 'C2G' : 'C2C';
  final out = Map<String, dynamic>.from(row);
  out['type'] = type;
  final envelope = row['payload'];
  if (envelope is Map &&
      row['msg_id'] != null &&
      envelope['id']?.toString() == row['msg_id']?.toString() &&
      envelope['type'] == type &&
      envelope.containsKey('payload')) {
    out['payload'] = envelope['payload'];
    if (envelope.containsKey('action')) out['action'] = envelope['action'];
  }

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
