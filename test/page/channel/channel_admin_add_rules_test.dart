// 频道添加管理员选人规则 — TDD 契约钉死
// RED 阶段：先写测试，实现文件尚不存在

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_admin_add_rules.dart';

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
  // filterContactsForAdmin
  //   — 从联系人列表中剔除已是管理员的人，返回候选列表
  // =========================================================================
  group('filterContactsForAdmin', () {
    final contacts = [
      _contact(peerId: 1001, nickname: 'Alice', account: 'alice'),
      _contact(peerId: 1002, nickname: 'Bob', account: 'bob'),
      _contact(peerId: 1003, nickname: 'Carol', account: 'carol'),
    ];

    test('没有现有管理员时返回全部联系人', () {
      final result = filterContactsForAdmin(contacts, existingAdminIds: []);
      expect(result.length, 3);
    });

    test('已是管理员的联系人被过滤掉', () {
      final result = filterContactsForAdmin(
        contacts,
        existingAdminIds: ['1002'],
      );
      expect(result.length, 2);
      expect(result.any((c) => c['peer_id'] == 1002), isFalse);
    });

    test('多个已有管理员全部过滤', () {
      final result = filterContactsForAdmin(
        contacts,
        existingAdminIds: ['1001', '1003'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1002);
    });

    test('空联系人列表返回空', () {
      final result = filterContactsForAdmin([], existingAdminIds: ['1001']);
      expect(result, isEmpty);
    });

    test('所有人都是管理员时返回空', () {
      final result = filterContactsForAdmin(
        contacts,
        existingAdminIds: ['1001', '1002', '1003'],
      );
      expect(result, isEmpty);
    });

    test('existingAdminIds 包含字符串形式的 ID（int 和 string 互通）', () {
      // 后端返回 peer_id 可能是 int，管理员列表可能是字符串
      final result = filterContactsForAdmin(
        contacts,
        existingAdminIds: ['1001'],
      );
      expect(result.any((c) => c['peer_id'] == 1001), isFalse);
    });
  });

  // =========================================================================
  // searchContactCandidates
  //   — 在候选列表中按关键字过滤（匹配 nickname / remark / account）
  // =========================================================================
  group('searchContactCandidates', () {
    final candidates = [
      _contact(
        peerId: 2001,
        nickname: '张三',
        account: 'zhangsan',
        remark: '好友张三',
      ),
      _contact(peerId: 2002, nickname: 'BobSmith', account: 'bob_s'),
      _contact(peerId: 2003, nickname: '李四', account: 'lisi'),
    ];

    test('空关键字返回全部候选', () {
      final result = searchContactCandidates(candidates, '');
      expect(result.length, 3);
    });

    test('按 nickname 匹配（包含）', () {
      final result = searchContactCandidates(candidates, '张三');
      expect(result.length, 1);
      expect(result.first['peer_id'], 2001);
    });

    test('按 account 匹配（包含）', () {
      final result = searchContactCandidates(candidates, 'bob_s');
      expect(result.length, 1);
      expect(result.first['peer_id'], 2002);
    });

    test('按 remark 匹配（包含）', () {
      final result = searchContactCandidates(candidates, '好友');
      expect(result.length, 1);
      expect(result.first['peer_id'], 2001);
    });

    test('大小写不敏感匹配 account', () {
      final result = searchContactCandidates(candidates, 'BOB');
      expect(result.any((c) => c['peer_id'] == 2002), isTrue);
    });

    test('关键字无匹配返回空', () {
      final result = searchContactCandidates(candidates, 'xyz999');
      expect(result, isEmpty);
    });

    test('关键字匹配多个时全部返回', () {
      final contacts2 = [
        _contact(peerId: 3001, nickname: 'Alice Wonderland'),
        _contact(peerId: 3002, nickname: 'Alice Chen'),
        _contact(peerId: 3003, nickname: 'Bob'),
      ];
      final result = searchContactCandidates(contacts2, 'Alice');
      expect(result.length, 2);
    });
  });

  // =========================================================================
  // validateAdminRole
  //   — 角色值合法性校验（1=editor, 2=admin；0 和 3 不允许由外部直接设置）
  // =========================================================================
  group('validateAdminRole', () {
    test('role=1(editor) 合法', () {
      expect(validateAdminRole(1), isTrue);
    });

    test('role=2(admin) 合法', () {
      expect(validateAdminRole(2), isTrue);
    });

    test('role=0 非法（none/subscriber，不应手动指定）', () {
      expect(validateAdminRole(0), isFalse);
    });

    test('role=3 非法（creator 由系统自动赋予，不允许手动设置）', () {
      expect(validateAdminRole(3), isFalse);
    });

    test('负数非法', () {
      expect(validateAdminRole(-1), isFalse);
    });

    test('超出范围非法', () {
      expect(validateAdminRole(99), isFalse);
    });
  });

  // =========================================================================
  // defaultAdminRole
  //   — 默认分配 editor(1) 角色，遵循最小权限原则
  // =========================================================================
  group('defaultAdminRole', () {
    test('返回 1（editor）', () {
      expect(defaultAdminRole(), 1);
    });

    test('返回值通过 validateAdminRole 校验', () {
      expect(validateAdminRole(defaultAdminRole()), isTrue);
    });
  });
}
