/// WebRTC 信令协议 v2.0
///
/// 扩展的信令消息类型和格式定义
library;

// ignore_for_file: constant_identifier_names
import 'signaling_models.dart';

/// WebRTC 信令消息类型 v2.0
///
/// 扩展原有信令类型，增加心跳、重连、质量报告等功能
enum WebRTCSignalingType {
  // === 原有类型 ===
  /// 发起通话（包含 SDP offer）
  offer,

  /// 接听通话（包含 SDP answer）
  answer,

  /// ICE 候选
  candidate,

  /// 挂断通话
  bye,

  /// 响铃中
  ringing,

  /// 对方忙碌
  busy,

  /// 离开通话
  leave,

  /// 心跳保活（旧版兼容）
  keepalive,

  // === 新增类型 v2.0 ===
  /// 会话心跳（替代 keepalive）
  heartbeat,

  /// 重连请求
  reconnect,

  /// 重连确认
  reconnect_ack,

  /// 质量报告
  quality_report,

  /// 错误通知
  error,

  /// 会话状态更新
  session_update,

  /// ICE 重启请求
  ice_restart,

  /// 带宽统计报告
  bandwidth_stats,
}

/// 扩展信令类型的辅助方法
extension WebRTCSignalingTypeExtension on WebRTCSignalingType {
  /// 获取信令类型的消息标识
  String get messageKey {
    switch (this) {
      case WebRTCSignalingType.offer:
        return 'webrtc_offer';
      case WebRTCSignalingType.answer:
        return 'webrtc_answer';
      case WebRTCSignalingType.candidate:
        return 'webrtc_candidate';
      case WebRTCSignalingType.bye:
        return 'webrtc_bye';
      case WebRTCSignalingType.ringing:
        return 'webrtc_ringing';
      case WebRTCSignalingType.busy:
        return 'webrtc_busy';
      case WebRTCSignalingType.leave:
        return 'webrtc_leave';
      case WebRTCSignalingType.keepalive:
        return 'webrtc_keepalive';
      case WebRTCSignalingType.heartbeat:
        return 'webrtc_heartbeat';
      case WebRTCSignalingType.reconnect:
        return 'webrtc_reconnect';
      case WebRTCSignalingType.reconnect_ack:
        return 'webrtc_reconnect_ack';
      case WebRTCSignalingType.quality_report:
        return 'webrtc_quality_report';
      case WebRTCSignalingType.error:
        return 'webrtc_error';
      case WebRTCSignalingType.session_update:
        return 'webrtc_session_update';
      case WebRTCSignalingType.ice_restart:
        return 'webrtc_ice_restart';
      case WebRTCSignalingType.bandwidth_stats:
        return 'webrtc_bandwidth_stats';
    }
  }

  /// 是否为控制消息（不需要可靠传输）
  bool get isControlMessage {
    return this == WebRTCSignalingType.heartbeat ||
        this == WebRTCSignalingType.keepalive ||
        this == WebRTCSignalingType.quality_report ||
        this == WebRTCSignalingType.bandwidth_stats;
  }

  /// 是否为关键消息（需要保证送达）
  bool get isCritical {
    return this == WebRTCSignalingType.offer ||
        this == WebRTCSignalingType.answer ||
        this == WebRTCSignalingType.bye ||
        this == WebRTCSignalingType.reconnect ||
        this == WebRTCSignalingType.reconnect_ack;
  }

  /// 是否需要确认
  bool get requiresAck {
    return isCritical;
  }

  /// 从字符串解析信令类型
  static WebRTCSignalingType? fromString(String value) {
    // 移除 'webrtc_' 前缀
    final typeKey = value.replaceFirst('webrtc_', '');

    try {
      return WebRTCSignalingType.values.firstWhere(
        (e) => e.name == typeKey,
      );
    } catch (_) {
      // 尝试直接匹配（兼容旧格式）
      try {
        return WebRTCSignalingType.values.firstWhere(
          (e) => e.name == value,
        );
      } catch (_) {
        return null;
      }
    }
  }
}

/// WebRTC 错误码规范
class WebRTCErrorCode {
  // 连接错误 (1xxx)
  static const int connectionFailed = 1001;
  static const int iceConnectionFailed = 1002;
  static const int timeout = 1003;
  static const int networkError = 1004;
  static const int iceRestartFailed = 1005;

  // 信令错误 (2xxx)
  static const int invalidSdp = 2001;
  static const int incompatibleMedia = 2002;
  static const int protocolError = 2003;
  static const int sdpCreationFailed = 2004;

  // 权限错误 (3xxx)
  static const int permissionDenied = 3001;
  static const int deviceNotFound = 3002;
  static const int userBlocked = 3003;
  static const int deviceInUse = 3004;

  // 资源错误 (4xxx)
  static const int noMemory = 4001;
  static const int cpuOverload = 4002;
  static const int batteryLow = 4003;

  // 业务错误 (5xxx)
  static const int userNotFound = 5001;
  static const int userOffline = 5002;
  static const int callRejected = 5003;
  static const int callAlreadyExists = 5004;
  static const int userInCall = 5005;

  /// 获取错误描述
  static String getDescription(int code) {
    switch (code) {
      case connectionFailed:
        return '连接失败';
      case iceConnectionFailed:
        return 'ICE 连接失败';
      case timeout:
        return '连接超时';
      case networkError:
        return '网络错误';
      case iceRestartFailed:
        return 'ICE 重启失败';
      case invalidSdp:
        return '无效的 SDP';
      case incompatibleMedia:
        return '不兼容的媒体类型';
      case protocolError:
        return '协议错误';
      case sdpCreationFailed:
        return 'SDP 创建失败';
      case permissionDenied:
        return '权限被拒绝';
      case deviceNotFound:
        return '设备未找到';
      case userBlocked:
        return '用户已被阻止';
      case deviceInUse:
        return '设备正在使用中';
      case noMemory:
        return '内存不足';
      case cpuOverload:
        return 'CPU 过载';
      case batteryLow:
        return '电量过低';
      case userNotFound:
        return '用户不存在';
      case userOffline:
        return '用户离线';
      case callRejected:
        return '通话被拒绝';
      case callAlreadyExists:
        return '通话已存在';
      case userInCall:
        return '用户正在通话中';
      default:
        return '未知错误';
    }
  }

  /// 是否为可重试的错误
  static bool isRetryable(int code) {
    return code == networkError ||
        code == timeout ||
        code == iceConnectionFailed ||
        code == userOffline;
  }

  /// 是否为致命错误
  static bool isFatal(int code) {
    return code == permissionDenied ||
        code == userBlocked ||
        code == noMemory ||
        code == userNotFound;
  }
}

/// WebRTC 消息优先级
enum WebRTCMessagePriority {
  /// 低优先级（统计信息、日志）
  low,

  /// 普通优先级（ICE 候选、控制消息）
  normal,

  /// 高优先级（信令消息、重连请求）
  high,

  /// 紧急优先级（挂断、错误通知）
  urgent,
}

/// 扩展消息优先级的辅助方法
extension WebRTCMessagePriorityExtension on WebRTCMessagePriority {
  /// 获取优先级权重（数字越大优先级越高）
  int get weight {
    switch (this) {
      case WebRTCMessagePriority.low:
        return 1;
      case WebRTCMessagePriority.normal:
        return 2;
      case WebRTCMessagePriority.high:
        return 3;
      case WebRTCMessagePriority.urgent:
        return 4;
    }
  }

  /// 从信令类型获取优先级
  static WebRTCMessagePriority fromSignalingType(WebRTCSignalingType type) {
    switch (type) {
      case WebRTCSignalingType.bye:
      case WebRTCSignalingType.error:
        return WebRTCMessagePriority.urgent;

      case WebRTCSignalingType.offer:
      case WebRTCSignalingType.answer:
      case WebRTCSignalingType.reconnect:
      case WebRTCSignalingType.reconnect_ack:
        return WebRTCMessagePriority.high;

      case WebRTCSignalingType.candidate:
      case WebRTCSignalingType.session_update:
      case WebRTCSignalingType.ice_restart:
        return WebRTCMessagePriority.normal;

      case WebRTCSignalingType.heartbeat:
      case WebRTCSignalingType.quality_report:
      case WebRTCSignalingType.bandwidth_stats:
        return WebRTCMessagePriority.low;

      default:
        return WebRTCMessagePriority.normal;
    }
  }
}

/// WebRTC 信令消息构建器
class WebRTCSignalingBuilder {
  /// 生成信令消息
  static Map<String, dynamic> buildMessage({
    required WebRTCSignalingType type,
    required String msgId,
    required String from,
    required String to,
    Map<String, dynamic>? payload,
    String? sessionId,
    int? sequence,
    String? correlationId,
    WebRTCMessagePriority? priority,
  }) {
    final message = <String, dynamic>{
      'id': msgId,
      'type': type.messageKey,
      'from': from,
      'to': to,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'payload': payload ?? <String, dynamic>{},
    };

    // v2.0 扩展字段
    if (sessionId != null) {
      message['session_id'] = sessionId;
    }
    if (sequence != null) {
      message['seq'] = sequence;
    }
    if (correlationId != null) {
      message['correlation_id'] = correlationId;
    }
    if (priority != null) {
      message['priority'] = priority.weight;
    }

    return message;
  }

  /// 构建 offer 消息
  static Map<String, dynamic> buildOffer({
    required String msgId,
    required String from,
    required String to,
    required Map<String, dynamic> sdp,
    required String mediaType,
    String? sessionId,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.offer,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'media': mediaType,
        'sd': sdp,
      },
    );
  }

  /// 构建 answer 消息
  static Map<String, dynamic> buildAnswer({
    required String msgId,
    required String from,
    required String to,
    required Map<String, dynamic> sdp,
    required String mediaType,
    String? sessionId,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.answer,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'media': mediaType,
        'sd': sdp,
      },
    );
  }

  /// 构建 candidate 消息
  static Map<String, dynamic> buildCandidate({
    required String msgId,
    required String from,
    required String to,
    required Map<String, dynamic> candidate,
    String? sessionId,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.candidate,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'candidate': candidate,
      },
    );
  }

  /// 构建 bye 消息
  static Map<String, dynamic> buildBye({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    String? reason,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.bye,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'sid': sessionId,
        'reason': reason,
      },
    );
  }

  /// 构建心跳消息
  static Map<String, dynamic> buildHeartbeat({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    int? timestamp,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.heartbeat,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// 构建重连请求消息
  static Map<String, dynamic> buildReconnect({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    required String reason,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.reconnect,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// 构建重连确认消息
  static Map<String, dynamic> buildReconnectAck({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    bool accepted = true,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.reconnect_ack,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'accepted': accepted,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// 构建错误消息
  static Map<String, dynamic> buildError({
    required String msgId,
    required String from,
    required String to,
    required int errorCode,
    String? errorMessage,
    String? sessionId,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.error,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      priority: WebRTCMessagePriority.urgent,
      payload: {
        'code': errorCode,
        'message': errorMessage ?? WebRTCErrorCode.getDescription(errorCode),
      },
    );
  }

  /// 构建质量报告消息
  static Map<String, dynamic> buildQualityReport({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    required WebRTCQualityStatsData stats,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.quality_report,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: stats.toJson(),
    );
  }

  /// 构建会话状态更新消息
  static Map<String, dynamic> buildSessionUpdate({
    required String msgId,
    required String from,
    required String to,
    required String sessionId,
    required String state,
    Map<String, dynamic>? metadata,
  }) {
    return buildMessage(
      type: WebRTCSignalingType.session_update,
      msgId: msgId,
      from: from,
      to: to,
      sessionId: sessionId,
      payload: {
        'state': state,
        'metadata': metadata,
      },
    );
  }
}
