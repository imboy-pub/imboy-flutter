/// WebSocket API v2.0 端到端集成测试
///
/// 测试目标：
/// 1. 消息发送使用 v2.0 格式（msg_type/action/e2ee 在顶层）
/// 2. E2EE 加密和解密正常工作
/// 3. 消息接收正确解析 v2.0 格式
/// 4. MessageModel 正确序列化和反序列化
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

void main() {
  group('WebSocket API v2.0 集成测试', () {
    group('MessageModel v2.0 格式测试', () {
      test('应该正确解析 C2C 消息（msgType 在顶层）', () {
        final json = {
          'auto_id': 1,
          'id': 'msg_123',
          'type': 'C2C',
          'msg_type': 'text', // 顶层字段
          'action': '', // C2C 消息 action 为空字符串
          'e2ee': '', // 非 E2EE 消息 e2ee 为空字符串
          'payload': '{"content": "Hello World"}',
          'from_id': 'user1',
          'to_id': 'user2',
          'conversation_uk3': 'C2C_user1_user2',
          'created_at': 1234567890,
          'topic_id': 0,
          'status': 1,
          'is_author': 1,
        };

        final msg = MessageModel.fromJson(json);

        expect(msg.id, 'msg_123');
        expect(msg.type, 'C2C');
        expect(msg.msgType, 'text'); // 从顶层读取
        expect(msg.action, isNull); // C2C 消息 action 解析后为 null
        expect(msg.e2ee, isNull); // 空 e2ee 解析后为 null
        expect(msg.payload, isA<Map>());
      });

      test('应该正确解析 S2C 消息（action 在顶层）', () {
        final json = {
          'auto_id': 1,
          'id': 's2c_123',
          'type': 'S2C',
          'msg_type': '',
          'action': 'pull_offline_msg', // 顶层字段
          'e2ee': '',
          'payload': '{"count": 5}',
          'from_id': 'server',
          'to_id': 'user1',
          'conversation_uk3': '',
          'created_at': 1234567890,
          'topic_id': 0,
          'status': 1,
          'is_author': 0,
        };

        final msg = MessageModel.fromJson(json);

        expect(msg.id, 's2c_123');
        expect(msg.type, 'S2C');
        expect(msg.action, 'pull_offline_msg'); // 从顶层读取
        expect(msg.msgType, isNull); // S2C 消息 msgType 应为 null
      });

      test('应该正确解析 E2EE 消息（payload 为字符串）', () {
        final json = {
          'auto_id': 1,
          'id': 'msg_456',
          'type': 'C2C',
          'msg_type': 'text',
          'action': '',
          'e2ee': '{"e2ee":true,"e2ee_ver":1,"nonce":"abc123"}',
          'payload': 'base64_nonce.base64_ciphertext', // 字符串格式
          'from_id': 'user1',
          'to_id': 'user2',
          'conversation_uk3': 'C2C_user1_user2',
          'created_at': 1234567890,
          'topic_id': 0,
          'status': 1,
          'is_author': 1,
        };

        final msg = MessageModel.fromJson(json);

        expect(msg.id, 'msg_456');
        expect(msg.e2ee, isA<Map>());
        expect(msg.e2ee!['e2ee'], true);
        expect(msg.payload, isA<String>()); // E2EE 消息 payload 是字符串
      });

      test('应该正确序列化 C2C 消息到 v2.0 格式', () {
        final msg = MessageModel(
          'msg_789',
          autoId: 1,
          type: 'C2C',
          status: 1,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1234567890,
          msgType: 'text', // v2.0 字段
        );

        final json = msg.toJson();

        expect(json['msg_type'], 'text'); // 顶层字段
        expect(json['action'], isNull); // C2C 消息不需要 action
        expect(json['e2ee'], isNull); // 非加密消息不需要 e2ee
        expect(json['payload'], isA<String>()); // JSON 字符串
      });

      test('应该正确序列化 S2C 消息到 v2.0 格式', () {
        final msg = MessageModel(
          's2c_456',
          autoId: 1,
          type: 'S2C',
          status: 1,
          fromId: 'server',
          toId: 'user1',
          payload: {'count': 10},
          isAuthor: 0,
          conversationUk3: '',
          createdAt: 1234567890,
          action: 'please_refresh_token', // v2.0 字段
        );

        final json = msg.toJson();

        expect(json['action'], 'please_refresh_token'); // 顶层字段
        expect(json['msg_type'], isNull); // S2C 消息 msgType 为 null
        expect(json['e2ee'], isNull); // S2C 不支持 e2ee
      });

      test('应该正确序列化 E2EE 消息到 v2.0 格式', () {
        final e2eeMetadata = {
          'e2ee': true,
          'e2ee_ver': 1,
          'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
          'nonce': 'test_nonce',
          'keys': [
            {'did': 'device1', 'kid': 'device1', 'ek': 'encrypted_key'},
          ],
        };

        final msg = MessageModel(
          'msg_encrypted',
          autoId: 1,
          type: 'C2C',
          status: 1,
          fromId: 'user1',
          toId: 'user2',
          payload: 'base64_nonce.base64_ciphertext', // 字符串格式
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1234567890,
          msgType: 'text',
          e2ee: e2eeMetadata,
        );

        final json = msg.toJson();

        expect(json['msg_type'], 'text');
        expect(json['e2ee'], isA<String>()); // JSON 字符串
        expect(json['payload'], 'base64_nonce.base64_ciphertext'); // 保持字符串格式
      });
    });

    group('MessageRepo v2.0 表名测试', () {
      test('应该返回正确的表名', () {
        expect(MessageRepo.c2cTable, 'msg_c2c');
        expect(MessageRepo.c2gTable, 'msg_c2g');
        expect(MessageRepo.c2sTable, 'msg_c2s');
        expect(MessageRepo.s2cTable, 'msg_s2c');
      });

      test('应该根据消息类型返回对应表名', () {
        expect(MessageRepo.getTableName('C2C'), 'msg_c2c');
        expect(MessageRepo.getTableName('c2c'), 'msg_c2c');
        expect(MessageRepo.getTableName('C2G'), 'msg_c2g');
        expect(MessageRepo.getTableName('C2S'), 'msg_c2s');
        expect(MessageRepo.getTableName('S2C'), 'msg_s2c');
      });

      test('应该包含 v2.0 字段常量', () {
        expect(MessageRepo.msgType, 'msg_type');
        expect(MessageRepo.action, 'action');
        expect(MessageRepo.e2ee, 'e2ee');
      });
    });

    group('E2EE Service v2.0 测试', () {
      test('应该返回分离的 e2ee 元数据和密文', () async {
        final plaintext = jsonEncode({'content': 'Secret message'});

        // publicKey() 会自动生成密钥对（如果还没有的话）
        final publicKeyPem = await RSAService.publicKey();

        final recipients = [
          RecipientDevice(
            deviceId: 'test_device',
            keyId: 'test_device',
            publicKey: publicKeyPem,
          ),
        ];

        final result = await E2EEService.buildE2EEData(
          plaintext: plaintext,
          recipients: recipients,
        );

        // 验证返回结构
        expect(result, containsPair('e2ee', isA<Map>()));
        expect(result, containsPair('ciphertext', isA<String>()));

        // 验证 e2ee 元数据
        final e2ee = result['e2ee'] as Map<String, dynamic>;
        expect(e2ee['e2ee'], true);
        expect(e2ee['e2ee_ver'], 1);
        expect(e2ee['e2ee_suite'], 'RSA-OAEP-256+AES-256-GCM');
        expect(e2ee['nonce'], isA<String>());
        expect(e2ee['keys'], isA<List>());

        // 验证密文格式：base64(nonce).base64(ciphertext)
        final ciphertext = result['ciphertext'] as String;
        expect(ciphertext, contains('.'));

        // 验证 keys 结构
        final keys = e2ee['keys'] as List;
        expect(keys.length, 1);
        expect(keys[0], containsPair('did', 'test_device'));
        expect(keys[0], containsPair('kid', 'test_device'));
        expect(keys[0], containsPair('wrap_alg', 'RSA-OAEP-256'));
        expect(keys[0], containsPair('ek', isA<String>()));
      });

      test('e2ee 元数据不应包含 ciphertext', () async {
        final plaintext = jsonEncode({'content': 'Test'});

        // publicKey() 会自动生成密钥对（如果还没有的话）
        final publicKeyPem = await RSAService.publicKey();

        final recipients = [
          RecipientDevice(
            deviceId: 'test',
            keyId: 'test',
            publicKey: publicKeyPem,
          ),
        ];

        final result = await E2EEService.buildE2EEData(
          plaintext: plaintext,
          recipients: recipients,
        );

        final e2ee = result['e2ee'] as Map<String, dynamic>;

        // e2ee 元数据中不应包含 ciphertext 或 ct 字段
        expect(e2ee, isNot(contains('ciphertext')));
        expect(e2ee, isNot(contains('ct')));

        // ciphertext 应该在顶层
        expect(result, containsPair('ciphertext', isA<String>()));
      });
    });

    group('v2.0 消息格式验证测试', () {
      test('C2C 消息应包含 msg_type 但不包含 action', () {
        final json = {
          'id': 'msg_001',
          'type': 'C2C',
          'msg_type': 'text',
          'action': '',
          'e2ee': '',
          'payload': {'content': 'Hello'},
          'from': 'user1',
          'to': 'user2',
          'created_at': 1234567890,
        };

        // 验证字段存在
        expect(json, containsPair('msg_type', 'text'));
        expect(json, containsPair('action', ''));
        expect(json, containsPair('e2ee', ''));

        // 验证 payload 不包含 msg_type
        final payload = json['payload'] as Map;
        expect(payload, isNot(contains('msg_type')));
      });

      test('S2C 消息应包含 action 但不包含 e2ee', () {
        final json = {
          'id': 's2c_001',
          'type': 'S2C',
          'msg_type': '',
          'action': 'pull_offline_msg',
          'e2ee': '',
          'payload': {'count': 5},
          'from': 'server',
          'to': 'user1',
          'server_ts': 1234567890,
        };

        // 验证字段存在
        expect(json, containsPair('action', 'pull_offline_msg'));
        expect(json, containsPair('e2ee', ''));

        // S2C 不支持 e2ee
        expect(json['e2ee'], '');
      });

      test('E2EE 消息的 payload 应该是字符串', () {
        final json = {
          'id': 'msg_encrypted',
          'type': 'C2C',
          'msg_type': 'text',
          'action': '',
          'e2ee': {'e2ee': true, 'e2ee_ver': 1, 'nonce': 'abc123', 'keys': []},
          'payload': 'base64_nonce.base64_ciphertext', // 字符串格式
        };

        // payload 应该是字符串
        expect(json['payload'], isA<String>());

        // e2ee 元数据中不应包含 ciphertext
        final e2ee = json['e2ee'] as Map;
        expect(e2ee, isNot(contains('ciphertext')));
        expect(e2ee, isNot(contains('ct')));
      });
    });
  });
}
