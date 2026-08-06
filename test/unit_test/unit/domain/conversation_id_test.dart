// ConversationId 值对象测试（纯 domain）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/value/conversation_id.dart';

void main() {
  group('ConversationId', () {
    test('parse 合法 conv_key (c2c)', () {
      final id = ConversationId.parse('c2c:2:9');
      expect(id.value, 'c2c:2:9');
    });

    test('parse 合法 conv_key (c2g)', () {
      expect(ConversationId.parse('c2g:100').value, 'c2g:100');
    });

    test('parse 空串抛 FormatException', () {
      expect(() => ConversationId.parse(''), throwsFormatException);
    });

    test('相同底层值相等', () {
      expect(ConversationId.parse('c2c:2:9'), ConversationId.parse('c2c:2:9'));
    });
  });
}
