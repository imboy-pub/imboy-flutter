/// Tests for `lib/component/chat/mention_model.dart`
///
/// 覆盖：
///   - MentionCandidate factories (all / fromGroupMember alias-vs-nickname / json)
///   - MentionCandidate role getters (isAdmin / showRoleBadge / roleText)
///   - groupRoleLabel + groupRoleBgColor + groupRoleFgColor (色彩矩阵)
///   - MentionData add/remove/cursor 操作 + json roundtrip + hasAllMention
///   - MentionRange json roundtrip + 默认值兜底
///   - MentionState copyWith + filteredCandidates (排除自己 + 关键词过滤)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  // 公共 fixtures
  const owner = MentionCandidate(
    userId: 'u_owner',
    displayName: 'Owner',
    role: 4,
  );
  const admin = MentionCandidate(
    userId: 'u_admin',
    displayName: 'Admin',
    role: 3,
  );
  const viceOwner = MentionCandidate(
    userId: 'u_vice',
    displayName: 'Vice',
    role: 5,
  );
  const member = MentionCandidate(
    userId: 'u_member',
    displayName: 'Member',
    role: 1,
  );
  const guest = MentionCandidate(
    userId: 'u_guest',
    displayName: 'Guest',
    role: 2,
  );

  group('MentionCandidate.all() factory', () {
    test('returns canonical @所有人 candidate', () {
      final all = MentionCandidate.all();
      expect(all.userId, 'all');
      expect(all.displayName, '所有人');
      expect(all.isAllMention, isTrue);
      expect(all.role, 0);
      expect(all.avatar, '');
    });
  });

  group('MentionCandidate.fromGroupMember', () {
    test('alias non-empty → displayName 用 alias', () {
      final c = MentionCandidate.fromGroupMember({
        'user_id': 'u_1',
        'alias': 'GroupAlias',
        'nickname': 'NickName',
        'avatar': 'http://a/x.jpg',
        'role': 3,
      });
      expect(c.userId, 'u_1');
      expect(c.displayName, 'GroupAlias',
          reason: 'alias 非空时优先使用 alias，与 nickname 无关');
      expect(c.avatar, 'http://a/x.jpg');
      expect(c.role, 3);
      expect(c.isAllMention, isFalse);
    });

    test('alias 为空 → fallback 到 nickname', () {
      final c = MentionCandidate.fromGroupMember({
        'user_id': 'u_2',
        'alias': '',
        'nickname': 'TheNick',
      });
      expect(c.displayName, 'TheNick');
    });

    test('alias / nickname 都缺失 → displayName 为空字符串', () {
      final c = MentionCandidate.fromGroupMember({'user_id': 'u_3'});
      expect(c.displayName, '');
      expect(c.userId, 'u_3');
      expect(c.role, 1, reason: 'role 缺失默认 1（成员）');
    });

    test('user_id 缺失 → 空字符串（防 null 崩溃）', () {
      final c = MentionCandidate.fromGroupMember(<String, dynamic>{});
      expect(c.userId, '');
    });
  });

  group('MentionCandidate role getters', () {
    test('admin (3) / owner (4) / vice_owner (5) → isAdmin/showRoleBadge true',
        () {
      expect(admin.isAdmin, isTrue);
      expect(owner.isAdmin, isTrue);
      expect(viceOwner.isAdmin, isTrue);
      expect(admin.showRoleBadge, isTrue);
      expect(owner.showRoleBadge, isTrue);
      expect(viceOwner.showRoleBadge, isTrue);
    });

    test('member (1) / guest (2) → isAdmin/showRoleBadge false', () {
      expect(member.isAdmin, isFalse);
      expect(guest.isAdmin, isFalse);
      expect(member.showRoleBadge, isFalse);
      expect(guest.showRoleBadge, isFalse);
    });
  });

  group('MentionCandidate.toJson', () {
    test('包含全部字段', () {
      final c = MentionCandidate(
        userId: 'u_1',
        displayName: 'X',
        avatar: 'http://a',
        role: 3,
        isAllMention: false,
      );
      final j = c.toJson();
      expect(j['user_id'], 'u_1');
      expect(j['display_name'], 'X');
      expect(j['avatar'], 'http://a');
      expect(j['role'], 3);
      expect(j['is_all_mention'], isFalse);
    });

    test('@所有人 候选 toJson 标记 is_all_mention=true', () {
      final j = MentionCandidate.all().toJson();
      expect(j['is_all_mention'], isTrue);
      expect(j['user_id'], 'all');
    });
  });

  group('MentionData.addMention', () {
    test('首次添加：mentionIds + ranges 各 +1', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      expect(m1.mentionIds, ['u_1']);
      expect(m1.ranges.length, 1);
      expect(m1.ranges.first.start, 0);
      expect(m1.ranges.first.end, 5);
      expect(m1.ranges.first.userId, 'u_1');
    });

    test('已存在的 userId 不重复加 mentionIds，但 ranges 每次都加新条目', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      final m2 = m1.addMention('u_1', 10, 15);
      expect(m2.mentionIds, ['u_1'],
          reason: 'mentionIds 是去重集合（同一用户只算一次）');
      expect(m2.ranges.length, 2,
          reason: 'ranges 是每次插入的位置元组，可重复');
    });

    test('返回新对象（不可变性）', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      expect(identical(m0, m1), isFalse);
      expect(m0.mentionIds, isEmpty);
      expect(m0.ranges, isEmpty);
    });
  });

  group('MentionData.removeRange', () {
    test('精确匹配 (start,end) 的 range 被移除', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5).addMention('u_2', 10, 15);
      final m2 = m1.removeRange(0, 5);
      expect(m2.ranges.length, 1);
      expect(m2.ranges.first.userId, 'u_2');
      expect(m2.mentionIds, ['u_2'],
          reason: '所属 range 全删后，对应 userId 也从 mentionIds 移除');
    });

    test('userId 仍有其他 range → mentionIds 保留', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5).addMention('u_1', 10, 15);
      final m2 = m1.removeRange(0, 5);
      expect(m2.ranges.length, 1);
      expect(m2.mentionIds, ['u_1'],
          reason: 'u_1 还有 (10,15) range，不应被移出 mentionIds');
    });

    test('不匹配的 (start,end) → 原状返回（新对象）', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      final m2 = m1.removeRange(99, 100);
      expect(m2.mentionIds, ['u_1']);
      expect(m2.ranges.length, 1);
    });
  });

  group('MentionData.removeByCursorPosition', () {
    test('光标 position 落在 (start, end] 区间内 → 移除该 range', () {
      const m0 = MentionData();
      // ranges: [0,5) [5,10)
      final m1 = m0.addMention('u_1', 0, 5).addMention('u_2', 5, 10);
      // position=3 → 落在 (0,5]，移除 u_1 的 range
      final m2 = m1.removeByCursorPosition(3);
      expect(m2.ranges.length, 1);
      expect(m2.ranges.first.userId, 'u_2');
      expect(m2.mentionIds, ['u_2']);
    });

    test('position == start → 不属于 (start, end]，不移除', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      final m2 = m1.removeByCursorPosition(0);
      expect(m2.ranges.length, 1, reason: 'position=start 不在 (start,end] 内');
    });

    test('position == end → 在 (start, end] 内，移除', () {
      const m0 = MentionData();
      final m1 = m0.addMention('u_1', 0, 5);
      final m2 = m1.removeByCursorPosition(5);
      expect(m2.ranges, isEmpty);
      expect(m2.mentionIds, isEmpty);
    });
  });

  group('MentionData.hasAllMention', () {
    test('mentionIds 含 "all" → true', () {
      final m = MentionData(mentionIds: ['all', 'u_1'], ranges: []);
      expect(m.hasAllMention, isTrue);
    });

    test('mentionIds 不含 "all" → false', () {
      final m = MentionData(mentionIds: ['u_1', 'u_2'], ranges: []);
      expect(m.hasAllMention, isFalse);
    });

    test('default constructor → false', () {
      const m = MentionData();
      expect(m.hasAllMention, isFalse);
    });
  });

  group('MentionData json roundtrip', () {
    test('toJson + fromJson 还原到同等内容', () {
      const m0 = MentionData();
      final m1 =
          m0.addMention('u_1', 0, 5).addMention('all', 6, 10);
      final j = m1.toJson();
      final restored = MentionData.fromJson(j);
      expect(restored.mentionIds, m1.mentionIds);
      expect(restored.ranges.length, m1.ranges.length);
      for (var i = 0; i < restored.ranges.length; i++) {
        expect(restored.ranges[i].start, m1.ranges[i].start);
        expect(restored.ranges[i].end, m1.ranges[i].end);
        expect(restored.ranges[i].userId, m1.ranges[i].userId);
      }
    });

    test('fromJson 缺字段 → 空列表兜底（不崩溃）', () {
      final restored = MentionData.fromJson(<String, dynamic>{});
      expect(restored.mentionIds, isEmpty);
      expect(restored.ranges, isEmpty);
    });
  });

  group('MentionRange', () {
    test('toJson 包含 start/end/user_id', () {
      const r = MentionRange(start: 1, end: 9, userId: 'u_1');
      final j = r.toJson();
      expect(j['start'], 1);
      expect(j['end'], 9);
      expect(j['user_id'], 'u_1');
    });

    test('fromJson 字段缺失 → 0/0/"" 兜底', () {
      final r = MentionRange.fromJson(<String, dynamic>{});
      expect(r.start, 0);
      expect(r.end, 0);
      expect(r.userId, '');
    });
  });

  group('MentionState.copyWith', () {
    test('未传字段保留旧值', () {
      const s0 = MentionState(
        candidates: [member],
        groupId: 'g_1',
        showAllMention: true,
        currentUserRole: 3,
        keyword: 'foo',
        isLoading: true,
        userIdToName: {'u_1': 'A'},
        currentUserId: 'me',
      );
      final s1 = s0.copyWith();
      expect(s1.candidates, s0.candidates);
      expect(s1.groupId, s0.groupId);
      expect(s1.showAllMention, s0.showAllMention);
      expect(s1.currentUserRole, s0.currentUserRole);
      expect(s1.keyword, s0.keyword);
      expect(s1.isLoading, s0.isLoading);
      expect(s1.userIdToName, s0.userIdToName);
      expect(s1.currentUserId, s0.currentUserId);
    });

    test('传入字段被覆盖', () {
      const s0 = MentionState();
      final s1 = s0.copyWith(
        groupId: 'g_2',
        keyword: 'bar',
        currentUserRole: 4,
      );
      expect(s1.groupId, 'g_2');
      expect(s1.keyword, 'bar');
      expect(s1.currentUserRole, 4);
      // 其他保持默认
      expect(s1.candidates, isEmpty);
    });
  });

  group('MentionState.isAdmin', () {
    test('role >= 3 (admin/owner/vice) → true', () {
      expect(const MentionState(currentUserRole: 3).isAdmin, isTrue);
      expect(const MentionState(currentUserRole: 4).isAdmin, isTrue);
      expect(const MentionState(currentUserRole: 5).isAdmin, isTrue);
    });

    test('role 1/2 → false', () {
      expect(const MentionState(currentUserRole: 1).isAdmin, isFalse);
      expect(const MentionState(currentUserRole: 2).isAdmin, isFalse);
    });
  });

  group('MentionState.filteredCandidates', () {
    test('currentUserId 为空 + keyword 为空 → 返回全部', () {
      const s = MentionState(candidates: [admin, member, guest]);
      final got = s.filteredCandidates;
      expect(got.length, 3);
    });

    test('currentUserId 设置 → 排除自己（C6 不能 @自己）', () {
      const s = MentionState(
        candidates: [admin, member, guest],
        currentUserId: 'u_member',
      );
      final got = s.filteredCandidates;
      expect(got.map((c) => c.userId).toList(), ['u_admin', 'u_guest']);
    });

    test('keyword 设置 → 大小写不敏感模糊匹配', () {
      const s = MentionState(
        candidates: [admin, member, guest],
        keyword: 'mEm', // 应匹配 displayName=Member
      );
      final got = s.filteredCandidates;
      expect(got.length, 1);
      expect(got.first.userId, 'u_member');
    });

    test('keyword + currentUserId 同时生效：先排除自己再过滤', () {
      const s = MentionState(
        candidates: [admin, member, guest],
        currentUserId: 'u_admin',
        keyword: 'a', // a 同时匹配 Admin/Guest（含 a）
      );
      final got = s.filteredCandidates;
      // 排除自己（admin），剩下 [member, guest]，再用 keyword='a' 过滤
      // → Guest 含 'a'（小写后 "guest" 不含 'a'）；
      //   "member" 不含 'a'。结果应为空。
      expect(got, isEmpty,
          reason: 'admin 自己被排除，member/guest 都不含小写 a');
    });

    test('keyword 不匹配任何候选 → 空列表', () {
      const s = MentionState(
        candidates: [admin, member],
        keyword: 'zzz_nope',
      );
      expect(s.filteredCandidates, isEmpty);
    });
  });

  group('groupRoleBgColor / groupRoleFgColor 色彩矩阵', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    test('owner (4) → bg 用 iosOrange.withAlpha 0.1，fg 用 iosOrange', () {
      final bg = groupRoleBgColor(4, colorScheme);
      final fg = groupRoleFgColor(4, colorScheme);
      // bg 是 iosOrange 透明 0.1 版（同色相，alpha < 1）
      expect(bg.r, AppColors.iosOrange.r);
      expect(bg.g, AppColors.iosOrange.g);
      expect(bg.b, AppColors.iosOrange.b);
      expect(bg.a, lessThan(1.0));
      expect(fg, AppColors.iosOrange);
    });

    test('admin (3) → bg colorScheme.primary.withAlpha 0.1，fg primary', () {
      final bg = groupRoleBgColor(3, colorScheme);
      final fg = groupRoleFgColor(3, colorScheme);
      expect(bg.r, colorScheme.primary.r);
      expect(bg.a, lessThan(1.0));
      expect(fg, colorScheme.primary);
    });

    test('member/guest/unknown → bg 走 surface，fg 走 onSurfaceVariant', () {
      for (final role in [0, 1, 2, 99]) {
        expect(groupRoleBgColor(role, colorScheme), colorScheme.surface,
            reason: 'role=$role 应走默认 surface');
        expect(groupRoleFgColor(role, colorScheme), colorScheme.onSurfaceVariant,
            reason: 'role=$role 应走默认 onSurfaceVariant');
      }
    });
  });

  group('groupRoleLabel (i18n)', () {
    // groupRoleLabel 用全局 t.* 取 i18n；slang 在无 TranslationProvider 时
    // 用默认 locale (zh-CN) 回退，这里测试 zh-CN 文案。
    test('role 4 → 群主', () {
      expect(groupRoleLabel(4), '群主');
    });

    test('role 3 → 管理员', () {
      expect(groupRoleLabel(3), '管理员');
    });

    test('role 2 → 嘉宾', () {
      expect(groupRoleLabel(2), '嘉宾');
    });

    test('role 1 / 0 / unknown → 空字符串', () {
      expect(groupRoleLabel(1), '');
      expect(groupRoleLabel(0), '');
      expect(groupRoleLabel(5), '',
          reason: '副群主(5) 当前没有专属 label，返回空');
      expect(groupRoleLabel(99), '');
    });
  });

  group('MentionCandidate.roleText (i18n delegation)', () {
    test('owner.roleText → "群主"', () {
      expect(owner.roleText, '群主');
    });

    test('admin.roleText → "管理员"', () {
      expect(admin.roleText, '管理员');
    });

    test('member.roleText → ""', () {
      expect(member.roleText, '');
    });
  });
}
