/// MessageTypeNormalizer 单元测试（strict msg_type 版本）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_normalizer.dart';

void main() {
  group('MessageTypeNormalizer.normalize', () {
    test('应该保留标准消息类型', () {
      expect(
        MessageTypeNormalizer.normalize(msgType: 'text', payload: {}),
        equals('text'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'image', payload: {}),
        equals('image'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'quote', payload: {}),
        equals('quote'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'voice', payload: {}),
        equals('voice'),
      );
    });

    test('旧别名 audio 应判定为 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'audio',
        payload: {},
      );
      expect(result, equals('unsupported'));
    });

    test('下划线命名应判定为 unsupported', () {
      expect(
        MessageTypeNormalizer.normalize(msgType: 'visit_card', payload: {}),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'webrtc_audio', payload: {}),
        equals('unsupported'),
      );
    });

    test('应该保留 custom 类型本身', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'foo': 'bar'},
      );
      expect(result, equals('custom'));
    });

    test('应该处理空值与无效值', () {
      expect(
        MessageTypeNormalizer.normalize(msgType: '', payload: {}),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: null, payload: {}),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(msgType: 'invalid_type', payload: {}),
        equals('unsupported'),
      );
    });

    test('应该处理带空格的 msg_type', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: '  text  ',
        payload: {},
      );
      expect(result, equals('text'));
    });

    test('应该处理 null payload', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'text',
        payload: null,
      );
      expect(result, equals('text'));
    });
  });

  group('MessageTypeNormalizer.normalizeBatch', () {
    test('应该批量归一化消息列表', () {
      final messages = [
        {'msg_type': 'audio', 'payload': {}},
        {'msg_type': 'visit_card', 'payload': {}},
        {'msg_type': 'image', 'payload': {}},
        {'msg_type': 'text', 'payload': {}},
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result, hasLength(4));
      expect(result[0]['msg_type'], equals('unsupported'));
      expect(result[1]['msg_type'], equals('unsupported'));
      expect(result[2]['msg_type'], equals('image'));
      expect(result[3]['msg_type'], equals('text'));
    });

    test('应该不修改原始消息列表', () {
      final messages = [
        {'msg_type': 'audio', 'payload': {}},
        {'msg_type': 'image', 'payload': {}},
      ];

      final originalMsgType = messages[0]['msg_type'];
      MessageTypeNormalizer.normalizeBatch(messages);

      expect(messages[0]['msg_type'], equals(originalMsgType));
    });

    test('应该处理包含无效类型的消息列表', () {
      final messages = [
        {'msg_type': 'text', 'payload': {}},
        {'msg_type': 'invalid_type', 'payload': {}},
        {'msg_type': '', 'payload': {}},
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result, hasLength(3));
      expect(result[0]['msg_type'], equals('text'));
      expect(result[1]['msg_type'], equals('unsupported'));
      expect(result[2]['msg_type'], equals('unsupported'));
    });
  });

  group('MessageTypeNormalizer.isValidType', () {
    test('应该识别有效类型', () {
      expect(MessageTypeNormalizer.isValidType('text'), isTrue);
      expect(MessageTypeNormalizer.isValidType('webrtcAudio'), isTrue);
      expect(MessageTypeNormalizer.isValidType('visitCard'), isTrue);
      expect(MessageTypeNormalizer.isValidType('custom'), isTrue);
      expect(MessageTypeNormalizer.isValidType('unsupported'), isTrue);
    });

    test('应该拒绝无效类型', () {
      expect(MessageTypeNormalizer.isValidType('invalid_type'), isFalse);
      expect(MessageTypeNormalizer.isValidType('audio'), isFalse);
      expect(MessageTypeNormalizer.isValidType('visit_card'), isFalse);
      expect(MessageTypeNormalizer.isValidType(''), isFalse);
    });
  });
}
