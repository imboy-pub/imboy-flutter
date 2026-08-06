// GroupId 值对象测试（纯 domain）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/group_collab/domain/value/group_id.dart';

void main() {
  group('GroupId', () {
    test('parse 合法 TSID 字符串', () {
      expect(GroupId.parse('100').value, '100');
    });

    test('parse 空串抛 FormatException', () {
      expect(() => GroupId.parse(''), throwsFormatException);
    });

    test('相同底层值相等', () {
      expect(GroupId.parse('100'), GroupId.parse('100'));
    });
  });
}
