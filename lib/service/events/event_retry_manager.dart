/// 事件重试管理器
///
/// 为关键事件提供失败重试功能，支持自定义重试策略
///
/// 设计原则：
/// - KISS: 简单易用的重试机制
/// - 灵活性: 支持自定义重试次数、延迟时间等
/// - 可追踪性: 详细的重试日志记录
/// - 自动化: 定时自动处理重试队列
///
/// 使用示例：
/// ```dart
/// // 1. 创建重试管理器实例
/// final retryManager = EventRetryManager();
///
/// // 2. 启动重试定时器
/// retryManager.startRetryTimer();
///
/// // 3. 添加重试任务
/// retryManager.addRetryTask(
///   eventId: 'msg_123',
///   event: MessageSendRequestedEvent(...),
///   maxRetries: 3,
///   delay: Duration(seconds: 5),
/// );
///
/// // 4. 监听重试失败事件
/// AppEventBus.on<EventRetryFailedEvent>().listen((event) {
///   print('事件重试彻底失败: ${event.eventId}');
/// });
///
/// // 5. 成功后移除重试任务
/// retryManager.removeRetryTask('msg_123');
///
/// // 6. 释放资源
/// retryManager.dispose();
/// ```
library;

import 'dart:async';

import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/service/events/common_events.dart'
    show EventRetryFailedEvent;

/// 事件重试管理器
///
/// 管理需要重试的事件队列，提供自动重试机制
class EventRetryManager {
  /// 重试队列，key 为事件 ID
  final Map<String, _RetryEntry> _retryQueue = {};

  /// 重试定时器
  Timer? _retryTimer;

  /// 重试处理间隔（默认 10 秒）
  final Duration processingInterval;

  /// 是否已启动
  bool _isStarted = false;

  /// 构造函数
  ///
  /// [processingInterval] 重试队列处理间隔，默认 10 秒
  EventRetryManager({this.processingInterval = const Duration(seconds: 10)});

  /// 添加重试任务
  ///
  /// [eventId] 事件唯一标识符
  /// [event] 需要重试的事件对象
  /// [maxRetries] 最大重试次数，默认 3 次
  /// [delay] 重试延迟时间，默认 5 秒
  /// [onRetry] 可选的重试回调函数
  void addRetryTask({
    required String eventId,
    required AppEvent event,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 5),
    void Function(int attempt)? onRetry,
  }) {
    // 如果事件已存在，先移除旧的
    if (_retryQueue.containsKey(eventId)) {
      AppLogger.warning('🔄 [EVENT_RETRY] 事件 $eventId 已存在于重试队列，将被覆盖');
      removeRetryTask(eventId);
    }

    _retryQueue[eventId] = _RetryEntry(
      event: event,
      maxRetries: maxRetries,
      delay: delay,
      lastAttempt: DateTime.now(),
      onRetry: onRetry,
    );

    AppLogger.debug(
      '📥 [EVENT_RETRY] 添加事件到重试队列: $eventId, '
      '最大重试次数: $maxRetries, 重试延迟: ${delay.inSeconds}秒',
    );
  }

  /// 移除重试任务
  ///
  /// [eventId] 事件唯一标识符
  /// [reason] 移除原因，用于日志记录
  void removeRetryTask(String eventId, {String? reason}) {
    final removed = _retryQueue.remove(eventId);
    if (removed != null) {
      final reasonStr = reason != null ? ' ($reason)' : '';
      AppLogger.debug('📤 [EVENT_RETRY] 从重试队列移除: $eventId$reasonStr');
    }
  }

  /// 检查事件是否在重试队列中
  bool hasRetryTask(String eventId) {
    return _retryQueue.containsKey(eventId);
  }

  /// 获取当前重试次数
  int? getCurrentRetryCount(String eventId) {
    return _retryQueue[eventId]?.currentRetry;
  }

  /// 启动重试定时器
  ///
  /// 定时处理重试队列中的事件
  void startRetryTimer() {
    if (_isStarted) {
      AppLogger.warning('⚠️ [EVENT_RETRY] 重试定时器已在运行');
      return;
    }

    _isStarted = true;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(processingInterval, (_) {
      _processRetries();
    });

    AppLogger.info(
      '✅ [EVENT_RETRY] 重试定时器已启动，间隔: ${processingInterval.inSeconds}秒',
    );
  }

  /// 停止重试定时器
  void stopRetryTimer() {
    if (!_isStarted) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _isStarted = false;

    AppLogger.info('⏸️ [EVENT_RETRY] 重试定时器已停止');
  }

  /// 立即处理重试队列
  ///
  /// 用于手动触发重试处理，例如网络恢复时
  void processRetriesNow() {
    AppLogger.debug('🚀 [EVENT_RETRY] 手动触发重试处理');
    _processRetries();
  }

  /// 处理重试队列
  void _processRetries() {
    if (_retryQueue.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final toRemove = <String>[];

    AppLogger.debug('🔄 [EVENT_RETRY] 开始处理重试队列，待处理事件数: ${_retryQueue.length}');

    // 遍历重试队列
    for (final entry in _retryQueue.entries) {
      final eventId = entry.key;
      final retryEntry = entry.value;

      // 检查是否到达重试时间
      if (now.difference(retryEntry.lastAttempt) < retryEntry.delay) {
        continue;
      }

      // 检查是否超过最大重试次数
      if (retryEntry.currentRetry >= retryEntry.maxRetries) {
        // 达到最大重试次数，标记为失败
        toRemove.add(eventId);

        AppLogger.error(
          '❌ [EVENT_RETRY] 事件重试失败: $eventId, '
          '已达到最大重试次数 ${retryEntry.maxRetries}',
        );

        // 发布重试失败事件
        AppEventBus.fire(
          EventRetryFailedEvent(
            eventId: eventId,
            eventType: retryEntry.event.runtimeType.toString(),
            attempts: retryEntry.maxRetries,
          ),
        );

        continue;
      }

      // 执行重试
      _retryEvent(eventId, retryEntry);
    }

    // 移除已完成或失败的事件
    for (final eventId in toRemove) {
      _retryQueue.remove(eventId);
    }

    if (_retryQueue.isNotEmpty) {
      AppLogger.debug('📊 [EVENT_RETRY] 重试处理完成，剩余事件数: ${_retryQueue.length}');
    }
  }

  /// 重试单个事件
  void _retryEvent(String eventId, _RetryEntry entry) {
    // 更新重试次数和最后尝试时间
    entry.currentRetry++;
    entry.lastAttempt = DateTime.now();

    AppLogger.info(
      '🔄 [EVENT_RETRY] 重试事件: $eventId, '
      '第 ${entry.currentRetry}/${entry.maxRetries} 次',
    );

    try {
      // 通过事件总线重新发布事件
      AppEventBus.fire(entry.event);

      // 执行回调（如果有）
      entry.onRetry?.call(entry.currentRetry);

      AppLogger.debug('✅ [EVENT_RETRY] 事件已重新发布: $eventId');
    } catch (e) {
      AppLogger.error('❌ [EVENT_RETRY] 事件重试发布失败: $eventId', e);
    }
  }

  /// 清空重试队列
  ///
  /// [reason] 清空原因
  void clearQueue({String? reason}) {
    final count = _retryQueue.length;
    _retryQueue.clear();

    final reasonStr = reason != null ? ' ($reason)' : '';
    AppLogger.info('🗑️ [EVENT_RETRY] 清空重试队列: $count 个事件$reasonStr');
  }

  /// 获取重试队列统计信息
  Map<String, dynamic> getQueueStats() {
    return {
      'total': _retryQueue.length,
      'isStarted': _isStarted,
      'events': _retryQueue.map(
        (eventId, entry) => MapEntry(eventId, {
          'type': entry.event.runtimeType.toString(),
          'currentRetry': entry.currentRetry,
          'maxRetries': entry.maxRetries,
          'delay': entry.delay.inSeconds,
        }),
      ),
    };
  }

  /// 释放资源
  void dispose() {
    stopRetryTimer();
    clearQueue(reason: 'dispose');
    AppLogger.info('🔚 [EVENT_RETRY] 重试管理器已释放');
  }
}

/// 重试条目内部类
class _RetryEntry {
  /// 需要重试的事件
  final AppEvent event;

  /// 最大重试次数
  final int maxRetries;

  /// 重试延迟时间
  final Duration delay;

  /// 最后尝试时间
  DateTime lastAttempt;

  /// 当前重试次数
  int currentRetry;

  /// 重试回调函数
  final void Function(int attempt)? onRetry;

  _RetryEntry({
    required this.event,
    required this.maxRetries,
    required this.delay,
    required this.lastAttempt,
    this.onRetry,
  }) : currentRetry = 0;
}
