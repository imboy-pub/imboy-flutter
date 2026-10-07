import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_conversation_utils.dart';

void main() {
  group('resolveConversationPeerId', () {
    test('C2C incoming uses sender as peer', () {
      final peerId = resolveConversationPeerId(
        chatType: 'C2C',
        data: {'from': 'u_other', 'to': 'u_me'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2C self echo uses receiver as peer', () {
      final peerId = resolveConversationPeerId(
        chatType: 'C2C',
        data: {'from': 'u_me', 'to': 'u_other'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2G uses group id from to', () {
      final peerId = resolveConversationPeerId(
        chatType: 'C2G',
        data: {'from': 'u_me', 'to': 'g_1'},
        currentUid: 'u_me',
      );

      expect(peerId, 'g_1');
    });

    test('C2C falls back to to when from is empty', () {
      final peerId = resolveConversationPeerId(
        chatType: 'C2C',
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
      expect(
        delta,
        0,
        reason: 'self-sent message must never bump mention_unread',
      );
    });

    test('returns 0 when user is already in that chat', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: true,
        mentionIds: const ['u_me'],
        currentUid: 'u_me',
      );
      expect(delta, 0, reason: 'user is viewing the chat → no badge');
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
      expect(delta, 0, reason: 'message mentions others, not current user');
    });

    test('returns 0 when empty currentUid (logged out edge case)', () {
      // If somehow currentUid is empty, only 'all' should still match.
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const [''],
        currentUid: '',
      );
      expect(
        delta,
        0,
        reason: 'empty currentUid must not opportunistically match empty id',
      );
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

  /// Q09/G1（AC22 免打扰）：C2G 群会话 DND 双源合并判定 + 接线不变量。
  ///
  /// 断点背景：群详情页免打扰开关只落 KV（group_notice_config，slice-6），
  /// 而通知管线只读 conversation.is_muted 列（C7-α-1）——两套存储未打通，
  /// 群 DND 开启后通知照常弹出。isGroupDndActive 把两源合并（任一命中
  /// 即抑制），message.dart 已在 C2G 分支接线。
  group('isGroupDndActive — Q09/G1 双源合并', () {
    test('列=0 + KV=false → 不抑制（默认通知）', () {
      expect(
        isGroupDndActive(isMutedColumn: 0, kvNoticeDisabled: false),
        isFalse,
      );
    });

    test('列命中（列>0，KV 任意）→ 抑制', () {
      expect(
        isGroupDndActive(isMutedColumn: 1, kvNoticeDisabled: false),
        isTrue,
      );
      expect(
        isGroupDndActive(isMutedColumn: 999, kvNoticeDisabled: true),
        isTrue,
      );
    });

    test('KV 命中、列=0 → 抑制（slice-6 存量记录 / 先设 DND 后建会话行）', () {
      // 覆盖两个列缺失场景：
      // 1. slice-6 时代只写 KV，列从未同步的存量用户；
      // 2. 用户先开免打扰、群会话行由首条消息 upsert 创建（is_muted 默认 0）。
      expect(
        isGroupDndActive(isMutedColumn: 0, kvNoticeDisabled: true),
        isTrue,
      );
    });

    test('列脏数据（负数）+ KV=true → KV 兜底抑制', () {
      expect(
        isGroupDndActive(isMutedColumn: -1, kvNoticeDisabled: true),
        isTrue,
      );
    });

    test('列脏数据（负数）+ KV=false → 防御性不抑制（宁可多弹不可丢通知）', () {
      expect(
        isGroupDndActive(isMutedColumn: -1, kvNoticeDisabled: false),
        isFalse,
      );
    });
  });

  /// Q09/G1 不变量：DND 只抑制通知弹窗，消息本体与已读/未读语义不受影响。
  ///
  /// message.dart 的接线顺序固化：消息落库、未读/mention 自增、UI 事件
  /// 全部在 DND 判定**之前**完成；DND 仅决定 _showMessageNotification 是否
  /// 调用。这里把「未读增量计算不接收 DND 参数」固化为契约——若未来有人
  /// 把 DND 传进未读计算（顺手"静音也不计未读"），此处编译期即暴露。
  group('Q09/G1 不变量 — DND 抑制通知但不动已读/未读语义', () {
    test('DND 命中时未读增量照常 +1（离线他人消息）', () {
      const dndHit = true;
      expect(
        computeConversationUnreadIncrement(
          isFromCurrentUser: false,
          isUserInChat: false,
        ),
        1,
        reason: '未读增量函数不接收 DND 参数：DND 命中不得影响未读计数',
      );
      expect(dndHit, isTrue); // 语义锚：上文场景确为 DND 命中
    });

    test('DND 命中时 mention 未读增量照常计算', () {
      expect(
        computeMentionUnreadIncrement(
          isFromCurrentUser: false,
          isUserInChat: false,
          mentionIds: const <String>['all'],
          currentUid: 'u_me',
        ),
        1,
        reason: '@所有人 的 mention 未读不受 DND 影响',
      );
    });

    test('DND 命中（KV 源）→ 通知被抑制；@ 穿透仍生效', () {
      final dndHit = isGroupDndActive(isMutedColumn: 0, kvNoticeDisabled: true);
      expect(dndHit, isTrue);
      // 管线实际组合形态：shouldSuppressNotification(isMuted: dndHit ? 1 : 0, ...)
      expect(
        shouldSuppressNotification(isMuted: dndHit ? 1 : 0),
        isTrue,
        reason: '群详情页开免打扰后，群消息通知必须被抑制（G1 断点修复）',
      );
      expect(
        shouldSuppressNotification(isMuted: dndHit ? 1 : 0, isMentioned: true),
        isFalse,
        reason: '被 @ 时穿透 DND（slice-8 语义在合并源下保持）',
      );
    });

    test('DND 未命中（双源全空）→ 通知正常', () {
      final dndHit = isGroupDndActive(
        isMutedColumn: 0,
        kvNoticeDisabled: false,
      );
      expect(shouldSuppressNotification(isMuted: dndHit ? 1 : 0), isFalse);
    });

    test('C2C 单聊语义不回归：isMuted 列直判（无 KV 源）', () {
      // message.dart C2C 分支不查 KV，直接 savedConv.isMuted > 0
      const c2cIsMuted = 1;
      expect(
        shouldSuppressNotification(isMuted: c2cIsMuted),
        isTrue,
        reason: 'C2C 单聊设置页（chat_setting_page）写列，管线读列——闭环不变',
      );
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
      final result = extractMentionIdsFromPayload(<String, dynamic>{
        'mentions': <dynamic>[],
      });
      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('mentions 是 List<String> → 按序返回', () {
      expect(
        extractMentionIdsFromPayload(<String, dynamic>{
          'mentions': ['u_a', 'u_b', 'u_c'],
        }),
        ['u_a', 'u_b', 'u_c'],
      );
    });

    test('mentions 包含 "all" 哨兵 → 原样保留（供 @所有人 判定）', () {
      final result = extractMentionIdsFromPayload(<String, dynamic>{
        'mentions': ['all', 'u_me'],
      });
      expect(result, contains('all'));
      expect(result, contains('u_me'));
    });

    test('mentions 含非字符串元素（int / bool）→ toString 兜底', () {
      final result = extractMentionIdsFromPayload(<String, dynamic>{
        'mentions': <dynamic>[1838294017982464, true, 'u_me'],
      });
      expect(result, ['1838294017982464', 'true', 'u_me']);
    });

    test('mentions 含 null 元素 → 字面量字符串 "null"（暴露后端脏数据）', () {
      final result = extractMentionIdsFromPayload(<String, dynamic>{
        'mentions': <dynamic>[null, 'u_me'],
      });
      // 当前实现 toString 会把 null 转成 "null"；
      // 若未来要过滤应在本函数而非调用侧修复 → 此断言会 RED 提醒。
      expect(result, ['null', 'u_me']);
    });

    test('返回的 List 是 unmodifiable（growable: false）', () {
      final result = extractMentionIdsFromPayload(<String, dynamic>{
        'mentions': ['u_me'],
      });
      expect(result, isNotNull);
      expect(() => result!.add('u_other'), throwsUnsupportedError);
    });
  });
}
