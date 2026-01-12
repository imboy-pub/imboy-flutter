/// 事件重试管理器使用示例
///
/// 本文件展示如何在服务中集成和使用 EventRetryManager
///
/// 场景：当消息发送失败时，使用事件重试管理器自动重试
library;

import 'package:get/get.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/store/model/message_model.dart';

/// 示例服务：展示如何集成 EventRetryManager
///
/// 在实际项目中，您可以参考此示例在您的服务中集成事件重试功能
class ExampleServiceWithRetry extends GetxService with EventSubscriptionManager {
  static ExampleServiceWithRetry get to => Get.find();

  /// 事件重试管理器实例
  late final EventRetryManager _eventRetryManager;

  @override
  void onInit() {
    super.onInit();

    // 1. 初始化事件重试管理器
    _eventRetryManager = EventRetryManager(
      processingInterval: const Duration(seconds: 10),
    );

    // 2. 启动重试定时器
    _eventRetryManager.startRetryTimer();

    // 3. 订阅事件重试失败事件
    subscribeTo(
      AppEventBus.on<EventRetryFailedEvent>().listen((event) {
        _handleRetryFailure(event);
      }),
    );

    // 4. 订阅网络状态变化事件
    subscribeTo(
      AppEventBus.on<NetworkConnectionEvent>().listen((event) {
        if (event.isConnected) {
          // 网络恢复时，立即处理重试队列
          _eventRetryManager.processRetriesNow();
        }
      }),
    );

    // 5. 订阅消息发送失败事件
    subscribeTo(
      AppEventBus.on<MessageSendFailedEvent>().listen((event) {
        _handleMessageSendFailed(event);
      }),
    );
  }

  @override
  void onClose() {
    // 释放事件重试管理器资源
    _eventRetryManager.dispose();
    // 取消所有事件订阅
    cancelAllSubscriptions();
    super.onClose();
  }

  /// 处理消息发送失败事件
  ///
  /// 将失败的消息发送请求添加到重试队列
  void _handleMessageSendFailed(MessageSendFailedEvent event) {
    // 如果不会自动重试，或者重试次数已用完，则添加到事件重试管理器
    if (!event.willRetry || event.currentRetryCount >= event.maxRetryCount) {
      // 创建一个新的消息发送请求事件
      // 注意：在实际使用中，您需要从数据库或其他地方获取完整的消息模型
      // 这里只是示例，展示如何使用事件重试管理器
      //
      // 示例代码（伪代码）：
      // final message = await MessageRepo().find(event.messageId);
      // final retryEvent = MessageSendRequestedEvent(
      //   message: message!,
      //   conversationUk3: event.conversationUk3,
      //   isOffline: false,
      //   priority: 5,
      // );

      // 由于 MessageModel 需要很多必填参数，这里使用一个示例事件
      // 在实际项目中，您应该使用真实的消息数据和完整的事件
      final retryEvent = MessageSendRequestedEvent(
        message: MessageModel(
          '', // id
          autoId: 0,
          type: event.messageType,
          status: 0,
          fromId: '',
          toId: '',
          payload: {},
          isAuthor: 0,
          conversationUk3: event.conversationUk3,
        ),
        conversationUk3: event.conversationUk3,
        isOffline: false,
        priority: 5,
      );

      // 添加到事件重试队列
      _eventRetryManager.addRetryTask(
        eventId: event.messageId,
        event: retryEvent,
        maxRetries: 3,
        delay: const Duration(seconds: 5),
        onRetry: (attempt) {
          AppLogger.debug('消息 ${event.messageId} 第 $attempt 次重试');
        },
      );
    }
  }

  /// 处理事件重试失败
  ///
  /// 当事件重试达到最大次数仍然失败时的处理逻辑
  void _handleRetryFailure(EventRetryFailedEvent event) {
    AppLogger.error(
      '事件重试彻底失败: ${event.eventId}, '
      '类型: ${event.eventType}, '
      '尝试次数: ${event.attempts}',
    );

    // 这里可以添加您的处理逻辑，例如：
    // 1. 通知用户消息发送失败
    // 2. 记录到本地日志
    // 3. 上报到错误监控系统
    // 4. 标记消息为永久失败状态

    // 示例：发布 Toast 提示
    AppEventBus.fire(ToastEvent(
      message: '消息发送失败，请检查网络连接',
      type: 'error',
      duration: 3000,
    ));
  }

  /// 手动添加消息到重试队列
  ///
  /// [messageId] 消息 ID
  /// [messageType] 消息类型（C2C, C2G 等）
  void addMessageToRetry(String messageId, String messageType) {
    // 检查是否已在重试队列中
    if (_eventRetryManager.hasRetryTask(messageId)) {
      AppLogger.debug('消息 $messageId 已在重试队列中');
      return;
    }

    // 创建消息发送请求事件
    // 注意：这是示例代码，实际使用时需要从数据库获取完整的消息模型
    final retryEvent = MessageSendRequestedEvent(
      message: MessageModel(
        '', // id
        autoId: 0,
        type: messageType,
        status: 0,
        fromId: '',
        toId: '',
        payload: {},
        isAuthor: 0,
        conversationUk3: '', // 实际使用时应该是真实的会话 ID
      ),
      conversationUk3: '', // 实际使用时应该是真实的会话 ID
      isOffline: false,
      priority: 5,
    );

    // 添加到重试队列
    _eventRetryManager.addRetryTask(
      eventId: messageId,
      event: retryEvent,
      maxRetries: 3,
      delay: const Duration(seconds: 5),
      onRetry: (attempt) {
        AppLogger.debug('消息 $messageId 第 $attempt 次重试');
      },
    );
  }

  /// 从重试队列移除消息
  ///
  /// [messageId] 消息 ID
  /// [reason] 移除原因
  void removeFromRetry(String messageId, {String? reason}) {
    _eventRetryManager.removeRetryTask(messageId, reason: reason);
  }

  /// 获取重试队列统计信息
  Map<String, dynamic> getRetryQueueStats() {
    return _eventRetryManager.getQueueStats();
  }

  /// 打印重试队列统计信息
  void printRetryQueueStats() {
    final stats = getRetryQueueStats();
    AppLogger.debug('========== 事件重试队列统计 ==========');
    AppLogger.debug('总数: ${stats['total']}');
    AppLogger.debug('已启动: ${stats['isStarted']}');
    AppLogger.debug('事件列表:');
    for (final entry in stats['events'].entries) {
      final eventId = entry.key;
      final info = entry.value;
      AppLogger.debug('  $eventId: ${info['type']}, '
          '重试 ${info['currentRetry']}/${info['maxRetries']}, '
          '延迟 ${info['delay']}秒');
    }
    AppLogger.debug('====================================');
  }
}

// ============================================================================
// 使用示例
// ============================================================================

/// 使用示例代码
///
/// 在您的应用初始化代码中：
/// ```dart
/// // 注册服务
/// Get.put(ExampleServiceWithRetry());
///
/// // 后续使用
/// ExampleServiceWithRetry.to.addMessageToRetry('msg_123', 'C2C');
/// ```
///
/// 监听重试失败事件：
/// ```dart
/// AppEventBus.on<EventRetryFailedEvent>().listen((event) {
///   // 处理重试失败
///   showErrorDialog('消息发送失败，请稍后重试');
/// });
/// ```
