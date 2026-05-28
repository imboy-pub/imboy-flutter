import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/websocket.dart';

/// ACK管理器 - 负责ACK的发送和重试
///
/// 功能：
/// 1. 发送ACK并记录待确认ACK
/// 2. 自动重试失败的ACK（最多4次，与服务端 QoS 重试次数对齐）
/// 3. 提供ACK状态查询
class AckManager {
  static AckManager? _instance;

  static AckManager get to {
    _instance ??= AckManager._internal();
    return _instance!;
  }

  AckManager._internal() {
    _init();
  }

  bool _isInitialized = false;

  /// 待确认的ACK映射表
  /// Key: msgId, Value: _PendingAck
  final Map<String, _PendingAck> _pendingAcks = {};

  /// 【修复】Timer 映射表，用于跟踪和取消所有活动的 Timer
  /// Key: msgId, Value: Timer
  final Map<String, Timer> _activeTimers = {};

  /// 【优化】定期清理 Timer（每小时清理一次孤立的 Timer）
  Timer? _timerCleanupTimer;

  // 【修复 H2】导入 async 库以使用 unawaited
  // 已经在顶部导入了 dart:async

  /// WebSocket 连接状态（通过事件同步）
  bool _isWebSocketConnected = false;

  /// 【修复】检查 WebSocket 是否已连接（双重检查：事件状态 + 直接查询）
  ///
  /// 解决竞态条件问题：当 WebSocket 刚连接时，状态事件可能还未被处理，
  /// 此时直接查询 WebSocketService 可以获得最新的连接状态。
  bool get _isConnected {
    // 优先使用事件总线状态（避免循环依赖）
    if (_isWebSocketConnected) return true;

    // 备选方案：直接查询 WebSocketService 的当前状态
    // 这解决了连接建立初期状态同步延迟的问题
    try {
      return WebSocketService.to.status == SocketStatus.connected;
    } on Object catch (e) {
      // 如果 WebSocketService 不可用（例如测试环境），返回缓存状态
      iPrint('⚠️ [ACK_MANAGER] WebSocketService 不可用: $e');
      return _isWebSocketConnected;
    }
  }

  /// 最大重试次数
  ///
  /// 与服务端 QoS 投递重试次数对齐（协议一致性修复 D1）：
  /// 服务端在线投递重试节奏为 2s/5s/7s/11s 共 4 次后转离线存储，
  /// 客户端 ACK 重试次数需对应设置为 4，避免服务端已完成全部重试
  /// 而客户端尚未重试到位导致消息被误判为未达成 ACK。
  static const int _maxRetries = 4;

  /// 重试间隔策略（毫秒）
  /// 采用指数退避：3s -> 5s -> 10s -> 15s（对应服务端4次重试窗口）
  static const List<int> _retryIntervals = [3000, 5000, 10000, 15000];

  /// 获取当前重试次数对应的间隔
  int _getRetryInterval(int retryCount) {
    if (retryCount < 0) return _retryIntervals.first;
    if (retryCount >= _retryIntervals.length) return _retryIntervals.last;
    return _retryIntervals[retryCount];
  }

  /// ACK RTT 观测窗口大小（用于分位统计）
  static const int _maxAckRttSamples = 200;

  /// 最近重试上限告警事件保留条数
  static const int _maxRetryCeilingEvents = 20;

  /// ACK RTT 样本（毫秒）
  final List<int> _ackRttSamples = [];

  /// 最近重试上限命中记录
  final List<Map<String, dynamic>> _recentRetryCeilingHits = [];

  /// 重试上限命中总次数
  int _retryCeilingHitCount = 0;

  /// 最新 ACK RTT（毫秒）
  int? _lastAckRttMs;

  /// WebSocket 状态订阅
  StreamSubscription<dynamic>? _wsStatusSubscription;

  void _init() {
    if (_isInitialized) return;

    // 订阅 WebSocket 状态变化事件（解耦：不再直接依赖 WebSocketService）
    _wsStatusSubscription?.cancel();
    _wsStatusSubscription = AppEventBus.on<WebSocketStatusChangedEvent>()
        .listen((event) {
          _isWebSocketConnected = event.status == 'connected';
        });

    // 【优化】启动定期清理 Timer（每小时清理一次孤立的 Timer）
    _timerCleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _cleanupOrphanTimers(),
    );

    _isInitialized = true;
    iPrint('✅ [ACK_MANAGER] AckManager initialized');
  }

  void dispose() {
    // 取消 WebSocket 状态订阅
    _wsStatusSubscription?.cancel();
    _wsStatusSubscription = null;
    // 取消所有活动的 Timer（包括清理 Timer）
    _cancelAllTimers();
    _timerCleanupTimer?.cancel();
    _timerCleanupTimer = null;
    // 清理待确认 ACK
    _pendingAcks.clear();
    _resetRuntimeStats();
    _isInitialized = false;
    _instance = null;
  }

  /// 【新增】取消所有活动的 Timer
  void _cancelAllTimers() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    iPrint('🗑️ [ACK_MANAGER] 已取消所有 Timer');
  }

  /// 【新增】取消特定消息的 Timer
  void _cancelTimer(String msgId) {
    final timer = _activeTimers.remove(msgId);
    if (timer != null) {
      timer.cancel();
    }
  }

  void _resetRuntimeStats() {
    _ackRttSamples.clear();
    _recentRetryCeilingHits.clear();
    _retryCeilingHitCount = 0;
    _lastAckRttMs = null;
  }

  _AckRttPercentiles _computeAckPercentiles() {
    if (_ackRttSamples.isEmpty) {
      return const _AckRttPercentiles();
    }
    final sorted = List<int>.from(_ackRttSamples)..sort();
    return _AckRttPercentiles(
      p50: _percentileOfSorted(sorted, 0.50),
      p90: _percentileOfSorted(sorted, 0.90),
      p95: _percentileOfSorted(sorted, 0.95),
      p99: _percentileOfSorted(sorted, 0.99),
    );
  }

  int _percentileOfSorted(List<int> sorted, double percentile) {
    if (sorted.isEmpty) return 0;
    final rawIndex = ((sorted.length - 1) * percentile).round();
    final index = rawIndex.clamp(0, sorted.length - 1);
    return sorted[index];
  }

  void _recordAckConfirmationMetrics(_PendingAck ack) {
    final now = DateTimeHelper.millisecond();
    final rttMs = (now - ack.sendTime).clamp(0, 24 * 60 * 60 * 1000).toInt();

    _lastAckRttMs = rttMs;
    _ackRttSamples.add(rttMs);
    if (_ackRttSamples.length > _maxAckRttSamples) {
      _ackRttSamples.removeAt(0);
    }

    final percentiles = _computeAckPercentiles();
    AppEventBus.fire(
      AckRttMetricsUpdatedEvent(
        messageId: ack.msgId,
        messageType: ack.type,
        rttMs: rttMs,
        retryCount: ack.retryCount,
        sampleCount: _ackRttSamples.length,
        p50Ms: percentiles.p50,
        p90Ms: percentiles.p90,
        p95Ms: percentiles.p95,
        p99Ms: percentiles.p99,
      ),
    );

    iPrint(
      '📈 [ACK_MANAGER] ACK RTT: msgId=${ack.msgId}, rtt=${rttMs}ms, p50=${percentiles.p50}ms, p95=${percentiles.p95}ms',
    );
  }

  void _recordRetryCeilingHit(_PendingAck ack) {
    final now = DateTimeHelper.millisecond();
    _retryCeilingHitCount++;

    final ceilingEvent = <String, dynamic>{
      'message_id': ack.msgId,
      'message_type': ack.type,
      'retry_count': ack.retryCount,
      'max_retry_count': _maxRetries,
      'occurred_at_ms': now,
    };
    _recentRetryCeilingHits.add(ceilingEvent);
    if (_recentRetryCeilingHits.length > _maxRetryCeilingEvents) {
      _recentRetryCeilingHits.removeAt(0);
    }

    AppEventBus.fire(
      AckRetryCeilingReachedEvent(
        messageId: ack.msgId,
        messageType: ack.type,
        retryCount: ack.retryCount,
        maxRetryCount: _maxRetries,
        pendingCount: _pendingAcks.length,
        occurredAtMs: now,
      ),
    );

    iPrint(
      '🚨 [ACK_MANAGER] ACK重试达到上限: msgId=${ack.msgId}, retry=${ack.retryCount}/$_maxRetries',
    );
  }

  @visibleForTesting
  void debugMarkRetryCeilingReached({
    required String messageId,
    String messageType = 'C2C',
    int retryCount = _maxRetries,
  }) {
    final mockAck = _PendingAck(
      msgId: messageId,
      type: messageType,
      content: '',
      sendTime: DateTimeHelper.millisecond(),
      retryCount: retryCount,
    );
    _recordRetryCeilingHit(mockAck);
  }

  /// 发送ACK（带重试机制）
  ///
  /// [type] 消息类型（C2C、C2G、S2C等）
  /// [msgId] 消息ID
  /// [overrideDeviceId] 可选：覆盖 deviceId（用于测试）
  void sendAck(String type, String msgId, {String? overrideDeviceId}) {
    // 【修复 C1】检查deviceId，支持测试环境 Mock
    final effectiveDeviceId = overrideDeviceId ?? deviceId;
    if (effectiveDeviceId.isEmpty) {
      iPrint('❌ [ACK_MANAGER] deviceId 为空，跳过ACK: msgId=$msgId');
      return;
    }

    // 【修复】移除去重逻辑，每次都发送 ACK 确保服务器收到
    // 如果服务器多次发送同一条消息（网络重试），客户端应该每次都返回 ACK

    final ackMsg = generateAckMessage(
      type,
      msgId,
      overrideDeviceId: effectiveDeviceId,
    );

    // 记录待确认的ACK
    _pendingAcks[msgId] = _PendingAck(
      msgId: msgId,
      type: type,
      content: ackMsg,
      sendTime: DateTimeHelper.millisecond(),
      retryCount: 0,
    );

    iPrint('📤 [ACK_MANAGER] 发送ACK: msgId=$msgId, type=$type, retryCount=0');
    _sendAckInternal(msgId);

    // 设置重试定时器
    _scheduleRetry(msgId);
  }

  /// 生成 ACK 消息格式（唯一维护点）
  ///
  /// [type] 消息类型（C2C、C2G、S2C等）
  /// [msgId] 消息ID
  /// [overrideDeviceId] 可选：覆盖 deviceId（用于测试）
  ///
  /// 返回格式：CLIENT_ACK,type,msgId,deviceId
  ///
  /// 抛出 [ArgumentError] 当参数无效时
  String generateAckMessage(
    String type,
    String msgId, {
    String? overrideDeviceId,
  }) {
    // 参数验证：防止空值导致格式错误
    if (type.isEmpty || msgId.isEmpty) {
      iPrint(
        '❌ [ACK_MANAGER] generateAckMessage 参数无效: type=$type, msgId=$msgId',
      );
      throw ArgumentError('ACK type and msgId cannot be empty');
    }
    // 【修复 C1】支持测试环境 Mock deviceId
    final effectiveDeviceId = overrideDeviceId ?? deviceId;
    if (effectiveDeviceId.isEmpty) {
      iPrint('⚠️ [ACK_MANAGER] deviceId 为空，ACK 可能无效');
    }
    return 'CLIENT_ACK,$type,$msgId,$effectiveDeviceId';
  }

  /// 直接发送 ACK（不经过重试队列，用于需要立即发送的场景）
  ///
  /// [overrideDeviceId] 可选：覆盖 deviceId（用于测试）
  void sendAckDirect(String type, String msgId, {String? overrideDeviceId}) {
    try {
      // 【修复 C1】支持测试环境 Mock deviceId
      final effectiveDeviceId = overrideDeviceId ?? deviceId;
      if (effectiveDeviceId.isEmpty) {
        iPrint('❌ [WS_ACK] deviceId 为空，无法发送ACK: msgId=$msgId, type=$type');
        return;
      }

      final ackMsg = generateAckMessage(
        type,
        msgId,
        overrideDeviceId: effectiveDeviceId,
      );
      iPrint('📤 [WS_ACK] 准备发送ACK: msgId=$msgId, type=$type, content=$ackMsg');

      // 【解耦】检查 WebSocket 连接状态（通过内部状态变量）
      iPrint(
        '🔌 [WS_ACK] WebSocket 状态: ${_isConnected ? "connected" : "disconnected"}',
      );

      if (!_isConnected) {
        iPrint('⚠️ [WS_ACK] WebSocket 未连接，无法发送ACK: msgId=$msgId');
        return;
      }

      // 【解耦】通过事件总线发送 ACK 消息
      if (WebSocketService.to.framing == FramingMode.v2) {
        // V2 模式优先使用二进制帧
        final int? numericId = int.tryParse(msgId);
        if (numericId != null) {
          final bytes = ImboyFrame.ack(numericId);
          WebSocketService.to.sendDirect(bytes);
          iPrint('⚡ [WS_ACK] 直接发送 v2 二进制 ACK 成功: msgId=$msgId');
          return;
        }
      }

      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: ackMsg,
          messageId: msgId,
          priority: 1, // ACK 消息优先级较高
        ),
      );
      iPrint('⚡ [WS_ACK] 直接发送ACK成功: msgId=$msgId, type=$type');
    } on Object catch (e) {
      iPrint('❌ [WS_ACK] ACK发送失败: msgId=$msgId, type=$type, error=$e');
    }
  }

  /// 内部发送ACK方法
  void _sendAckInternal(String msgId) {
    final ack = _pendingAcks[msgId];
    if (ack == null) {
      iPrint('⚠️ [ACK_MANAGER] ACK不存在（可能已确认）: msgId=$msgId');
      return;
    }

    try {
      // 【解耦】通过事件总线发送 ACK 消息
      if (WebSocketService.to.framing == FramingMode.v2) {
        final int? numericId = int.tryParse(msgId);
        if (numericId != null) {
          final bytes = ImboyFrame.ack(numericId);
          WebSocketService.to.sendDirect(bytes);
          iPrint(
            '✅ [ACK_MANAGER] v2 二进制 ACK 发送成功: msgId=$msgId, retryCount=${ack.retryCount}',
          );
          return;
        }
      }

      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: ack.content,
          messageId: msgId,
        ),
      );
      iPrint(
        '✅ [ACK_MANAGER] ACK发送成功: msgId=$msgId, retryCount=${ack.retryCount}',
      );
    } on Object catch (e) {
      iPrint('❌ [ACK_MANAGER] ACK发送异常: msgId=$msgId, error=$e');
      // 不立即重试，等待定时器触发
    }
  }

  /// 安排重试
  void _scheduleRetry(String msgId) {
    // 【修复】取消之前的 Timer（如果存在）
    _cancelTimer(msgId);

    final ack = _pendingAcks[msgId];
    if (ack == null) return;

    // 计算重试间隔
    final interval = _getRetryInterval(ack.retryCount);

    // 【修复 H2】创建新的 Timer 并跟踪，添加异常保护
    final timer = Timer(Duration(milliseconds: interval), () {
      try {
        // 从跟踪表中移除
        _activeTimers.remove(msgId);

        final ack = _pendingAcks[msgId];

        // ACK已被确认，不需要重试
        if (ack == null) {
          iPrint('✅ [ACK_MANAGER] ACK已确认，取消重试: msgId=$msgId');
          return;
        }

        // 达到最大重试次数
        if (ack.retryCount >= _maxRetries) {
          _recordRetryCeilingHit(ack);
          iPrint('❌ [ACK_MANAGER] ACK发送失败，已达最大重试次数: msgId=$msgId');
          _pendingAcks.remove(msgId);
          return;
        }

        // 重试
        ack.retryCount++;
        iPrint(
          '🔄 [ACK_MANAGER] ACK重试 ${ack.retryCount}/$_maxRetries: msgId=$msgId',
        );
        _sendAckInternal(msgId);

        // 继续安排下一次重试
        if (ack.retryCount < _maxRetries) {
          try {
            _scheduleRetry(msgId);
          } catch (e) {
            iPrint('❌ [ACK_MANAGER] 安排下次重试失败: msgId=$msgId, error=$e');
          }
        }
      } catch (e, s) {
        // 【修复 H2】Timer 回调异常保护：防止未捕获异常导致 Timer 泄漏
        iPrint('❌ [ACK_MANAGER] Timer 回调异常: msgId=$msgId, error=$e, stack=$s');
      }
    });

    // 【修复】跟踪 Timer
    _activeTimers[msgId] = timer;
  }

  /// ACK确认后删除记录（当收到服务端确认时调用）
  ///
  /// 目前服务端没有返回ACK确认，这个方法预留
  /// 未来可以通过服务端返回的ACK确认来调用
  void ackConfirmed(String msgId) {
    // 【修复】取消对应的 Timer
    _cancelTimer(msgId);
    final ack = _pendingAcks.remove(msgId);
    if (ack != null) {
      _recordAckConfirmationMetrics(ack);
      iPrint('✅ [ACK_MANAGER] ACK已确认: msgId=$msgId');
    }
  }

  /// 获取待确认ACK数量
  int get pendingCount => _pendingAcks.length;

  /// 获取待确认ACK列表
  List<String> get pendingAckList => _pendingAcks.keys.toList();

  /// 清理所有待确认ACK
  void clear() {
    // 【修复】取消所有 Timer
    _cancelAllTimers();
    final count = _pendingAcks.length;
    _pendingAcks.clear();
    _resetRuntimeStats();
    iPrint('🗑️ [ACK_MANAGER] 已清理 $count 个待确认ACK');
  }

  /// 清理过期的待确认ACK（超过30秒）
  void cleanupExpired() {
    final now = DateTimeHelper.millisecond();
    final expiredKeys = <String>[];

    _pendingAcks.forEach((msgId, ack) {
      final age = now - ack.sendTime; // 毫秒差
      if (age > 30000) {
        // 30秒
        expiredKeys.add(msgId);
      }
    });

    if (expiredKeys.isNotEmpty) {
      for (final msgId in expiredKeys) {
        // 【修复】取消对应的 Timer
        _cancelTimer(msgId);
        _pendingAcks.remove(msgId);
      }
      iPrint('🗑️ [ACK_MANAGER] 清理了 ${expiredKeys.length} 个过期ACK');
    }
  }

  /// 【优化】清理孤立的 Timer（对应的 ACK 已被确认但 Timer 未被取消）
  void _cleanupOrphanTimers() {
    if (_activeTimers.isEmpty) return;

    final orphanTimers = <String>[];

    for (final entry in _activeTimers.entries) {
      final msgId = entry.key;
      // 如果对应的 ACK 不存在，说明是孤立的 Timer
      if (!_pendingAcks.containsKey(msgId)) {
        orphanTimers.add(msgId);
      }
    }

    if (orphanTimers.isNotEmpty) {
      for (final msgId in orphanTimers) {
        _cancelTimer(msgId);
      }
      iPrint('🧹 [ACK_MANAGER] 清理了 ${orphanTimers.length} 个孤立的 Timer');
    }
  }

  /// 获取ACK统计信息
  Map<String, dynamic> getStats() {
    final percentiles = _computeAckPercentiles();
    return {
      'pending_count': _pendingAcks.length,
      'max_retries': _maxRetries,
      'retry_interval_ms': _retryIntervals.first,
      'retry_intervals_ms': _retryIntervals,
      'pending_ack_list': pendingAckList,
      'ack_rtt_sample_count': _ackRttSamples.length,
      'ack_rtt_last_ms': _lastAckRttMs,
      'ack_rtt_p50_ms': percentiles.p50,
      'ack_rtt_p90_ms': percentiles.p90,
      'ack_rtt_p95_ms': percentiles.p95,
      'ack_rtt_p99_ms': percentiles.p99,
      'retry_ceiling_hit_count': _retryCeilingHitCount,
      'recent_retry_ceiling_hits': List<Map<String, dynamic>>.from(
        _recentRetryCeilingHits,
      ),
    };
  }
}

class _AckRttPercentiles {
  final int p50;
  final int p90;
  final int p95;
  final int p99;

  const _AckRttPercentiles({
    this.p50 = 0,
    this.p90 = 0,
    this.p95 = 0,
    this.p99 = 0,
  });
}

/// 待确认的ACK
class _PendingAck {
  final String msgId;
  final String type;
  final String content;
  final int sendTime; // 毫秒时间戳
  int retryCount;

  _PendingAck({
    required this.msgId,
    required this.type,
    required this.content,
    required this.sendTime,
    required this.retryCount,
  });

  /// 转换为JSON（用于调试）
  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'type': type,
      'content': content,
      'sendTime': sendTime, // 毫秒时间戳
      'sendTimeIso': DateTime.fromMillisecondsSinceEpoch(
        sendTime,
      ).toIso8601String(),
      'retryCount': retryCount,
    };
  }
}
