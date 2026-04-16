// 频道邀请规则 — TDD 契约钉死
// RED 阶段：先写测试，实现文件尚不存在

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_invitation_rules.dart';

// ---------------------------------------------------------------------------
// 测试用辅助数据构造器（纯 Map，不依赖 ContactModel 避免 sqflite→win32 链）
// ---------------------------------------------------------------------------
Map<String, dynamic> _contact({
  required int peerId,
  required String nickname,
  String account = '',
  String remark = '',
}) =>
    {
      'peer_id': peerId,
      'nickname': nickname,
      'account': account,
      'remark': remark,
    };

void main() {
  // =========================================================================
  // filterContactsForInvitation
  //   — 从联系人列表中剔除已有待处理邀请的人，返回可被邀请的候选列表
  // =========================================================================
  group('filterContactsForInvitation', () {
    final contacts = [
      _contact(peerId: 1001, nickname: 'Alice', account: 'alice'),
      _contact(peerId: 1002, nickname: 'Bob', account: 'bob'),
      _contact(peerId: 1003, nickname: 'Carol', account: 'carol'),
    ];

    test('没有待处理邀请时返回全部联系人', () {
      final result = filterContactsForInvitation(
        contacts,
        pendingInviteeIds: [],
      );
      expect(result.length, 3);
    });

    test('已有待处理邀请的联系人被过滤掉', () {
      final result = filterContactsForInvitation(
        contacts,
        pendingInviteeIds: ['1002'],
      );
      expect(result.length, 2);
      expect(result.any((c) => c['peer_id'] == 1002), isFalse);
    });

    test('多个待处理邀请全部过滤', () {
      final result = filterContactsForInvitation(
        contacts,
        pendingInviteeIds: ['1001', '1003'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1002);
    });

    test('空联系人列表返回空', () {
      final result = filterContactsForInvitation(
        [],
        pendingInviteeIds: ['1001'],
      );
      expect(result, isEmpty);
    });

    test('所有人都有待处理邀请时返回空', () {
      final result = filterContactsForInvitation(
        contacts,
        pendingInviteeIds: ['1001', '1002', '1003'],
      );
      expect(result, isEmpty);
    });

    test('pendingInviteeIds 包含字符串形式的 ID（int 和 string 互通）', () {
      final result = filterContactsForInvitation(
        contacts,
        pendingInviteeIds: ['1001'],
      );
      expect(result.any((c) => c['peer_id'] == 1001), isFalse);
    });
  });

  // =========================================================================
  // canSendChannelInvitation
  //   — 只有私有频道（private）才需要邀请流程；公开/付费频道无需邀请
  // =========================================================================
  group('canSendChannelInvitation', () {
    test('private 频道可以发送邀请', () {
      expect(canSendChannelInvitation('private'), isTrue);
    });

    test('public 频道不需要邀请（任何人可订阅）', () {
      expect(canSendChannelInvitation('public'), isFalse);
    });

    test('paid 付费频道不走邀请流程', () {
      expect(canSendChannelInvitation('paid'), isFalse);
    });

    test('空字符串或未知类型返回 false（安全默认）', () {
      expect(canSendChannelInvitation(''), isFalse);
      expect(canSendChannelInvitation('unknown'), isFalse);
    });
  });

  // =========================================================================
  // extractPendingInviteeIds
  //   — 从已发邀请列表中提取待处理（status==0）的被邀请者 UID
  // =========================================================================
  group('extractPendingInviteeIds', () {
    test('只提取 status=0 的待处理邀请', () {
      final sentInvitations = [
        {'invitee_uid': '1001', 'status': 0},
        {'invitee_uid': '1002', 'status': 1}, // 已接受
        {'invitee_uid': '1003', 'status': 2}, // 已拒绝
        {'invitee_uid': '1004', 'status': 0},
      ];
      final result = extractPendingInviteeIds(sentInvitations);
      expect(result, containsAll(['1001', '1004']));
      expect(result.length, 2);
    });

    test('空列表返回空集合', () {
      expect(extractPendingInviteeIds([]), isEmpty);
    });

    test('全部已处理时返回空集合', () {
      final sentInvitations = [
        {'invitee_uid': '1001', 'status': 1},
        {'invitee_uid': '1002', 'status': 3},
      ];
      expect(extractPendingInviteeIds(sentInvitations), isEmpty);
    });

    test('invitee_uid 为空或 null 的记录跳过', () {
      final sentInvitations = [
        {'invitee_uid': '', 'status': 0},
        {'invitee_uid': null, 'status': 0},
        {'invitee_uid': '1005', 'status': 0},
      ];
      final result = extractPendingInviteeIds(sentInvitations);
      expect(result, ['1005']);
    });
  });
}
