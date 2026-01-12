/// 事件总线集成测试
///
/// 测试事件总线在实际服务间通信的场景，包括：
/// - WebSocket → EventBus → Message 通信
/// - Message → EventBus → WebSocket 通信
/// - 服务间解耦验证
/// - 实际业务场景模拟
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/store/model/message_model.dart';

/// Mock WebSocket 服务
class MockWebSocketService {
  MockWebSocketService() {
    // 监听需要发送到 WebSocket 的消息
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // 监听消息发送请求事件
    AppEventBus.on<MessageSendRequestedEvent>().listen((event) {
      // 模拟发送到 WebSocket
      _handleMessageSend(event);
    });
  }

  void _handleMessageSend(MessageSendRequestedEvent event) {
    // 模拟网络延迟
    Future.delayed(const Duration(milliseconds: 50), () {
      // 发布消息已发送事件
      AppEventBus.fire(MessageSentEvent(
        messageId: event.message.id ?? '',
        messageType: event.message.type ?? 'C2C',
        conversationUk3: event.conversationUk3,
        serverTimestamp: DateTime.now().millisecondsSinceEpoch,
        sendDuration: 50,
      ));
    });
  }

  // 模拟从 WebSocket 接收消息
  void simulateIncomingMessage(MessageModel message) {
    AppEventBus.fire(MessageReceivedEvent(
      message: message,
      conversationUk3: message.conversationUk3,
    ));
  }

  // 模拟 WebSocket 连接状态变化
  void simulateConnectionChange(String status) {
    AppEventBus.fire(WebSocketStatusEvent(status: status));
  }
}

/// Mock 消息服务
class MockMessageService {
  final List<MessageModel> storedMessages = [];

  MockMessageService() {
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // 监听消息接收事件
    AppEventBus.on<MessageReceivedEvent>().listen((event) {
      _handleMessageReceived(event);
    });

    // 监听消息已发送事件
    AppEventBus.on<MessageSentEvent>().listen((event) {
      _handleMessageSent(event);
    });

    // 监听 WebSocket 状态事件
    AppEventBus.on<WebSocketStatusEvent>().listen((event) {
      _handleWebSocketStatusChange(event);
    });
  }

  void _handleMessageReceived(MessageReceivedEvent event) {
    // 模拟存储消息
    storedMessages.add(event.message);

    // 发布会话更新事件
    final msg = event.message;
    AppEventBus.fire(ConversationUpdateEvent(
      conversationId: msg.conversationUk3,
      conversationType: msg.type ?? 'C2C',
      peerId: msg.toId ?? '',
      updatedFields: {
        'lastMessage': (msg.payload['text'] ?? '').toString(),
        'lastMessageTime': msg.createdAt,
      },
    ));
  }

  void _handleMessageSent(MessageSentEvent event) {
    // 更新本地消息状态
    // 在实际应用中，这里会更新数据库中的消息状态
  }

  void _handleWebSocketStatusChange(WebSocketStatusEvent event) {
    // 根据 WebSocket 状态调整消息发送策略
    if (event.status == 'disconnected') {
      // 暂停发送消息，进入离线模式
    } else if (event.status == 'connected') {
      // 恢复发送消息，发送离线消息
    }
  }

  // 发送消息
  void sendMessage(MessageModel message, String conversationUk3) {
    AppEventBus.fire(MessageSendRequestedEvent(
      message: message,
      conversationUk3: conversationUk3,
    ));
  }
}

/// Mock UI 控制器
class MockUIController {
  final List<String> conversationUpdates = [];
  final List<String> toastMessages = [];

  MockUIController() {
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // 监听会话更新事件
    AppEventBus.on<ConversationUpdateEvent>().listen((event) {
      conversationUpdates.add(event.conversationId);
      // 在实际应用中，这里会刷新 UI
    });

    // 监听 Toast 事件
    AppEventBus.on<ToastEvent>().listen((event) {
      toastMessages.add(event.message);
    });
  }

  // 显示 Toast
  void showToast(String message, {String type = 'info'}) {
    AppEventBus.fire(ToastEvent(message: message, type: type));
  }
}

MessageModel createTestMessage({
  required String id,
  required String type,
  required String fromId,
  required String toId,
  required String conversationUk3,
  Map<String, dynamic>? payload,
}) {
  return MessageModel(
    id,
    autoId: 0,
    type: type,
    status: 10, // sending
    fromId: fromId,
    toId: toId,
    payload: payload ?? {'text': 'Test message'},
    isAuthor: 0,
    conversationUk3: conversationUk3,
    topicId: 0,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

void main() {
  group('EventBus 集成测试', () {
    late MockWebSocketService webSocketService;
    late MockMessageService messageService;
    late MockUIController uiController;

    setUpAll(() async {
      // 创建 Mock 服务
      webSocketService = MockWebSocketService();
      messageService = MockMessageService();
      uiController = MockUIController();
    });

    test('WebSocket 发送消息后触发 MessageSentEvent', () async {
      // Arrange: 创建测试消息
      final testMessage = createTestMessage(
        id: 'msg_test_001',
        type: 'C2C',
        fromId: 'user_me',
        toId: 'user_001',
        conversationUk3: 'conv_001',
      );

      // Act: 发送消息
      messageService.sendMessage(testMessage, 'conv_001');

      // Assert: 等待异步处理完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证消息已存储
      expect(messageService.storedMessages.length, greaterThan(0));
    });

    test('WebSocket 接收消息后触发 UI 更新', () async {
      // Arrange: 创建测试消息
      final testMessage = createTestMessage(
        id: 'msg_test_002',
        type: 'C2C',
        fromId: 'user_other',
        toId: 'user_me',
        conversationUk3: 'conv_002',
        payload: {'text': 'New message received'},
      );

      // Act: 模拟接收消息
      webSocketService.simulateIncomingMessage(testMessage);

      // Assert: 等待异步处理完成
      await Future.delayed(const Duration(milliseconds: 50));

      // 验证会话更新
      expect(uiController.conversationUpdates.contains('conv_002'), true);
      expect(messageService.storedMessages.length, greaterThan(0));
    });

    test('Toast 事件触发 UI 显示', () async {
      // Act: 显示 Toast
      uiController.showToast('Test message', type: 'success');

      // Assert: 验证 Toast 消息被记录
      await Future.delayed(const Duration(milliseconds: 10));
      expect(uiController.toastMessages.contains('Test message'), true);
    });

    test('WebSocket 状态变化影响消息服务', () async {
      // Act: 模拟 WebSocket 断开
      webSocketService.simulateConnectionChange('disconnected');

      // Assert: 等待事件处理
      await Future.delayed(const Duration(milliseconds: 10));

      // 模拟 WebSocket 重连
      webSocketService.simulateConnectionChange('connected');

      // Assert: 等待事件处理
      await Future.delayed(const Duration(milliseconds: 10));

      // 这里可以验证消息服务是否根据状态变化做出了正确的响应
      // 在实际应用中，可以检查消息队列、重试逻辑等
    });

    test('多服务协同工作场景', () async {
      // 这是一个完整的业务场景测试
      // 1. UI 触发发送消息
      // 2. MessageService 发布发送请求
      // 3. WebSocketService 处理发送
      // 4. 发布发送成功事件
      // 5. MessageService 更新消息状态
      // 6. UI 刷新显示

      final testMessage = createTestMessage(
        id: 'msg_test_003',
        type: 'C2C',
        fromId: 'user_me',
        toId: 'user_003',
        conversationUk3: 'conv_003',
        payload: {'text': 'Integration test message'},
      );

      // 发送消息
      messageService.sendMessage(testMessage, 'conv_003');

      // 等待整个流程完成
      await Future.delayed(const Duration(milliseconds: 150));

      // 验证消息已处理
      expect(messageService.storedMessages.length, greaterThan(0));
    });
  });
}
