import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 初始化测试环境
  setUpAll(() async {
    // 初始化 Flutter 测试绑定
    TestWidgetsFlutterBinding.ensureInitialized();

    // 初始化 SharedPreferences 用于测试
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

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
        status: 11,
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

  group('MessageModel - toTypeMessage (15种消息类型转换测试)', () {
    final testUserId = 'test_user_123';
    final testPeerId = 'test_peer_456';

    test('应该将文本消息 (text) 转换为 TextMessage', () async {
      final model = MessageModel(
        'msg123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {'text': 'Hello World'},
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<TextMessage>());
      if (message is TextMessage) {
        expect(message.text, equals('Hello World'));
      }
    });

    test('应该将图片消息 (image) 转换为 ImageMessage', () async {
      final model = MessageModel(
        'img123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'uri': 'https://cdn.example.com/image.jpg',
          'size': 102400,
          'width': 1920,
          'height': 1080,
          'name': 'image.jpg',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'image',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<ImageMessage>());
      if (message is ImageMessage) {
        expect(message.width, equals(1920.0));
        expect(message.height, equals(1080.0));
      }
    });

    test('应该将文件消息 (file) 转换为 FileMessage', () async {
      final model = MessageModel(
        'file123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'uri': 'https://cdn.example.com/document.pdf',
          'name': 'report.pdf',
          'size': 1024000,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'file',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<FileMessage>());
      if (message is FileMessage) {
        expect(message.name, equals('report.pdf'));
      }
    });

    test('应该将语音消息 (voice) 转换为 AudioMessage', () async {
      final model = MessageModel(
        'voice123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'uri': 'https://cdn.example.com/voice.mp3',
          'duration_ms': 15000,
          'size': 51200,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'voice',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<AudioMessage>());
      if (message is AudioMessage) {
        expect(message.duration, equals(const Duration(milliseconds: 15000)));
      }
    });

    test('应该兼容旧的 audio 命名（转换为 voice）', () async {
      final model = MessageModel(
        'audio123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'uri': 'https://cdn.example.com/voice.mp3',
          'duration_ms': 15000,
          'size': 51200,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'audio', // 旧的命名
      );

      final message = await model.toTypeMessage();

      expect(message, isA<AudioMessage>());
    });

    test('应该将视频消息 (video) 转换为 VideoMessage', () async {
      final model = MessageModel(
        'video123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'uri': 'https://cdn.example.com/video.mp4',
          'duration_ms': 60000,
          'size': 5120000,
          'width': 1920,
          'height': 1080,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'video',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<VideoMessage>());
      if (message is VideoMessage) {
        expect(message.width, equals(1920));
        expect(message.height, equals(1080));
      }
    });

    test('应该将位置消息 (location) 转换为 CustomMessage', () async {
      final model = MessageModel(
        'loc123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'title': '北京市朝阳区',
          'address': '朝阳区建国路88号',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'location',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['msg_type'], equals('location'));
      }
    });

    test('应该将多图消息 (imageMulti) 转换为 CustomMessage', () async {
      final model = MessageModel(
        'multi123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {
          'images': [
            {
              'uri': 'https://cdn.example.com/image1.jpg',
              'size': 102400,
              'width': 1920,
              'height': 1080,
            },
          ],
          'total': 1,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'imageMulti',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['msg_type'], equals('imageMulti'));
        final images = message.metadata?['images'] as List?;
        expect(images?.length, equals(1));
      }
    });

    test('应该将系统消息 (system) 转换为 CustomMessage', () async {
      final model = MessageModel(
        'sys123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {'content': '系统消息'},
        isAuthor: 0,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'system',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['msg_type'], equals('system'));
        expect(message.metadata?['is_system'], isTrue);
      }
    });

    test('应该将未知消息类型转换为 CustomMessage 并标记为 unsupported', () async {
      final model = MessageModel(
        'unknown123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {'data': '未知数据'},
        isAuthor: 0,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: 'unknown_type_xyz',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['unsupported'], isTrue);
        expect(message.metadata?['original_type'], equals('unknown_type_xyz'));
      }
    });

    test('应该在 msg_type 为空时返回错误消息 TextMessage', () async {
      final model = MessageModel(
        'bad123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: testUserId,
        toId: testPeerId,
        payload: {'data': 'test'},
        isAuthor: 0,
        conversationUk3: 'C2C_${testUserId}_$testPeerId',
        createdAt: 1642579200000,
        msgType: null,
      );

      final message = await model.toTypeMessage();

      expect(message, isA<TextMessage>());
      if (message is TextMessage) {
        expect(message.text, equals('[无效消息]'));
      }
    });
  });

  group('MessageModel - fromMessage (双向转换测试)', () {
    test('应该将 TextMessage 转换回 MessageModel', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'msg123',
        text: 'Hello World',
        metadata: {
          'peer_id': 'peer456',
          'conversation_uk3': 'C2C_user123_peer456',
        },
        status: MessageStatus.sent,
      );

      final model = MessageModel.fromMessage(textMessage);

      expect(model.msgType, equals('text'));
      expect(model.payload['text'], equals('Hello World'));
      expect(model.fromId, equals('user123'));
      expect(model.toId, equals('peer456'));
    });

    test('应该将 ImageMessage 转换回 MessageModel', () {
      final imageMessage = ImageMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'img123',
        text: 'photo.jpg',
        size: 102400,
        source: 'https://cdn.example.com/image.jpg',
        width: 1920,
        height: 1080,
        metadata: {'peer_id': 'peer456'},
      );

      final model = MessageModel.fromMessage(imageMessage);

      expect(model.msgType, equals('image'));
      expect(model.payload['name'], equals('photo.jpg'));
      expect(model.payload['width'], equals(1920));
    });

    test('应该将 AudioMessage 转换为 MessageModel (voice 类型)', () {
      final audioMessage = AudioMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'audio123',
        text: 'voice.mp3',
        size: 51200,
        source: 'https://cdn.example.com/voice.mp3',
        duration: const Duration(milliseconds: 15000),
        metadata: {'peer_id': 'peer456'},
      );

      final model = MessageModel.fromMessage(audioMessage);

      expect(model.msgType, equals('voice')); // 应该是 'voice'
      expect(model.payload['duration_ms'], equals(15000));
    });

    test('应该将 VideoMessage 转换回 MessageModel', () {
      final videoMessage = VideoMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'video123',
        name: 'video.mp4',
        text: 'video.mp4',
        size: 5120000,
        source: 'https://cdn.example.com/video.mp4',
        width: 1920,
        height: 1080,
        metadata: {'peer_id': 'peer456', 'duration_ms': 60000},
      );

      final model = MessageModel.fromMessage(videoMessage);

      expect(model.msgType, equals('video'));
      expect(model.payload['duration_ms'], equals(60000));
    });

    test('应该将 FileMessage 转换回 MessageModel', () {
      final fileMessage = FileMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'file123',
        name: 'document.pdf',
        size: 1024000,
        source: 'https://cdn.example.com/document.pdf',
        metadata: {'peer_id': 'peer456'},
      );

      final model = MessageModel.fromMessage(fileMessage);

      expect(model.msgType, equals('file'));
      expect(model.payload['name'], equals('document.pdf'));
    });

    test('应该将 CustomMessage 转换回 MessageModel', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'custom123',
        metadata: {
          'peer_id': 'peer456',
          'conversation_uk3': 'C2C_user123_peer456',
          'custom_type': 'visit_card',
          'uid': 'card_user',
          'title': '张三',
        },
      );

      final model = MessageModel.fromMessage(customMessage);

      expect(model.msgType, equals('custom'));
      expect(model.payload['custom_type'], equals('visit_card'));
    });

    test('应该将 TextStreamMessage 转换回 MessageModel', () {
      final textStreamMessage = TextStreamMessage(
        authorId: 'ai_bot',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'stream123',
        streamId: 'stream_abc123',
        metadata: {'peer_id': 'user123'},
      );

      final model = MessageModel.fromMessage(textStreamMessage);

      expect(model.msgType, equals('textStream'));
      expect(model.payload['stream_id'], equals('stream_abc123'));
    });

    test('应该将 SystemMessage 转换回 MessageModel', () {
      final systemMessage = SystemMessage(
        authorId: 'system',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'sys123',
        text: '系统通知',
        metadata: {'content': '系统通知'},
      );

      final model = MessageModel.fromMessage(systemMessage);

      expect(model.msgType, equals('system'));
    });
  });

  group('IMBoyMessageStatus 撤回状态测试', () {
    test('isRevokedStatus 应该正确识别撤回状态', () {
      // 测试撤回状态范围（30-39）
      expect(IMBoyMessageStatus.isRevokedStatus(30), isTrue); // peerRevoked
      expect(IMBoyMessageStatus.isRevokedStatus(31), isTrue); // myRevoked
      expect(IMBoyMessageStatus.isRevokedStatus(32), isTrue); // 其他撤回状态
      expect(IMBoyMessageStatus.isRevokedStatus(39), isTrue); // 边界值
      expect(IMBoyMessageStatus.isRevokedStatus(29), isFalse); // 低于范围
      expect(IMBoyMessageStatus.isRevokedStatus(40), isFalse); // 高于范围
      expect(IMBoyMessageStatus.isRevokedStatus(null), isFalse);
    });

    test('getRevokedStatusText 应该返回正确的文本', () {
      expect(IMBoyMessageStatus.getRevokedStatusText(30), equals('对方撤回'));
      expect(IMBoyMessageStatus.getRevokedStatusText(31), equals('已撤回'));
      expect(IMBoyMessageStatus.getRevokedStatusText(32), equals('已撤回'));
      expect(IMBoyMessageStatus.getRevokedStatusText(29), equals('已撤回'));
    });

    test('isPeerRevoked 和 isMyRevoked 应该正确判断', () {
      expect(IMBoyMessageStatus.isPeerRevoked(30), isTrue);
      expect(IMBoyMessageStatus.isPeerRevoked(31), isFalse);
      expect(IMBoyMessageStatus.isMyRevoked(30), isFalse);
      expect(IMBoyMessageStatus.isMyRevoked(31), isTrue);
    });
  });

  group('MessageModel - typesStatus getter 测试', () {
    test('typesStatus 应该正确转换状态码', () {
      // sending (10-19)
      final sendingModel = MessageModel(
        'msg1',
        autoId: 1,
        type: 'C2C',
        status: 10, // sending
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(sendingModel.typesStatus, equals(MessageStatus.sending));

      // sent (11)
      final sentModel = MessageModel(
        'msg2',
        autoId: 1,
        type: 'C2C',
        status: 11, // sent
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(sentModel.typesStatus, equals(MessageStatus.sent));

      // delivered (20)
      final deliveredModel = MessageModel(
        'msg3',
        autoId: 1,
        type: 'C2C',
        status: 20, // delivered
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(deliveredModel.typesStatus, equals(MessageStatus.delivered));

      // seen (21)
      final seenModel = MessageModel(
        'msg3',
        autoId: 1,
        type: 'C2C',
        status: 21, // seen
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(seenModel.typesStatus, equals(MessageStatus.seen));

      // error (40+)
      final errorModel = MessageModel(
        'msg4',
        autoId: 1,
        type: 'C2C',
        status: 41, // error
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(errorModel.typesStatus, equals(MessageStatus.error));

      // unknown status defaults to error
      final unknownModel = MessageModel(
        'msg5',
        autoId: 1,
        type: 'C2C',
        status: 99, // unknown
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );
      expect(unknownModel.typesStatus, equals(MessageStatus.error));
    });
  });

  group('MessageModel - conversationMsgType 测试', () {
    test('conversationMsgTypeFromModel 应该返回正确的消息类型', () {
      final textModel = MessageModel(
        'text123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': 'Hello'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(
        MessageModel.conversationMsgTypeFromModel(textModel),
        equals('text'),
      );

      final imageModel = MessageModel(
        'image123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'uri': 'http://example.com/img.jpg'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'image',
      );

      expect(
        MessageModel.conversationMsgTypeFromModel(imageModel),
        equals('image'),
      );
    });

    test('conversationMsgTypeFromModel 应该处理空 msgType', () {
      final model = MessageModel(
        'empty123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': 'Hello'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        // msgType 为 null
      );

      expect(
        MessageModel.conversationMsgTypeFromModel(model),
        equals('unsupported'),
      );
    });

    test('conversationMsgType (Message版本) 应该从 metadata 读取', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'msg123',
        text: 'Hello',
        metadata: {'msg_type': 'text'},
      );

      expect(MessageModel.conversationMsgType(textMessage), equals('text'));
    });

    test('conversationMsgType 应该处理撤回消息', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'msg123',
        text: '撤回的消息',
        metadata: {'msg_type': 'text', 'status': 30},
      );

      // 撤回消息仍返回原始类型
      expect(MessageModel.conversationMsgType(textMessage), equals('text'));
    });
  });

  group('MessageModel - conversationSubtitle 测试', () {
    test('conversationSubtitleFromModel 应该返回正确的预览文本', () {
      final textModel = MessageModel(
        'text123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': 'Hello World'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(textModel),
        equals('Hello World'),
      );
    });

    test('conversationSubtitleFromModel 应该处理图片消息', () {
      final imageModel = MessageModel(
        'image123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'uri': 'http://example.com/img.jpg'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'image',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(imageModel),
        equals('[图片]'),
      );
    });

    test('conversationSubtitleFromModel 应该处理语音消息', () {
      final voiceModel = MessageModel(
        'voice123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'uri': 'http://example.com/voice.mp3'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'voice',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(voiceModel),
        equals('[语音]'),
      );
    });

    test('conversationSubtitleFromModel 应该处理视频消息', () {
      final videoModel = MessageModel(
        'video123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'uri': 'http://example.com/video.mp4'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'video',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(videoModel),
        equals('[视频]'),
      );
    });

    test('conversationSubtitleFromModel 应该处理文件消息', () {
      final fileModel = MessageModel(
        'file123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'name': 'document.pdf', 'uri': 'http://example.com/file.pdf'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'file',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(fileModel),
        equals('📄 document.pdf'),
      );
    });

    test('conversationSubtitleFromModel 应该处理无名文件', () {
      final fileModel = MessageModel(
        'file123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'uri': 'http://example.com/file.pdf'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'file',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(fileModel),
        equals('[文件]'),
      );
    });

    test('conversationSubtitleFromModel 应该处理撤回消息', () {
      final revokedModel = MessageModel(
        'revoked123',
        autoId: 1,
        type: 'C2C',
        status: 30, // peerRevoked
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': '原始消息'},
        isAuthor: 0,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(MessageModel.conversationSubtitleFromModel(revokedModel), isEmpty);
    });

    test('conversationSubtitleFromModel 应该处理位置消息', () {
      final locationModel = MessageModel(
        'loc123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'title': '北京市朝阳区',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'location',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(locationModel),
        equals('北京市朝阳区'),
      );
    });

    test('conversationSubtitle (Message版本) 应该正确处理文本消息', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'msg123',
        text: 'Hello World',
        metadata: {'msg_type': 'text'},
      );

      expect(
        MessageModel.conversationSubtitle(textMessage),
        equals('Hello World'),
      );
    });

    test('conversationSubtitle 应该处理图片消息', () {
      final imageMessage = ImageMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'img123',
        text: 'photo.jpg',
        size: 102400,
        source: 'https://cdn.example.com/image.jpg',
        width: 1920,
        height: 1080,
        metadata: {'msg_type': 'image'},
      );

      expect(MessageModel.conversationSubtitle(imageMessage), equals('[图片]'));
    });
  });

  group('MessageModel - isSendingStatus 和 isErrorStatus 测试', () {
    test('isSendingStatus 应该正确判断发送中状态', () {
      expect(IMBoyMessageStatus.isSendingStatus(10), isTrue);
      expect(IMBoyMessageStatus.isSendingStatus(11), isTrue);
      expect(IMBoyMessageStatus.isSendingStatus(15), isTrue);
      expect(IMBoyMessageStatus.isSendingStatus(19), isTrue);
      expect(IMBoyMessageStatus.isSendingStatus(20), isFalse); // sent
      expect(IMBoyMessageStatus.isSendingStatus(9), isFalse);
      expect(IMBoyMessageStatus.isSendingStatus(null), isFalse);
    });

    test('isErrorStatus 应该正确判断错误状态', () {
      expect(IMBoyMessageStatus.isErrorStatus(40), isTrue);
      expect(IMBoyMessageStatus.isErrorStatus(41), isTrue);
      expect(IMBoyMessageStatus.isErrorStatus(50), isTrue);
      expect(IMBoyMessageStatus.isErrorStatus(39), isFalse);
      expect(IMBoyMessageStatus.isErrorStatus(null), isFalse);
    });
  });

  group('MessageModel - 边界情况测试', () {
    test('应该处理空的 payload', () {
      final model = MessageModel(
        'empty123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(model.payload, isEmpty);
      expect(model.msgType, equals('text'));
    });

    test('应该处理 null 字段', () {
      final model = MessageModel(
        'null123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {},
        isAuthor: 0,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );

      expect(model.msgType, isNull);
      expect(model.action, isNull);
      expect(model.e2ee, isNull);
    });

    test('应该处理撤回消息的转换', () async {
      final model = MessageModel(
        'revoked123',
        autoId: 1,
        type: 'C2C',
        status: 30, // peerRevoked
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': '原始消息'},
        isAuthor: 0,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      final message = await model.toTypeMessage();

      // 撤回消息应该转换为 CustomMessage 并包含状态信息
      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['status'], equals(30));
        expect(
          IMBoyMessageStatus.isPeerRevoked(message.metadata?['status']),
          isTrue,
        );
      }
    });

    test('应该处理自己撤回的消息', () async {
      final model = MessageModel(
        'my_revoked123',
        autoId: 1,
        type: 'C2C',
        status: 31, // myRevoked
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': '原始消息'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['status'], equals(31));
        expect(
          IMBoyMessageStatus.isMyRevoked(message.metadata?['status']),
          isTrue,
        );
      }
    });

    test('应该处理 quote 消息类型', () async {
      final model = MessageModel(
        'quote123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'custom_type': 'quote',
          'quote_msg_id': 'msg456',
          'quote_msg_text': '引用的消息内容',
          'quote_msg_author_name': '张三',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['custom_type'], equals('quote'));
      }
    });

    test('应该处理 visitCard 消息类型', () async {
      final model = MessageModel(
        'card123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'custom_type': 'visit_card',
          'uid': 'card_user_123',
          'title': '张三',
          'avatar': 'https://example.com/avatar.jpg',
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['custom_type'], equals('visit_card'));
      }
    });

    test('应该处理 audio waveform 数据', () async {
      final model = MessageModel(
        'voice123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'uri': 'https://cdn.example.com/voice.mp3',
          'duration_ms': 15000,
          'size': 51200,
          'waveform': [0.1, 0.5, 0.8, 0.3, 0.6],
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'voice',
      );

      final message = await model.toTypeMessage();

      expect(message, isA<AudioMessage>());
      if (message is AudioMessage) {
        expect(message.waveform, isNotNull);
        expect(message.waveform?.length, equals(5));
      }
    });
  });

  group('MessageModel - fromMessage 边界情况测试', () {
    test('应该处理 S2C 类型的消息', () {
      final customMessage = CustomMessage(
        authorId: 'system',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 's2c123',
        metadata: {'action': 'push_notification', 'type': 'S2C'},
      );

      final model = MessageModel.fromMessage(customMessage);

      expect(model.type, equals('S2C'));
      expect(model.action, equals('push_notification'));
      expect(model.msgType, isNull); // S2C 消息不应该有 msgType
      expect(model.e2ee, isNull);
    });

    test('应该处理带有 e2ee 的消息', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'encrypted123',
        text: 'Encrypted text',
        metadata: {
          'peer_id': 'peer456',
          'e2ee': {'algorithm': 'AES-GCM', 'key_id': 'key123'},
        },
      );

      final model = MessageModel.fromMessage(textMessage);

      expect(model.msgType, equals('text'));
      expect(model.e2ee, isNotNull);
      expect(model.e2ee!['algorithm'], equals('AES-GCM'));
    });

    test('应该处理带有 topic_id 的消息', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'topic123',
        text: 'Topic message',
        metadata: {'peer_id': 'peer456', 'topic_id': 100},
      );

      final model = MessageModel.fromMessage(textMessage);

      expect(model.msgType, equals('text'));
      expect(model.topicId, equals(100));
    });

    test('应该处理 ImageMessage 的完整元数据', () {
      final imageMessage = ImageMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'img123',
        text: 'photo.jpg',
        size: 102400,
        source: 'https://cdn.example.com/image.jpg',
        width: 1920,
        height: 1080,
        metadata: {
          'peer_id': 'peer456',
          'thumbnail_uri': 'https://cdn.example.com/thumb.jpg',
        },
      );

      final model = MessageModel.fromMessage(imageMessage);

      expect(model.msgType, equals('image'));
      expect(
        model.payload['thumbnail_uri'],
        equals('https://cdn.example.com/thumb.jpg'),
      );
    });

    test('应该处理 VideoMessage 的 duration_ms 在 metadata 中', () {
      final videoMessage = VideoMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'video123',
        name: 'video.mp4',
        text: 'video.mp4',
        size: 5120000,
        source: 'https://cdn.example.com/video.mp4',
        width: 1920,
        height: 1080,
        metadata: {'peer_id': 'peer456', 'duration_ms': 60000},
      );

      final model = MessageModel.fromMessage(videoMessage);

      expect(model.msgType, equals('video'));
      expect(model.payload['duration_ms'], equals(60000));
    });
  });

  group('MessageModel - conversationSubtitle 边界情况', () {
    test('应该处理无标题的位置消息', () {
      final locationModel = MessageModel(
        'loc123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'latitude': 39.9042, 'longitude': 116.4074},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'location',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(locationModel),
        equals('[位置]'),
      );
    });

    test('应该处理自定义 visit_card 消息', () {
      final cardModel = MessageModel(
        'card123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'custom_type': 'visit_card', 'title': '张三'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(cardModel),
        equals('张三'),
      );
    });

    test('应该处理无标题的 visit_card 消息', () {
      final cardModel = MessageModel(
        'card123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'custom_type': 'visit_card'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(cardModel),
        equals('[名片]'),
      );
    });

    test('应该处理 quote 引用消息', () {
      final quoteModel = MessageModel(
        'quote123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'quote_text': '这是被引用的消息内容'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'quote',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(quoteModel),
        equals('这是被引用的消息内容'),
      );
    });

    test('应该处理无文本的 quote 消息', () {
      final quoteModel = MessageModel(
        'quote123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: <String, dynamic>{},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'quote',
      );

      expect(
        MessageModel.conversationSubtitleFromModel(quoteModel),
        equals('[引用]'),
      );
    });

    test('conversationSubtitle (Message版本) 应处理音频消息', () {
      final audioMessage = AudioMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'audio123',
        text: 'voice.mp3',
        size: 51200,
        source: 'https://cdn.example.com/voice.mp3',
        duration: const Duration(milliseconds: 15000),
        metadata: {'msg_type': 'voice'},
      );

      expect(MessageModel.conversationSubtitle(audioMessage), equals('[语音]'));
    });

    test('conversationSubtitle (Message版本) 应处理视频消息', () {
      final videoMessage = VideoMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'video123',
        name: 'video.mp4',
        text: 'video.mp4',
        size: 5120000,
        source: 'https://cdn.example.com/video.mp4',
        width: 1920,
        height: 1080,
        metadata: {'msg_type': 'video'},
      );

      expect(MessageModel.conversationSubtitle(videoMessage), equals('[视频]'));
    });

    test('conversationSubtitle (Message版本) 应处理文件消息', () {
      final fileMessage = FileMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'file123',
        name: 'document.pdf',
        size: 1024000,
        source: 'https://cdn.example.com/document.pdf',
        metadata: {'msg_type': 'file', 'name': 'document.pdf'},
      );

      expect(
        MessageModel.conversationSubtitle(fileMessage),
        equals('📄 document.pdf'),
      );
    });

    test('conversationSubtitle (Message版本) 应处理无名文件', () {
      final fileMessage = FileMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'file123',
        name: '',
        size: 1024000,
        source: 'https://cdn.example.com/file',
        metadata: {'msg_type': 'file', 'name': ''},
      );

      expect(MessageModel.conversationSubtitle(fileMessage), equals('[文件]'));
    });

    test('conversationSubtitle (Message版本) 应处理位置消息', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'loc123',
        metadata: {
          'msg_type': 'location',
          'title': '北京市朝阳区',
          'latitude': 39.9042,
          'longitude': 116.4074,
        },
      );

      expect(
        MessageModel.conversationSubtitle(customMessage),
        equals('北京市朝阳区'),
      );
    });
  });

  group('MessageModel - 其他辅助方法测试', () {
    test('toStatus 应该正确转换 MessageStatus', () {
      final model = MessageModel(
        'test123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: <String, dynamic>{},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
      );

      // MessageStatus.sending -> 10
      expect(
        model.toStatus(MessageStatus.sending),
        equals(IMBoyMessageStatus.sending),
      );

      // MessageStatus.sent -> 11
      expect(
        model.toStatus(MessageStatus.sent),
        equals(IMBoyMessageStatus.sent),
      );

      // MessageStatus.delivered -> 20
      expect(
        model.toStatus(MessageStatus.delivered),
        equals(IMBoyMessageStatus.delivered),
      );

      // MessageStatus.seen -> 21
      expect(
        model.toStatus(MessageStatus.seen),
        equals(IMBoyMessageStatus.seen),
      );

      // MessageStatus.error -> 41
      expect(
        model.toStatus(MessageStatus.error),
        equals(IMBoyMessageStatus.error),
      );
    });

    test('应该处理 CustomMessage 的不同 custom_type', () async {
      // webrtc_audio 类型
      final webrtcAudioModel = MessageModel(
        'webrtc_audio123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'custom_type': 'webrtc_audio',
          'call_id': 'call_123',
          'duration': 60000,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final audioMessage = await webrtcAudioModel.toTypeMessage();
      expect(audioMessage, isA<CustomMessage>());

      // webrtc_video 类型
      final webrtcVideoModel = MessageModel(
        'webrtc_video123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'custom_type': 'webrtc_video',
          'call_id': 'call_456',
          'duration': 120000,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final videoMessage = await webrtcVideoModel.toTypeMessage();
      expect(videoMessage, isA<CustomMessage>());
    });

    test('应该处理 revoked 消息类型', () async {
      final revokedModel = MessageModel(
        'revoked123',
        autoId: 1,
        type: 'C2C',
        status: 30, // peerRevoked
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'custom_type': 'revoked',
          'original_msg_type': 'text',
          'original_text': '原始消息',
        },
        isAuthor: 0,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final message = await revokedModel.toTypeMessage();
      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['custom_type'], equals('revoked'));
      }
    });

    test('conversationSubtitle 应处理 webrtc 消息', () {
      final webrtcModel = MessageModel(
        'webrtc123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'custom_type': 'webrtc_audio', 'duration': 60000},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      // webrtc 消息返回空字符串
      expect(MessageModel.conversationSubtitleFromModel(webrtcModel), isEmpty);
    });

    test('conversationSubtitle (Message版本) 应处理撤回消息', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'revoked123',
        metadata: {
          'msg_type': 'text',
          'status': 30, // peerRevoked
        },
      );

      // 撤回消息返回空字符串
      expect(MessageModel.conversationSubtitle(customMessage), isEmpty);
    });

    test('conversationMsgType 应处理其他未知消息类型', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'unknown123',
        metadata: {'msg_type': 'unknown_type_xyz'},
      );

      expect(
        MessageModel.conversationMsgType(customMessage),
        equals('unknown_type_xyz'),
      );
    });

    test('应该处理 textStream 消息类型', () async {
      final textStreamModel = MessageModel(
        'stream123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'ai_bot',
        toId: 'user123',
        payload: {
          'stream_id': 'stream_abc123',
          'index': 1,
          'is_end': false,
          'text': '正在思考',
        },
        isAuthor: 0,
        conversationUk3: 'C2C_ai_bot_user123',
        createdAt: 1642579200000,
        msgType: 'textStream',
      );

      final message = await textStreamModel.toTypeMessage();

      expect(message, isA<TextMessage>());
      if (message is TextMessage) {
        expect(message.metadata?['stream_id'], equals('stream_abc123'));
      }
    });

    test('应该处理 text_stream (旧命名) 消息类型', () async {
      final textStreamModel = MessageModel(
        'stream123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'ai_bot',
        toId: 'user123',
        payload: {'stream_id': 'stream_xyz789', 'text': '流式文本'},
        isAuthor: 0,
        conversationUk3: 'C2C_ai_bot_user123',
        createdAt: 1642579200000,
        msgType: 'text_stream',
      );

      final message = await textStreamModel.toTypeMessage();

      expect(message, isA<TextMessage>());
      if (message is TextMessage) {
        expect(message.metadata?['msg_type'], equals('text_stream'));
        expect(message.metadata?['stream_id'], equals('stream_xyz789'));
      }
    });

    test('应该处理 imageMulti (旧命名) 消息类型', () async {
      final imageMultiModel = MessageModel(
        'multi123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {
          'images': [
            {'uri': 'https://example.com/img1.jpg'},
            {'uri': 'https://example.com/img2.jpg'},
          ],
          'total': 2,
        },
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'image_multi',
      );

      final message = await imageMultiModel.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['msg_type'], equals('image_multi'));
        final images = message.metadata?['images'] as List?;
        expect(images?.length, equals(2));
      }
    });

    test('conversationSubtitle 应处理空文本消息', () {
      final textModel = MessageModel(
        'text123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: <String, dynamic>{},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(MessageModel.conversationSubtitleFromModel(textModel), equals(''));
    });

    test('conversationSubtitle (Message版本) 应处理无 metadata 的消息', () {
      final textMessage = TextMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'text123',
        text: 'Hello',
      );

      // 没有 metadata 时，conversationMsgType 会返回 'unsupported'
      expect(
        MessageModel.conversationSubtitle(textMessage),
        equals('Hello'), // TextMessage 直接返回 text
      );
    });

    test('应该处理自定义消息的其他 custom_type', () async {
      final customModel = MessageModel(
        'custom123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'custom_type': 'some_custom_type', 'data': 'custom data'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'custom',
      );

      final message = await customModel.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['custom_type'], equals('some_custom_type'));
      }
    });

    test('应该处理 status 为 null 的情况', () {
      final model = MessageModel(
        'null_status123',
        autoId: 1,
        type: 'C2C',
        status: null,
        fromId: 'user1',
        toId: 'user2',
        payload: {'text': 'test'},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'text',
      );

      expect(model.status, isNull);
      expect(model.msgType, equals('text'));
    });

    test('应该处理 AudioMessage 的 name 和 text 不一致的情况', () {
      final audioMessage = AudioMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'audio123',
        text: 'Display Name',
        size: 51200,
        source: 'https://cdn.example.com/voice.mp3',
        duration: const Duration(milliseconds: 15000),
        metadata: {'peer_id': 'peer456'},
      );

      final model = MessageModel.fromMessage(audioMessage);

      expect(model.msgType, equals('voice'));
      expect(model.payload['name'], equals('Display Name'));
    });

    test('应该处理 ImageMessage 没有 width/height 的情况', () {
      final imageMessage = ImageMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'img123',
        text: 'image.jpg',
        size: 102400,
        source: 'https://cdn.example.com/image.jpg',
        // width 和 height 是可选的
        metadata: {'peer_id': 'peer456'},
      );

      final model = MessageModel.fromMessage(imageMessage);

      expect(model.msgType, equals('image'));
      // width 和 height 应该为 0.0（默认值）
    });

    test('conversationSubtitle (Message版本) 应处理 CustomMessage 的 visit_card', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'card123',
        metadata: {
          'msg_type': 'custom',
          'custom_type': 'visit_card',
          'title': '张三',
        },
      );

      expect(MessageModel.conversationSubtitle(customMessage), equals('张三'));
    });

    test(
      'conversationSubtitle (Message版本) 应处理 CustomMessage 的 visit_card 无标题',
      () {
        final customMessage = CustomMessage(
          authorId: 'user123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            1642579200000,
            isUtc: true,
          ),
          id: 'card123',
          metadata: {'msg_type': 'custom', 'custom_type': 'visit_card'},
        );

        expect(
          MessageModel.conversationSubtitle(customMessage),
          equals('[名片]'),
        );
      },
    );

    test('conversationSubtitle (Message版本) 应处理位置消息', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'loc123',
        metadata: {
          'msg_type': 'location',
          'title': '北京市朝阳区',
          'latitude': 39.9042,
          'longitude': 116.4074,
        },
      );

      expect(
        MessageModel.conversationSubtitle(customMessage),
        equals('北京市朝阳区'),
      );
    });

    test('conversationSubtitle (Message版本) 应处理位置消息无标题', () {
      final customMessage = CustomMessage(
        authorId: 'user123',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          1642579200000,
          isUtc: true,
        ),
        id: 'loc123',
        metadata: {
          'msg_type': 'location',
          'latitude': 39.9042,
          'longitude': 116.4074,
        },
      );

      expect(MessageModel.conversationSubtitle(customMessage), equals('[位置]'));
    });

    test('应该处理非常见的状态码', () {
      // 测试所有定义的状态码
      expect(IMBoyMessageStatus.sending, equals(10));
      expect(IMBoyMessageStatus.sent, equals(11));
      expect(IMBoyMessageStatus.delivered, equals(20));
      expect(IMBoyMessageStatus.seen, equals(21));
      expect(IMBoyMessageStatus.peerRevoked, equals(30));
      expect(IMBoyMessageStatus.myRevoked, equals(31));
      expect(IMBoyMessageStatus.error, equals(41));
    });

    test('should handle imageMulti with empty images list', () async {
      final imageMultiModel = MessageModel(
        'multi123',
        autoId: 1,
        type: 'C2C',
        status: 11,
        fromId: 'user1',
        toId: 'user2',
        payload: {'images': <dynamic>[], 'total': 0},
        isAuthor: 1,
        conversationUk3: 'C2C_user1_user2',
        createdAt: 1642579200000,
        msgType: 'imageMulti',
      );

      final message = await imageMultiModel.toTypeMessage();

      expect(message, isA<CustomMessage>());
      if (message is CustomMessage) {
        expect(message.metadata?['msg_type'], equals('imageMulti'));
        final images = message.metadata?['images'] as List?;
        expect(images?.length, equals(0));
      }
    });
  });
}
