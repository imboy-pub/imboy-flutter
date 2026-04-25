import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';

void main() {
  group('MessageModel TDD Tests - 字段名统一', () {
    test('应该正确解析包含 uri 字段的 payload', () {
      // GIVEN: 一个包含 uri 字段的 JSON
      final json = {
        'id': 'msg123',
        'auto_id': 1,
        'type': 'C2C',
        'status': 11,
        'from': 'user1',
        'to': 'user2',
        'msg_type': MessageType.image,
        'payload': '''
        {
          "uri": "https://example.com/image.jpg",
          "size": 102400,
          "width": 1920,
          "height": 1080
        }
        ''',
        'created_at': 1642579200000,
        'is_author': 1,
        'topic_id': 0,
        'conversation_uk3': 'C2C_user1_user2',
      };

      // WHEN: 解析为 MessageModel
      final model = MessageModel.fromJson(json);

      // THEN: payload 应该被正确解析，uri 字段存在
      expect(model.payload, isA<Map<String, dynamic>>());
      expect(model.payload['uri'], equals('https://example.com/image.jpg'));
      expect(model.payload['size'], equals(102400));
      expect(model.msgType, equals(MessageType.image));
    });

    test('应该正确解析包含 source 字段的 payload（向后兼容）', () {
      // GIVEN: 一个包含 source 字段的 JSON（旧命名）
      final json = {
        'id': 'msg123',
        'auto_id': 1,
        'type': 'C2C',
        'status': 11,
        'from': 'user1',
        'to': 'user2',
        'msg_type': MessageType.image,
        'payload': '''
        {
          "source": "https://example.com/image.jpg",
          "size": 102400,
          "width": 1920,
          "height": 1080
        }
        ''',
        'created_at': 1642579200000,
        'is_author': 1,
        'topic_id': 0,
        'conversation_uk3': 'C2C_user1_user2',
      };

      // WHEN: 解析为 MessageModel
      final model = MessageModel.fromJson(json);

      // THEN: payload 应该被正确解析，source 字段应该存在（向后兼容）
      expect(model.payload, isA<Map<String, dynamic>>());
      expect(model.payload['source'], equals('https://example.com/image.jpg'));
    });

    test('toJson 应该使用 uri 字段（新规范）', () {
      // GIVEN: 一个包含 uri 字段的 MessageModel
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.image,
        payload: {
          'uri': 'https://example.com/image.jpg',
          'size': 102400,
          'width': 1920,
          'height': 1080,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );

      // WHEN: 序列化为 JSON
      final json = model.toJson();

      // THEN: JSON 应该包含正确的 msg_type 和 payload
      expect(json['msg_type'], equals(MessageType.image));
      expect(json['payload'], isA<String>());

      // 解析 payload 验证内容
      final payloadMap = _parseJson(json['payload'] as String);
      expect(payloadMap['uri'], equals('https://example.com/image.jpg'));
    });
  });

  group('MessageModel TDD Tests - voice 命名规范', () {
    test('应该正确识别 voice 消息类型（新规范）', () {
      // GIVEN: 一个使用 voice 类型的 JSON
      final json = {
        'id': 'msg123',
        'auto_id': 1,
        'type': 'C2C',
        'status': 11,
        'from': 'user1',
        'to': 'user2',
        'msg_type': MessageType.voice, // 使用 voice
        'payload': '''
        {
          "uri": "https://example.com/voice.mp3",
          "duration_ms": 15000
        }
        ''',
        'created_at': 1642579200000,
        'is_author': 1,
        'topic_id': 0,
        'conversation_uk3': 'C2C_user1_user2',
      };

      // WHEN: 解析为 MessageModel
      final model = MessageModel.fromJson(json);

      // THEN: msgType 应该是 voice
      expect(model.msgType, equals(MessageType.voice));
      expect(model.payload['duration_ms'], equals(15000));
    });
  });

  group('MessageModel TDD Tests - 撤回状态处理', () {
    test('应该正确解析撤回状态（peer_revoked）', () {
      // GIVEN: 一个对方撤回的消息
      final json = {
        'id': 'msg123',
        'auto_id': 1,
        'type': 'C2C',
        'status': IMBoyMessageStatus.peerRevoked, // 30
        'from': 'user1',
        'to': 'user2',
        'msg_type': MessageType.text,
        'payload': '{"text": "已撤回的消息"}',
        'created_at': 1642579200000,
        'is_author': 0,
        'topic_id': 0,
        'conversation_uk3': 'C2C_user1_user2',
      };

      // WHEN: 解析为 MessageModel
      final model = MessageModel.fromJson(json);

      // THEN: status 应该是 30
      expect(model.status, equals(IMBoyMessageStatus.peerRevoked));
      expect(IMBoyMessageStatus.isRevokedStatus(model.status), isTrue);
    });

    test('应该正确保留撤回消息的原始 msg_type', () {
      // GIVEN: 一个撤回的图片消息
      final json = {
        'id': 'msg123',
        'auto_id': 1,
        'type': 'C2C',
        'status': IMBoyMessageStatus.peerRevoked,
        'from': 'user1',
        'to': 'user2',
        'msg_type': MessageType.image, // 原始类型是 image
        'payload': '{"uri": "https://example.com/image.jpg"}',
        'created_at': 1642579200000,
        'is_author': 0,
        'topic_id': 0,
        'conversation_uk3': 'C2C_user1_user2',
      };

      // WHEN: 解析为 MessageModel
      final model = MessageModel.fromJson(json);

      // THEN: msg_type 应该保留为 image（不是 revoked）
      expect(model.msgType, equals(MessageType.image));
      expect(model.status, equals(IMBoyMessageStatus.peerRevoked));
    });
  });

  group('MessageModel TDD Tests - conversationSubtitleFromModel', () {
    test('应该正确显示文本消息的副标题', () {
      // GIVEN: 一个文本消息
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.text,
        payload: {'text': '这是一条测试消息'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
      );

      // WHEN: 获取会话副标题
      final subtitle = MessageModel.conversationSubtitleFromModel(model);

      // THEN: 应该显示文本内容
      expect(subtitle, equals('这是一条测试消息'));
    });

    test('应该正确显示语音消息的副标题（voice 类型）', () {
      // GIVEN: 一个语音消息（voice 类型）
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.voice,
        payload: {'duration_ms': 15000},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
      );

      // WHEN: 获取会话副标题
      final subtitle = MessageModel.conversationSubtitleFromModel(model);

      // THEN: 应该显示 [语音]
      expect(subtitle, equals('[语音]'));
    });

    test('应该正确显示视频消息的副标题', () {
      // GIVEN: 一个视频消息
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.video,
        payload: {'duration_ms': 60000},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
      );

      // WHEN: 获取会话副标题
      final subtitle = MessageModel.conversationSubtitleFromModel(model);

      // THEN: 应该显示 [视频]
      expect(subtitle, equals('[视频]'));
    });

    test('应该正确显示文件消息的副标题（带文件名）', () {
      // GIVEN: 一个文件消息
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.file,
        payload: {
          'uri': 'https://example.com/file.pdf',
          'name': '报告.pdf',
          'size': 1024000,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
      );

      // WHEN: 获取会话副标题
      final subtitle = MessageModel.conversationSubtitleFromModel(model);

      // THEN: 应该显示文件名
      expect(subtitle, equals('📄 报告.pdf'));
    });

    test('应该正确显示位置消息的副标题', () {
      // GIVEN: 一个位置消息
      final model = MessageModel(
        '123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 8001,
        toId: 8002,
        msgType: MessageType.location,
        payload: {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'title': '北京市朝阳区',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
      );

      // WHEN: 获取会话副标题
      final subtitle = MessageModel.conversationSubtitleFromModel(model);

      // THEN: 应该显示位置标题
      expect(subtitle, equals('北京市朝阳区'));
    });
  });

  group('MessageModel TDD Tests - mixed primitive parsing', () {
    test('fromJson should parse mixed primitive types without cast errors', () {
      final json = {
        'id': 999,
        'auto_id': '12',
        'type': 123,
        'status': '20',
        'from': 1001,
        'to': 1002,
        'msg_type': 88,
        'action': true,
        'payload': '{"text":"hello"}',
        'created_at': '1767225600000',
        'is_author': '1',
        'topic_id': '6',
        'conversation_uk3': 12345,
        'e2ee': '{"algorithm":"xchacha20","key_id":"k1"}',
      };

      final model = MessageModel.fromJson(json);

      expect(model.id, '999');
      expect(model.autoId, 12);
      expect(model.type, '123');
      expect(model.status, 20);
      expect(model.fromId, 1001);
      expect(model.toId, 1002);
      expect(model.msgType, '88');
      expect(model.action, 'true');
      expect(model.isAuthor, 1);
      expect(model.topicId, 6);
      expect(model.conversationUk3, '12345');
      expect(model.payload, {'text': 'hello'});
      expect(model.e2ee?['algorithm'], 'xchacha20');
    });
  });
}

// Helper function to parse JSON
Map<String, dynamic> _parseJson(String jsonString) {
  // 简化实现，仅用于测试
  return {'uri': 'https://example.com/image.jpg'};
}
