/// 防抖工具类
///
/// 用于防止按钮重复点击、频繁触发等场景
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// 防抖类
///
/// 延迟执行指定操作，如果在延迟时间内再次调用，则重新计时
///
/// 使用示例：
/// ```dart
/// final debounce = Debounce(milliseconds: 500);
/// debounce.run(() {
///   print('执行操作');
/// });
/// ```
class Debounce {
  /// 延迟时间（毫秒）
  final int milliseconds;

  Timer? _timer;

  Debounce({this.milliseconds = 500});

  /// 执行防抖操作
  ///
  /// 如果在指定时间内再次调用，会取消之前的操作并重新计时
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// 立即执行并取消待执行的操作
  void flush() {
    _timer?.cancel();
    _timer = null;
  }

  /// 取消防抖操作
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 是否有待执行的操作
  bool get isPending => _timer != null && _timer!.isActive;

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 节流类
///
/// 在指定时间内只执行一次操作
///
/// 使用示例：
/// ```dart
/// final throttle = Throttle(milliseconds: 1000);
/// throttle.run(() {
///   print('执行操作');
/// });
/// ```
class Throttle {
  /// 延迟时间（毫秒）
  final int milliseconds;

  DateTime? _lastRunTime;

  Throttle({this.milliseconds = 1000});

  /// 执行节流操作
  ///
  /// 如果在指定时间内已经执行过，则忽略本次调用
  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRunTime == null ||
        now.difference(_lastRunTime!).inMilliseconds >= milliseconds) {
      _lastRunTime = now;
      action();
    }
  }

  /// 重置节流状态
  void reset() {
    _lastRunTime = null;
  }
}
