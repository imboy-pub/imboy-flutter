import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_conversation_utils.dart';

void main() {
  group('resolveConversationPeerId', () {
    test('C2C incoming uses sender as peer', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': 'u_other', 'to': 'u_me'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2C self echo uses receiver as peer', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': 'u_me', 'to': 'u_other'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2G uses group id from to', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2G',
        data: {'from': 'u_me', 'to': 'g_1'},
        currentUid: 'u_me',
      );

      expect(peerId, 'g_1');
    });

    test('C2C falls back to to when from is empty', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': '', 'to': 'u_other'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });
  });

  group('computeConversationUnreadIncrement', () {
    test('incoming message in background adds unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
      );

      expect(increment, 1);
    });

    test('incoming message in active chat does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: true,
      );

      expect(increment, 0);
    });

    test('self message in background does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: false,
      );

      expect(increment, 0);
    });

    test('self message in active chat does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: true,
      );

      expect(increment, 0);
    });
  });

  group('computeMentionUnreadIncrement (C7-β-2a)', () {
    test('returns 0 when message is from current user', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: false,
        mentionIds: const ['u_me', 'all'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'self-sent message must never bump mention_unread');
    });

    test('returns 0 when user is already in that chat', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: true,
        mentionIds: const ['u_me'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'user is viewing the chat → no badge');
    });

    test('returns 0 when mentionIds is null', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: null,
        currentUid: 'u_me',
      );
      expect(delta, 0);
    });

    test('returns 0 when mentionIds is empty', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const [],
        currentUid: 'u_me',
      );
      expect(delta, 0);
    });

    test('returns 1 when mentionIds contains current user', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['u_other', 'u_me'],
        currentUid: 'u_me',
      );
      expect(delta, 1);
    });

    test("returns 1 when mentionIds contains 'all'", () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['all'],
        currentUid: 'u_me',
      );
      expect(delta, 1);
    });

    test('returns 0 when mentionIds excludes current user and has no all', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['u_alice', 'u_bob'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'message mentions others, not current user');
    });

    test('returns 0 when empty currentUid (logged out edge case)', () {
      // If somehow currentUid is empty, only 'all' should still match.
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const [''],
        currentUid: '',
      );
      expect(delta, 0,
          reason: 'empty currentUid must not opportunistically match empty id');
    });
  });

  group('shouldSuppressNotification (C7-α-2)', () {
    test('returns false when isMuted = 0 (default: notify)', () {
      expect(shouldSuppressNotification(isMuted: 0), isFalse);
    });

    test('returns true when isMuted = 1 (user enabled DND)', () {
      expect(shouldSuppressNotification(isMuted: 1), isTrue);
    });

    test('treats any positive int as muted (future-proof)', () {
      expect(shouldSuppressNotification(isMuted: 2), isTrue);
      expect(shouldSuppressNotification(isMuted: 999), isTrue);
    });

    test('treats negative defensively as not muted', () {
      // corrupted data defaults to "not muted" — show notifications rather
      // than silently dropping messages.
      expect(shouldSuppressNotification(isMuted: -1), isFalse);
    });
  });

  /// slice-8 (C6 接线) RED-24：DND 下 @ 穿透。
  ///
  /// 对齐 `shouldNotifyGroupMessage`（slice-5）契约：
  ///   - 即便 `isMuted > 0`，若消息 @ 了当前用户，仍应通知
  ///   - 这是行业共识（微信 / TG / Slack）：免打扰不屏蔽定向呼叫
  ///   - 参数 `isMentioned` 默认 false 以保持向后兼容
  group('shouldSuppressNotification — @ 穿透（slice-8）', () {
    test('isMuted>0 + isMentioned=true → false（不抑制，让通知穿透）', () {
      expect(
        shouldSuppressNotification(isMuted: 1, isMentioned: true),
        isFalse,
        reason: '定向 @ 呼叫应穿透 DND',
      );
      expect(
        shouldSuppressNotification(isMuted: 999, isMentioned: true),
        isFalse,
      );
    });

    test('isMuted>0 + isMentioned=false → true（保留抑制）', () {
      expect(
        shouldSuppressNotification(isMuted: 1, isMentioned: false),
        isTrue,
      );
    });

    test('isMuted=0 + isMentioned=true → false（无 DND，正常通知）', () {
      expect(
        shouldSuppressNotification(isMuted: 0, isMentioned: true),
        isFalse,
      );
    });

    test('isMentioned 参数省略 → 向后兼容（等价 false）', () {
      // 既有调用方不传 isMentioned 时行为不变
      expect(shouldSuppressNotification(isMuted: 1), isTrue);
      expect(shouldSuppressNotification(isMuted: 0), isFalse);
    });
  });

  /// `extractMentionIdsFromPayload` 的契约固化测试。
  ///
  /// 这个函数在 `message.dart:836` / `message_repo_sqlite.dart:1465` 两处消费，
  /// 但原本零单测覆盖 —— 这里补齐 characterization，防止 wire-format 改动时
  /// 悄悄破坏 @mention 未读 / DND 穿透两条已稳定的链路。
  group('extractMentionIdsFromPayload', () {
    test('null payload → null', () {
      expect(extractMentionIdsFromPayload(null), isNull);
    });

    test('缺少 mentions 键 → null', () {
      expect(
        extractMentionIdsFromPayload(<String, dynamic>{'text': 'hi'}),
        isNull,
      );
    });

    test('mentions 是 String（非 List）→ null（防御性）', () {
      expect(
        extractMentionIdsFromPayload(<String, dynamic>{'mentions': 'u_me'}),
        isNull,
      );
    });

    test('mentions 是 int → null', () {
      expect(
        extractMentionIdsFromPayload(<String, dynamic>{'mentions': 42}),
        isNull,
      );
    });

    test('mentions 是 Map → null', () {
      expect(
        extractMentionIdsFromPayload(<String, dynamic>{
          'mentions': {'u_me': true},
        }),
        isNull,
      );
    });

    test('mentions 是空 List → 空 List（非 null）', () {
      final result = extractMentionIdsFromPayload(
        <String, dynamic>{'mentions': <dynamic>[]},
      );
      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('mentions 是 List<String> → 按序返回', () {
      expect(
        extractMentionIdsFromPayload(
          <String, dynamic>{'mentions': ['u_a', 'u_b', 'u_c']},
        ),
        ['u_a', 'u_b', 'u_c'],
      );
    });

    test('mentions 包含 "all" 哨兵 → 原样保留（供 @所有人 判定）', () {
      final result = extractMentionIdsFromPayload(
        <String, dynamic>{'mentions': ['all', 'u_me']},
      );
      expect(result, contains('all'));
      expect(result, contains('u_me'));
    });

    test('mentions 含非字符串元素（int / bool）→ toString 兜底', () {
      final result = extractMentionIdsFromPayload(
        <String, dynamic>{'mentions': <dynamic>[1838294017982464, true, 'u_me']},
      );
      expect(result, ['1838294017982464', 'true', 'u_me']);
    });

    test('mentions 含 null 元素 → 字面量字符串 "null"（暴露后端脏数据）', () {
      final result = extractMentionIdsFromPayload(
        <String, dynamic>{'mentions': <dynamic>[null, 'u_me']},
      );
      // 当前实现 toString 会把 null 转成 "null"；
      // 若未来要过滤应在本函数而非调用侧修复 → 此断言会 RED 提醒。
      expect(result, ['null', 'u_me']);
    });

    test('返回的 List 是 unmodifiable（growable: false）', () {
      final result = extractMentionIdsFromPayload(
        <String, dynamic>{'mentions': ['u_me']},
      );
      expect(result, isNotNull);
      expect(() => result!.add('u_other'), throwsUnsupportedError);
    });
  });
}
