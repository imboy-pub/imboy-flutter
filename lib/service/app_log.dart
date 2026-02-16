/// 统一日志管理服务
///
/// 替代项目中分散的 iPrint/debugPrint/print 调用
/// 提供统一的日志接口，支持：
/// - 日志级别控制
/// - 敏感信息脱敏
/// - 生产环境禁用调试日志
/// - 结构化日志输出
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 日志级别
enum LogLevel {
  /// 调试日志（仅开发环境）
  debug(0),

  /// 信息日志
  info(1),

  /// 警告日志
  warning(2),

  /// 错误日志
  error(3),

  /// 严重错误
  fatal(4),

  /// 无日志
  none(5);

  final int value;
  const LogLevel(this.value);

  /// 当前构建的默认日志级别
  static LogLevel get defaultLevel {
    if (kDebugMode) return LogLevel.debug;
    if (kProfileMode) return LogLevel.info;
    return LogLevel.warning; // release
  }
}

/// 敏感信息脱敏处理器
class SensitiveDataSanitizer {
  /// 敏感字段列表
  static const _sensitiveKeys = {
    'token',
    'access_token',
    'refresh_token',
    'password',
    'pwd',
    'secret',
    'api_key',
    'apikey',
    'authorization',
    'credential',
    'private_key',
    'session_id',
    'cookie',
  };

  /// 需要部分遮蔽的字段（保留前后各 4 个字符）
  static const _partialMaskKeys = {
    'phone',
    'mobile',
    'email',
    'id_card',
    'card_number',
  };

  /// 脱敏处理
  static String sanitize(Map<String, dynamic>? data) {
    if (data == null) return '{}';

    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      if (_sensitiveKeys.any((k) => key.contains(k))) {
        sanitized[entry.key] = '***REDACTED***';
      } else if (_partialMaskKeys.any((k) => key.contains(k))) {
        sanitized[entry.key] = _partialMask(entry.value.toString());
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized.toString();
  }

  /// 部分遮蔽
  static String _partialMask(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
  }
}

/// 统一日志服务
///
/// 使用方法：
/// ```dart
/// // 替代 iPrint
/// AppLog.debug('消息', tag: 'ChatProvider');
///
/// // 替代 debugPrint
/// AppLog.info('网络请求: $url');
///
/// // 错误日志
/// AppLog.error('发送失败', error, stackTrace);
/// ```
class AppLog {
  AppLog._();

  /// 当前日志级别（可通过配置修改）
  static LogLevel level = LogLevel.defaultLevel;

  /// 是否启用详细日志（包含时间戳、文件位置等）
  static bool verbose = kDebugMode;

  /// 是否启用敏感信息脱敏
  static bool sanitizeData = !kDebugMode;

  /// 调试日志
  ///
  /// 仅在 debug 模式下输出
  static void debug(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
  }) {
    if (level.value > LogLevel.debug.value) return;

    _log(
      level: LogLevel.debug,
      message: message,
      tag: tag,
      data: data,
    );
  }

  /// 信息日志
  static void info(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
  }) {
    if (level.value > LogLevel.info.value) return;

    _log(
      level: LogLevel.info,
      message: message,
      tag: tag,
      data: data,
    );
  }

  /// 警告日志
  static void warning(
    String message, {
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
  }) {
    if (level.value > LogLevel.warning.value) return;

    _log(
      level: LogLevel.warning,
      message: message,
      tag: tag,
      data: data,
      error: error,
    );
  }

  /// 错误日志
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (level.value > LogLevel.error.value) return;

    _log(
      level: LogLevel.error,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 严重错误日志
  static void fatal(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    _log(
      level: LogLevel.fatal,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 网络请求日志（自动脱敏）
  static void networkRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    String? tag,
  }) {
    if (level.value > LogLevel.debug.value) return;

    final data = <String, dynamic>{
      'method': method,
      'url': url,
      // ignore: use_null_aware_elements
      if (headers != null) 'headers': headers,
      // ignore: use_null_aware_elements
      if (body != null) 'body': body,
    };

    _log(
      level: LogLevel.debug,
      message: 'HTTP Request: $method $url',
      tag: tag ?? 'Network',
      data: sanitizeData ? null : data,
    );
  }

  /// 网络响应日志（自动脱敏）
  static void networkResponse({
    required String method,
    required String url,
    required int statusCode,
    dynamic body,
    int? duration,
    String? tag,
  }) {
    if (level.value > LogLevel.debug.value) return;

    final data = <String, dynamic>{
      'method': method,
      'url': url,
      'statusCode': statusCode,
      // ignore: use_null_aware_elements
      if (body != null) 'body': body,
      // ignore: use_null_aware_elements
      if (duration != null) 'duration': '${duration}ms',
    };

    _log(
      level: LogLevel.debug,
      message: 'HTTP Response: $statusCode $method $url${duration != null ? ' (${duration}ms)' : ''}',
      tag: tag ?? 'Network',
      data: sanitizeData ? null : data,
    );
  }

  /// 内部日志方法
  static void _log({
    required LogLevel level,
    required String message,
    String? tag,
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer();

    // 时间戳
    if (verbose) {
      buffer.write('${DateTime.now().toIso8601String()} ');
    }

    // 日志级别
    buffer.write('[${level.name.toUpperCase()}]');

    // 标签
    if (tag != null) {
      buffer.write(' [$tag]');
    }

    // 消息
    buffer.write(' $message');

    // 数据
    if (data != null) {
      final dataStr = sanitizeData
          ? SensitiveDataSanitizer.sanitize(data)
          : data.toString();
      buffer.write(' | $dataStr');
    }

    // 错误
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    final output = buffer.toString();

    // 根据级别选择输出方式
    if (kDebugMode) {
      developer.log(
        output,
        name: tag ?? 'App',
        level: _getDeveloperLogLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // 生产环境只输出 warning 及以上
      if (level.value >= LogLevel.warning.value) {
        debugPrint(output);
      }
    }
  }

  static int _getDeveloperLogLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
      LogLevel.fatal => 2000,
      LogLevel.none => 0,
    };
  }
}

/// 日志扩展方法（便于迁移）
extension LogExtension on String {
  /// 调试日志扩展
  void logDebug([String? tag]) => AppLog.debug(this, tag: tag);

  /// 信息日志扩展
  void logInfo([String? tag]) => AppLog.info(this, tag: tag);

  /// 警告日志扩展
  void logWarning([String? tag]) => AppLog.warning(this, tag: tag);

  /// 错误日志扩展
  void logError([String? tag]) => AppLog.error(this, null, null, tag);
}
