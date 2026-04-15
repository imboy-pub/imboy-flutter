/// 钉住群成员禁言 UI 入口的**权限矩阵**与**剩余时间标签**纯函数 —— 驱动 slice-2。
///
/// 角色约定（与后端 `include/group_role.hrl` 对齐）：
///   1 = 普通成员 (ROLE_MEMBER)
///   2 = 嘉宾 (ROLE_GUEST)
///   3 = 管理员 (ROLE_ADMIN)
///   4 = 群主 (ROLE_OWNER)
///   5 = 副群主 (ROLE_VICE_OWNER)
///
/// **关键**：数值顺序 ≠ 权威顺序。副群主 (5) 权威介于管理员 (3) 与群主 (4) 之间。
/// 权威排序：member(1) < guest(2) < admin(3) < vice_owner(5) < owner(4)
///
/// 契约：
///   1. 仅 role ∈ {3, 4, 5} 的成员可发起禁言操作
///   2. 不可禁言自己（即使是群主）
///   3. 权威严格低于自己的目标可被禁言；同级或更高 → 拒绝
///   4. 群主可禁言所有人（除自己，含副群主）
///   5. 副群主可禁言管理员/嘉宾/普通成员，不可禁言群主或另一副群主
///   6. 管理员不可禁言副群主（副群主权威高于自己）
///   7. muteRemainingLabel：
///      - muteUntilMs == null 或 <= now → 返回 ''（未禁言）
///      - 剩余 < 60s → "X 秒"
///      - 剩余 < 60min → "X 分钟"
///      - 剩余 < 24h → "X 小时"
///      - 剩余 ≥ 24h → "X 天"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_member/group_member_mute_rules.dart';

void main() {
  group('canMuteGroupMember — 角色权限矩阵', () {
    test('普通成员（role=1）不可禁言任何人', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'u1',
          currentRole: 1,
          targetUserId: 'u2',
          targetRole: 1,
        ),
        isFalse,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'u1',
          currentRole: 1,
          targetUserId: 'u2',
          targetRole: 3,
        ),
        isFalse,
      );
    });

    test('嘉宾（role=2）不可禁言任何人', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'u1',
          currentRole: 2,
          targetUserId: 'u2',
          targetRole: 1,
        ),
        isFalse,
      );
    });

    test('管理员（role=3）可禁言普通成员和嘉宾', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'admin',
          currentRole: 3,
          targetUserId: 'member',
          targetRole: 1,
        ),
        isTrue,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'admin',
          currentRole: 3,
          targetUserId: 'guest',
          targetRole: 2,
        ),
        isTrue,
      );
    });

    test('管理员不可禁言另一个管理员（平级）', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'admin1',
          currentRole: 3,
          targetUserId: 'admin2',
          targetRole: 3,
        ),
        isFalse,
      );
    });

    test('管理员不可禁言群主', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'admin',
          currentRole: 3,
          targetUserId: 'owner',
          targetRole: 4,
        ),
        isFalse,
      );
    });

    test('群主（role=4）可禁言管理员、嘉宾、普通成员', () {
      for (final targetRole in [1, 2, 3]) {
        expect(
          canMuteGroupMember(
            currentUserId: 'owner',
            currentRole: 4,
            targetUserId: 'other',
            targetRole: targetRole,
          ),
          isTrue,
          reason: '群主应能禁言 role=$targetRole',
        );
      }
    });

    test('自己不能禁言自己（即使是群主）', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'me',
          currentRole: 4,
          targetUserId: 'me',
          targetRole: 4,
        ),
        isFalse,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'me',
          currentRole: 3,
          targetUserId: 'me',
          targetRole: 3,
        ),
        isFalse,
      );
    });

    test('非法 role 数值（0 / 负数）一律拒绝', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'u1',
          currentRole: 0,
          targetUserId: 'u2',
          targetRole: 1,
        ),
        isFalse,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'u1',
          currentRole: 3,
          targetUserId: 'u2',
          targetRole: 0,
        ),
        isFalse,
      );
    });

    // ---------- slice-2 补丁：role=5 副群主 扩展 ----------
    //
    // 权威排序：member(1) < guest(2) < admin(3) < vice_owner(5) < owner(4)
    // 数值大小不代表权威高低 —— 不能再用 `targetRole < currentRole` 的朴素比较。

    test('副群主（role=5）可禁言管理员/嘉宾/普通成员', () {
      for (final targetRole in [1, 2, 3]) {
        expect(
          canMuteGroupMember(
            currentUserId: 'vice',
            currentRole: 5,
            targetUserId: 'target',
            targetRole: targetRole,
          ),
          isTrue,
          reason: '副群主应能禁言 role=$targetRole',
        );
      }
    });

    test('副群主不可禁言群主（群主权威更高）', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'vice',
          currentRole: 5,
          targetUserId: 'owner',
          targetRole: 4,
        ),
        isFalse,
      );
    });

    test('副群主不可禁言另一个副群主（同级）', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'vice1',
          currentRole: 5,
          targetUserId: 'vice2',
          targetRole: 5,
        ),
        isFalse,
      );
    });

    test('副群主不可禁言自己', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'me',
          currentRole: 5,
          targetUserId: 'me',
          targetRole: 5,
        ),
        isFalse,
      );
    });

    test('群主可禁言副群主', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'owner',
          currentRole: 4,
          targetUserId: 'vice',
          targetRole: 5,
        ),
        isTrue,
      );
    });

    test('管理员不可禁言副群主（副群主权威更高）', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'admin',
          currentRole: 3,
          targetUserId: 'vice',
          targetRole: 5,
        ),
        isFalse,
        reason: '副群主权威高于管理员，即使 5 > 3',
      );
    });

    test('普通成员/嘉宾不可禁言副群主', () {
      expect(
        canMuteGroupMember(
          currentUserId: 'member',
          currentRole: 1,
          targetUserId: 'vice',
          targetRole: 5,
        ),
        isFalse,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'guest',
          currentRole: 2,
          targetUserId: 'vice',
          targetRole: 5,
        ),
        isFalse,
      );
    });

    test('空 userId 视为非法输入', () {
      expect(
        canMuteGroupMember(
          currentUserId: '',
          currentRole: 4,
          targetUserId: 'u2',
          targetRole: 1,
        ),
        isFalse,
      );
      expect(
        canMuteGroupMember(
          currentUserId: 'owner',
          currentRole: 4,
          targetUserId: '',
          targetRole: 1,
        ),
        isFalse,
      );
    });
  });

  group('muteRemainingLabel — 剩余时间文案', () {
    const nowMs = 1_700_000_000_000;

    test('muteUntilMs == null → ""', () {
      expect(muteRemainingLabel(muteUntilMs: null, nowMs: nowMs), '');
    });

    test('muteUntilMs <= now → ""（已解禁）', () {
      expect(muteRemainingLabel(muteUntilMs: nowMs, nowMs: nowMs), '');
      expect(muteRemainingLabel(muteUntilMs: nowMs - 1000, nowMs: nowMs), '');
    });

    test('剩余 30 秒 → "30 秒"', () {
      expect(
        muteRemainingLabel(muteUntilMs: nowMs + 30 * 1000, nowMs: nowMs),
        '30 秒',
      );
    });

    test('剩余 5 分钟 → "5 分钟"', () {
      expect(
        muteRemainingLabel(muteUntilMs: nowMs + 5 * 60 * 1000, nowMs: nowMs),
        '5 分钟',
      );
    });

    test('剩余 2 小时 → "2 小时"', () {
      expect(
        muteRemainingLabel(
          muteUntilMs: nowMs + 2 * 60 * 60 * 1000,
          nowMs: nowMs,
        ),
        '2 小时',
      );
    });

    test('剩余 3 天 → "3 天"', () {
      expect(
        muteRemainingLabel(
          muteUntilMs: nowMs + 3 * 24 * 60 * 60 * 1000,
          nowMs: nowMs,
        ),
        '3 天',
      );
    });

    test('剩余 59 秒 → "59 秒"（边界）', () {
      expect(
        muteRemainingLabel(muteUntilMs: nowMs + 59 * 1000, nowMs: nowMs),
        '59 秒',
      );
    });

    test('剩余正好 60 秒 → "1 分钟"（边界）', () {
      expect(
        muteRemainingLabel(muteUntilMs: nowMs + 60 * 1000, nowMs: nowMs),
        '1 分钟',
      );
    });

    test('剩余正好 60 分钟 → "1 小时"（边界）', () {
      expect(
        muteRemainingLabel(
          muteUntilMs: nowMs + 60 * 60 * 1000,
          nowMs: nowMs,
        ),
        '1 小时',
      );
    });

    test('剩余正好 24 小时 → "1 天"（边界）', () {
      expect(
        muteRemainingLabel(
          muteUntilMs: nowMs + 24 * 60 * 60 * 1000,
          nowMs: nowMs,
        ),
        '1 天',
      );
    });
  });
}
