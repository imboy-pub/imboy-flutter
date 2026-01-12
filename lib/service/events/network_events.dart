import 'base_event.dart';
import 'package:imboy/service/network_monitor.dart' show NetworkType;

/// 网络状态相关事件
///
/// 定义了网络连接状态变化、重连请求等网络相关的事件类型

/// 网络状态变化事件
///
/// 当设备网络连接状态发生变化时触发
final class NetworkStatusChangedEvent extends AppEvent {
  /// 旧的网络类型
  final NetworkType oldType;

  /// 新的网络类型
  final NetworkType newType;

  /// 是否从无网络变为有网络
  final bool isNetworkRecovered;

  /// 是否从有网络变为无网络
  final bool isNetworkLost;

  /// 是否为网络类型切换（如 WiFi ↔ 移动网络）
  final bool isTypeChanged;

  /// 当前网络是否可用
  final bool isAvailable;

  const NetworkStatusChangedEvent({
    required this.oldType,
    required this.newType,
    required this.isAvailable,
  })  : isNetworkRecovered = oldType == NetworkType.none && newType != NetworkType.none,
        isNetworkLost = oldType != NetworkType.none && newType == NetworkType.none,
        isTypeChanged = oldType != NetworkType.none && newType != NetworkType.none && oldType != newType;

  @override
  List<Object> get props => [oldType, newType, isAvailable];

  @override
  String toString() {
    return 'NetworkStatusChangedEvent(oldType: ${oldType.name}, newType: ${newType.name}, isAvailable: $isAvailable, isRecovered: $isNetworkRecovered, isLost: $isNetworkLost, isTypeChanged: $isTypeChanged)';
  }
}

/// 网络重连请求事件
///
/// 当需要重新建立 WebSocket 连接时触发
final class NetworkReconnectRequestedEvent extends AppEvent {
  /// 重连原因
  final NetworkReconnectReason reason;

  /// 触发源（标识是谁发起的重连请求）
  final String source;

  /// 是否为自动重连
  final bool isAutomatic;

  /// 当前重连次数（本次会话）
  final int currentAttempt;

  /// 最大重连次数
  final int maxAttempts;

  /// 建议的重连延迟（毫秒）
  final int? suggestedDelay;

  const NetworkReconnectRequestedEvent({
    required this.reason,
    required this.source,
    this.isAutomatic = true,
    this.currentAttempt = 1,
    this.maxAttempts = 16,
    this.suggestedDelay,
  });

  @override
  List<Object?> get props => [reason, source, isAutomatic, currentAttempt, maxAttempts, suggestedDelay];

  @override
  String toString() {
    return 'NetworkReconnectRequestedEvent(reason: $reason, source: $source, isAutomatic: $isAutomatic, attempt: $currentAttempt/$maxAttempts, suggestedDelay: ${suggestedDelay}ms)';
  }
}

/// 网络重连原因枚举
enum NetworkReconnectReason {
  /// 应用启动时首次连接
  appStart,

  /// 网络从无到有
  networkRecovered,

  /// WebSocket 连接断开
  websocketDisconnected,

  /// WebSocket 连接超时
  websocketTimeout,

  /// WebSocket 发生错误
  websocketError,

  /// 心跳超时
  heartbeatTimeout,

  /// 服务器主动断开
  serverInitiated,

  /// 用户手动触发
  userInitiated,

  /// Token 刷新后需要重连
  tokenRefreshed,

  /// 其他原因
  other,
}

/// 网络质量变化事件
///
/// 当检测到网络质量（延迟、丢包率等）发生变化时触发
final class NetworkQualityChangedEvent extends AppEvent {
  /// 当前网络类型
  final NetworkType networkType;

  /// 网络延迟（毫秒）
  final int latency;

  /// 网络质量评级
  final NetworkQuality quality;

  /// 丢包率（0.0 - 1.0）
  final double? packetLoss;

  /// 带宽（字节/秒）
  final int? bandwidth;

  const NetworkQualityChangedEvent({
    required this.networkType,
    required this.latency,
    required this.quality,
    this.packetLoss,
    this.bandwidth,
  });

  @override
  List<Object?> get props => [networkType, latency, quality, packetLoss, bandwidth];

  @override
  String toString() {
    return 'NetworkQualityChangedEvent(networkType: ${networkType.name}, latency: ${latency}ms, quality: $quality, packetLoss: $packetLoss, bandwidth: $bandwidth)';
  }
}

/// 网络质量枚举
enum NetworkQuality {
  /// 优秀（延迟 < 50ms）
  excellent,

  /// 良好（延迟 50-150ms）
  good,

  /// 一般（延迟 150-300ms）
  fair,

  /// 较差（延迟 300-600ms）
  poor,

  /// 很差（延迟 > 600ms）
  terrible,

  /// 未知（无法测量）
  unknown,
}

/// 网络连通性测试事件
///
/// 当进行网络连通性测试时触发
final class NetworkConnectivityTestEvent extends AppEvent {
  /// 测试类型（ping, http, dns 等）
  final NetworkTestType testType;

  /// 测试目标（URL 或 IP）
  final String target;

  /// 测试结果
  final bool isSuccess;

  /// 测试耗时（毫秒）
  final int duration;

  /// 错误消息（如果失败）
  final String? errorMessage;

  /// 附加信息（如 DNS 解析时间、HTTP 状态码等）
  final Map<String, dynamic>? extraInfo;

  const NetworkConnectivityTestEvent({
    required this.testType,
    required this.target,
    required this.isSuccess,
    required this.duration,
    this.errorMessage,
    this.extraInfo,
  });

  @override
  List<Object?> get props => [testType, target, isSuccess, duration, errorMessage, extraInfo];

  @override
  String toString() {
    return 'NetworkConnectivityTestEvent(testType: $testType, target: $target, isSuccess: $isSuccess, duration: ${duration}ms, errorMessage: $errorMessage)';
  }
}

/// 网络测试类型枚举
enum NetworkTestType {
  /// Ping 测试
  ping,

  /// HTTP 请求测试
  http,

  /// HTTPS 请求测试
  https,

  /// DNS 解析测试
  dns,

  /// WebSocket 连接测试
  websocket,

  /// 综合测试
  combined,
}

/// 网络使用警告事件
///
/// 当检测到网络使用异常（如流量过大、频繁请求等）时触发
final class NetworkUsageWarningEvent extends AppEvent {
  /// 警告类型
  final NetworkWarningType warningType;

  /// 警告消息
  final String message;

  /// 当前使用的字节数（会话累计）
  final int bytesUsed;

  /// 请求次数（会话累计）
  final int requestCount;

  /// 阈值（触发警告的临界值）
  final int? threshold;

  const NetworkUsageWarningEvent({
    required this.warningType,
    required this.message,
    required this.bytesUsed,
    required this.requestCount,
    this.threshold,
  });

  @override
  List<Object?> get props => [warningType, message, bytesUsed, requestCount, threshold];

  @override
  String toString() {
    return 'NetworkUsageWarningEvent(warningType: $warningType, message: $message, bytesUsed: $bytesUsed, requestCount: $requestCount, threshold: $threshold)';
  }
}

/// 网络警告类型枚举
enum NetworkWarningType {
  /// 流量过大
  highDataUsage,

  /// 请求过于频繁
  frequentRequests,

  /// 长时间连接
  longConnection,

  /// 异常流量模式
  unusualPattern,

  /// 其他警告
  other,
}
