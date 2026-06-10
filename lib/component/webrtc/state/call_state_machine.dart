/// WebRTC 通话状态机
///
/// 管理音视频通话的状态转换，确保状态转换的正确性
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'call_state.dart';
import '../connection/connection.dart';
import '../connection/connection_state.dart';

/// WebRTC 通话状态机
///
/// 实现标准化的状态转换逻辑，消除竞态条件
class WebRTCCallStateMachine {
  /// 会话 ID
  final String sessionId;

  /// 对等端 ID
  final String peerId;

  /// 通话类型
  final WebRTCCallType callType;

  /// 通话方向
  final WebRTCCallDirection direction;

  /// 当前状态
  WebRTCCallState _state = WebRTCCallState.idle;

  /// 开始时间
  DateTime? _startTime;

  /// 连接时间
  DateTime? _connectTime;

  /// 结束时间
  DateTime? _endTime;

  /// 状态变更流控制器
  final StreamController<WebRTCCallStateEvent> _stateController =
      StreamController<WebRTCCallStateEvent>.broadcast();

  /// 关联的连接
  WebRTCConnection? _connection;

  /// 连接状态订阅（用于在 dispose 时取消）
  StreamSubscription<WebRTCConnectionStateEvent>? _connectionSubscription;

  /// 状态转换历史
  final List<WebRTCCallStateEvent> _history = [];

  /// 当前状态
  WebRTCCallState get state => _state;

  /// 状态转换历史
  List<WebRTCCallStateEvent> get history => List.unmodifiable(_history);

  /// 状态变更流
  Stream<WebRTCCallStateEvent> get stateStream => _stateController.stream;

  /// 是否为发起方
  bool get isCaller => direction == WebRTCCallDirection.outgoing;

  /// 通话时长（秒）
  int get duration {
    final endTime = _endTime ?? DateTime.now();
    final startTime = _connectTime ?? _startTime ?? DateTime.now();
    return endTime.difference(startTime).inSeconds;
  }

  /// 是否已接通
  bool get isConnected => _connectTime != null;

  /// 通话信息
  WebRTCCallInfo get info {
    return WebRTCCallInfo(
      sessionId: sessionId,
      callId: sessionId, // 简化处理，实际应该有独立的 callId
      peerId: peerId,
      callType: callType,
      direction: direction,
      state: _state,
      startTime: _startTime ?? DateTime.now(),
      connectTime: _connectTime,
      endTime: _endTime,
    );
  }

  /// 创建状态机
  WebRTCCallStateMachine({
    required this.sessionId,
    required this.peerId,
    required this.callType,
    required this.direction,
  });

  /// 初始化状态机
  void initialize() {
    if (_state != WebRTCCallState.idle) {
      throw StateError('StateMachine already initialized');
    }

    _startTime = DateTime.now();

    if (isCaller) {
      _setState(WebRTCCallState.inviting);
    } else {
      _setState(WebRTCCallState.ringing);
    }
  }

  /// 设置关联的连接
  void setConnection(WebRTCConnection connection) {
    // 取消旧订阅，防止泄漏
    _connectionSubscription?.cancel();
    _connection = connection;

    // 监听连接状态变化
    _connectionSubscription = connection.stateStream.listen((event) {
      _handleConnectionStateChange(event);
    });
  }

  /// 处理连接状态变化
  void _handleConnectionStateChange(WebRTCConnectionStateEvent event) {
    switch (event.state) {
      case WebRTCConnectionState.connected:
        _onConnected();
        break;

      case WebRTCConnectionState.disconnected:
        if (_state == WebRTCCallState.connected) {
          _setState(WebRTCCallState.reconnecting);
        }
        break;

      case WebRTCConnectionState.failed:
        _setState(
          WebRTCCallState.failed,
          error: event.error ?? 'Connection failed',
        );
        break;

      case WebRTCConnectionState.closed:
        if (_state != WebRTCCallState.ended &&
            _state != WebRTCCallState.failed &&
            _state != WebRTCCallState.rejected &&
            _state != WebRTCCallState.busy &&
            _state != WebRTCCallState.unanswered) {
          _setState(WebRTCCallState.ended);
        }
        break;

      default:
        break;
    }
  }

  /// 连接成功回调
  void _onConnected() {
    _connectTime ??= DateTime.now();
    _setState(WebRTCCallState.connected);
  }

  /// 开始连接（转为连接中状态）
  Future<void> startConnecting() async {
    if (!canTransitionTo(WebRTCCallState.connecting)) {
      return;
    }

    _setState(WebRTCCallState.connecting);
  }

  /// 对方响铃
  void onRinging() {
    if (!canTransitionTo(WebRTCCallState.ringing)) {
      return;
    }

    _setState(WebRTCCallState.ringing);
  }

  /// 对方拒绝接听
  void onRejected({String? reason}) {
    if (!canTransitionTo(WebRTCCallState.rejected)) {
      return;
    }

    _endTime = DateTime.now();
    _setState(WebRTCCallState.rejected, error: reason);
  }

  /// 对方忙碌
  void onBusy({String? reason}) {
    if (!canTransitionTo(WebRTCCallState.busy)) {
      return;
    }

    _endTime = DateTime.now();
    _setState(WebRTCCallState.busy, error: reason);
  }

  /// 对方无响应
  void onUnanswered() {
    if (!canTransitionTo(WebRTCCallState.unanswered)) {
      return;
    }

    _endTime = DateTime.now();
    _setState(WebRTCCallState.unanswered);
  }

  /// 挂断通话
  Future<void> hangup({String? reason}) async {
    if (!canTransitionTo(WebRTCCallState.ended)) {
      return;
    }

    _endTime = DateTime.now();
    _setState(
      WebRTCCallState.ended,
      metadata: {'reason': reason ?? 'user_hangup'},
    );

    // 关闭连接
    await _connection?.close(reason: reason ?? 'hangup');
  }

  /// 暂停通话
  void pause() {
    if (_state != WebRTCCallState.connected) {
      return;
    }

    _setState(WebRTCCallState.paused);
  }

  /// 恢复通话
  void resume() {
    if (_state != WebRTCCallState.paused) {
      return;
    }

    _setState(WebRTCCallState.connected);
  }

  /// 静音/取消静音
  void setMuted(bool muted) {
    if (_state != WebRTCCallState.connected) {
      return;
    }

    _setState(muted ? WebRTCCallState.muted : WebRTCCallState.connected);
  }

  /// 设置状态
  void _setState(
    WebRTCCallState newState, {
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    if (_state == newState) {
      return; // 状态未变化
    }

    if (!canTransitionTo(newState)) {
      throw StateError('Invalid state transition: $_state -> $newState');
    }

    final previousState = _state;
    _state = newState;

    final event = WebRTCCallStateEvent(
      state: newState,
      previousState: previousState,
      timestamp: DateTime.now(),
      error: error,
      metadata: metadata,
      sessionId: sessionId,
      userId: peerId,
    );

    _history.add(event);

    if (!_stateController.isClosed) {
      _stateController.add(event);
    }
  }

  /// 检查是否可以转换到目标状态
  bool canTransitionTo(WebRTCCallState targetState) {
    // 定义合法的状态转换
    const validTransitions = {
      // 从空闲状态
      WebRTCCallState.idle: {WebRTCCallState.inviting, WebRTCCallState.ringing},

      // 从发起中状态
      WebRTCCallState.inviting: {
        WebRTCCallState.ringing,
        WebRTCCallState.connecting,
        WebRTCCallState.rejected,
        WebRTCCallState.busy,
        WebRTCCallState.unanswered,
        WebRTCCallState.ended,
      },

      // 从响铃中状态
      WebRTCCallState.ringing: {
        WebRTCCallState.connecting,
        WebRTCCallState.rejected,
        WebRTCCallState.busy,
        WebRTCCallState.unanswered,
        WebRTCCallState.ended,
      },

      // 从连接中状态
      WebRTCCallState.connecting: {
        WebRTCCallState.connected,
        WebRTCCallState.failed,
        WebRTCCallState.ended,
      },

      // 从已连接状态
      WebRTCCallState.connected: {
        WebRTCCallState.paused,
        WebRTCCallState.muted,
        WebRTCCallState.reconnecting,
        WebRTCCallState.ended,
      },

      // 从重连中状态
      WebRTCCallState.reconnecting: {
        WebRTCCallState.connected,
        WebRTCCallState.failed,
        WebRTCCallState.ended,
      },

      // 从暂停状态
      WebRTCCallState.paused: {
        WebRTCCallState.connected,
        WebRTCCallState.ended,
      },

      // 从静音状态
      WebRTCCallState.muted: {WebRTCCallState.connected, WebRTCCallState.ended},

      // 从失败状态
      WebRTCCallState.failed: {WebRTCCallState.ended},

      // 从拒绝状态
      WebRTCCallState.rejected: {WebRTCCallState.ended},

      // 从忙碌状态
      WebRTCCallState.busy: {WebRTCCallState.ended},

      // 从无响应状态
      WebRTCCallState.unanswered: {WebRTCCallState.ended},
    };

    final allowedStates = validTransitions[_state];
    return allowedStates?.contains(targetState) ?? false;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    await _connection?.dispose();
    _connection = null;

    await _stateController.close();
  }

  /// 获取状态转换图描述（用于调试）
  static String getStateTransitionGraph() {
    return '''
WebRTC Call State Machine:

idle ──┬──► inviting (caller)
     │
     └──► ringing (callee)

inviting ──► ringing ──► connecting ──► connected
ringing ──► connecting ──► connected
           │              │
           ├──────────────┴──► rejected
           │              │
           ├──────────────┴──► busy
           │              │
           ├──────────────┴──► unanswered
           │              │
           └──────────────┴──► failed
                                 │
                                 └──► ended

connected ──► paused
          ───► muted
          ───► reconnecting ──► connected
          ───► ended

paused ──► connected
muted ──► connected
''';
  }
}

/// WebRTC 通话状态机管理器
///
/// 管理多个通话状态机
class WebRTCCallStateMachineManager {
  /// 单例实例
  static final WebRTCCallStateMachineManager instance =
      WebRTCCallStateMachineManager._internal();

  /// 工厂构造函数
  factory WebRTCCallStateMachineManager() => instance;

  /// 私有构造函数
  WebRTCCallStateMachineManager._internal();

  /// 活跃的状态机映射 (sessionId -> stateMachine)
  final Map<String, WebRTCCallStateMachine> _stateMachines = {};

  /// 用户到会话的映射 (userId -> sessionId)
  final Map<String, String> _userSessions = {};

  /// 状态变更流控制器
  final StreamController<WebRTCCallStateEvent> _stateController =
      StreamController<WebRTCCallStateEvent>.broadcast();

  /// 全局状态变更流
  Stream<WebRTCCallStateEvent> get stateStream => _stateController.stream;

  /// 创建状态机
  WebRTCCallStateMachine createStateMachine({
    required String sessionId,
    required String peerId,
    required WebRTCCallType callType,
    required WebRTCCallDirection direction,
  }) {
    if (_stateMachines.containsKey(sessionId)) {
      throw StateError('StateMachine for session $sessionId already exists');
    }

    // 检查用户是否已在通话中
    final existingSessionId = _userSessions[peerId];
    if (existingSessionId != null) {
      throw StateError('User $peerId is already in call $existingSessionId');
    }

    final stateMachine = WebRTCCallStateMachine(
      sessionId: sessionId,
      peerId: peerId,
      callType: callType,
      direction: direction,
    );

    // 监听状态变化
    stateMachine.stateStream.listen((event) {
      // 转发状态变化
      if (!_stateController.isClosed) {
        _stateController.add(event);
      }

      // 处理终止状态，清理状态机
      if (event.state.isTerminal) {
        Future<dynamic>.delayed(const Duration(seconds: 5), () {
          removeStateMachine(sessionId);
        });
      }
    });

    _stateMachines[sessionId] = stateMachine;
    _userSessions[peerId] = sessionId;

    return stateMachine;
  }

  /// 获取状态机
  WebRTCCallStateMachine? getStateMachine(String sessionId) {
    return _stateMachines[sessionId];
  }

  /// 根据用户 ID 获取状态机
  WebRTCCallStateMachine? getStateMachineByUser(String userId) {
    final sessionId = _userSessions[userId];
    if (sessionId != null) {
      return _stateMachines[sessionId];
    }
    return null;
  }

  /// 移除状态机
  void removeStateMachine(String sessionId) {
    final stateMachine = _stateMachines.remove(sessionId);
    if (stateMachine != null) {
      _userSessions.remove(stateMachine.peerId);
    }
  }

  /// 关闭所有状态机
  Future<void> closeAll() async {
    final stateMachines = List<WebRTCCallStateMachine>.from(
      _stateMachines.values,
    );
    _stateMachines.clear();
    _userSessions.clear();

    for (final stateMachine in stateMachines) {
      await stateMachine.dispose();
    }

    await _stateController.close();
  }

  /// 获取所有活跃的通话信息
  List<WebRTCCallInfo> getActiveCalls() {
    return _stateMachines.values
        .where((sm) => !sm.state.isTerminal)
        .map((sm) => sm.info)
        .toList();
  }

  /// 检查用户是否在通话中
  bool isUserInCall(String userId) {
    return _userSessions.containsKey(userId);
  }

  /// 释放资源
  Future<void> dispose() async {
    await closeAll();
  }
}
