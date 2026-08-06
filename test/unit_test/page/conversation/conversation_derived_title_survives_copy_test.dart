import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 会话列表「无名群显示未命名」的真根因回归测试。
///
/// 真机实证（2026-08-06 18:03，华为 MRD_AL00 / 生产）：
///   computeTitle 104603643803863040, 1 members found in local db
///   computeTitle local result: IMBoy          ← 成员昵称回落**成功**
///   104603643803863040 computedTitle          ← 群自身无名，返回空串
/// 也就是说 `obj.computeTitle` 确实被赋成了「IMBoy」；界面上仍是「未命名」，
/// 断点在**之后**：`recalculateAllReminds` 触发 500ms 防抖回写未读数，
/// `setConversationRemind` 用 `copyWith(unreadNum:)` 重建模型放回 state，
/// 而 `copyWith` 走 `fromJson`，认不出 `computeTitle` 这个只活在内存里的派生名。
///
/// 群列表页不受影响：它每次 build 都重新 `service.computeTitle()`，
/// 从不 copyWith，所以同一批群在群列表有名字、在会话列表没有。
ConversationModel _groupConv({String title = '', String computeTitle = ''}) {
  final m = ConversationModel(
    id: 1,
    peerId: 104603643803863040,
    avatar: '',
    title: title,
    subtitle: '',
    type: 'C2G',
    msgType: 'text',
    unreadNum: 3,
    isShow: 1,
  );
  m.computeTitle = computeTitle;
  return m;
}

void main() {
  group('无名群回落到成员昵称', () {
    test('成员行按 别名→好友备注→昵称→账号 取名', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': '', 'nickname': 'IMBoy', 'account': 'imboy01'},
      ]);
      expect(names, ['IMBoy']);
    });

    test('拼好的成员名经 computeTitle 进入展示名', () {
      final conv = _groupConv(computeTitle: 'IMBoy');
      expect(conv.resolvedTitle, 'IMBoy');
      expect(conv.displayTitle, 'IMBoy');
    });

    test('确实取不到名字才回落占位，且不泄漏 TSID', () {
      final shown = _groupConv().displayTitle;
      expect(shown, isNotEmpty);
      expect(shown.contains('104603643803863040'), isFalse);
    });
  });

  group('copyWith 必须带上派生名（本次根因）', () {
    test('未读数回写不得把成员昵称抹成「未命名」', () {
      final conv = _groupConv(computeTitle: 'IMBoy');
      final afterUnreadWrite = conv.copyWith(unreadNum: 0, mentionUnread: 0);

      expect(
        afterUnreadWrite.computeTitle,
        'IMBoy',
        reason: 'copyWith 走 fromJson，不显式搬运就会丢掉只在内存里的 computeTitle',
      );
      expect(afterUnreadWrite.displayTitle, 'IMBoy');
    });

    test('存量脏值 title==peerId 时，派生名仍要能顶上来', () {
      final conv = _groupConv(
        title: '104603643803863040',
        computeTitle: 'IMBoy',
      );
      expect(conv.copyWith(unreadNum: 1).displayTitle, 'IMBoy');
    });

    test('派生名依然不落库：copyWith 不把它写进 title', () {
      final copied = _groupConv(computeTitle: 'IMBoy').copyWith(unreadNum: 0);
      expect(copied.title, '', reason: '成员改名后派生名要能跟着变，固化进 title 就永远更新不了');
    });
  });
}
