import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

/// 阅后即焚服务
///
/// 负责阅后即焚消息的定时器管理、过期删除、已读标记等功能。
/// 从 ChatNotifier 提取，字段 burnDeleteTimers / burnPurgeTimers 由外部持有并传入。
class ChatBurnService {
  const ChatBurnService();

  // ===== Payload 判断辅助 =====

  /// 检查是否是阅后即焚消息（静态，供外部使用）
  static bool isBurnPayload(Map<String, dynamic> payload) {
    return payload['burn'] == true || payload['is_burn'] == true;
  }

  bool checkBurnPayload(Map<String, dynamic> payload) => isBurnPayload(payload);

  bool isBurnTombstonePayload(Map<String, dynamic> payload) =>
      payload['burn_deleted'] == true;

  int burnAfterMsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['burn_after_ms'] ?? payload['expiry_time'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  int burnReadAtMsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['burn_read_at'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  bool isBurnExpired(Map<String, dynamic> payload, int nowMs) {
    if (!isBurnPayload(payload)) return false;
    final int burnAfter = burnAfterMsFromPayload(payload);
    final int readAt = burnReadAtMsFromPayload(payload);
    if (burnAfter <= 0 || readAt <= 0) return false;
    return readAt + burnAfter <= nowMs;
  }

  // ===== 定时器调度 =====

  static const int maxBurnTimers = 500;

  /// 为一条阅后即焚消息调度删除定时器
  Future<void> scheduleBurnDeletion({
    required Map<String, Timer> burnDeleteTimers,
    required ConversationModel conversation,
    required String messageId,
    required int burnAfterMs,
    required int readAtMs,
    required Future<void> Function(ConversationModel, String) onDelete,
  }) async {
    if (burnAfterMs <= 0 || readAtMs <= 0) return;
    burnDeleteTimers[messageId]?.cancel();
    final int expireAt = readAtMs + burnAfterMs;
    final int now = DateTimeHelper.millisecond();
    final int delayMs = expireAt - now;
    if (delayMs <= 0) {
      await onDelete(conversation, messageId);
      return;
    }
    // 防止内存泄漏：超过上限时移除最早的定时器
    if (burnDeleteTimers.length >= maxBurnTimers) {
      final String oldestKey = burnDeleteTimers.keys.first;
      burnDeleteTimers.remove(oldestKey)?.cancel();
    }
    burnDeleteTimers[messageId] = Timer(
      Duration(milliseconds: delayMs),
      () async {
        await onDelete(conversation, messageId);
      },
    );
  }

  /// 确保消息对应的阅后即焚定时器已设置
  Future<void> ensureBurnTimerForItem({
    required Map<String, Timer> burnDeleteTimers,
    required ConversationModel conversation,
    required MessageRepo repo,
    required MessageModel item,
    required int nowMs,
    required Future<void> Function(ConversationModel, String) onDelete,
  }) async {
    final payload = item.payload as Map<String, dynamic>;
    if (!isBurnPayload(payload)) return;
    if (isBurnTombstonePayload(payload)) return;
    final int burnAfter = burnAfterMsFromPayload(payload);
    if (burnAfter <= 0) return;

    int readAt = burnReadAtMsFromPayload(payload);
    if (readAt <= 0 && item.status == IMBoyMessageStatus.seen) {
      readAt = nowMs;
      payload['burn_read_at'] = readAt;
      final String messageId = item.id;
      if (messageId.isNotEmpty) {
        await repo.update({
          MessageRepo.id: messageId,
          MessageRepo.payload: payload,
        });
      }
    }

    if (readAt > 0) {
      await scheduleBurnDeletion(
        burnDeleteTimers: burnDeleteTimers,
        conversation: conversation,
        messageId: item.id,
        burnAfterMs: burnAfter,
        readAtMs: readAt,
        onDelete: onDelete,
      );
    }
  }

  // ===== 删除/过期 =====

  /// 内部删除阅后即焚消息（由定时器触发）
  Future<void> deleteBurnMessage({
    required Map<String, Timer> burnDeleteTimers,
    required SqliteChatService? chatService,
    required ConversationModel conversation,
    required String messageId,
    required Future<void> Function(ConversationModel, String) onExpire,
  }) async {
    try {
      final String tb = MessageRepo.getTableName(conversation.type);
      final MessageRepo repo = MessageRepo(tableName: tb);
      final MessageModel? m = await repo.find(messageId);
      if (m == null) {
        try {
          if (chatService?.isDisposed != true) {
            await chatService?.removeMessageById(messageId);
          }
        } catch (_) {}
        return;
      }
      await onExpire(conversation, messageId);
    } catch (_) {}
    burnDeleteTimers.remove(messageId)?.cancel();
  }

  /// 标记阅后即焚消息为已读，并调度定时器
  Future<void> markBurnReadAt({
    required Map<String, Timer> burnDeleteTimers,
    required ConversationModel conversation,
    required String messageId,
    required int readAtMs,
    required Future<void> Function(ConversationModel, String) onDelete,
  }) async {
    try {
      final String tb = MessageRepo.getTableName(conversation.type);
      final MessageRepo repo = MessageRepo(tableName: tb);
      final MessageModel? m = await repo.find(messageId);
      if (m == null) return;
      final payload = Map<String, dynamic>.from(
        m.payload as Map<dynamic, dynamic>,
      );
      if (!isBurnPayload(payload)) return;

      final int burnAfter = burnAfterMsFromPayload(payload);
      if (burnAfter <= 0) return;

      final int existingReadAt = burnReadAtMsFromPayload(payload);
      final int nextReadAt = existingReadAt > 0 ? existingReadAt : readAtMs;
      if (existingReadAt <= 0) {
        payload['burn_read_at'] = nextReadAt;
        await repo.update({
          MessageRepo.id: messageId,
          MessageRepo.payload: payload,
        });
      }

      await scheduleBurnDeletion(
        burnDeleteTimers: burnDeleteTimers,
        conversation: conversation,
        messageId: messageId,
        burnAfterMs: burnAfter,
        readAtMs: nextReadAt,
        onDelete: onDelete,
      );

      final MessageModel? updated = await repo.find(messageId);
      if (updated != null) {
        AppEventBus.fireData([await updated.toTypeMessage()], 'List<Message>');
      }
    } catch (_) {}
  }

  /// 过期阅后即焚消息（写墓碑或直接删除）
  Future<void> expireBurnMessage({
    required SqliteChatService? chatService,
    required ConversationModel conversation,
    required String messageId,
    required String deletedMessageIdsKey,
    required Future<bool> Function(ConversationModel, Message) onRemoveMessage,
    int? deletedAtMs,
  }) async {
    try {
      final String tb = MessageRepo.getTableName(conversation.type);
      final MessageRepo repo = MessageRepo(tableName: tb);

      final MessageModel? m = await repo.find(messageId);
      if (m == null) {
        try {
          if (chatService?.isDisposed != true) {
            await chatService?.removeMessageById(messageId);
          }
        } catch (_) {}
        return;
      }

      final payload = Map<String, dynamic>.from(
        m.payload as Map<dynamic, dynamic>,
      );
      if (!isBurnPayload(payload)) {
        await onRemoveMessage(conversation, await m.toTypeMessage());
        return;
      }

      MessageRetry.instance.removeFromRetryQueue(messageId);
      await repo.delete(messageId);

      await recordDeletedMessageId(messageId, deletedMessageIdsKey);

      try {
        if (chatService?.isDisposed != true) {
          await chatService?.removeMessageById(messageId);
        }
      } catch (_) {}

      await updateConversationLastMessageAfterBurnHidden(
        conversation: conversation,
        messageRepo: repo,
        hiddenMessageId: messageId,
      );
    } catch (_) {}
  }

  // ===== 会话最后消息更新 =====

  Future<MessageModel?> findLatestVisibleMessageModel(
    MessageRepo repo,
    ConversationModel conversation, {
    required int nowMs,
    int scanLimit = 40,
  }) async {
    final items = await repo.page(
      conversationUk3: conversation.uk3,
      page: 1,
      size: scanLimit,
      orderBy: "${MessageRepo.autoId} DESC",
    );
    if (items.isEmpty) return null;

    for (final item in items) {
      final payload = item.payload as Map<String, dynamic>;
      if (isBurnTombstonePayload(payload)) continue;
      if (isBurnExpired(payload, nowMs)) continue;
      return item;
    }
    return null;
  }

  Future<void> updateConversationLastMessageAfterBurnHidden({
    required ConversationModel conversation,
    required MessageRepo messageRepo,
    required String hiddenMessageId,
  }) async {
    try {
      if (conversation.lastMsgId.toString() != hiddenMessageId) return;
      final int nowMs = DateTimeHelper.millisecond();
      final ConversationRepo repo = ConversationRepo();
      final MessageModel? latest = await findLatestVisibleMessageModel(
        messageRepo,
        conversation,
        nowMs: nowMs,
      );

      if (latest == null) {
        final int conversationTime = conversation.lastTime > 0
            ? conversation.lastTime
            : DateTimeHelper.millisecond();
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: 0,
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.lastTime: conversationTime,
          ConversationRepo.subtitle: '',
        });
      } else {
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastMsgStatus: latest.status,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgTypeFromModel(
            latest,
          ),
          ConversationRepo.subtitle: MessageModel.conversationSubtitleFromModel(
            latest,
          ),
        });
      }

      final ConversationModel? updated = await repo.findById(conversation.id);
      if (updated != null) {
        AppEventBus.fireData(updated);
      }
    } catch (_) {}
  }

  // ===== SharedPreferences 辅助 =====

  static const int deletedMessageRetentionMs = 24 * 60 * 60 * 1000;

  /// 记录已删除的消息ID到 SharedPreferences
  Future<void> recordDeletedMessageId(String messageId, String spKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> deleted = prefs.getStringList(spKey) ?? [];
      final int nowMs = DateTimeHelper.millisecond();
      deleted.add('$messageId:$nowMs');
      await prefs.setStringList(spKey, deleted);
      iPrint('记录已删除消息ID: $messageId');
    } catch (e) {
      iPrint('记录已删除消息ID失败: $e');
    }
  }

  /// 检查消息ID是否已被删除
  static Future<bool> isMessageDeleted(String messageId, String spKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> deleted = prefs.getStringList(spKey) ?? [];
      final int nowMs = DateTimeHelper.millisecond();
      for (final String entry in deleted) {
        final List<String> parts = entry.split(':');
        if (parts.length == 2 && parts[0] == messageId) {
          final int deletedAt = int.tryParse(parts[1]) ?? 0;
          if (nowMs - deletedAt >= deletedMessageRetentionMs) {
            return false;
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      iPrint('检查消息删除状态失败: $e');
      return false;
    }
  }

  /// 清理过期的已删除消息ID记录
  Future<void> cleanupDeletedMessageIds(String spKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> deleted = prefs.getStringList(spKey) ?? [];
      final int nowMs = DateTimeHelper.millisecond();
      final List<String> cleaned = [];
      for (final String entry in deleted) {
        final List<String> parts = entry.split(':');
        if (parts.length == 2) {
          final int deletedAt = int.tryParse(parts[1]) ?? 0;
          if (nowMs - deletedAt < deletedMessageRetentionMs) {
            cleaned.add(entry);
          }
        }
      }
      await prefs.setStringList(spKey, cleaned);
      iPrint('清理已删除消息ID记录完成: ${deleted.length} -> ${cleaned.length}');
    } catch (e) {
      iPrint('清理已删除消息ID记录失败: $e');
    }
  }
}
