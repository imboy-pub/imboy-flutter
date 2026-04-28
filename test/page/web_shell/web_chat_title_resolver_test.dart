/// Phase 2.1.d RED — Web Shell ChatPanel header 标题决策纯函数
///
/// 优先级（按 chatType 选用对应 source）：
/// - C2C: contactTitle (remark > nickname > account 已在 ContactModel.title 内合并) → fallback peerId
/// - C2G: groupTitle → fallback peerId
/// - 其他 chatType / source 为 null/空白 → fallback peerId
///
/// 设计决策：
/// - 不在本函数内做异步 repo 查询（保持纯函数 + 零外部依赖）
/// - source 为 null/空字符串/全空白 视为缺失 → fallback peerId
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_chat_title_resolver.dart';

void main() {
  group('pickChatTitle — C2C', () {
    test('contactTitle 非空 → 返回 contactTitle', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-001',
        contactTitle: '张三',
      );
      expect(t, '张三');
    });

    test('contactTitle null → fallback peerId', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-002',
      );
      expect(t, 'u-002');
    });

    test('contactTitle 空字符串 → fallback peerId', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-003',
        contactTitle: '',
      );
      expect(t, 'u-003');
    });

    test('contactTitle 全空白 → fallback peerId', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-004',
        contactTitle: '   ',
      );
      expect(t, 'u-004');
    });

    test('C2C 时即使传入 groupTitle 也忽略', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-005',
        groupTitle: '不该被使用的群名',
      );
      expect(t, 'u-005');
    });
  });

  group('pickChatTitle — C2G', () {
    test('groupTitle 非空 → 返回 groupTitle', () {
      final t = pickChatTitle(
        chatType: 'C2G',
        peerId: 'g-001',
        groupTitle: '产品研发群',
      );
      expect(t, '产品研发群');
    });

    test('groupTitle null → fallback peerId', () {
      final t = pickChatTitle(
        chatType: 'C2G',
        peerId: 'g-002',
      );
      expect(t, 'g-002');
    });

    test('groupTitle 空字符串 → fallback peerId', () {
      final t = pickChatTitle(
        chatType: 'C2G',
        peerId: 'g-003',
        groupTitle: '',
      );
      expect(t, 'g-003');
    });

    test('C2G 时即使传入 contactTitle 也忽略', () {
      final t = pickChatTitle(
        chatType: 'C2G',
        peerId: 'g-004',
        contactTitle: '不该被使用的联系人',
      );
      expect(t, 'g-004');
    });
  });

  group('pickChatTitle — 未知 chatType', () {
    test('chatType=C2S → fallback peerId（暂不支持）', () {
      final t = pickChatTitle(
        chatType: 'C2S',
        peerId: 's-001',
        contactTitle: '客服',
      );
      expect(t, 's-001');
    });

    test('chatType 空字符串 → fallback peerId', () {
      final t = pickChatTitle(
        chatType: '',
        peerId: 'x-001',
        contactTitle: 't',
        groupTitle: 'g',
      );
      expect(t, 'x-001');
    });
  });

  group('pickChatTitle — 边界', () {
    test('peerId 也为空 → 返回空字符串（让调用方决定 placeholder）', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: '',
      );
      expect(t, '');
    });

    test('contactTitle 含前后空白 → trim 后返回（保留中间空格）', () {
      final t = pickChatTitle(
        chatType: 'C2C',
        peerId: 'u-006',
        contactTitle: '  John Doe  ',
      );
      expect(t, '  John Doe  ',
          reason: '保留原始字符串：trim 仅用于"是否为空"判断，不修改返回值');
    });
  });
}
