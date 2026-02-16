/// MessageTypeNormalizer 单元测试
///
/// 测试覆盖：
/// 1. custom 类型转换（custom -> custom_type）
/// 2. audio 到 voice 的归一化
/// 3. 空值和无效类型处理
/// 4. 批量消息处理
/// 5. 类型别名转换
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/message_type_constants.dart' show MessageType;

void main() {
  group('MessageTypeNormalizer.normalize', () {
    test('应该保留有效的标准消息类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'text',
        payload: {},
      );
      expect(result, equals('text'));
    });

    test('应该保留 image 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'image',
        payload: {},
      );
      expect(result, equals('image'));
    });

    test('应该保留 video 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'video',
        payload: {},
      );
      expect(result, equals('video'));
    });

    test('应该保留 location 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'location',
        payload: {},
      );
      expect(result, equals('location'));
    });

    test('应该保留 file 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'file',
        payload: {},
      );
      expect(result, equals('file'));
    });

    test('应该保留 quote 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'quote',
        payload: {},
      );
      expect(result, equals('quote'));
    });

    test('应该将 audio 归一化为 voice', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'audio',
        payload: {},
      );
      expect(result, equals('voice'));
    });

    test('应该保留 voice 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'voice',
        payload: {},
      );
      expect(result, equals('voice'));
    });

    test('应该将 custom + custom_type=audio 转换为 voice', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'audio'},
      );
      expect(result, equals('voice'));
    });

    test('应该将 custom + custom_type=voice 保留为 voice', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'voice'},
      );
      expect(result, equals('voice'));
    });

    test('应该将 custom + custom_type=webrtcAudio 保留', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'webrtcAudio'},
      );
      expect(result, equals('webrtcAudio'));
    });

    test('应该将 custom + custom_type=visitCard 保留', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'visitCard'},
      );
      expect(result, equals('visitCard'));
    });

    test('应该处理 custom + custom_type=audio 并归一化为 voice', () {
      // custom_type='audio' 应该被归一化为 'voice'
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'audio'},
      );
      expect(result, equals('voice'));
    });

    test('应该处理空 msg_type 返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: '',
        payload: {},
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理 null msg_type 返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: null,
        payload: {},
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理 custom 但缺少 custom_type 返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {},
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理 custom 但 custom_type 为空字符串返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': ''},
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理无效的 msg_type 返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'invalid_type',
        payload: {},
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理 null payload', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'text',
        payload: null,
      );
      expect(result, equals('text'));
    });

    test('应该处理 custom 类型且 payload 为 null 返回 unsupported', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: null,
      );
      expect(result, equals('unsupported'));
    });

    test('应该处理带空格的 msg_type', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: '  text  ',
        payload: {},
      );
      expect(result, equals('text'));
    });

    test('应该处理带空格的 custom_type', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': '  voice  '},
      );
      expect(result, equals('voice'));
    });

    test('应该处理 imageMulti 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'imageMulti',
        payload: {},
      );
      expect(result, equals('imageMulti'));
    });

    test('应该处理 textStream 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'textStream',
        payload: {},
      );
      expect(result, equals('textStream'));
    });

    test('应该处理 system 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'system',
        payload: {},
      );
      expect(result, equals('system'));
    });

    test('应该处理 webrtcVideo 类型', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'webrtcVideo',
        payload: {},
      );
      expect(result, equals('webrtcVideo'));
    });

    test('应该处理 custom + custom_type=webrtcVideo', () {
      final result = MessageTypeNormalizer.normalize(
        msgType: 'custom',
        payload: {'custom_type': 'webrtcVideo'},
      );
      expect(result, equals('webrtcVideo'));
    });
  });

  group('MessageTypeNormalizer.normalizeBatch', () {
    test('应该批量归一化消息列表', () {
      final messages = [
        {'msg_type': 'custom', 'payload': {'custom_type': 'audio'}},
        {'msg_type': 'audio', 'payload': {}},
        {'msg_type': 'image', 'payload': {}},
        {'msg_type': 'text', 'payload': {}},
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result, hasLength(4));
      expect(result[0]['msg_type'], equals('voice'));
      expect(result[1]['msg_type'], equals('voice'));
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

      // 验证原始数据未被修改
      expect(messages[0]['msg_type'], equals(originalMsgType));
    });

    test('应该处理空消息列表', () {
      final result = MessageTypeNormalizer.normalizeBatch([]);
      expect(result, isEmpty);
    });

    test('应该处理包含无效类型的消息列表', () {
      final messages = [
        {'msg_type': 'text', 'payload': {}},
        {'msg_type': 'invalid_type', 'payload': {}},
        {'msg_type': 'custom', 'payload': {}}, // 缺少 custom_type
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result, hasLength(3));
      expect(result[0]['msg_type'], equals('text'));
      expect(result[1]['msg_type'], equals('unsupported'));
      expect(result[2]['msg_type'], equals('unsupported'));
    });

    test('应该保留 payload 中的其他字段', () {
      final messages = [
        {
          'msg_type': 'custom',
          'payload': {'custom_type': 'audio', 'duration_ms': 15000}
        },
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result[0]['msg_type'], equals('voice'));
      expect(result[0]['payload']['custom_type'], equals('audio'));
      expect(result[0]['payload']['duration_ms'], equals(15000));
    });
  });

  group('MessageTypeNormalizer.isValidType', () {
    test('应该识别所有有效的标准消息类型', () {
      expect(MessageTypeNormalizer.isValidType('text'), isTrue);
      expect(MessageTypeNormalizer.isValidType('image'), isTrue);
      expect(MessageTypeNormalizer.isValidType('imageMulti'), isTrue);
      expect(MessageTypeNormalizer.isValidType('voice'), isTrue);
      expect(MessageTypeNormalizer.isValidType('video'), isTrue);
      expect(MessageTypeNormalizer.isValidType('file'), isTrue);
      expect(MessageTypeNormalizer.isValidType('location'), isTrue);
      expect(MessageTypeNormalizer.isValidType('quote'), isTrue);
    });

    test('应该识别有效的自定义消息类型', () {
      expect(MessageTypeNormalizer.isValidType('webrtcAudio'), isTrue);
      expect(MessageTypeNormalizer.isValidType('webrtcVideo'), isTrue);
      expect(MessageTypeNormalizer.isValidType('visitCard'), isTrue);
    });

    test('应该识别特殊类型', () {
      expect(MessageTypeNormalizer.isValidType('custom'), isTrue);
      expect(MessageTypeNormalizer.isValidType('unsupported'), isTrue);
    });

    test('应该识别兼容旧数据的 audio 类型', () {
      expect(MessageTypeNormalizer.isValidType('audio'), isTrue);
    });

    test('应该拒绝无效的消息类型', () {
      expect(MessageTypeNormalizer.isValidType('invalid_type'), isFalse);
      expect(MessageTypeNormalizer.isValidType(''), isFalse);
      expect(MessageTypeNormalizer.isValidType('random'), isFalse);
    });
  });

  group('MessageTypeNormalizer.getStandardName', () {
    test('应该将 audio 别名转换为 voice', () {
      final result = MessageTypeNormalizer.getStandardName('audio');
      expect(result, equals('voice'));
    });

    test('应该保留标准类型名称', () {
      expect(MessageTypeNormalizer.getStandardName('text'), equals('text'));
      expect(MessageTypeNormalizer.getStandardName('image'), equals('image'));
      expect(MessageTypeNormalizer.getStandardName('voice'), equals('voice'));
      expect(MessageTypeNormalizer.getStandardName('video'), equals('video'));
    });

    test('应该保留未知类型名称', () {
      expect(
        MessageTypeNormalizer.getStandardName('unknown_type'),
        equals('unknown_type'),
      );
    });
  });

  group('MessageTypeNormalizer.needsNormalization', () {
    test('custom 类型需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization('custom'), isTrue);
    });

    test('audio 类型需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization('audio'), isTrue);
    });

    test('voice 类型不需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization('voice'), isFalse);
    });

    test('text 类型不需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization('text'), isFalse);
    });

    test('image 类型不需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization('image'), isFalse);
    });

    test('null 需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization(null), isTrue);
    });

    test('空字符串需要归一化', () {
      expect(MessageTypeNormalizer.needsNormalization(''), isTrue);
    });
  });

  group('MessageTypeNormalizer.getNormalizedType', () {
    test('应该将 custom + custom_type=audio 转换为 voice', () {
      final result = MessageTypeNormalizer.getNormalizedType(
        'custom',
        'audio',
      );
      expect(result, equals('voice'));
    });

    test('应该将 audio 转换为 voice', () {
      final result = MessageTypeNormalizer.getNormalizedType('audio', null);
      expect(result, equals('voice'));
    });

    test('应该保留 voice', () {
      final result = MessageTypeNormalizer.getNormalizedType('voice', null);
      expect(result, equals('voice'));
    });

    test('应该保留 text', () {
      final result = MessageTypeNormalizer.getNormalizedType('text', null);
      expect(result, equals('text'));
    });

    test('应该处理 null custom_type', () {
      final result = MessageTypeNormalizer.getNormalizedType('custom', null);
      expect(result, equals('custom'));
    });

    test('应该处理空字符串返回 unsupported', () {
      final result = MessageTypeNormalizer.getNormalizedType('', null);
      expect(result, equals('unsupported'));
    });

    test('应该处理 custom 但 custom_type=webrtcAudio', () {
      final result = MessageTypeNormalizer.getNormalizedType(
        'custom',
        'webrtcAudio',
      );
      expect(result, equals('webrtcAudio'));
    });

    test('应该处理 custom 但 custom_type=visitCard', () {
      final result = MessageTypeNormalizer.getNormalizedType(
        'custom',
        'visitCard',
      );
      expect(result, equals('visitCard'));
    });
  });

  group('MessageTypeNormalizer 与 MessageType 常量集成测试', () {
    test('MessageType.aliases 应该包含 audio->voice 映射', () {
      expect(MessageType.aliases['audio'], equals('voice'));
    });

    test('MessageType.allTypes 应该包含所有标准类型', () {
      expect(MessageType.allTypes, contains('text'));
      expect(MessageType.allTypes, contains('image'));
      expect(MessageType.allTypes, contains('voice'));
      expect(MessageType.allTypes, contains('video'));
      expect(MessageType.allTypes, contains('file'));
      expect(MessageType.allTypes, contains('location'));
      expect(MessageType.allTypes, contains('quote'));
      expect(MessageType.allTypes, contains('audio')); // 兼容旧数据
    });

    test('MessageType.getStandardName 应该与 MessageTypeNormalizer 一致', () {
      expect(MessageType.getStandardName('audio'), equals('voice'));
      expect(
        MessageTypeNormalizer.getStandardName('audio'),
        equals(MessageType.getStandardName('audio')),
      );
    });

    test('MessageType.isValidType 应该与 MessageTypeNormalizer 一致', () {
      // 标准类型
      expect(MessageType.isValidType('text'), isTrue);
      expect(MessageTypeNormalizer.isValidType('text'), isTrue);

      // 兼容旧数据
      expect(MessageType.isValidType('audio'), isTrue);
      expect(MessageTypeNormalizer.isValidType('audio'), isTrue);

      // 特殊类型
      expect(MessageType.isValidType('custom'), isTrue);
      expect(MessageTypeNormalizer.isValidType('custom'), isTrue);

      expect(MessageType.isValidType('unsupported'), isTrue);
      expect(MessageTypeNormalizer.isValidType('unsupported'), isTrue);

      // 无效类型
      expect(MessageType.isValidType('invalid_type'), isFalse);
      expect(MessageTypeNormalizer.isValidType('invalid_type'), isFalse);
    });
  });
}
