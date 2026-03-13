import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/base_event.dart';

/// 错误上报事件
///
/// 当发生错误时触发，可用于上报到第三方错误监控服务
///
/// 使用示例：
/// ```dart
/// // 监听错误上报事件
/// AppEventBus.on<ErrorReportEvent>().listen((event) {
///   // 上报到 Sentry/Firebase Crashlytics
///   Sentry.captureException(
///     event.error,
///     stackTrace: event.stackTrace,
///   );
/// });
/// ```
final class ErrorReportEvent extends AppEvent {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isFatal;

  const ErrorReportEvent({
    required this.message,
    this.error,
    this.stackTrace,
    this.isFatal = false,
  });

  @override
  List<Object?> get props => [message, error, stackTrace, isFatal];
}

/// 统一日志管理器
/// 提供分级日志、环境控制、性能监控等功能
///
/// 遵循原则：
/// - KISS: 简单易用的日志接口
/// - 性能优化：生产环境最小化日志开销
/// - 可维护性：统一的日志格式和配置
///
/// 错误上报：
/// - 生产环境通过 ErrorReportEvent 事件发送错误
/// - 可以在应用启动时监听此事件并上报到第三方服务（如 Sentry、Firebase Crashlytics）
class AppLogger {
  /// 是否为调试模式
  static final bool _isDebugMode = kDebugMode;

  /// Logger 实例
  static Logger? _logger;

  /// 获取 Logger 实例
  static Logger _getLogger() {
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        noBoxingByDefault: false,
      ),
    );
    return _logger!;
  }

  /// 设置日志级别
  static void setLogLevel(Level level) {
    Logger.level = level;
  }

  /// 追踪日志（verbose 的替代）
  static void trace(String message, [Object? error, StackTrace? stackTrace]) {
    if (_isDebugMode) {
      _getLogger().t(message, error: error, stackTrace: stackTrace);
    }
  }

  /// 调试日志（仅在调试模式输出）
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_isDebugMode) {
      _getLogger().d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// 信息日志（开发和生产环境都输出）
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _getLogger().i(message, error: error, stackTrace: stackTrace);
  }

  /// 警告日志
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _getLogger().w(message, error: error, stackTrace: stackTrace);
  }

  /// 错误日志（开发和生产环境都输出）
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _getLogger().e(message, error: error, stackTrace: stackTrace);

    // 生产环境发送错误上报事件
    // 可以在应用启动时监听 ErrorReportEvent 并上报到第三方服务
    if (!_isDebugMode) {
      AppEventBus.fire(
        ErrorReportEvent(
          message: message,
          error: error,
          stackTrace: stackTrace,
          isFatal: false,
        ),
      );
    }
  }

  /// 严重错误日志
  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _getLogger().f(message, error: error, stackTrace: stackTrace);

    // 生产环境发送严重错误上报事件
    if (!_isDebugMode) {
      AppEventBus.fire(
        ErrorReportEvent(
          message: message,
          error: error,
          stackTrace: stackTrace,
          isFatal: true,
        ),
      );
    }
  }

  /// 性能监控日志（用于记录操作耗时）
  static void performance(String operation, Duration duration) {
    final msg = '⏱ $operation took ${duration.inMilliseconds}ms';
    if (duration.inMilliseconds > 1000) {
      warning(msg);
    } else {
      debug(msg);
    }
  }

  /// 兼容 iPrint（项目中使用的旧日志函数）
  static void iPrint(dynamic msg) {
    if (msg is String) {
      debug(msg);
    } else {
      debug(msg.toString());
    }
  }
}

/// 全局日志实例（方便调用）
final appLogger = AppLogger;
final log = AppLogger;
