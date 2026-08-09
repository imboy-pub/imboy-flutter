/// MessageTypeNormalizer 单元测试（strict msg_type 版本）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_normalizer.dart';

void main() {
  group('MessageTypeNormalizer.normalize', () {
    test('应该保留标准消息类型', () {
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'text',
          payload: <String, dynamic>{},
        ),
        equals('text'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'image',
          payload: <String, dynamic>{},
        ),
        equals('image'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'quote',
          payload: <String, dynamic>{},
        ),
        equals('quote'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'voice',
          payload: <String, dynamic>{},
        ),
        equals('voice'),
      );
      // 业务消息类型（回归：redPacket 曾被漏出 allTypes，
      // 归一化成 unsupported → 读回渲染成「不支持的消息类型」）
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'redPacket',
          payload: <String, dynamic>{},
        ),
        equals('redPacket'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'transfer',
          payload: <String, dynamic>{},
        ),
        equals('transfer'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'groupSchedule',
          payload: <String, dynamic>{},
        ),
        equals('groupSchedule'),
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
        MessageTypeNormalizer.normalize(
          msgType: 'visit_card',
          payload: <String, dynamic>{},
        ),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'webrtc_audio',
          payload: <String, dynamic>{},
        ),
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
        MessageTypeNormalizer.normalize(
          msgType: '',
          payload: <String, dynamic>{},
        ),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: null,
          payload: <String, dynamic>{},
        ),
        equals('unsupported'),
      );
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'invalid_type',
          payload: <String, dynamic>{},
        ),
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
        {'msg_type': 'audio', 'payload': <String, dynamic>{}},
        {'msg_type': 'visit_card', 'payload': <String, dynamic>{}},
        {'msg_type': 'image', 'payload': <String, dynamic>{}},
        {'msg_type': 'text', 'payload': <String, dynamic>{}},
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
        {'msg_type': 'audio', 'payload': <String, dynamic>{}},
        {'msg_type': 'image', 'payload': <String, dynamic>{}},
      ];

      final originalMsgType = messages[0]['msg_type'];
      MessageTypeNormalizer.normalizeBatch(messages);

      expect(messages[0]['msg_type'], equals(originalMsgType));
    });

    test('应该处理包含无效类型的消息列表', () {
      final messages = [
        {'msg_type': 'text', 'payload': <String, dynamic>{}},
        {'msg_type': 'invalid_type', 'payload': <String, dynamic>{}},
        {'msg_type': '', 'payload': <String, dynamic>{}},
      ];

      final result = MessageTypeNormalizer.normalizeBatch(messages);

      expect(result, hasLength(3));
      expect(result[0]['msg_type'], equals('text'));
      expect(result[1]['msg_type'], equals('unsupported'));
      expect(result[2]['msg_type'], equals('unsupported'));
    });
  });

  group('MessageTypeNormalizer.renderType', () {
    test('msg_type 有效时优先用原值（修复脏 effective_msg_type 缓存）', () {
      // 旧版本曾把 transfer/redPacket 归一化成 unsupported 并随 WS 回显持久化，
      // 渲染层若优先读 effective_msg_type 会挡住本应正常渲染的类型
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: 'transfer',
        ),
        equals('transfer'),
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: 'redPacket',
        ),
        equals('redPacket'),
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: 'groupSchedule',
        ),
        equals('groupSchedule'),
      );
    });

    test('msg_type 无效时回退 effective_msg_type（脏 unsupported 除外）', () {
      // unsupported 是归一化器的脏值不是真值：raw 无效时若 effective 也是
      // unsupported，说明历史数据已被归一化成 unsupported，无有效类型可渲染
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: 'invalid_type',
        ),
        equals(''),
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: '',
        ),
        equals(''),
      );
    });

    test('raw 为脏 unsupported 时 effective 有效值救回（修复核心场景）', () {
      // 旧版本把 transfer/redPacket 归一化成 unsupported 持久化进 msg_type，
      // 渲染层 raw 恒"有效"（_isValidType('unsupported')=true）挡住 effective
      // ——修复前这类消息永远渲染成「不支持的消息类型」
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'redPacket',
          rawMsgType: 'unsupported',
        ),
        equals('redPacket'),
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'transfer',
          rawMsgType: 'unsupported',
        ),
        equals('transfer'),
      );
    });

    test('raw 与 effective 都是 unsupported（双脏）不可恢复返回空串', () {
      // 旧版本 normalize 后持久化的 msg_type 与 effective_msg_type 同源，
      // 双脏数据没有真值可救，渲染层 resolve('') 会走 unsupported builder
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'unsupported',
          rawMsgType: 'unsupported',
        ),
        equals(''),
      );
    });

    test('常规消息 msg_type 与 effective_msg_type 一致时返回原值', () {
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: 'text',
          rawMsgType: 'text',
        ),
        equals('text'),
      );
    });

    test('两者都为空返回空串', () {
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: null,
        ),
        equals(''),
      );
    });
  });

  group('MessageTypeNormalizer.isValidType', () {
    test('应该识别有效类型', () {
      expect(MessageTypeNormalizer.isValidType('text'), isTrue);
      expect(MessageTypeNormalizer.isValidType('webrtcAudio'), isTrue);
      expect(MessageTypeNormalizer.isValidType('visitCard'), isTrue);
      expect(MessageTypeNormalizer.isValidType('redPacket'), isTrue);
      expect(MessageTypeNormalizer.isValidType('transfer'), isTrue);
      expect(MessageTypeNormalizer.isValidType('groupSchedule'), isTrue);
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
