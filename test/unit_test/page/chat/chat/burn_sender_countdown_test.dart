import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// BUG#139：发送方自己发出的阅后即焚消息永不销毁（本地隐私残留）
///
/// 真机证据（批次72）：开启阅后即焚后发送消息，停留「已发送」64 秒+ 仍显示，
/// 退出重进也不清理。根因：发送方消息的 burn_read_at 恒为 0（可视已读只对
/// 接收方注册，且 AI 机器人不回已读回执），而 isBurnExpired / 定时器都要求
/// burn_read_at > 0 → 永不销毁。
///
/// 修复语义（对齐 Telegram/微信闪照）：发送方倒计时从「发送时间」起算，
/// 接收方从「已读」起算。
ChatBurnService service() => const ChatBurnService();

ConversationModel conv() => ConversationModel(
  id: 0,
  peerId: 2,
  avatar: '',
  title: '',
  subtitle: '',
  type: 'C2C',
  msgType: 'empty',
  unreadNum: 0,
);

Map<String, dynamic> burnPayload({int? burnReadAt, int burnAfterMs = 30000}) {
  return <String, dynamic>{
    'text': 'qa_batch72_burn_001',
    'burn': true,
    'burn_after_ms': burnAfterMs,
    'burn_read_at': ?burnReadAt,
  };
}

MessageModel item({
  required String id,
  required Map<String, dynamic> payload,
  required int createdAt,
  int isAuthor = 1,
  int status = IMBoyMessageStatus.sent,
}) {
  return MessageModel(
    id,
    autoId: 0,
    type: 'C2C',
    status: status,
    fromId: isAuthor == 1 ? 1 : 2,
    toId: isAuthor == 1 ? 2 : 1,
    payload: payload,
    isAuthor: isAuthor,
    conversationUk3: 'c2c_1_2',
    createdAt: createdAt,
  );
}

void main() {
  group('isBurnExpired 发送方语义（倒计时从发送时间起算）', () {
    test('发送方消息 burn_read_at 为 0 时，超过发送时间+burnAfter 即过期', () {
      final int createdAt = DateTime.now().millisecondsSinceEpoch - 60000;
      // 已过 60s > 30s 销毁时长
      expect(
        service().isBurnExpired(
          burnPayload(),
          DateTime.now().millisecondsSinceEpoch,
          fallbackStartMs: createdAt,
        ),
        isTrue,
        reason: '发送方自己的消息应从发送时间起算销毁，不得依赖已读回执',
      );
    });

    test('发送方消息未到发送时间+burnAfter 时不过期', () {
      final int now = DateTime.now().millisecondsSinceEpoch;
      expect(
        service().isBurnExpired(
          burnPayload(),
          now,
          fallbackStartMs: now - 10000, // 刚发 10s，30s 未到
        ),
        isFalse,
      );
    });

    test('反证：不传 fallbackStartMs（旧行为）发送方消息永不销毁', () {
      // 反向断言：修复前 isBurnExpired 只认 burn_read_at，发送方恒 0 → 永不销毁。
      expect(
        service().isBurnExpired(
          burnPayload(),
          DateTime.now().millisecondsSinceEpoch,
        ),
        isFalse,
        reason: '旧契约 burn_read_at=0 时永不销毁，这正是 BUG#139',
      );
    });

    test('接收方语义不变：未读（无 burn_read_at 且不传 fallback）不销毁', () {
      // 接收方未读的消息不传 fallback（调用方对 isAuthor != 1 传 0）
      expect(
        service().isBurnExpired(
          burnPayload(),
          DateTime.now().millisecondsSinceEpoch,
          fallbackStartMs: 0,
        ),
        isFalse,
        reason: '接收方倒计时从已读起算，未读不销毁',
      );
    });

    test('burn_read_at 已存在时优先按已读时间（接收方已读路径不受影响）', () {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int readAt = now - 40000;
      expect(
        service().isBurnExpired(
          burnPayload(burnReadAt: readAt),
          now,
          fallbackStartMs: 0, // 即使调用方误传 fallback 也以 readAt 为准
        ),
        isTrue,
      );
    });

    test('非阅后即焚消息不受影响', () {
      expect(
        service().isBurnExpired({
          'text': 'x',
        }, DateTime.now().millisecondsSinceEpoch),
        isFalse,
      );
    });
  });

  group('burnCountdownStartMs 起点解析', () {
    test('burn_read_at 优先于 fallback', () {
      expect(
        ChatBurnService.burnCountdownStartMs(
          burnPayload(burnReadAt: 12345),
          100,
        ),
        12345,
      );
    });

    test('无 burn_read_at 时回退 fallback（发送方=发送时间）', () {
      expect(ChatBurnService.burnCountdownStartMs(burnPayload(), 999), 999);
    });

    test('两者皆无返回 0（不销毁）', () {
      expect(ChatBurnService.burnCountdownStartMs({'burn': true}, 0), 0);
    });
  });

  group('ensureBurnTimerForItem 发送方排期', () {
    test('发送方消息（status=sent，无 burn_read_at）按发送时间排销毁定时器', () async {
      final Map<String, Timer> timers = {};
      final int now = DateTime.now().millisecondsSinceEpoch;
      final String id = 'sender-burn-msg-1';
      final int createdAt = now - 10000; // 已发 10s，30s 倒计时未结束

      await service().ensureBurnTimerForItem(
        burnDeleteTimers: timers,
        conversation: conv(),
        repo: MessageRepo(tableName: 'msg_c2c'), // 发送方路径不得触碰 DB（payload 不落库）
        item: item(
          id: id,
          payload: burnPayload(),
          createdAt: createdAt,
          isAuthor: 1,
          status: IMBoyMessageStatus.sent,
        ),
        nowMs: now,
        onDelete: (_, _) async {},
      );

      expect(timers.containsKey(id), isTrue, reason: '发送方自己的阅后即焚消息必须排上销毁定时器');
      expect(timers[id]!.isActive, isTrue);
      timers[id]!.cancel();
    });

    test('发送方消息已超过发送时间+burnAfter 时立即销毁', () async {
      final Map<String, Timer> timers = {};
      final int now = DateTime.now().millisecondsSinceEpoch;
      final String id = 'sender-burn-expired-1';
      bool deleted = false;

      await service().ensureBurnTimerForItem(
        burnDeleteTimers: timers,
        conversation: conv(),
        repo: MessageRepo(tableName: 'msg_c2c'),
        item: item(
          id: id,
          payload: burnPayload(),
          createdAt: now - 60000, // 超过 30s 销毁时长
          isAuthor: 1,
          status: IMBoyMessageStatus.sent,
        ),
        nowMs: now,
        onDelete: (_, msgId) async {
          if (msgId == id) deleted = true;
        },
      );

      expect(deleted, isTrue, reason: '发送方消息过期应立即销毁');
      expect(timers.containsKey(id), isFalse);
    });

    test('接收方未读消息（无 burn_read_at、status=delivered）不排定时器', () async {
      final Map<String, Timer> timers = {};
      final int now = DateTime.now().millisecondsSinceEpoch;
      final String id = 'incoming-unread-1';

      await service().ensureBurnTimerForItem(
        burnDeleteTimers: timers,
        conversation: conv(),
        repo: MessageRepo(tableName: 'msg_c2c'),
        item: item(
          id: id,
          payload: burnPayload(),
          createdAt: now - 60000,
          isAuthor: 0,
          status: IMBoyMessageStatus.delivered,
        ),
        nowMs: now,
        onDelete: (_, _) async {},
      );

      expect(timers.containsKey(id), isFalse, reason: '接收方未读不销毁（从已读起算）');
    });
  });
}
