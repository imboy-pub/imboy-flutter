/// UserTagRepo.buildUpdateData 的守卫契约。
///
/// 这里钉住两个真实发生过的隐蔽 bug：
/// 1. 增删成员（不传 name）把标签名写成字面量 "null" —— 真机上表现为
///    标签列表显示 `null (1)`，且因列表优先读内存、重启后才显形。
/// 2. 成员全部移除时 refererTime=0 被 `>0` 守卫吞掉，计数停在旧值。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';

void main() {
  group('UserTagRepo.buildUpdateData', () {
    test('不传 name 时不得写入 name 列（防止写成字面量 "null"）', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.refererTime: 1,
      });
      expect(data.containsKey(UserTagRepo.name), isFalse);
      expect(data[UserTagRepo.name], isNot('null'));
    });

    test('显式传 null 同样不得写入 name 列', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.name: null,
      });
      expect(data.containsKey(UserTagRepo.name), isFalse);
    });

    test('传了有效 name 时正常写入（重命名路径）', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.name: 'qa0804',
      });
      expect(data[UserTagRepo.name], 'qa0804');
    });

    test('refererTime 传 0 必须写入 —— 成员被全部移除的合法场景', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.refererTime: 0,
      });
      expect(data.containsKey(UserTagRepo.refererTime), isTrue);
      expect(data[UserTagRepo.refererTime], 0);
    });

    test('不传 refererTime 时跳过（重命名不应动计数）', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.name: 'qa0804',
      });
      expect(data.containsKey(UserTagRepo.refererTime), isFalse);
    });

    test('subtitle 空串要写入 —— 清空成员后副标题应随之清空', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.subtitle: '',
      });
      expect(data.containsKey(UserTagRepo.subtitle), isTrue);
      expect(data[UserTagRepo.subtitle], '');
    });

    test('增删成员的完整入参：写 refererTime + subtitle，不碰 name', () {
      final data = UserTagRepo.buildUpdateData({
        UserTagRepo.tagId: 123,
        UserTagRepo.refererTime: 2,
        UserTagRepo.subtitle: 'IMBoy, leeyi',
      });
      expect(data[UserTagRepo.refererTime], 2);
      expect(data[UserTagRepo.subtitle], 'IMBoy, leeyi');
      expect(data.containsKey(UserTagRepo.name), isFalse);
    });
  });
}
