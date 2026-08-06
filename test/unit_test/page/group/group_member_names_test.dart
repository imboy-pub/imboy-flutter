import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';

/// 回归：无名群取成员昵称当群名。
///
/// 原实现的 SQL 以 `contact` 为驱动表 LEFT JOIN `group_member`，只能取到
/// **同时是我好友**的群成员，非好友成员一个都出不来。
///
/// SQL 方向本身要靠真机/集成验证，这里锁住取名优先级：
/// 群内别名 → 好友备注 → 昵称 → 账号，且缺名的行不能产出空串占位。
/// 其中「非好友成员（remark 为 null）仍能取到昵称」那条，对应的正是
/// 原 SQL 取不到的那类行。
void main() {
  group('GroupListService.pickMemberNames 取名优先级', () {
    test('群内别名优先于好友备注、昵称、账号', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '小队长', 'remark': '老王', 'nickname': 'wang', 'account': 'w001'},
      ]);
      expect(names, ['小队长']);
    });

    test('无别名时用好友备注', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': '老王', 'nickname': 'wang', 'account': 'w001'},
      ]);
      expect(names, ['老王']);
    });

    test('非好友成员（remark 为 null）仍能取到昵称，不被丢掉', () {
      // 这条正是原 SQL 取不到的那类成员：不在 contact 表里
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': null, 'nickname': '张三', 'account': 'z001'},
      ]);
      expect(names, ['张三']);
    });

    test('只剩账号时用账号', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '  ', 'remark': null, 'nickname': '', 'account': 'z001'},
      ]);
      expect(names, ['z001']);
    });

    test('整行全空的成员被跳过，不产出空串占位', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': null, 'nickname': '', 'account': ''},
        {'alias': '', 'remark': null, 'nickname': '张三', 'account': ''},
      ]);
      expect(names, ['张三']);
    });

    test('多成员按顺序返回，供调用方以「、」拼接', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': null, 'nickname': '张三', 'account': ''},
        {'alias': '', 'remark': '老王', 'nickname': 'wang', 'account': ''},
        {'alias': '小李', 'remark': null, 'nickname': 'li', 'account': ''},
      ]);
      expect(names.join('、'), '张三、老王、小李');
    });

    test('空输入返回空列表', () {
      expect(GroupListService.pickMemberNames([]), isEmpty);
    });
  });
}
