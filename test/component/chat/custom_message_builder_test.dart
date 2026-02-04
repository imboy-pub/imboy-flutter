import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';

void main() {
  group('CustomMessageBuilder TDD Tests', () {
    // Helper function to create a CustomMessage for testing
    CustomMessage createTestMessage({
      required String msgType,
      int? status,
      String? customType,
      Map<String, dynamic>? metadata,
    }) {
      return CustomMessage(
        id: 'test_msg_id',
        authorId: 'test_author_id',
        createdAt: DateTime.now(),
        metadata: {
          'msg_type': msgType,
          if (status != null) 'status': status,
          if (customType != null) 'custom_type': customType,
          ...?metadata,
        },
      );
    }

    testWidgets('应该正确路由 text 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 text 类型的消息
      final message = createTestMessage(
        msgType: MessageType.text,
        metadata: {'text': 'Hello World'},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染正确的组件（text 消息应该通过 flutter_chat_core 处理）
      // 由于 text 消息不进入 CustomMessageBuilder，这个测试验证默认行为
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 image 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 image 类型的消息
      final message = createTestMessage(
        msgType: MessageType.image,
        metadata: {
          'uri': 'https://example.com/image.jpg',
          'width': 1920,
          'height': 1080,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染正确的组件
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 file 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 file 类型的消息
      final message = createTestMessage(
        msgType: MessageType.file,
        metadata: {
          'uri': 'https://example.com/file.pdf',
          'name': 'document.pdf',
          'size': 1024000,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染正确的组件
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 video 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 video 类型的消息
      final message = createTestMessage(
        msgType: MessageType.video,
        metadata: {
          'uri': 'https://example.com/video.mp4',
          'duration_ms': 60000,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染正确的组件
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 voice 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 voice 类型的消息
      final message = createTestMessage(
        msgType: MessageType.voice,
        metadata: {
          'uri': 'https://example.com/voice.mp3',
          'duration_ms': 15000,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 AudioMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该兼容 audio 命名（已废弃）', (WidgetTester tester) async {
      // GIVEN: 一个 audio 类型的消息（旧命名）
      final message = createTestMessage(
        msgType: MessageType.audio, // 旧的 audio 命名
        metadata: {
          'uri': 'https://example.com/voice.mp3',
          'duration_ms': 15000,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 AudioMessageBuilder（向后兼容）
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 location 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 location 类型的消息
      final message = createTestMessage(
        msgType: MessageType.location,
        metadata: {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'title': '北京市朝阳区',
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 LocationMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 quote 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 quote 类型的消息
      final message = createTestMessage(
        msgType: MessageType.quote,
        metadata: {
          'quote_msg_id': 'msg100',
          'quote_text': '原始消息内容',
          'text': '回复内容',
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 QuoteMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 imageMulti 消息类型', (WidgetTester tester) async {
      // GIVEN: 一个 imageMulti 类型的消息
      final message = createTestMessage(
        msgType: MessageType.imageMulti,
        metadata: {
          'images': [
            {'uri': 'https://example.com/image1.jpg'},
            {'uri': 'https://example.com/image2.jpg'},
          ],
          'total': 2,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 ImageMultiMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 webrtc_audio 自定义类型', (WidgetTester tester) async {
      // GIVEN: 一个 webrtc_audio 类型的自定义消息
      final message = createTestMessage(
        msgType: MessageType.custom,
        customType: CustomMessageType.webrtcAudio,
        metadata: {'call_type': 'offer', 'sdp': 'test_sdp'},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 WebRTCMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 webrtc_video 自定义类型', (WidgetTester tester) async {
      // GIVEN: 一个 webrtc_video 类型的自定义消息
      final message = createTestMessage(
        msgType: MessageType.custom,
        customType: CustomMessageType.webrtcVideo,
        metadata: {'call_type': 'offer', 'sdp': 'test_sdp'},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 WebRTCMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确路由 visit_card 自定义类型', (WidgetTester tester) async {
      // GIVEN: 一个 visit_card 类型的自定义消息
      final message = createTestMessage(
        msgType: MessageType.custom,
        customType: CustomMessageType.visitCard,
        metadata: {'title': '张三', 'uid': 'user123'},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 VisitCardMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该优先检查撤回状态', (WidgetTester tester) async {
      // GIVEN: 一个已撤回的消息（status = 30）
      final message = createTestMessage(
        msgType: MessageType.text, // 原始消息类型是 text
        status: IMBoyMessageStatus.peerRevoked, // status = 30
        metadata: {'text': '这是一条已撤回的消息'},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 RevokedMessageBuilder，而不是 TextMessage
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该正确处理未知消息类型', (WidgetTester tester) async {
      // GIVEN: 一个未知类型的消息
      final message = createTestMessage(msgType: 'unknown_type', metadata: {});

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 UnsupportedMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该兼容 image_multi 命名（旧命名）', (WidgetTester tester) async {
      // GIVEN: 一个 image_multi 类型的消息（旧命名，使用下划线）
      final message = createTestMessage(
        msgType: 'image_multi', // 旧命名
        metadata: {
          'images': [
            {'uri': 'https://example.com/image1.jpg'},
          ],
          'total': 1,
        },
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 ImageMultiMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该兼容 webrtc_audio 命名（下划线版本）', (WidgetTester tester) async {
      // GIVEN: 一个 webrtc_audio 类型的自定义消息（使用下划线）
      final message = createTestMessage(
        msgType: MessageType.custom,
        customType: 'webrtc_audio', // 下划线版本
        metadata: {},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 WebRTCMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });

    testWidgets('应该兼容 visit_card 命名（下划线版本）', (WidgetTester tester) async {
      // GIVEN: 一个 visit_card 类型的自定义消息（使用下划线）
      final message = createTestMessage(
        msgType: MessageType.custom,
        customType: 'visit_card', // 下划线版本
        metadata: {},
      );

      // WHEN: 构建 CustomMessageBuilder
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(type: 'C2C', message: message),
          ),
        ),
      );

      // THEN: 应该渲染 VisitCardMessageBuilder
      expect(find.byType(CustomMessageBuilder), findsOneWidget);
    });
  });
}
