// MessageId 值对象测试（纯 domain，零 flutter 依赖逻辑）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/value/message_id.dart';

void main() {
  group('MessageId', () {
    test('parse 合法 Xid 字符串', () {
      final id = MessageId.parse('9m4e2mr0ui3e8a215n4g');
      expect(id.value, '9m4e2mr0ui3e8a215n4g');
    });

    test('parse 空串抛 FormatException', () {
      expect(() => MessageId.parse(''), throwsFormatException);
    });

    test('相同底层值相等', () {
      expect(MessageId.parse('m1'), MessageId.parse('m1'));
    });

    test('不同底层值不等', () {
      expect(MessageId.parse('m1') == MessageId.parse('m2'), isFalse);
    });
  });
}
