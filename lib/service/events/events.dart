/// 服务层事件系统统一导出文件
///
/// 本文件导出所有事件类型和事件总线服务，方便其他模块统一导入使用
///
/// 使用示例：
/// ```dart
/// import 'package:imboy/service/events/events.dart';
///
/// // 发布事件（静态方法调用）
/// AppEventBus.fire(WebSocketConnectedEvent(
///   url: 'wss://example.com/ws',
/// ));
///
/// // 监听事件（静态方法调用）
/// AppEventBus.on<WebSocketConnectedEvent>().listen((event) {
///   print('WebSocket connected: ${event.url}');
/// });
///
/// // 使用事件重试管理器
/// final retryManager = EventRetryManager();
/// retryManager.addRetryTask(
///   eventId: 'msg_123',
///   event: MessageSendRequestedEvent(...),
///   maxRetries: 3,
/// );
///
/// // 或者使用全局 eventBus 变量（兼容旧代码）
/// import 'package:imboy/config/init.dart';
///
/// eventBus.fire(WebSocketConnectedEvent(...));
/// eventBus.on<WebSocketConnectedEvent>().listen(...);
/// ```
library;

// 事件总线服务
export '../event_bus.dart' show AppEventBus;

// WebSocket 相关事件（在上一级目录）
// 注意：隐藏 MessageSentEvent 和 MessageSendFailedEvent，使用 message_events.dart 中的版本
export '../websocket_events.dart' hide MessageSentEvent, MessageSendFailedEvent;

// 消息相关事件
export 'message_events.dart';

// 网络相关事件
export 'network_events.dart';

// UI 相关事件
export 'ui_events.dart';

// 常用事件定义
export 'common_events.dart';

// 事件重试管理器
export 'event_retry_manager.dart';
