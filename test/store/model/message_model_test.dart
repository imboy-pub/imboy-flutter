import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/message_model.dart';

void main() {
  group('MessageModel WebSocket API v2.0 Tests', () {
    test('应该正确解析 C2C 消息的 msgType 字段', () {
      final json = {
        'auto_id': 1,
        'id': 'msg123',
        'type': 'C2C',
        'msg_type': 'text',
        'from_id': 'user1',
        'to_id': 'user2',
        'payload': '{"text":"Hello"}',
        'created_at': 1640000000000,
        'is_author': 1,
        'status': 20,
        'conversation_uk3': 'C2C_user1_user2',
        'topic_id': 0,
      };

      final model = MessageModel.fromJson(json);

      expect(model.type, 'C2C');
      expect(model.msgType, 'text');
      expect(model.action, isNull);
      expect(model.e2ee, isNull);
    });

    test('应该正确解析 S2C 消息的 action 字段', () {
      final json = {
        'auto_id': 1,
        'id': 'msg456',
        'type': 'S2C',
        'action': 'push_notification',
        'from_id': 'server',
        'to_id': 'user1',
        'payload': '{}',
        'created_at': 1640000000000,
        'is_author': 0,
        'status': 20,
        'conversation_uk3': 'S2C_server_user1',
        'topic_id': 0,
      };

      final model = MessageModel.fromJson(json);

      expect(model.type, 'S2C');
      expect(model.msgType, isNull);
      expect(model.action, 'push_notification');
      expect(model.e2ee, isNull);
    });

    test('应该正确解析 C2C 消息的 e2ee 字段', () {
      final json = {
        'auto_id': 1,
        'id': 'msg789',
        'type': 'C2C',
        'msg_type': 'text',
        'from_id': 'user1',
        'to_id': 'user2',
        'e2ee': '{"algorithm":"AES-GCM","key_id":"key123"}',
        'payload': '{"text":"Encrypted message"}',
        'created_at': 1640000000000,
        'is_author': 1,
        'status': 20,
        'conversation_uk3': 'C2C_user1_user2',
        'topic_id': 0,
      };

      final model = MessageModel.fromJson(json);

      expect(model.type, 'C2C');
      expect(model.msgType, 'text');
      expect(model.e2ee, isNotNull);
      expect(model.e2ee!['algorithm'], 'AES-GCM');
      expect(model.e2ee!['key_id'], 'key123');
    });

    test('应该正确序列化 C2C 消息到 JSON', () {
      final model = MessageModel(
        'msg123',
        autoId: 1,
        type: 'C2C',
        status: 20,
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': 'Hello'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        topicId: 0,
        createdAt: 1640000000000,
        msgType: 'text',
        e2ee: {'algorithm': 'AES-GCM', 'key_id': 'key123'},
      );

      final json = model.toJson();

      expect(json['type'], 'C2C');
      expect(json['msg_type'], 'text');
      expect(json['action'], isNull);
      expect(json['e2ee'], isNotNull);
      expect(json['from_id'], 'user1');
      expect(json['to_id'], 'user2');
    });

    test('应该正确序列化 S2C 消息到 JSON', () {
      final model = MessageModel(
        'msg456',
        autoId: 1,
        type: 'S2C',
        status: 20,
        fromId: 'server',
        toId: 'user1',
        payload: {},
        isAuthor: 0,
        conversationUk3: 'S2C_server_user1',
        topicId: 0,
        createdAt: 1640000000000,
        action: 'push_notification',
      );

      final json = model.toJson();

      expect(json['type'], 'S2C');
      expect(json['msg_type'], isNull);
      expect(json['action'], 'push_notification');
      expect(json['e2ee'], isNull);
    });

    test('应该支持 payload 为 String 类型（加密数据）', () {
      final model = MessageModel(
        'msg999',
        autoId: 1,
        type: 'C2C',
        status: 20,
        fromId: 'user1',
        toId: 'user2',
        payload: 'encrypted_json_string',
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        topicId: 0,
        createdAt: 1640000000000,
        msgType: 'text',
        e2ee: {'algorithm': 'AES-GCM'},
      );

      final json = model.toJson();

      expect(json['payload'], 'encrypted_json_string');
    });

    test('fromJson 应该兼容旧的 payload.msg_type 结构', () {
      final json = {
        'auto_id': 1,
        'id': 'msg_old',
        'type': 'C2C',
        'from_id': 'user1',
        'to_id': 'user2',
        'payload': '{"msg_type":"text","text":"Hello from old version"}',
        'created_at': 1640000000000,
        'is_author': 1,
        'status': 20,
        'conversation_uk3': 'C2C_user1_user2',
        'topic_id': 0,
      };

      final model = MessageModel.fromJson(json);

      expect(model.type, 'C2C');
      expect(model.msgType, isNull); // 顶层没有 msg_type
      expect(model.payload, isA<Map<String, dynamic>>());
      expect(model.payload['msg_type'], 'text');
    });

    test('customMsgType getter 应该优先使用顶层 msgType', () {
      final model = MessageModel(
        'msg_priority',
        autoId: 1,
        type: 'C2C',
        status: 20,
        fromId: 'user1',
        toId: 'user2',
        payload: {'msg_type': 'image', 'uri': 'http://example.com/img.jpg'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        topicId: 0,
        createdAt: 1640000000000,
        msgType: 'text', // 顶层字段
      );

      // 应该优先使用顶层的 msgType
      expect(model.msgType, 'text');
    });
  });
}
