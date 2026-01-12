/// 事件基类
///
/// 所有事件都应继承此类，以便统一管理事件的元数据和生命周期
///
/// 设计原则：
/// - KISS: 简单的事件基类，只包含必要的元数据
/// - 可追踪性: 每个事件都有自动生成的时间戳
/// - 类型安全: 使用 event_bus_plus 的类型系统
///
/// 使用示例：
/// ```dart
/// class UserLoginEvent extends AppEvent {
///   final String userId;
///   final String username;
///
///   const UserLoginEvent({
///     required this.userId,
///     required this.username,
///   });
/// }
/// ```
///
/// 发布事件：
/// ```dart
/// AppEventBus.fire(UserLoginEvent(
///   userId: '123',
///   username: 'imboy',
/// ));
/// ```
///
/// 订阅事件：
/// ```dart
/// AppEventBus.on<UserLoginEvent>().listen((event) {
///   print('用户登录: ${event.username}');
/// });
/// ```
///
/// 取消订阅：
/// ```dart
/// StreamSubscription? subscription = AppEventBus.on<UserLoginEvent>().listen(...);
/// subscription?.cancel();
/// ```
///
library;

import 'package:event_bus_plus/event_bus_plus.dart';

export 'package:event_bus_plus/event_bus_plus.dart' show AppEvent;

/// 错误事件基类
///
/// 用于所有需要携带错误信息的事件
/// 自动包含错误码、错误消息、错误对象和堆栈跟踪
abstract class ErrorEvent extends AppEvent {
  /// 创建错误事件
  const ErrorEvent({
    required this.errorCode,
    required this.errorMessage,
    this.error,
    this.stackTrace,
  });

  /// 错误码
  final String errorCode;

  /// 错误消息
  final String errorMessage;

  /// 错误对象（如果有）
  final Object? error;

  /// 堆栈跟踪（如果有）
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [errorCode, errorMessage, error, stackTrace];

  @override
  String toString() {
    return 'ErrorEvent(errorCode: $errorCode, errorMessage: $errorMessage, error: $error, stackTrace: $stackTrace)';
  }
}
