import 'dart:math';

import 'package:imboy/service/app_logger.dart';

/// 可配置的指数退避工具类，支持多种 jitter 算法与详细参数控制。
class ExponentialBackoff {
  /// 初始延迟
  final Duration baseDelay;

  /// 最大延迟
  final Duration maxDelay;

  /// 最大重试次数
  final int maxRetries;

  /// 抖动因子（0.0 ~ 1.0），0为无抖动，1为最大抖动
  final double jitterFactor;

  /// 抖动算法类型
  final JitterType jitterType;

  /// 当前已重试次数（私有，通过 getter 只读暴露）
  int _attempts = 0;
  int get attempts => _attempts;

  ExponentialBackoff({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 2),
    this.maxRetries = 20,
    this.jitterFactor = 0.3,
    this.jitterType = JitterType.full,
  });

  /// 获取下一次重试的延迟
  Duration nextDelay() {
    _attempts = (_attempts + 1).clamp(0, maxRetries);
    // cap 位移上界防止整数溢出（2^30 * 1000ms >> 2min，足够覆盖最大退避）
    final int exp = (_attempts - 1).clamp(0, 30);
    final int expMs = baseDelay.inMilliseconds * (1 << exp);
    final int cappedMs = expMs.clamp(
      baseDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );
    final Duration rawDelay = Duration(milliseconds: cappedMs);

    switch (jitterType) {
      case JitterType.none:
        return rawDelay;
      case JitterType.full:
        return _fullJitter(rawDelay);
      case JitterType.equal:
        return _equalJitter(rawDelay);
      case JitterType.deviation:
        return _deviationJitter(rawDelay);
    }
  }

  /// 重置重试计数器（连接成功后调用）
  void reset() {
    if (_attempts > 0) {
      AppLogger.debug('重连计数器已重置（之前尝试了 $_attempts 次）');
    }
    _attempts = 0;
  }

  /// 完全随机 jitter：[0, delay * jitterFactor]
  Duration _fullJitter(Duration base) {
    final int maxMs = (base.inMilliseconds * jitterFactor).toInt();
    if (maxMs <= 0) return base;
    return Duration(milliseconds: Random().nextInt(maxMs + 1));
  }

  /// 抖动范围为 [delay * (1-jitter), delay]
  Duration _equalJitter(Duration base) {
    final int range = (base.inMilliseconds * jitterFactor).toInt();
    final int minMs = base.inMilliseconds - range;
    final int delayMs = minMs + Random().nextInt(range + 1);
    return Duration(milliseconds: delayMs);
  }

  /// ±jitterFactor * delay
  Duration _deviationJitter(Duration base) {
    final int deviation = (base.inMilliseconds * jitterFactor).toInt();
    final int jitterValue = deviation > 0
        ? Random().nextInt(deviation * 2 + 1) - deviation
        : 0;
    return Duration(milliseconds: base.inMilliseconds + jitterValue);
  }
}

/// 抖动类型枚举
enum JitterType {
  /// 不做抖动
  none,

  /// 完全抖动（full jitter，Google/Netflix 推荐）
  full,

  /// 区间抖动（equal jitter，AWS 推荐）
  equal,

  /// 偏差抖动（±jitterFactor * delay）
  deviation,
}
