import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 初始化测试环境
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock SharedPreferences - 单元测试中需要
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // 设置测试用户 ID
    await StorageService.to.setString(Keys.currentUid, 'user1');
  });

  group('Message Routing TDD Tests', () {
    group('MessageModel.toTypeMessage 路由测试', () {
      test('text 消息应该路由到 TextMessage', () async {
        // GIVEN: 一个 text 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.text,
          payload: {'text': 'Hello World'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 TextMessage
        expect(message, isA<TextMessage>());
      });

      test('image 消息应该路由到 ImageMessage', () async {
        // GIVEN: 一个 image 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
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

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 ImageMessage
        expect(message, isA<ImageMessage>());
        final imgMsg = message as ImageMessage;
        expect(imgMsg.source, contains('image.jpg'));
      });

      test('file 消息应该路由到 FileMessage', () async {
        // GIVEN: 一个 file 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.file,
          payload: {
            'uri': 'https://example.com/file.pdf',
            'name': 'document.pdf',
            'size': 1024000,
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 FileMessage
        expect(message, isA<FileMessage>());
        final fileMsg = message as FileMessage;
        expect(fileMsg.name, equals('document.pdf'));
      });

      test('video 消息应该路由到 VideoMessage', () async {
        // GIVEN: 一个 video 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.video,
          payload: {
            'uri': 'https://example.com/video.mp4',
            'duration_ms': 60000,
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 VideoMessage
        expect(message, isA<VideoMessage>());
      });

      test('voice 消息应该路由到 AudioMessage（新规范）', () async {
        // GIVEN: 一个 voice 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.voice, // 使用 voice
          payload: {
            'uri': 'https://example.com/voice.mp3',
            'duration_ms': 15000,
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 AudioMessage
        expect(message, isA<AudioMessage>());
        final audioMsg = message as AudioMessage;
        expect(audioMsg.duration.inMilliseconds, equals(15000));
      });

      test('audio 消息应该路由到 AudioMessage（向后兼容）', () async {
        // GIVEN: 一个 audio 类型的 MessageModel（旧命名）
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.audio, // 使用旧的 audio
          payload: {
            'uri': 'https://example.com/voice.mp3',
            'duration_ms': 15000,
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 AudioMessage
        expect(message, isA<AudioMessage>());
      });

      test('location 消息应该路由到 CustomMessage', () async {
        // GIVEN: 一个 location 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.location,
          payload: {
            'latitude': 39.9042,
            'longitude': 116.4074,
            'title': '北京市朝阳区',
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 CustomMessage（location 使用自定义 builder）
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['msg_type'], equals(MessageType.location));
      });

      test('quote 消息应该路由到 CustomMessage', () async {
        // GIVEN: 一个 quote 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.quote,
          payload: {
            'quote_msg_id': 'msg100',
            'quote_text': '原始消息内容',
            'text': '回复内容',
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 CustomMessage
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['msg_type'], equals(MessageType.quote));
      });

      test('imageMulti 消息应该路由到 CustomMessage', () async {
        // GIVEN: 一个 imageMulti 类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.imageMulti,
          payload: {
            'images': [
              {'uri': 'https://example.com/image1.jpg'},
              {'uri': 'https://example.com/image2.jpg'},
            ],
            'total': 2,
          },
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 CustomMessage
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['msg_type'], equals(MessageType.imageMulti));
      });

      test('撤回的消息应该保留原始 msg_type 并使用 CustomMessage', () async {
        // GIVEN: 一个撤回的消息
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.peerRevoked, // 30
          fromId: 'user1',
          toId: 'user2',
          msgType: MessageType.text, // 原始类型是 text
          payload: {'text': '已撤回的消息'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 CustomMessage，且保留原始 msg_type
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['msg_type'], equals(MessageType.text));
        expect(
          message.metadata?['status'],
          equals(IMBoyMessageStatus.peerRevoked),
        );
      });

      test('未知的消息类型应该路由到 CustomMessage 并标记为 unsupported', () async {
        // GIVEN: 一个未知类型的 MessageModel
        final model = MessageModel(
          'msg123',
          autoId: 1,
          type: 'C2C',
          status: 11,
          fromId: 'user1',
          toId: 'user2',
          msgType: 'unknown_type',
          payload: {},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
          createdAt: 1642579200000,
        );

        // WHEN: 转换为 Message
        final message = await model.toTypeMessage();

        // THEN: 应该是 CustomMessage，且标记为 unsupported
        expect(message, isA<CustomMessage>());
        expect(message.metadata?['unsupported'], isTrue);
        expect(message.metadata?['error'], equals('unknown_msg_type'));
      });
    });

    group('MessageModel.fromMessage 序列化测试', () {
      test('TextMessage 应该正确序列化为 MessageModel', () {
        // GIVEN: 一个 TextMessage
        final textMessage = TextMessage(
          authorId: 'user1',
          id: 'msg123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1642579200000),
          text: 'Hello World',
          metadata: {'conversation_uk3': 'C2C_user1_user2', 'peer_id': 'user2'},
        );

        // WHEN: 转换为 MessageModel
        final model = MessageModel.fromMessage(
          textMessage,
          currentUid: 'test_user',
        );

        // THEN: msgType 应该是 text
        expect(model.msgType, equals(MessageType.text));
        expect(model.payload['text'], equals('Hello World'));
      });

      test('ImageMessage 应该正确序列化为 MessageModel', () {
        // GIVEN: 一个 ImageMessage
        final imageMessage = ImageMessage(
          authorId: 'user1',
          id: 'msg123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1642579200000),
          source: 'https://example.com/image.jpg',
          width: 1920,
          height: 1080,
          size: 102400,
          metadata: {'conversation_uk3': 'C2C_user1_user2', 'peer_id': 'user2'},
        );

        // WHEN: 转换为 MessageModel
        final model = MessageModel.fromMessage(
          imageMessage,
          currentUid: 'test_user',
        );

        // THEN: msgType 应该是 image，payload 应该包含 uri
        expect(model.msgType, equals(MessageType.image));
        expect(model.payload['uri'], equals('https://example.com/image.jpg'));
      });

      test('AudioMessage 应该正确序列化为 MessageModel 并使用 voice 类型', () {
        // GIVEN: 一个 AudioMessage
        final audioMessage = AudioMessage(
          authorId: 'user1',
          id: 'msg123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1642579200000),
          source: 'https://example.com/voice.mp3',
          duration: const Duration(milliseconds: 15000),
          metadata: {'conversation_uk3': 'C2C_user1_user2', 'peer_id': 'user2'},
        );

        // WHEN: 转换为 MessageModel
        final model = MessageModel.fromMessage(
          audioMessage,
          currentUid: 'test_user',
        );

        // THEN: msgType 应该是 voice（新规范）
        expect(model.msgType, equals('voice'));
        expect(model.payload['duration_ms'], equals(15000));
      });

      test('VideoMessage 应该正确序列化为 MessageModel', () {
        // GIVEN: 一个 VideoMessage
        final videoMessage = VideoMessage(
          authorId: 'user1',
          id: 'msg123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1642579200000),
          source: 'https://example.com/video.mp4',
          metadata: {
            'conversation_uk3': 'C2C_user1_user2',
            'peer_id': 'user2',
            'duration_ms': 60000,
          },
        );

        // WHEN: 转换为 MessageModel
        final model = MessageModel.fromMessage(
          videoMessage,
          currentUid: 'test_user',
        );

        // THEN: msgType 应该是 video
        expect(model.msgType, equals(MessageType.video));
        expect(model.payload['duration_ms'], equals(60000));
      });

      test('FileMessage 应该正确序列化为 MessageModel', () {
        // GIVEN: 一个 FileMessage
        final fileMessage = FileMessage(
          authorId: 'user1',
          id: 'msg123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1642579200000),
          name: 'document.pdf',
          size: 1024000,
          source: 'https://example.com/file.pdf',
          metadata: {'conversation_uk3': 'C2C_user1_user2', 'peer_id': 'user2'},
        );

        // WHEN: 转换为 MessageModel
        final model = MessageModel.fromMessage(
          fileMessage,
          currentUid: 'test_user',
        );

        // THEN: msgType 应该是 file
        expect(model.msgType, equals(MessageType.file));
        expect(model.payload['name'], equals('document.pdf'));
        expect(model.payload['uri'], equals('https://example.com/file.pdf'));
      });
    });
  });
}
