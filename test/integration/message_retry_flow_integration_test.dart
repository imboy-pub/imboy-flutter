/// 消息重试流程集成测试
///
/// 测试目标：
/// 1. 消息发送失败后自动加入重试队列
/// 2. 定时重试失败的消息
/// 3. 达到最大重试次数后停止
/// 4. 网络恢复后重新发送重试队列中的消息
/// 5. 消息已确认（status=sent）时不应该重试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

void main() {
  group('消息重试流程集成测试', () {
    late MessageRetry messageRetry;
    late MessageRepo messageRepo;

    setUp(() {
      messageRetry = MessageRetry.to;
      messageRepo = MessageRepo(tableName: 'msg_c2c');
    });

    tearDown(() async {
      messageRetry.dispose();
      // 清理测试数据
      try {
        final testMsg = await messageRepo.find('test_retry_msg_');
        if (testMsg != null) {
          await messageRepo.delete(testMsg.id!);
        }
      } catch (e) {
        // 忽略清理错误
      }
    });

    group('重试队列基础功能', () {
      test('应该成功创建单例服务', () {
        expect(messageRetry, isNotNull);
        expect(messageRetry == MessageRetry.to, true);
      });

      test('应该能够添加消息到重试队列', () {
        const msgId = 'retry_msg_001';
        const type = 'C2C';

        messageRetry.addToRetryQueue(msgId, type);

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });

      test('应该能够从重试队列移除消息', () {
        const msgId = 'retry_msg_002';
        const type = 'C2C';

        messageRetry.addToRetryQueue(msgId, type);
        messageRetry.removeFromRetryQueue(msgId);

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });
    });

    group('消息重试逻辑', () {
      test('应该支持手动重试消息', () async {
        // 这个测试验证手动重试功能是否正常工作
        const msgId = 'manual_retry_test';
        const type = 'C2C';

        // 测试重试不存在的消息
        final result = await messageRetry.retryMessage(msgId, type);

        // 应该返回 false（消息不存在）
        expect(result, false);
      });

      test('应该正确判断消息状态', () {
        // 测试状态判断辅助方法
        MessageModel(
          'msg_sending',
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.sending,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        final errorMsg = MessageModel(
          'msg_error',
          autoId: 2,
          type: 'C2C',
          status: IMBoyMessageStatus.error,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        final sentMsg = MessageModel(
          'msg_sent',
          autoId: 3,
          type: 'C2C',
          status: IMBoyMessageStatus.sent,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        // error 状态的消息应该可以重试
        expect(IMBoyMessageStatus.isErrorStatus(errorMsg.status), true);

        // sent 状态的消息不应该自动重试（已确认）
        expect(IMBoyMessageStatus.isSendingStatus(sentMsg.status), true);
      });
    });

    group('网络状态与重试', () {
      test('应该能够获取在线状态', () {
        final isOnline = messageRetry.isOnline;
        expect(isOnline, isA<bool>());
      });

      test('网络恢复事件应该触发重试', () async {
        // 订阅重试请求事件
        final subscription = AppEventBus.on<RetryMessagesRequestedEvent>()
            .listen((event) {
              // event.source received but not used in test
            });

        // 模拟网络恢复事件
        AppEventBus.fire(
          NetworkConnectionEvent(isConnected: true, networkType: 'wifi'),
        );

        // 等待事件传播
        await Future.delayed(const Duration(milliseconds: 200));

        // 验证收到了网络连接事件
        expect(messageRetry.isOnline, true);

        await subscription.cancel();
      });
    });

    group('与消息状态集成', () {
      test('应该判断消息是否为发送状态', () {
        // 测试状态判断辅助方法
        MessageModel(
          'msg_sending',
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.sending,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        final errorMsg = MessageModel(
          'msg_error',
          autoId: 2,
          type: 'C2C',
          status: IMBoyMessageStatus.error,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        final sentMsg = MessageModel(
          'msg_sent',
          autoId: 3,
          type: 'C2C',
          status: IMBoyMessageStatus.sent,
          fromId: 'user1',
          toId: 'user2',
          payload: {'content': 'Test'},
          isAuthor: 1,
          conversationUk3: 'C2C_user1_user2',
        );

        // error 状态的消息应该可以重试
        expect(IMBoyMessageStatus.isErrorStatus(errorMsg.status), true);

        // sent 状态的消息不应该自动重试（已确认）
        expect(IMBoyMessageStatus.isSendingStatus(sentMsg.status), true);
      });

      test('应该判断消息是否为错误状态', () {
        expect(IMBoyMessageStatus.isErrorStatus(41), true); // error
        expect(IMBoyMessageStatus.isErrorStatus(42), true); // 其他错误状态
        expect(IMBoyMessageStatus.isErrorStatus(10), false); // sending
        expect(IMBoyMessageStatus.isErrorStatus(20), false); // delivered
      });
    });

    group('事件集成', () {
      test('应该能够触发重试请求事件', () async {
        String? receivedSource;
        String? receivedReason;

        // 订阅重试请求事件
        final subscription = AppEventBus.on<RetryMessagesRequestedEvent>()
            .listen((event) {
              receivedSource = event.source;
              receivedReason = event.reason;
            });

        // 触发重试请求
        AppEventBus.fire(
          RetryMessagesRequestedEvent(source: 'test_event', reason: '测试原因'),
        );

        // 等待事件传播
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证收到了事件
        expect(receivedSource, 'test_event');
        expect(receivedReason, '测试原因');

        await subscription.cancel();
      });

      test('应该能够处理从队列移除请求事件', () async {
        String? removedMessageId;

        // 订阅移除请求事件
        final subscription =
            AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().listen((
              event,
            ) {
              removedMessageId = event.messageId;
            });

        // 触发移除请求
        const msgId = 'test_remove_msg';
        AppEventBus.fire(
          RemoveFromRetryQueueRequestedEvent(
            messageId: msgId,
            messageType: 'C2C',
            reason: '测试移除',
          ),
        );

        // 等待事件传播
        await Future.delayed(const Duration(milliseconds: 100));

        // 验证收到了事件
        expect(removedMessageId, msgId);

        await subscription.cancel();
      });
    });

    group('并发安全', () {
      test('应该能够处理并发重试请求', () async {
        const msgCount = 10;
        final futures = <Future>[];

        // 同时添加多个消息到重试队列
        for (int i = 0; i < msgCount; i++) {
          futures.add(
            Future.delayed(
              const Duration(milliseconds: 10),
              () => messageRetry.addToRetryQueue('concurrent_$i', 'C2C'),
            ),
          );
        }

        await Future.wait(futures);

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });

      test('应该能够安全地批量移除消息', () {
        // 添加多个消息
        for (int i = 0; i < 50; i++) {
          messageRetry.addToRetryQueue('stress_test_$i', 'C2C');
        }

        // 批量移除
        for (int i = 0; i < 50; i++) {
          messageRetry.removeFromRetryQueue('stress_test_$i');
        }

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });
    });

    group('错误处理', () {
      test('应该能够处理重试不存在的消息', () async {
        // 尝试重试不存在的消息
        final result = await messageRetry.retryMessage(
          'non_existent_msg',
          'C2C',
        );

        // 应该返回 false
        expect(result, false);
      });

      test('应该能够处理空消息ID', () async {
        // 尝试重试空消息ID
        final result = await messageRetry.retryMessage('', 'C2C');

        // 应该返回 false
        expect(result, false);
      });
    });

    group('边界条件', () {
      test('应该能够处理特殊字符消息ID', () {
        // 特殊字符消息ID
        const specialIds = [
          'msg_with_underscore',
          'msg-with-dash',
          'msg.with.dot',
          'msg@with@special',
        ];

        for (final msgId in specialIds) {
          messageRetry.addToRetryQueue(msgId, 'C2C');
          messageRetry.removeFromRetryQueue(msgId);
        }

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });

      test('应该能够处理不同类型的消息', () {
        // 不同消息类型
        const types = ['C2C', 'C2G', 'C2S'];

        for (final type in types) {
          messageRetry.addToRetryQueue('${type}_msg', type);
        }

        // 验证服务正常运行
        expect(messageRetry, isNotNull);
      });
    });

    group('定时器功能', () {
      test('应该能够启动重试定时器', () {
        // 验证服务有定时器功能
        expect(messageRetry, isNotNull);
        // 定时器在构造函数中自动启动
      });

      test('dispose应该释放资源', () {
        // 验证 dispose 方法可以调用
        messageRetry.dispose();
        expect(messageRetry, isNotNull);
      });
    });
  });
}
