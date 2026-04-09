/// WebRTC 信令消息模型 v2.0
///
/// 定义信令消息的数据模型和解析逻辑
library;

import 'signaling_v2.dart';

/// WebRTC 信令消息模型 v2.0
class WebRTCSignalingModel {
  /// 消息 ID
  final String msgId;

  /// 会话 ID（v2.0 新增）
  final String sessionId;

  /// 信令类型
  final WebRTCSignalingType type;

  /// 发送者 ID
  final String from;

  /// 接收者 ID
  final String to;

  /// 消息负载
  final Map<String, dynamic> payload;

  /// 时间戳
  final int timestamp;

  /// 序号（v2.0 新增，用于排序）
  final int? sequence;

  /// 关联 ID（v2.0 新增，用于追踪）
  final String? correlationId;

  /// 优先级权重（v2.0 新增）
  final int? priority;

  /// 质量统计（仅 quality_report 消息）
  final WebRTCQualityStatsData? qualityStats;

  const WebRTCSignalingModel({
    required this.msgId,
    this.sessionId = '',
    required this.type,
    required this.from,
    required this.to,
    required this.payload,
    required this.timestamp,
    this.sequence,
    this.correlationId,
    this.priority,
    this.qualityStats,
  });

  /// 从 JSON 解析
  factory WebRTCSignalingModel.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String?;
    final type = WebRTCSignalingTypeExtension.fromString(typeValue ?? '');

    if (type == null) {
      throw ArgumentError('Invalid signaling type: $typeValue');
    }

    // 解析质量统计（如果是质量报告消息）
    WebRTCQualityStatsData? qualityStats;
    if (type == WebRTCSignalingType.quality_report) {
      final payload = json['payload'] as Map<String, dynamic>?;
      if (payload != null) {
        qualityStats = WebRTCQualityStatsData.fromJson(payload);
      }
    }

    return WebRTCSignalingModel(
      msgId: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      type: type,
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      timestamp: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      sequence: json['seq'] as int?,
      correlationId: json['correlation_id'] as String?,
      priority: json['priority'] as int?,
      qualityStats: qualityStats,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': msgId,
      'type': type.messageKey,
      'from': from,
      'to': to,
      'ts': timestamp,
      'payload': payload,
    };

    if (sessionId.isNotEmpty) {
      json['session_id'] = sessionId;
    }
    if (sequence != null) {
      json['seq'] = sequence;
    }
    if (correlationId != null) {
      json['correlation_id'] = correlationId;
    }
    if (priority != null) {
      json['priority'] = priority;
    }

    return json;
  }

  /// 获取消息优先级
  WebRTCMessagePriority get messagePriority {
    final priorityValue = priority;
    if (priorityValue != null) {
      return WebRTCMessagePriority.values
          .firstWhere((p) => p.weight == priorityValue, orElse: () => WebRTCMessagePriority.normal);
    }
    return WebRTCMessagePriorityExtension.fromSignalingType(type);
  }

  /// 是否需要确认
  bool get requiresAck => type.requiresAck;

  /// 是否为控制消息
  bool get isControlMessage => type.isControlMessage;

  /// 复制并修改部分信息
  WebRTCSignalingModel copyWith({
    String? msgId,
    String? sessionId,
    WebRTCSignalingType? type,
    String? from,
    String? to,
    Map<String, dynamic>? payload,
    int? timestamp,
    int? sequence,
    String? correlationId,
    int? priority,
    WebRTCQualityStatsData? qualityStats,
  }) {
    return WebRTCSignalingModel(
      msgId: msgId ?? this.msgId,
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      from: from ?? this.from,
      to: to ?? this.to,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      sequence: sequence ?? this.sequence,
      correlationId: correlationId ?? this.correlationId,
      priority: priority ?? this.priority,
      qualityStats: qualityStats ?? this.qualityStats,
    );
  }

  @override
  String toString() {
    return 'WebRTCSignalingModel('
        'type: $type, '
        'from: $from, '
        'to: $to, '
        'sessionId: $sessionId'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCSignalingModel &&
        other.msgId == msgId &&
        other.sessionId == sessionId &&
        other.type == type &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode {
    return Object.hash(msgId, sessionId, type, from, to);
  }
}

/// WebRTC 质量统计数据
class WebRTCQualityStatsData {
  /// 往返时延 (ms)
  final int rtt;

  /// 丢包率 (0-100)
  final int packetLoss;

  /// 抖动 (ms)
  final int jitter;

  /// 比特率 (bps)
  final int bitrate;

  /// 视频宽度
  final int width;

  /// 视频高度
  final int height;

  /// 帧率 (fps)
  final int frameRate;

  /// 编解码器
  final String codec;

  /// 音频电平 (0-32767)
  final int audioLevel;

  /// 统计时间戳
  final int timestamp;

  const WebRTCQualityStatsData({
    required this.rtt,
    required this.packetLoss,
    required this.jitter,
    required this.bitrate,
    required this.width,
    required this.height,
    required this.frameRate,
    required this.codec,
    required this.audioLevel,
    required this.timestamp,
  });

  /// 从 JSON 解析
  factory WebRTCQualityStatsData.fromJson(Map<String, dynamic> json) {
    return WebRTCQualityStatsData(
      rtt: json['rtt'] as int? ?? 0,
      packetLoss: json['packetLoss'] as int? ?? 0,
      jitter: json['jitter'] as int? ?? 0,
      bitrate: json['bitrate'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      frameRate: json['frameRate'] as int? ?? 0,
      codec: json['codec'] as String? ?? '',
      audioLevel: json['audioLevel'] as int? ?? 0,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'rtt': rtt,
      'packetLoss': packetLoss,
      'jitter': jitter,
      'bitrate': bitrate,
      'width': width,
      'height': height,
      'frameRate': frameRate,
      'codec': codec,
      'audioLevel': audioLevel,
      'timestamp': timestamp,
    };
  }

  /// 创建空的统计数据
  factory WebRTCQualityStatsData.empty() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WebRTCQualityStatsData(
      rtt: 0,
      packetLoss: 0,
      jitter: 0,
      bitrate: 0,
      width: 0,
      height: 0,
      frameRate: 0,
      codec: '',
      audioLevel: 0,
      timestamp: now,
    );
  }

  /// 计算质量评分 (0-100)
  int calculateScore() {
    int score = 100;

    // RTT 影响 (0-25分)
    if (rtt > 300) {
      score -= 25;
    } else if (rtt > 200) {
      score -= 15;
    } else if (rtt > 100) {
      score -= 5;
    }

    // 丢包影响 (0-35分)
    if (packetLoss > 10) {
      score -= 35;
    } else if (packetLoss > 5) {
      score -= 25;
    } else if (packetLoss > 2) {
      score -= 10;
    }

    // 抖动影响 (0-20分)
    if (jitter > 50) {
      score -= 20;
    } else if (jitter > 30) {
      score -= 10;
    }

    // 帧率影响 (0-20分)
    if (frameRate < 15) {
      score -= 20;
    } else if (frameRate < 24) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  /// 获取网络质量等级
  WebRTCNetworkQuality getQualityLevel() {
    final score = calculateScore();
    if (score >= 80) {
      return WebRTCNetworkQuality.excellent;
    } else if (score >= 60) {
      return WebRTCNetworkQuality.good;
    } else if (score >= 40) {
      return WebRTCNetworkQuality.fair;
    } else {
      return WebRTCNetworkQuality.poor;
    }
  }

  @override
  String toString() {
    return 'WebRTCQualityStatsData('
        'rtt: ${rtt}ms, '
        'packetLoss: $packetLoss%, '
        'jitter: ${jitter}ms, '
        'score: ${calculateScore()}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebRTCQualityStatsData &&
        other.rtt == rtt &&
        other.packetLoss == packetLoss &&
        other.jitter == jitter &&
        other.bitrate == bitrate &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(rtt, packetLoss, jitter, bitrate, timestamp);
  }
}

/// WebRTC 网络质量等级
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

/// WebRTC 会话状态
enum WebRTCSessionState {
  /// 初始化中
  initializing,

  /// 响铃中
  ringing,

  /// 连接中
  connecting,

  /// 已连接
  connected,

  /// 重连中
  reconnecting,

  /// 已暂停
  paused,

  /// 已结束
  ended,

  /// 失败
  failed,
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

  /// 获取对应的颜色名称
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
  bool get isAcceptable => this != WebRTCNetworkQuality.poor;

  /// 是否为优秀的质量
  bool get isExcellent => this == WebRTCNetworkQuality.excellent;
}
