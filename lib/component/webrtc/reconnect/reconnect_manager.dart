/// WebRTC 重连管理器
///
/// 管理连接断开后的智能重连逻辑
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'reconnect_config.dart';

/// WebRTC 重连管理器
///
/// 实现指数退避和心跳保活机制
class WebRTCReconnectManager {
  /// 重连配置
  final WebRTCReconnectConfig config;

  /// 重连回调
  final Future<void> Function() onReconnect;

  /// 心跳发送回调（可选）
  /// 返回 true 表示心跳发送成功，false 表示发送失败
  final Future<bool> Function()? onSendHeartbeat;

  /// 当前重试次数
  int _retryCount = 0;

  /// 重连定时器
  Timer? _retryTimer;

  /// 心跳定时器
  Timer? _heartbeatTimer;

  /// 心跳超时定时器
  Timer? _heartbeatTimeoutTimer;

  /// 是否正在重连
  bool _isReconnecting = false;

  /// 是否已连接
  bool _isConnected = false;

  /// 最后心跳时间
  DateTime? _lastHeartbeatTime;

  /// 重连状态变更流控制器
  final StreamController<WebRTCReconnectStateEvent> _stateController =
      StreamController<WebRTCReconnectStateEvent>.broadcast();

  /// 重连状态变更流
  Stream<WebRTCReconnectStateEvent> get stateStream => _stateController.stream;

  /// 创建重连管理器
  WebRTCReconnectManager({
    required this.config,
    required this.onReconnect,
    this.onSendHeartbeat,
  });

  /// 连接成功时调用
  void onConnected() {
    if (!_isConnected) {
      _isConnected = true;
      _reset();
      _startHeartbeat();
      _notifyState(WebRTCReconnectState.connected);
    }
  }

  /// 连接断开时调用
  void onDisconnected() {
    if (_isConnected && !_isReconnecting) {
      _isConnected = false;
      _stopHeartbeat();
      _scheduleReconnect(reason: 'disconnected');
    }
  }

  /// 连接失败时调用
  void onConnectionFailed() {
    _isConnected = false;
    _stopHeartbeat();
    _scheduleReconnect(reason: 'connection_failed');
  }

  /// 计划重连
  void _scheduleReconnect({String? reason}) {
    if (!config.enabled) {
      _notifyState(WebRTCReconnectState.disabled);
      return;
    }

    if (_retryCount >= config.maxRetries) {
      _notifyState(WebRTCReconnectState.gaveUp);
      dispose();
      return;
    }

    if (_isReconnecting) {
      return;
    }

    _isReconnecting = true;

    final delay = config.calculateRetryDelay(_retryCount);

    _notifyState(
      WebRTCReconnectState.scheduled,
      metadata: {'delay': delay, 'attempt': _retryCount + 1},
    );

    _retryTimer = Timer(delay, () async {
      _retryCount++;
      _notifyState(
        WebRTCReconnectState.reconnecting,
        metadata: {'attempt': _retryCount},
      );

      try {
        await onReconnect();
      } catch (e, s) {
        _isReconnecting = false;

        // 如果未达到最大重试次数，继续重试
        if (_retryCount < config.maxRetries) {
          _scheduleReconnect(reason: 'retry_failed');
        } else {
          _notifyState(WebRTCReconnectState.gaveUp);
          dispose();
        }
      }
    });
  }

  /// 开始心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();

    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
  }

  /// 发送心跳
  Future<void> _sendHeartbeat() async {
    if (_isConnected && !_isReconnecting) {
      _lastHeartbeatTime = DateTime.now();

      // 尝试通过回调发送心跳消息
      bool heartbeatSent = false;
      if (onSendHeartbeat != null) {
        try {
          heartbeatSent = await onSendHeartbeat!();
        } catch (e) {
          heartbeatSent = false;
        }
      }

      // 如果没有心跳回调或发送失败，仅记录日志
      if (heartbeatSent) {
      } else {}

      // 设置心跳超时检测
      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = Timer(config.heartbeatTimeout, () {
        // 心跳超时，认为连接已断开
        if (_isConnected) {
          onDisconnected();
        }
      });
    }
  }

  /// 重置状态
  void _reset() {
    _retryCount = 0;
    _isReconnecting = false;
    _retryTimer?.cancel();
  }

  /// 通知状态变更
  void _notifyState(
    WebRTCReconnectState state, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_stateController.isClosed) {
      _stateController.add(
        WebRTCReconnectStateEvent(
          state: state,
          retryCount: _retryCount,
          maxRetries: config.maxRetries,
          metadata: metadata,
        ),
      );
    }
  }

  /// 释放资源
  void dispose() {
    _reset();
    _stopHeartbeat();
    _stateController.close();
  }
}

/// 重连状态
enum WebRTCReconnectState {
  /// 已连接
  connected,

  /// 计划重连
  scheduled,

  /// 正在重连
  reconnecting,

  /// 放弃重连
  gaveUp,

  /// 已禁用
  disabled,
}

/// 重连状态事件
class WebRTCReconnectStateEvent {
  /// 状态
  final WebRTCReconnectState state;

  /// 当前重试次数
  final int retryCount;

  /// 最大重试次数
  final int maxRetries;

  /// 额外数据
  final Map<String, dynamic>? metadata;

  const WebRTCReconnectStateEvent({
    required this.state,
    required this.retryCount,
    required this.maxRetries,
    this.metadata,
  });

  /// 是否为最终状态
  bool get isTerminal {
    return state == WebRTCReconnectState.gaveUp ||
        state == WebRTCReconnectState.disabled;
  }

  @override
  String toString() {
    return 'ReconnectStateEvent{state: $state, retryCount: $retryCount/$maxRetries}';
  }
}
