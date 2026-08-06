import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/identity/domain/user.dart';
import 'package:imboy/modules/identity/domain/value/user_id.dart';

void main() {
  group('User 资料校验（镜像后端 user_agg）', () {
    test('性别 1/2/3 合法，其余非法', () {
      expect(User.isValidGender(1), isTrue);
      expect(User.isValidGender(2), isTrue);
      expect(User.isValidGender(3), isTrue);
      expect(User.isValidGender(0), isFalse);
      expect(User.isValidGender(4), isFalse);
    });

    test('允许搜索 1/2 合法，其余非法', () {
      expect(User.isValidAllowSearch(1), isTrue);
      expect(User.isValidAllowSearch(2), isTrue);
      expect(User.isValidAllowSearch(3), isFalse);
    });

    test('邮箱格式校验对齐后端正则', () {
      expect(User.isValidEmail('a@b.com'), isTrue);
      expect(User.isValidEmail('x_y-z@sub.example.co'), isTrue);
      expect(User.isValidEmail('not-an-email'), isFalse);
      expect(User.isValidEmail('a@b'), isFalse);
      expect(User.isValidEmail(''), isFalse);
    });
  });

  group('User 不可变更新', () {
    test('copyWith 返回新实例且原实例不变', () {
      final u = User(id: UserId('100'), nickname: '旧', gender: 3);
      final u2 = u.copyWith(nickname: '新', gender: 1);
      expect(u2.nickname, '新');
      expect(u2.gender, 1);
      expect(u.nickname, '旧'); // 原实例不变
      expect(u.gender, 3);
      expect(u2.id, u.id); // id 透传
    });

    test('默认性别为保密(3)', () {
      final u = User(id: UserId('1'));
      expect(u.gender, User.genderSecret);
    });
  });
}
