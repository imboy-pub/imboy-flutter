/// WebRTC 质量监控配置
///
/// 定义网络质量监控和自适应码率的参数
library;

/// WebRTC 质量配置
class WebRTCQualityConfig {
  /// 监控间隔（收集统计信息的频率）
  final Duration monitorInterval;

  /// 质量评分自适应阈值（低于此值时降低码率）
  final int adaptiveThreshold;

  /// 质量评分恢复阈值（高于此值时恢复码率）
  final int recoveryThreshold;

  /// 最大码率（bps）
  final int maxBitrate;

  /// 最小码率（bps）
  final int minBitrate;

  /// 初始码率（bps）
  final int initialBitrate;

  /// 是否启用自适应码率
  final bool enableAdaptiveBitrate;

  /// 是否启用质量监控
  final bool enabled;

  /// RTT 优秀阈值（ms）
  final int rttExcellentThreshold;

  /// RTT 良好阈值（ms）
  final int rttGoodThreshold;

  /// 丢包率优秀阈值（%）
  final int packetLossExcellentThreshold;

  /// 丢包率良好阈值（%）
  final int packetLossGoodThreshold;

  /// 抖动优秀阈值（ms）
  final int jitterExcellentThreshold;

  /// 抖动良好阈值（ms）
  final int jitterGoodThreshold;

  const WebRTCQualityConfig({
    this.monitorInterval = const Duration(seconds: 1),
    this.adaptiveThreshold = 60,
    this.recoveryThreshold = 80,
    this.maxBitrate = 2000000, // 2 Mbps
    this.minBitrate = 300000, // 300 Kbps
    this.initialBitrate = 1000000, // 1 Mbps
    this.enableAdaptiveBitrate = true,
    this.enabled = true,
    this.rttExcellentThreshold = 100,
    this.rttGoodThreshold = 200,
    this.packetLossExcellentThreshold = 1,
    this.packetLossGoodThreshold = 3,
    this.jitterExcellentThreshold = 30,
    this.jitterGoodThreshold = 50,
  });

  /// 创建默认配置
  factory WebRTCQualityConfig.defaultConfig() {
    return const WebRTCQualityConfig();
  }

  /// 创建禁用质量监控的配置
  factory WebRTCQualityConfig.disabled() {
    return WebRTCQualityConfig.defaultConfig().copyWith(enabled: false);
  }

  /// 创建高质量配置（适用于高速网络）
  factory WebRTCQualityConfig.highQuality() {
    return const WebRTCQualityConfig(
      monitorInterval: Duration(seconds: 1),
      adaptiveThreshold: 70,
      recoveryThreshold: 85,
      maxBitrate: 3000000, // 3 Mbps
      minBitrate: 500000, // 500 Kbps
      initialBitrate: 2000000, // 2 Mbps
      enableAdaptiveBitrate: true,
      enabled: true,
    );
  }

  /// 创建省流量配置（适用于移动网络）
  factory WebRTCQualityConfig.dataSaver() {
    return const WebRTCQualityConfig(
      monitorInterval: Duration(seconds: 2),
      adaptiveThreshold: 70,
      recoveryThreshold: 85,
      maxBitrate: 800000, // 800 Kbps
      minBitrate: 200000, // 200 Kbps
      initialBitrate: 400000, // 400 Kbps
      enableAdaptiveBitrate: true,
      enabled: true,
    );
  }

  /// 根据网络条件计算质量评分
  ///
  /// 返回值范围: 0-100，分数越高表示质量越好
  int calculateQualityScore({
    required int rtt,
    required int packetLoss,
    required int jitter,
    int? bitrate,
    int? frameRate,
  }) {
    if (!enabled) return 100;

    int score = 100;

    // RTT 影响 (0-25分)
    if (rtt > rttGoodThreshold * 2) {
      score -= 25;
    } else if (rtt > rttGoodThreshold) {
      score -= 15;
    } else if (rtt > rttExcellentThreshold) {
      score -= 5;
    }

    // 丢包影响 (0-35分)
    if (packetLoss > 10) {
      score -= 35;
    } else if (packetLoss > packetLossGoodThreshold) {
      score -= 25;
    } else if (packetLoss > packetLossExcellentThreshold) {
      score -= 10;
    }

    // 抖动影响 (0-20分)
    if (jitter > jitterGoodThreshold * 2) {
      score -= 20;
    } else if (jitter > jitterGoodThreshold) {
      score -= 10;
    } else if (jitter > jitterExcellentThreshold) {
      score -= 5;
    }

    // 帧率影响 (0-20分，可选)
    if (frameRate != null) {
      if (frameRate < 10) {
        score -= 20;
      } else if (frameRate < 15) {
        score -= 15;
      } else if (frameRate < 24) {
        score -= 10;
      }
    }

    return score.clamp(0, 100);
  }

  /// 根据质量评分获取网络等级
  WebRTCNetworkQuality getNetworkQuality(int score) {
    if (score >= recoveryThreshold) {
      return WebRTCNetworkQuality.excellent;
    } else if (score >= adaptiveThreshold) {
      return WebRTCNetworkQuality.good;
    } else if (score >= 40) {
      return WebRTCNetworkQuality.fair;
    } else {
      return WebRTCNetworkQuality.poor;
    }
  }

  /// 计算目标码率
  int calculateTargetBitrate(int qualityScore) {
    if (!enableAdaptiveBitrate) {
      return initialBitrate;
    }

    final quality = getNetworkQuality(qualityScore);

    switch (quality) {
      case WebRTCNetworkQuality.excellent:
        return maxBitrate;
      case WebRTCNetworkQuality.good:
        return (maxBitrate * 0.7).toInt().clamp(minBitrate, maxBitrate);
      case WebRTCNetworkQuality.fair:
        return (maxBitrate * 0.4).toInt().clamp(minBitrate, maxBitrate);
      case WebRTCNetworkQuality.poor:
        return minBitrate;
    }
  }

  /// 复制并修改部分配置
  WebRTCQualityConfig copyWith({
    Duration? monitorInterval,
    int? adaptiveThreshold,
    int? recoveryThreshold,
    int? maxBitrate,
    int? minBitrate,
    int? initialBitrate,
    bool? enableAdaptiveBitrate,
    bool? enabled,
    int? rttExcellentThreshold,
    int? rttGoodThreshold,
    int? packetLossExcellentThreshold,
    int? packetLossGoodThreshold,
    int? jitterExcellentThreshold,
    int? jitterGoodThreshold,
  }) {
    return WebRTCQualityConfig(
      monitorInterval: monitorInterval ?? this.monitorInterval,
      adaptiveThreshold: adaptiveThreshold ?? this.adaptiveThreshold,
      recoveryThreshold: recoveryThreshold ?? this.recoveryThreshold,
      maxBitrate: maxBitrate ?? this.maxBitrate,
      minBitrate: minBitrate ?? this.minBitrate,
      initialBitrate: initialBitrate ?? this.initialBitrate,
      enableAdaptiveBitrate:
          enableAdaptiveBitrate ?? this.enableAdaptiveBitrate,
      enabled: enabled ?? this.enabled,
      rttExcellentThreshold:
          rttExcellentThreshold ?? this.rttExcellentThreshold,
      rttGoodThreshold: rttGoodThreshold ?? this.rttGoodThreshold,
      packetLossExcellentThreshold:
          packetLossExcellentThreshold ?? this.packetLossExcellentThreshold,
      packetLossGoodThreshold:
          packetLossGoodThreshold ?? this.packetLossGoodThreshold,
      jitterExcellentThreshold:
          jitterExcellentThreshold ?? this.jitterExcellentThreshold,
      jitterGoodThreshold: jitterGoodThreshold ?? this.jitterGoodThreshold,
    );
  }

  @override
  String toString() {
    return 'WebRTCQualityConfig('
        'enabled: $enabled, '
        'adaptive: $enableAdaptiveBitrate, '
        'bitrate: $minBitrate-$maxBitrate'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCQualityConfig &&
        other.monitorInterval == monitorInterval &&
        other.adaptiveThreshold == adaptiveThreshold &&
        other.recoveryThreshold == recoveryThreshold &&
        other.maxBitrate == maxBitrate &&
        other.minBitrate == minBitrate &&
        other.initialBitrate == initialBitrate &&
        other.enableAdaptiveBitrate == enableAdaptiveBitrate &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      monitorInterval,
      adaptiveThreshold,
      recoveryThreshold,
      maxBitrate,
      minBitrate,
      initialBitrate,
      enableAdaptiveBitrate,
      enabled,
    );
  }
}

/// 网络质量等级
enum WebRTCNetworkQuality {
  /// 优秀 (80-100分)
  excellent,

  /// 良好 (60-79分)
  good,

  /// 一般 (40-59分)
  fair,

  /// 较差 (0-39分)
  poor,
}

/// 扩展网络质量等级的辅助方法
extension WebRTCNetworkQualityExtension on WebRTCNetworkQuality {
  /// 获取质量等级名称
  String get name {
    switch (this) {
      case WebRTCNetworkQuality.excellent:
        return '优秀';
      case WebRTCNetworkQuality.good:
        return '良好';
      case WebRTCNetworkQuality.fair:
        return '一般';
      case WebRTCNetworkQuality.poor:
        return '较差';
    }
  }

  /// 获取对应的颜色（用于 UI）
  /// 注意：这里返回字符串，实际使用时需要配合 Color
  String get colorName {
    switch (this) {
      case WebRTCNetworkQuality.excellent:
        return 'green';
      case WebRTCNetworkQuality.good:
        return 'lightGreen';
      case WebRTCNetworkQuality.fair:
        return 'orange';
      case WebRTCNetworkQuality.poor:
        return 'red';
    }
  }

  /// 获取对应的信号强度（格数）
  int get signalBars {
    switch (this) {
      case WebRTCNetworkQuality.excellent:
        return 4;
      case WebRTCNetworkQuality.good:
        return 3;
      case WebRTCNetworkQuality.fair:
        return 2;
      case WebRTCNetworkQuality.poor:
        return 1;
    }
  }

  /// 是否为可接受的质量
  bool get isAcceptable {
    return this != WebRTCNetworkQuality.poor;
  }

  /// 是否为优秀的质量
  bool get isExcellent {
    return this == WebRTCNetworkQuality.excellent;
  }
}
