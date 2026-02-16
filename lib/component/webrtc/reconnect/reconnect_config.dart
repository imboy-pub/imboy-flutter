/// WebRTC 重连配置
///
/// 定义连接断开后的重连策略和参数
library;

/// 重连策略
enum ReconnectStrategy {
  /// 固定间隔重试
  fixed,

  /// 指数退避（每次重试间隔翻倍）
  exponential,

  /// 线性增长（每次增加固定间隔）
  linear,
}

/// WebRTC 重连配置
class WebRTCReconnectConfig {
  /// 最大重试次数
  final int maxRetries;

  /// 初始重试延迟
  final Duration retryDelay;

  /// 最大退避时间（指数退避时使用）
  final Duration maxBackoff;

  /// 重连策略
  final ReconnectStrategy strategy;

  /// 心跳间隔
  final Duration heartbeatInterval;

  /// 心跳超时时间
  final Duration heartbeatTimeout;

  /// 是否启用自动重连
  final bool enabled;

  const WebRTCReconnectConfig({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.maxBackoff = const Duration(seconds: 30),
    this.strategy = ReconnectStrategy.exponential,
    this.heartbeatInterval = const Duration(seconds: 10),
    this.heartbeatTimeout = const Duration(seconds: 5),
    this.enabled = true,
  });

  /// 创建默认配置
  factory WebRTCReconnectConfig.defaultConfig() {
    return const WebRTCReconnectConfig(
      maxRetries: 3,
      retryDelay: Duration(seconds: 2),
      maxBackoff: Duration(seconds: 30),
      strategy: ReconnectStrategy.exponential,
      heartbeatInterval: Duration(seconds: 10),
      heartbeatTimeout: Duration(seconds: 5),
      enabled: true,
    );
  }

  /// 创建禁用重连的配置
  factory WebRTCReconnectConfig.disabled() {
    return WebRTCReconnectConfig.defaultConfig().copyWith(enabled: false);
  }

  /// 创建快速重连配置（适合测试）
  factory WebRTCReconnectConfig.fast() {
    return const WebRTCReconnectConfig(
      maxRetries: 5,
      retryDelay: Duration(milliseconds: 500),
      maxBackoff: Duration(seconds: 5),
      strategy: ReconnectStrategy.exponential,
      heartbeatInterval: Duration(seconds: 3),
      heartbeatTimeout: Duration(seconds: 2),
      enabled: true,
    );
  }

  /// 计算第 N 次重试的延迟时间
  Duration calculateRetryDelay(int retryCount) {
    if (!enabled || retryCount >= maxRetries) {
      return Duration.zero; // 不再重试
    }

    switch (strategy) {
      case ReconnectStrategy.fixed:
        return retryDelay;

      case ReconnectStrategy.exponential:
        final seconds = (2 << retryCount).toDouble();
        final milliseconds = (seconds * 1000).toInt();
        return Duration(
          milliseconds: milliseconds.clamp(
            retryDelay.inMilliseconds,
            maxBackoff.inMilliseconds,
          ),
        );

      case ReconnectStrategy.linear:
        final milliseconds =
            retryDelay.inMilliseconds * (retryCount + 1);
        return Duration(
          milliseconds: milliseconds.clamp(
            retryDelay.inMilliseconds,
            maxBackoff.inMilliseconds,
          ),
        );
    }
  }

  /// 复制并修改部分配置
  WebRTCReconnectConfig copyWith({
    int? maxRetries,
    Duration? retryDelay,
    Duration? maxBackoff,
    ReconnectStrategy? strategy,
    Duration? heartbeatInterval,
    Duration? heartbeatTimeout,
    bool? enabled,
  }) {
    return WebRTCReconnectConfig(
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      maxBackoff: maxBackoff ?? this.maxBackoff,
      strategy: strategy ?? this.strategy,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      heartbeatTimeout: heartbeatTimeout ?? this.heartbeatTimeout,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  String toString() {
    return 'WebRTCReconnectConfig('
        'maxRetries: $maxRetries, '
        'strategy: $strategy, '
        'enabled: $enabled'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCReconnectConfig &&
        other.maxRetries == maxRetries &&
        other.retryDelay == retryDelay &&
        other.maxBackoff == maxBackoff &&
        other.strategy == strategy &&
        other.heartbeatInterval == heartbeatInterval &&
        other.heartbeatTimeout == heartbeatTimeout &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      maxRetries,
      retryDelay,
      maxBackoff,
      strategy,
      heartbeatInterval,
      heartbeatTimeout,
      enabled,
    );
  }
}
