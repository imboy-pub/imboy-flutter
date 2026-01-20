/// 事件总线（基于 event_bus_plus 极简封装）
///
/// 提供统一的事件发布/订阅机制，用于服务间解耦通信
///
/// 设计原则：
/// - KISS: 极简封装，仅暴露必要的 API
/// - 单例模式: 全局唯一实例
/// - 类型安全: 支持泛型，编译时类型检查
/// - 事件追溯: 自动时间戳支持
/// - 进度追踪: 支持 watch/complete 模式
///
/// 所有事件必须继承 AppEvent（从 event_bus_plus 导出）
///
/// 使用示例：
///
/// 1. 定义事件：
/// ```dart
/// import 'package:imboy/service/events/base_event.dart';
///
/// class UserLoginEvent extends AppEvent {
///   final String userId;
///   final String username;
///
///   const UserLoginEvent({
///     required this.userId,
///     required this.username,
///   });
///
///   @override
///   List<Object> get props => [userId, username];
/// }
/// ```
///
/// 2. 发布事件：
/// ```dart
/// // 发布事件
/// AppEventBus.fire(UserLoginEvent(
///   userId: '123',
///   username: 'imboy',
/// ));
///
/// // 发布并追踪进度
/// AppEventBus.watch(DataSyncStartEvent(syncType: 'message'));
/// // ... 处理完成
/// AppEventBus.complete(DataSyncCompleteEvent(
///   syncType: 'message',
///   success: true,
/// ));
/// ```
///
/// 3. 订阅事件：
/// ```dart
/// // 订阅特定类型事件
/// final subscription = AppEventBus.on<UserLoginEvent>().listen((event) {
///   print('用户 ${event.username} 登录成功');
/// });
///
/// // 取消订阅
/// subscription.cancel();
/// ```
///
/// 4. 使用追踪功能（调试模式）：
/// ```dart
/// // 发布带追踪的事件
/// AppEventBus.fireTracked(UserLoginEvent(userId: '123', username: 'imboy'));
///
/// // 订阅带追踪的事件
/// final subscription = AppEventBus.onTracked<UserLoginEvent>();
/// subscription.listen((event) { ... });
///
/// // 发布并监控耗时
/// AppEventBus.fireWithTiming(HeavyEvent(data: largeData));
///
/// // 获取统计信息
/// final eventStats = EventBusTracker.getEventStats();
/// final subStats = EventBusTracker.getSubscriptionStats();
/// final perfStats = EventBusTracker.getPerformanceStats();
///
/// // 打印完整报告
/// EventBusTracker.printReport();
///
/// // 重置统计
/// EventBusTracker.reset();
/// ```
///
/// 注意事项：
/// - 所有事件必须继承 AppEvent
/// - 事件对象应该是不可变的（immutable），使用 const 构造函数
/// - 及时取消不再需要的订阅，防止内存泄漏
/// - 避免在事件处理器中进行耗时操作
library;

import 'dart:async';

import 'package:event_bus_plus/event_bus_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/events/common_events.dart';

/// 底层 EventBus 实例
final _eventBus = EventBus();

/// 事件总线追踪器
///
/// 提供事件发布/订阅统计、性能监控等功能
class EventBusTracker {
  EventBusTracker();

  /// 是否启用事件追踪
  static bool get isEnabled => kDebugMode;

  /// 事件计数器（事件类型 -> 触发次数）
  static final Map<String, int> _eventCounts = {};

  /// 订阅计数器（事件类型 -> 订阅次数）
  static final Map<String, int> _subscriptionCounts = {};

  /// 事件处理耗时记录（事件类型 -> 总耗时(微秒)）
  static final Map<String, int> _eventTiming = {};

  /// 事件处理次数（用于计算平均耗时）
  static final Map<String, int> _eventTimingCounts = {};

  /// 记录事件发布
  static void trackEvent(String eventType, Map<String, dynamic>? props) {
    if (!isEnabled) return;

    _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;

    final propsStr = props != null && props.isNotEmpty
        ? ' | props: ${props.keys.join(", ")}'
        : '';

    AppLogger.debug('📡 [EVENT_BUS] Fire: $eventType$propsStr');
  }

  /// 记录订阅
  static void trackSubscription(String eventType) {
    if (!isEnabled) return;

    _subscriptionCounts[eventType] = (_subscriptionCounts[eventType] ?? 0) + 1;
    AppLogger.debug('📡 [EVENT_BUS] Subscribe: $eventType');
  }

  /// 记录事件处理耗时
  static void trackTiming(String eventType, int durationMicroseconds) {
    if (!isEnabled) return;

    _eventTiming[eventType] =
        (_eventTiming[eventType] ?? 0) + durationMicroseconds;
    _eventTimingCounts[eventType] = (_eventTimingCounts[eventType] ?? 0) + 1;

    final durationMs = durationMicroseconds / 1000;
    if (durationMs > 100) {
      AppLogger.warning(
        '⚠️ [EVENT_BUS] Slow event: $eventType took ${durationMs.toStringAsFixed(2)}ms',
      );
    }
  }

  /// 获取事件统计
  static Map<String, int> getEventStats() {
    return Map.unmodifiable(_eventCounts);
  }

  /// 获取订阅统计
  static Map<String, int> getSubscriptionStats() {
    return Map.unmodifiable(_subscriptionCounts);
  }

  /// 获取性能统计（平均耗时，单位毫秒）
  static Map<String, double> getPerformanceStats() {
    final result = <String, double>{};
    _eventTiming.forEach((eventType, totalMicroseconds) {
      final count = _eventTimingCounts[eventType] ?? 1;
      result[eventType] = (totalMicroseconds / count) / 1000;
    });
    return Map.unmodifiable(result);
  }

  /// 重置所有统计
  static void reset() {
    _eventCounts.clear();
    _subscriptionCounts.clear();
    _eventTiming.clear();
    _eventTimingCounts.clear();
    AppLogger.debug('📡 [EVENT_BUS] Stats reset');
  }

  /// 打印统计报告
  static void printReport() {
    if (!isEnabled) return;

    AppLogger.debug('========== Event Bus Report ==========');
    AppLogger.debug('📊 Event Stats:');
    _eventCounts.forEach((event, count) {
      AppLogger.debug('  $event: $count');
    });

    AppLogger.debug('📊 Subscription Stats:');
    _subscriptionCounts.forEach((event, count) {
      AppLogger.debug('  $event: $count');
    });

    AppLogger.debug('⏱ Performance Stats (avg ms):');
    final perfStats = getPerformanceStats();
    perfStats.forEach((event, avgMs) {
      AppLogger.debug('  $event: ${avgMs.toStringAsFixed(2)}ms');
    });
    AppLogger.debug('====================================');
  }
}

/// 应用事件总线（极简封装）
///
/// 静态方法访问，无需实例化
class AppEventBus {
  AppEventBus._();

  /// 获取底层 EventBus 实例（用于高级用法）
  static EventBus get i => _eventBus;

  /// 获取事件追踪器（用于调试和统计）
  ///
  /// 返回 EventBusTracker 类，提供静态方法访问统计功能
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.tracker.printReport();
  /// AppEventBus.tracker.reset();
  /// ```
  static Type get tracker => EventBusTracker;

  /// 订阅事件
  ///
  /// [T] 事件类型，必须继承 AppEvent
  ///
  /// 返回：Stream 订阅
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.on<UserLoginEvent>().listen((event) {
  ///   print('用户登录: ${event.username}');
  /// });
  /// ```
  static Stream<T> on<T extends AppEvent>() => _eventBus.on<T>();

  /// 发布事件
  ///
  /// [event] 事件对象，必须继承 AppEvent
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.fire(UserLoginEvent(userId: '123', username: 'imboy'));
  /// ```
  static void fire(AppEvent event) => _eventBus.fire(event);

  /// 发布事件（带追踪）
  ///
  /// [event] 事件对象，必须继承 AppEvent
  ///
  /// 在调试模式下会记录事件发布信息，包括事件类型和属性
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.fireTracked(UserLoginEvent(userId: '123', username: 'imboy'));
  /// ```
  static void fireTracked(AppEvent event) {
    final eventType = event.runtimeType.toString();

    // 提取事件属性用于追踪
    Map<String, dynamic>? props;
    if (event.props.isNotEmpty) {
      props = <String, dynamic>{};
      for (var i = 0; i < event.props.length; i++) {
        props['prop$i'] = event.props[i];
      }
    }

    EventBusTracker.trackEvent(eventType, props);
    _eventBus.fire(event);
  }

  /// 订阅事件（带追踪）
  ///
  /// 在调试模式下会记录订阅信息
  ///
  /// 返回：Stream 订阅
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.onTracked<UserLoginEvent>().listen((event) {
  ///   print('用户登录: ${event.username}');
  /// });
  /// ```
  static Stream<T> onTracked<T extends AppEvent>() {
    final eventType = T.toString();
    EventBusTracker.trackSubscription(eventType);

    return _eventBus.on<T>();
  }

  /// 订阅事件（带追踪和完整回调）
  ///
  /// [onData] 数据处理回调
  /// [onError] 错误处理回调
  /// [onDone] 完成回调
  /// [cancelOnError] 是否在错误时取消订阅
  ///
  /// 返回：StreamSubscription
  ///
  /// 在调试模式下会记录订阅信息
  ///
  /// 示例：
  /// ```dart
  /// final subscription = AppEventBus.onTrackedWithCallbacks<UserLoginEvent>(
  ///   onData: (event) => print('用户登录: ${event.username}'),
  ///   onError: (error) => print('Error: $error'),
  ///   onDone: () => print('Done'),
  /// );
  /// ```
  static StreamSubscription<T> onTrackedWithCallbacks<T extends AppEvent>({
    void Function(T event)? onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final eventType = T.toString();
    EventBusTracker.trackSubscription(eventType);

    final stream = _eventBus.on<T>();
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: () {
        if (onDone != null) {
          AppLogger.debug('📡 [EVENT_BUS] Done: $eventType');
          onDone();
        }
      },
      cancelOnError: cancelOnError,
    );

    return subscription;
  }

  /// 发布事件并监控耗时
  ///
  /// [event] 事件对象，必须继承 AppEvent
  ///
  /// 会记录事件发布的同步耗时，超过 100ms 会发出警告
  ///
  /// 注意：这只能监控事件发布的同步耗时，异步处理的耗时需要使用 fireTracked
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.fireWithTiming(HeavyEvent(data: largeData));
  /// ```
  static void fireWithTiming(AppEvent event) {
    final stopwatch = Stopwatch()..start();
    final eventType = event.runtimeType.toString();

    _eventBus.fire(event);

    stopwatch.stop();
    EventBusTracker.trackTiming(eventType, stopwatch.elapsedMicroseconds);
  }

  /// 发布事件并追踪进度（标记为进行中）
  ///
  /// [event] 事件对象，必须继承 AppEvent
  ///
  /// 用于需要追踪进度的异步操作
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.watch(DataSyncStartEvent(syncType: 'message'));
  /// // ... 执行同步操作
  /// ```
  static void watch(AppEvent event) => _eventBus.watch(event);

  /// 完成事件追踪
  ///
  /// [event] 完成事件
  /// [nextEvent] 可选的下一个事件，用于链式操作
  ///
  /// 示例：
  /// ```dart
  /// AppEventBus.complete(DataSyncCompleteEvent(
  ///   syncType: 'message',
  ///   success: true,
  /// ));
  /// ```
  static void complete(AppEvent event, {AppEvent? nextEvent}) =>
      _eventBus.complete(event, nextEvent: nextEvent);

  /// 响应者模式（链式处理）
  ///
  /// [responder] 处理函数，接收事件并处理
  ///
  /// 返回：Subscription，可以用于取消订阅
  ///
  /// 注意：这是 event_bus_plus 的 respond 方法，用于注册事件响应器
  /// 与 fire/on 不同，respond 会返回 Subscription 对象用于管理订阅
  ///
  /// 示例：
  /// ```dart
  /// final subscription = AppEventBus.respond<UserLoginEvent>((event) {
  ///   print('用户登录: ${event.username}');
  /// });
  ///
  /// // 取消订阅
  /// subscription.dispose();
  /// ```
  ///
  /// 如需监听并返回新事件，应使用 on() 配合 Stream map：
  /// ```dart
  /// AppEventBus.on<RequestEvent>().map((event) {
  ///   return ResponseEvent(result: 'done');
  /// }).listen((response) {
  ///   // 处理响应
  /// });
  /// ```
  static Subscription respond<T extends AppEvent>(
    void Function(T event) responder,
  ) => _eventBus.respond<T>(responder);

  /// 发布数据包装事件（兼容旧代码）
  ///
  /// 将非 AppEvent 类型的数据包装为 DataWrapperEvent 发布
  ///
  /// [data] 要发布的任意类型数据
  /// [dataType] 数据类型描述（可选）
  ///
  /// 示例：
  /// ```dart
  /// // 发布模型对象
  /// AppEventBus.fireData(conversationModel, 'ConversationModel');
  ///
  /// // 发布消息列表
  /// AppEventBus.fireData(messageList, 'List<Message>');
  /// ```
  static void fireData(dynamic data, [String? dataType]) {
    fire(
      DataWrapperEvent(
        data: data,
        dataType: dataType ?? data.runtimeType.toString(),
      ),
    );
  }
}
