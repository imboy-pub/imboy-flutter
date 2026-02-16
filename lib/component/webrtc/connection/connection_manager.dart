/// WebRTC 连接管理器
///
/// 管理所有 WebRTC 连接的生命周期，替代全局 webRTCSessions Map
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection.dart';
import 'connection_state.dart';
import 'connection_config.dart';

/// WebRTC 连接管理器
///
/// 单例模式，负责创建、管理和清理所有 WebRTC 连接
class WebRTCConnectionManager {
  /// 单例实例
  static final WebRTCConnectionManager instance =
      WebRTCConnectionManager._internal();

  /// 工厂构造函数
  factory WebRTCConnectionManager() => instance;

  /// 私有构造函数
  WebRTCConnectionManager._internal() {
    debugPrint('WebRTCConnectionManager initialized');
  }

  /// 活跃的连接映射 (sessionId -> connection)
  final Map<String, WebRTCConnection> _connections = {};

  /// 用户到会话的映射 (userId -> sessionId)
  final Map<String, String> _userSessions = {};

  /// 连接状态变更流控制器
  final StreamController<WebRTCConnectionStateEvent> _stateController =
      StreamController<WebRTCConnectionStateEvent>.broadcast();

  /// 全局状态变更流
  Stream<WebRTCConnectionStateEvent> get stateStream => _stateController.stream;

  /// 获取所有活跃连接
  List<WebRTCConnection> get connections => _connections.values.toList();

  /// 获取连接数量
  int get connectionCount => _connections.length;

  /// 创建新连接
  ///
  /// [sessionId] 会话 ID
  /// [peerId] 对等端 ID
  /// [mediaType] 媒体类型
  /// [config] 连接配置（可选）
  ///
  /// 返回新创建的连接实例
  Future<WebRTCConnection> createConnection({
    required String sessionId,
    required String peerId,
    required WebRTCMediaType mediaType,
    WebRTCConnectionConfig? config,
  }) async {
    // 检查是否已存在相同会话
    if (_connections.containsKey(sessionId)) {
      debugPrint('Connection $sessionId already exists');
      return _connections[sessionId]!;
    }

    // 检查用户是否已在其他通话中
    final existingSessionId = _userSessions[peerId];
    if (existingSessionId != null) {
      debugPrint('User $peerId already in session $existingSessionId');
      throw StateError('User $peerId is already in a call');
    }

    debugPrint('Creating new WebRTC connection: $sessionId with $peerId');

    // 创建连接实例
    final connection = WebRTCConnection(
      sessionId: sessionId,
      peerId: peerId,
      mediaType: mediaType,
      config: config,
    );

    // 监听状态变更
    connection.stateStream.listen((event) {
      // 转发状态变更
      if (!_stateController.isClosed) {
        _stateController.add(event);
      }

      // 处理连接关闭
      if (event.state == WebRTCConnectionState.closed) {
        _removeConnection(sessionId);
      }
    });

    // 初始化连接
    await connection.initialize();

    // 存储连接
    _connections[sessionId] = connection;
    _userSessions[peerId] = sessionId;

    debugPrint('Connection $sessionId created and initialized');

    return connection;
  }

  /// 获取连接
  ///
  /// [sessionId] 会话 ID
  ///
  /// 返回连接实例，如果不存在返回 null
  WebRTCConnection? getConnection(String sessionId) {
    return _connections[sessionId];
  }

  /// 根据用户 ID 获取连接
  ///
  /// [userId] 用户 ID
  ///
  /// 返回连接实例，如果用户不在通话中返回 null
  WebRTCConnection? getConnectionByUser(String userId) {
    final sessionId = _userSessions[userId];
    if (sessionId != null) {
      return _connections[sessionId];
    }
    return null;
  }

  /// 检查用户是否在通话中
  ///
  /// [userId] 用户 ID
  ///
  /// 返回 true 如果用户正在通话
  bool isUserInCall(String userId) {
    return _userSessions.containsKey(userId);
  }

  /// 获取用户的会话 ID
  ///
  /// [userId] 用户 ID
  ///
  /// 返回会话 ID，如果用户不在通话中返回 null
  String? getSessionIdByUser(String userId) {
    return _userSessions[userId];
  }

  /// 关闭连接
  ///
  /// [sessionId] 会话 ID
  /// [reason] 关闭原因（可选）
  Future<void> closeConnection(String sessionId, {String? reason}) async {
    final connection = _connections.remove(sessionId);
    if (connection != null) {
      debugPrint('Closing connection $sessionId (reason: $reason)');
      await connection.close(reason: reason);
    }
  }

  /// 根据用户 ID 关闭连接
  ///
  /// [userId] 用户 ID
  /// [reason] 关闭原因（可选）
  Future<void> closeConnectionByUser(String userId, {String? reason}) async {
    final sessionId = _userSessions[userId];
    if (sessionId != null) {
      await closeConnection(sessionId, reason: reason);
    }
  }

  /// 移除连接（内部使用）
  void _removeConnection(String sessionId) {
    final connection = _connections[sessionId];
    if (connection != null) {
      // 从用户映射中移除
      _userSessions.remove(connection.peerId);
      // 从连接映射中移除
      _connections.remove(sessionId);
      debugPrint('Connection $sessionId removed from manager');
    }
  }

  /// 关闭所有连接
  Future<void> closeAll({String? reason}) async {
    debugPrint('Closing all connections (${_connections.length})');

    final connections = List<WebRTCConnection>.from(_connections.values);
    _connections.clear();
    _userSessions.clear();

    for (final connection in connections) {
      try {
        await connection.close(reason: reason ?? 'close_all');
      } catch (e, s) {
        debugPrint('Error closing connection ${connection.sessionId}: $e\n$s');
      }
    }
  }

  /// 清理已关闭的连接
  void cleanupClosedConnections() {
    final closedSessions = <String>[];
    _connections.forEach((sessionId, connection) {
      if (connection.isClosed) {
        closedSessions.add(sessionId);
      }
    });

    for (final sessionId in closedSessions) {
      _removeConnection(sessionId);
    }

    if (closedSessions.isNotEmpty) {
      debugPrint('Cleaned up ${closedSessions.length} closed connections');
    }
  }

  /// 获取连接统计信息
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{
      'total': _connections.length,
      'byState': <String, int>{},
      'byType': <String, int>{},
    };

    for (final connection in _connections.values) {
      // 按状态统计
      final stateName = connection.state.name;
      stats['byState'][stateName] = (stats['byState'][stateName] ?? 0) + 1;

      // 按类型统计
      final typeName = connection.mediaType.name;
      stats['byType'][typeName] = (stats['byType'][typeName] ?? 0) + 1;
    }

    return stats;
  }

  /// 打印调试信息
  void printDebugInfo() {
    debugPrint('=== WebRTC Connection Manager Debug Info ===');
    debugPrint('Active connections: ${_connections.length}');
    debugPrint('User sessions: ${_userSessions.length}');

    _connections.forEach((sessionId, connection) {
      debugPrint('  - $sessionId: ${connection.state} with ${connection.peerId}');
    });

    final stats = getStatistics();
    debugPrint('Statistics: $stats');
    debugPrint('==========================================');
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('Disposing WebRTCConnectionManager');
    await closeAll(reason: 'manager_dispose');
    await _stateController.close();
  }

  /// 检查内存泄漏（用于调试）
  void checkMemoryLeaks() {
    if (_connections.isNotEmpty) {
      debugPrint('⚠️  Memory leak warning: ${_connections.length} connections still active');
      printDebugInfo();
    }

    if (_userSessions.isNotEmpty) {
      debugPrint('⚠️  Memory leak warning: ${_userSessions.length} user sessions still active');
    }
  }
}
