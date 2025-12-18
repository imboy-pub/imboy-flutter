import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/config/init.dart';

/// 通用工具类模块
/// 包含防抖、节流、错误处理等可复用功能

/// 防抖工具类
/// 用于限制函数的执行频率，避免频繁触发
class Debouncer {
  final int milliseconds; // 防抖时间间隔（毫秒）
  Timer? _timer; // 内部计时器
  VoidCallback? _lastAction; // 上次执行的动作

  Debouncer({required this.milliseconds});

  /// 执行防抖动作
  /// 如果在指定时间内再次调用，会取消之前的执行，重新计时
  void run(VoidCallback action) {
    _lastAction = action;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      action();
      _lastAction = null;
    });
  }

  /// 立即执行最后一次的动作
  void flush() {
    if (_lastAction != null) {
      _timer?.cancel();
      _lastAction!();
      _lastAction = null;
    }
  }

  /// 取消待执行的动作
  void cancel() {
    _timer?.cancel();
    _lastAction = null;
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _lastAction = null;
  }
}

/// 节流工具类
/// 用于限制函数的执行频率，在指定时间内只执行一次
class Throttler {
  final int milliseconds; // 节流时间间隔（毫秒）
  DateTime? _lastExecutionTime; // 上次执行时间

  Throttler({required this.milliseconds});

  /// 执行节流动作
  /// 如果在指定时间内已经执行过，则不再执行
  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastExecutionTime == null ||
        now.difference(_lastExecutionTime!).inMilliseconds >= milliseconds) {
      action();
      _lastExecutionTime = now;
    }
  }

  /// 重置节流器
  void reset() {
    _lastExecutionTime = null;
  }
}

/// 错误处理工具类
/// 提供统一的错误处理和显示方式
class ErrorHandler {
  /// 处理错误并显示提示
  /// [message] 错误消息
  /// [error] 错误对象
  /// [stackTrace] 堆栈跟踪
  /// [showSnackbar] 是否显示提示条
  static void handleError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool showSnackbar = true,
  }) {
    // 记录错误日志
    logger.e(message, error: error, stackTrace: stackTrace);

    // 显示错误提示
    if (showSnackbar) {
      getx.Get.snackbar(
        'error'.tr,
        message,
        snackPosition: getx.SnackPosition.bottom,
        backgroundColor: getx.Get.theme.colorScheme.error.withValues(
          alpha: 0.8,
        ),
        colorText: getx.Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// 处理异步错误
  /// [future] 要执行的异步操作
  /// [errorMessage] 错误消息
  /// [onSuccess] 成功回调
  /// [onError] 错误回调
  static Future<T?> handleAsyncError<T>(
    Future<T> future, {
    required String errorMessage,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      final result = await future;
      onSuccess?.call();
      return result;
    } catch (e, stack) {
      handleError(errorMessage, error: e, stackTrace: stack);
      onError?.call();
      return null;
    }
  }
}

/// 内存管理工具类
/// 用于管理内存和资源清理
class MemoryManager {
  final List<VoidCallback> _disposeCallbacks = [];
  final List<StreamSubscription> _subscriptions = [];

  /// 添加资源清理回调
  void addDisposeCallback(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  /// 添加流订阅
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// 清理所有资源
  void dispose() {
    // 清理所有回调
    for (final callback in _disposeCallbacks) {
      try {
        callback();
      } catch (e) {
        logger.w('清理回调时发生错误: $e');
      }
    }
    _disposeCallbacks.clear();

    // 清理所有流订阅
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        logger.w('取消流订阅时发生错误: $e');
      }
    }
    _subscriptions.clear();
  }
}

/// 安全执行工具类
/// 用于安全地执行可能出错的代码
class SafeExecutor {
  /// 安全执行代码
  /// [action] 要执行的代码
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [showError] 是否显示错误
  static T? execute<T>(
    T Function() action, {
    String? errorMessage,
    VoidCallback? onError,
    bool showError = true,
  }) {
    try {
      return action();
    } catch (e, stack) {
      if (errorMessage != null && showError) {
        ErrorHandler.handleError(errorMessage, error: e, stackTrace: stack);
      }
      onError?.call();
      return null;
    }
  }

  /// 安全执行异步代码
  /// [action] 要执行的异步代码
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [showError] 是否显示错误
  static Future<T?> executeAsync<T>(
    Future<T> Function() action, {
    String? errorMessage,
    VoidCallback? onError,
    bool showError = true,
  }) async {
    try {
      return await action();
    } catch (e, stack) {
      if (errorMessage != null && showError) {
        ErrorHandler.handleError(errorMessage, error: e, stackTrace: stack);
      }
      onError?.call();
      return null;
    }
  }
}

/// 延迟执行工具类
/// 用于延迟执行代码
class DelayExecutor {
  static final Map<String, Timer> _timers = {};

  /// 延迟执行代码
  /// [key] 唯一标识，用于取消之前的延迟执行
  /// [milliseconds] 延迟时间（毫秒）
  /// [action] 要执行的代码
  static void delayed(String key, int milliseconds, VoidCallback action) {
    // 取消之前的延迟执行
    _timers[key]?.cancel();

    // 创建新的延迟执行
    _timers[key] = Timer(Duration(milliseconds: milliseconds), () {
      action();
      _timers.remove(key);
    });
  }

  /// 取消延迟执行
  /// [key] 唯一标识
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  /// 清理所有延迟执行
  static void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

/// 批量执行工具类
/// 用于批量执行代码并处理错误
class BatchExecutor {
  /// 批量执行异步代码
  /// [actions] 要执行的代码列表
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [stopOnError] 是否在遇到错误时停止执行
  static Future<List<T?>> executeAsync<T>(
    List<Future<T> Function()> actions, {
    String? errorMessage,
    VoidCallback? onError,
    bool stopOnError = false,
  }) async {
    final results = <T?>[];

    for (final action in actions) {
      try {
        final result = await action();
        results.add(result);
      } catch (e, stack) {
        if (errorMessage != null) {
          ErrorHandler.handleError(errorMessage, error: e, stackTrace: stack);
        }
        onError?.call();
        results.add(null);

        if (stopOnError) {
          break;
        }
      }
    }

    return results;
  }

  /// 批量执行同步代码
  /// [actions] 要执行的代码列表
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [stopOnError] 是否在遇到错误时停止执行
  static List<T?> execute<T>(
    List<T Function()> actions, {
    String? errorMessage,
    VoidCallback? onError,
    bool stopOnError = false,
  }) {
    final results = <T?>[];

    for (final action in actions) {
      try {
        final result = action();
        results.add(result);
      } catch (e, stack) {
        if (errorMessage != null) {
          ErrorHandler.handleError(errorMessage, error: e, stackTrace: stack);
        }
        onError?.call();
        results.add(null);

        if (stopOnError) {
          break;
        }
      }
    }

    return results;
  }
}

/// 通用工具类
/// 提供便捷的工厂方法来创建各种工具实例
class Utils {
  Utils._(); // 私有构造函数，防止实例化

  /// 创建防抖器
  /// [milliseconds] 防抖时间间隔（毫秒）
  static Debouncer debouncer({required int milliseconds}) {
    return Debouncer(milliseconds: milliseconds);
  }

  /// 创建节流器
  /// [milliseconds] 节流时间间隔（毫秒）
  static Throttler throttler({required int milliseconds}) {
    return Throttler(milliseconds: milliseconds);
  }

  /// 创建内存管理器
  static MemoryManager memoryManager() {
    return MemoryManager();
  }

  /// 延迟执行代码
  /// [key] 唯一标识
  /// [milliseconds] 延迟时间（毫秒）
  /// [action] 要执行的代码
  static void delayed(String key, int milliseconds, VoidCallback action) {
    DelayExecutor.delayed(key, milliseconds, action);
  }

  /// 取消延迟执行
  /// [key] 唯一标识
  static void cancelDelayed(String key) {
    DelayExecutor.cancel(key);
  }

  /// 清理所有延迟执行
  static void clearAllDelayed() {
    DelayExecutor.clear();
  }

  /// 安全执行代码
  /// [action] 要执行的代码
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [showError] 是否显示错误
  static T? safeExecute<T>(
    T Function() action, {
    String? errorMessage,
    VoidCallback? onError,
    bool showError = true,
  }) {
    return SafeExecutor.execute(
      action,
      errorMessage: errorMessage,
      onError: onError,
      showError: showError,
    );
  }

  /// 安全执行异步代码
  /// [action] 要执行的异步代码
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [showError] 是否显示错误
  static Future<T?> safeExecuteAsync<T>(
    Future<T> Function() action, {
    String? errorMessage,
    VoidCallback? onError,
    bool showError = true,
  }) {
    return SafeExecutor.executeAsync(
      action,
      errorMessage: errorMessage,
      onError: onError,
      showError: showError,
    );
  }

  /// 处理错误
  /// [message] 错误消息
  /// [error] 错误对象
  /// [stackTrace] 堆栈跟踪
  /// [showSnackbar] 是否显示提示条
  static void handleError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool showSnackbar = true,
  }) {
    ErrorHandler.handleError(
      message,
      error: error,
      stackTrace: stackTrace,
      showSnackbar: showSnackbar,
    );
  }

  /// 处理异步错误
  /// [future] 要执行的异步操作
  /// [errorMessage] 错误消息
  /// [onSuccess] 成功回调
  /// [onError] 错误回调
  static Future<T?> handleAsyncError<T>(
    Future<T> future, {
    required String errorMessage,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) {
    return ErrorHandler.handleAsyncError(
      future,
      errorMessage: errorMessage,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  /// 批量执行异步代码
  /// [actions] 要执行的代码列表
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [stopOnError] 是否在遇到错误时停止执行
  static Future<List<T?>> batchExecuteAsync<T>(
    List<Future<T> Function()> actions, {
    String? errorMessage,
    VoidCallback? onError,
    bool stopOnError = false,
  }) {
    return BatchExecutor.executeAsync(
      actions,
      errorMessage: errorMessage,
      onError: onError,
      stopOnError: stopOnError,
    );
  }

  /// 批量执行同步代码
  /// [actions] 要执行的代码列表
  /// [errorMessage] 错误消息
  /// [onError] 错误回调
  /// [stopOnError] 是否在遇到错误时停止执行
  static List<T?> batchExecute<T>(
    List<T Function()> actions, {
    String? errorMessage,
    VoidCallback? onError,
    bool stopOnError = false,
  }) {
    return BatchExecutor.execute(
      actions,
      errorMessage: errorMessage,
      onError: onError,
      stopOnError: stopOnError,
    );
  }
}
