// UserId 值对象测试（纯 domain）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/identity/domain/value/user_id.dart';

void main() {
  group('UserId', () {
    test('parse 合法 TSID 字符串', () {
      expect(UserId.parse('650069').value, '650069');
    });

    test('parse 空串抛 FormatException', () {
      expect(() => UserId.parse(''), throwsFormatException);
    });

    test('相同底层值相等', () {
      expect(UserId.parse('650069'), UserId.parse('650069'));
    });

    test('不同底层值不等', () {
      expect(UserId.parse('1') == UserId.parse('2'), isFalse);
    });
  });
}
