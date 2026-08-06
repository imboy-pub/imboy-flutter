/// F5-A slice-3 发送侧决策内核 RED。
///
/// `resolveMentionsForSend` 是 chat 发送链路（`chat_page.dart:1271-1275`）
/// 附加 mentions 字段前的最后一道闸门：
///   - 无 @ → 不需附字段
///   - @ 普通用户 → 去重编码
///   - @所有人 + admin/owner/vice_owner → 编码 ["all"]
///   - @所有人 + member/guest → 拒绝（UI 层据此 toast 并阻塞发送）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/mention_all_rules.dart';

void main() {
  group('resolveMentionsForSend — 空结果分支', () {
    test('非群聊 → Empty（mentions 字段不应附加）', () {
      final r = resolveMentionsForSend(
        isGroupChat: false,
        role: 3,
        uids: const ['u1'],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveEmpty>());
    });

    test('群聊但无 @ 选择 → Empty', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 3,
        uids: const [],
        isAllSelected: false,
      );
      expect(r, isA<MentionResolveEmpty>());
    });

    test('群聊 + 去重过滤后为空 → Empty', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 3,
        uids: const ['', '  '],
        isAllSelected: false,
      );
      expect(r, isA<MentionResolveEmpty>());
    });
  });

  group('resolveMentionsForSend — @普通用户分支', () {
    test('member 可以 @ 普通用户', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 1,
        uids: const ['u1', 'u2'],
        isAllSelected: false,
      );
      expect(r, isA<MentionResolveOk>());
      expect((r as MentionResolveOk).mentions, const ['u1', 'u2']);
    });

    test('guest 也可以 @ 普通用户', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 2,
        uids: const ['u1'],
        isAllSelected: false,
      );
      expect(r, isA<MentionResolveOk>());
    });

    test('@ 普通用户经过去重', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 1,
        uids: const ['u1', 'u1', 'u2'],
        isAllSelected: false,
      );
      expect((r as MentionResolveOk).mentions, const ['u1', 'u2']);
    });
  });

  group('resolveMentionsForSend — @所有人分支', () {
    test('admin(3) + @所有人 → Ok(["all"])', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 3,
        uids: const [],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveOk>());
      expect((r as MentionResolveOk).mentions, const ['all']);
    });

    test('owner(4) + @所有人 → Ok(["all"])', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 4,
        uids: const [],
        isAllSelected: true,
      );
      expect((r as MentionResolveOk).mentions, const ['all']);
    });

    test('vice_owner(5) + @所有人 → Ok(["all"])', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 5,
        uids: const [],
        isAllSelected: true,
      );
      expect((r as MentionResolveOk).mentions, const ['all']);
    });

    test('member(1) + @所有人 → DeniedAll（无权限）', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 1,
        uids: const [],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveDeniedAll>());
    });

    test('guest(2) + @所有人 → DeniedAll', () {
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 2,
        uids: const [],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveDeniedAll>());
    });

    test('@所有人优先：isAllSelected=true 压过 uids（admin）', () {
      // 即使同时选了普通 uid，["all"] 字面量语义应覆盖
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 3,
        uids: const ['u1', 'u2'],
        isAllSelected: true,
      );
      expect((r as MentionResolveOk).mentions, const ['all']);
    });

    test('@所有人优先：member + isAllSelected=true + 普通 uid → 拒绝（不降级）', () {
      // 关键：即使普通 uid 可 @，只要用户意图是 @所有人就必须整体拒绝
      // 不能"偷偷降级"为 @ 子集，语义与用户意图不符
      final r = resolveMentionsForSend(
        isGroupChat: true,
        role: 1,
        uids: const ['u1'],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveDeniedAll>());
    });
  });

  group('resolveMentionsForSend — 非群聊永远 Empty', () {
    test('C2C 即使 isAllSelected=true 也返回 Empty（后端会拒但客户端先拦）', () {
      final r = resolveMentionsForSend(
        isGroupChat: false,
        role: 4,
        uids: const ['u1'],
        isAllSelected: true,
      );
      expect(r, isA<MentionResolveEmpty>());
    });
  });
}
