import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' show defaultHeaders;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/storage.dart';
import '../component/helper/datetime.dart' show DateTimeHelper;
import 'websocket_message_queue.dart';
import 'package:imboy/config/routes.dart' show AppRoutes;
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:flutter/foundation.dart';

enum SocketStatus { connecting, connected, disconnected }

class WebSocketService {
  // 单例模式
  static WebSocketService? _instance;
  static WebSocketService get to => _instance ??= WebSocketService._internal();
  WebSocketService._internal();

  // 状态管理
  SocketStatus _status = SocketStatus.disconnected;
  SocketStatus get status => _status;

  // 状态变化回调
  final List<void Function(SocketStatus)> _statusCallbacks = [];

  final PersistentMessageQueue _messageQueue = PersistentMessageQueue.to;

  // 网络与连接
  final ExponentialBackoff _backoff = ExponentialBackoff(maxRetries: 16);
  final Set<String> _pendingMessages = <String>{}; // 等待确认的消息ID
  WebSocketChannel? _channel;
  bool _isFlushing = false;

  // 订阅管理
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  // 配置参数
  static const _pingInterval = Duration(seconds: 120);
  bool _connecting = false;

  /// 初始化服务
  void init() {
    // 订阅消息发送请求事件（解耦：MessageService 通过事件请求发送消息）
    AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
      _handleMessageSendRequest,
    );

    // 订阅强制关闭事件（解耦：MessageS2C 通过事件强制关闭连接）
    AppEventBus.on<WebSocketForceCloseEvent>().listen(_handleForceClose);

    // 订阅重连请求事件（解耦：NetworkMonitor 通过事件请求重连）
    AppEventBus.on<WebSocketReconnectRequestEvent>().listen(
      _handleReconnectRequest,
    );

    // 初始化连接（应用启动时调用）
    if (_shouldReconnect()) {
      openSocket(from: 'init');
    }
  }

  /// 处理消息发送请求事件
  void _handleMessageSendRequest(WebSocketMessageSendRequestEvent event) {
    sendMessage(event.message, event.messageId);
  }

  /// 处理强制关闭事件
  void _handleForceClose(WebSocketForceCloseEvent event) {
    iPrint('> ws: 收到强制关闭请求，permanent=${event.permanent}');
    closeSocket(permanent: event.permanent);
  }

  /// 处理重连请求事件
  void _handleReconnectRequest(WebSocketReconnectRequestEvent event) {
    iPrint('> ws: 收到重连请求，source=${event.source}');
    if (event.force || _shouldReconnect()) {
      // 延迟重连以避免频繁重连
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_shouldReconnect()) {
          openSocket(from: event.source);
        }
      });
    }
  }

  /// 释放资源
  void dispose() {
    _cleanupResources();
  }

  /// 统一状态更新方法
  void _updateStatus(SocketStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;

      // 发布状态变化事件（解耦：MessageService 等通过事件监听状态）
      AppEventBus.fire(WebSocketStatusChangedEvent(status: newStatus.name));

      // 通知所有监听器
      for (final callback in _statusCallbacks) {
        try {
          callback(newStatus);
        } catch (e) {
          iPrint('> ws: 状态回调执行失败: $e');
        }
      }

      iPrint('> ws: 状态变化: ${oldStatus.name} -> ${newStatus.name}');
    }
  }

  /// 添加状态监听器
  void addStatusListener(void Function(SocketStatus) callback) {
    if (!_statusCallbacks.contains(callback)) {
      _statusCallbacks.add(callback);
    }
  }

  /// 移除状态监听器
  void removeStatusListener(void Function(SocketStatus) callback) {
    _statusCallbacks.remove(callback);
  }

  /// 判断是否需要建立连接
  bool _shouldReconnect() {
    return UserRepoLocal.to.isLoggedIn && !_connecting;
  }

  /// 对外接口：建立连接
  Future<void> openSocket({String from = ''}) async {
    if (!_preConnectionCheck()) return;
    await _establishConnection(from);
  }

  /// 连接前置检查
  bool _preConnectionCheck() {
    if (_connecting || _status == SocketStatus.connected) return false;
    if (!_checkLoginStatus()) return false;
    return true;
  }

  /// 检查用户登录状态
  bool _checkLoginStatus() {
    if (UserRepoLocal.to.isLoggedIn) return true;
    iPrint('> ws: 取消连接（用户未登录）');
    return false;
  }

  /// 建立WebSocket连接核心逻辑
  Future<void> _establishConnection(String from) async {
    _connecting = true;
    _updateStatus(SocketStatus.connecting);
    iPrint('> ws: 开始连接 (from: $from)');

    try {
      // 增强的网络连通性检查
      if (!await _checkNetworkConnectivity()) {
        iPrint('> ws: 网络连通性检查失败，取消连接');
        return;
      }

      final token = await _getValidToken();
      if (token.isEmpty) {
        iPrint('> ws: 无效的访问令牌，取消连接');
        return;
      }

      _channel = IOWebSocketChannel.connect(
        Env.effectiveWsUrl ?? 'wss://pro.imboy.pub/ws/',
        headers: {...await defaultHeaders(), Keys.tokenKey: token},
        protocols: ['text', 'sip'],
        pingInterval: _pingInterval,
      );
      await _channel!.ready;

      _updateStatus(SocketStatus.connected);
      _backoff.reset();
      _cancelReconnectTimer();
      await _flushMessageQueue();

      _wsSub?.cancel();
      final start = DateTime.now();

      _wsSub = _channel?.stream.listen(
        (data) => _onMessage(data),
        onError: _onError,
        onDone: () {
          final end = DateTime.now();
          iPrint(
            'Connection closed after ${end.difference(start).inSeconds} seconds',
          );
          _onClose();
        },
        cancelOnError: true,
      );
      AppLogger.info('WebSocket 连接成功: ${Env.effectiveWsUrl}');

      // 连接成功后重置重连计数器
      _backoff.reset();
      _cancelReconnectTimer();
    } catch (e, s) {
      AppLogger.error('WebSocket 连接失败: ${Env.effectiveWsUrl}', e, s);
      _handleConnectionFailure(e);
      // 【修复】异常发生时确保清理 WebSocket 资源
      _cancelStream();
    } finally {
      _connecting = false;
    }
  }

  /// 处理连接失败后的操作
  void _handleConnectionFailure(dynamic error) {
    _updateStatus(SocketStatus.disconnected);
    _scheduleReconnection();
  }

  /// 处理接收到的消息（优化版：非阻塞立即分发）
  /// Process received messages (optimized: non-blocking immediate dispatch)
  Future<void> _onMessage(dynamic message) async {
    // 【新增】记录接收消息的基本信息
    final msgPreview = message.toString().length > 100
        ? '${message.toString().substring(0, 100)}...'
        : message.toString();
    iPrint('📡 [WS] 收到消息: $msgPreview');

    // iPrint("ws_onMessage ${DateTime.now()}");

    // 快速空值检查
    if (message == null || (message is String && message.trim().isEmpty)) {
      return;
    }

    try {
      // 统一消息解析
      final msg = _parseMessage(message);
      if (msg.isEmpty) return;

      final action = msg['action']?.toString() ?? '';
      final messageType = msg['type']?.toString() ?? '';
      final messageId = msg['id']?.toString() ?? '';

      final type = messageType.toUpperCase();
      msg['type'] = type;

      iPrint('📩 [WS] 解析消息: type=$type, msgId=$messageId');

      // 【关键优化】立即发送ACK，避免服务器超时重试
      // 先处理 WEBRTC（需要独立处理）
      if (type.startsWith('WEBRTC_') && messageId.isNotEmpty) {
        try {
          iPrint('🎯 [WS_ACK] 发送WEBRTC ACK: msgId=$messageId');
          AckManager.to.sendAckDirect('WEBRTC', messageId);
        } catch (e) {
          iPrint('⚠️ [WS_ACK] WEBRTC ACK发送失败: msgId=$messageId, error=$e');
        }
      }

      // 统一 ACK 发送入口：所有需要 ACK 的消息类型（按优先级排序）
      // 优先级：S2C(服务端指令) > C2S(服务端确认) > C2C(单聊) > C2G(群聊)
      if (['S2C', 'C2S', 'C2C', 'C2G'].contains(type) && messageId.isNotEmpty) {
        try {
          iPrint('🎯 [WS_ACK] 准备发送ACK: type=$type, msgId=$messageId');
          AckManager.to.sendAckDirect(type, messageId);
        } catch (e) {
          iPrint('⚠️ [WS_ACK] ACK发送失败: msgId=$messageId, error=$e');
        }
      } else if (messageId.isEmpty && !type.startsWith('WEBRTC_')) {
        iPrint('⚠️ [WS_ACK] 消息ID为空，跳过ACK: type=$type');
      }

      // 消息确认处理（包含ACK和撤回确认）
      _handleMessageAck(action, messageId);

      // 【优化】过滤 ACK 相关消息，避免转发到 MessageService
      // 这些消息已在 WebSocket 层面处理完成，不需要进一步处理
      if (action == 'CLIENT_ACK_CONFIRM' ||
          action == 'CLIENT_ACK_ERROR' ||
          action.endsWith('_ACK')) {
        iPrint('⏭️ [WS] ACK消息已处理，跳过转发: action=$action, msgId=$messageId');
        return;
      }

      // 统一分发到事件总线（非阻塞，不等待处理完成）
      // Unified dispatch to event bus (non-blocking, don't wait for processing)
      try {
        iPrint("> msg listen: $type, ${DateTime.now()}");

        // 如果有 ts 字段，则打印延迟
        // Log latency if timestamp provided
        if (msg.containsKey('ts')) {
          iPrint(
            "> msg latency: ${DateTimeHelper.millisecond() - (msg['ts'] as int)} ms",
          );
        }

        // ⚡ 非阻塞处理：通过事件总线发布消息，解耦 WebSocket 和 MessageService
        // Non-blocking processing: publish message via event bus to decouple WebSocket and MessageService
        AppEventBus.fire(WebSocketMessageReceivedEvent(type: type, data: msg));
      } catch (e, s) {
        iPrint('Error dispatching message event: $e - $s');
      }
    } catch (e) {
      iPrint('> ws: 消息处理失败: $e');
      // 解析失败时发送原始消息事件
      _handleRawMessage(message);
    }
  }

  /// 统一消息解析方法
  Map<String, dynamic> _parseMessage(dynamic message) {
    if (message is String) {
      return jsonDecode(message);
    } else if (message is Map<String, dynamic>) {
      return message;
    } else if (message is Map) {
      return Map<String, dynamic>.from(message);
    }
    throw FormatException('不支持的消息格式: ${message.runtimeType}');
  }

  /// 统一处理消息确认（包含ACK和撤回确认）
  void _handleMessageAck(String action, String messageId) {
    if (action.endsWith('_ACK')) {
      _handleMessageConfirmation(messageId);
    }

    // 处理撤回消息的特殊确认
    if (action.contains('REVOKE') &&
        action.endsWith('_REVOKE_ACK') &&
        messageId.isNotEmpty) {
      _handleMessageConfirmation(messageId);
    }

    // 【改进】处理CLIENT_ACK的确认消息，通知AckManager停止重试
    if (action == 'CLIENT_ACK_CONFIRM' && messageId.isNotEmpty) {
      try {
        AckManager.to.ackConfirmed(messageId);
        iPrint('✅ [WS] CLIENT_ACK确认收到: msgId=$messageId');
      } catch (e) {
        iPrint('⚠️ [WS] AckManager处理失败: $e');
      }
    }

    // 【补充】处理CLIENT_ACK的确认消息，通知AckManager停止重试
    if (action == 'CLIENT_ACK_ERROR' && messageId.isNotEmpty) {
      try {
        AckManager.to.ackConfirmed(messageId);
        iPrint('⚠️ [WS] CLIENT_ACK_ERROR收到: msgId=$messageId（ACK处理失败）');
      } catch (e) {
        iPrint('⚠️ [WS] AckManager处理失败: $e');
      }
    }
  }

  /// 处理原始消息（当JSON解析失败时）
  void _handleRawMessage(dynamic rawMessage) {
    try {
      AppEventBus.fireData({
        'type': 'RAW_MESSAGE',
        'data': rawMessage,
        'timestamp': DateTimeHelper.millisecond(),
      });
    } catch (e) {
      iPrint('> ws: 原始消息处理失败: $e');
    }
  }

  /// 清理所有资源
  void _cleanupResources() {
    _cancelStream();
    _cancelReconnectTimer();
  }

  /// 发送积压消息（优化版：加边界、异常、速率限制、并发防护）
  Future<void> _flushMessageQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      const int maxBatch = 10;
      const Duration minDelay = Duration(milliseconds: 30);

      int sentCount = 0;

      while (!_messageQueue.isEmpty && _status == SocketStatus.connected) {
        if (_channel == null) break;
        final message = _messageQueue.dequeue();
        if (message == null) continue;

        try {
          _channel!.sink.add(message);
          sentCount++;
          if (sentCount >= maxBatch) {
            await Future.delayed(Duration(milliseconds: 300));
            sentCount = 0;
          } else {
            await Future.delayed(minDelay);
          }
        } catch (e, s) {
          iPrint('> ws: flushMessageQueue failed: $e\n$s');
          _messageQueue.enqueueLegacy(message);
          break;
        }
        if (_status != SocketStatus.connected) break;
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// 获取有效Token（含自动刷新）
  Future<String> _getValidToken() async {
    try {
      if (!UserRepoLocal.to.isLoggedIn) return '';
      String token = await UserRepoLocal.to.accessToken;
      if (!tokenExpired(token)) return token;
      return await _refreshAccessToken();
    } catch (e, s) {
      iPrint("$e; $s");
      UserRepoLocal.to.quitLogin();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
      return '';
    }
  }

  /// 刷新访问令牌
  Future<String> _refreshAccessToken() async {
    final newToken = await UserApi.to.refreshAccessTokenApi(
      await UserRepoLocal.to.refreshToken,
      checkNewToken: false,
    );
    return newToken;
  }

  /// 处理连接丢失
  void _onError(Object e) {
    iPrint("_onError $e;");
    if (_status == SocketStatus.disconnected) return;
    iPrint('> ws_onError: 连接丢失');
    _updateStatus(SocketStatus.disconnected);
    _cancelStream();
    _scheduleReconnection();
  }

  void _onClose() {
    if (_status == SocketStatus.disconnected) return;
    int closeCode = _channel?.closeCode ?? 0;
    String closeReason = _channel?.closeReason ?? '';
    iPrint('> ws_onClose: 连接丢失 $closeCode: $closeReason;');

    _updateStatus(SocketStatus.disconnected);

    switch (closeCode) {
      case 4006:
        UserRepoLocal.to.quitLogin();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.signIn,
          (route) => false,
        );
        break;
      default:
        _cancelStream();
        _scheduleReconnection();
    }
  }

  /// 调度重连任务
  void _scheduleReconnection() {
    if (!_shouldScheduleReconnect()) {
      AppLogger.warning(
        'WebSocket 停止重试（已尝试 ${_backoff.attempts}/${_backoff.maxRetries} 次）',
      );
      return;
    }

    final delay = _backoff.nextDelay();
    final nextAttempt = _backoff.attempts;

    AppLogger.info(
      'WebSocket 将在 ${delay.inSeconds} 秒后重连 (第 $nextAttempt/${_backoff.maxRetries} 次尝试)',
    );

    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () {
      AppLogger.debug('WebSocket 重连定时器触发');
      openSocket(from: 'reconnectattempt_$nextAttempt');
    });
  }

  /// 判断是否需要调度重连
  bool _shouldScheduleReconnect() {
    return _shouldReconnect() &&
        _backoff.attempts < _backoff.maxRetries &&
        _status != SocketStatus.connected;
  }

  /// 网络连通性检查（使用网络监控服务）
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // 使用网络监控服务检查网络状态
      final hasNetwork = NetworkMonitorService.to.hasNetwork;

      if (!hasNetwork) {
        iPrint('> ws: 设备无网络连接');
        _updateStatus(SocketStatus.disconnected);
        _connecting = false;
        return false;
      }

      // 可选：真实网络连通性测试（更准确）
      final hasRealNetwork = await _testRealNetworkConnectivity();

      if (!hasRealNetwork) {
        iPrint('> ws: 网络连通性测试失败，可能无法访问外网');
        // 不立即断开，允许尝试连接（可能是DNS问题或测试服务器问题）
        iPrint('> ws: 继续尝试 WebSocket 连接...');
      }

      return true; // 允许尝试连接，即使真实网络测试失败
    } catch (e) {
      iPrint('> ws: 网络连通性检查异常: $e');
      // 出现异常时，假设网络可用，继续尝试连接
      return true;
    }
  }

  /// 真实网络连通性测试
  Future<bool> _testRealNetworkConnectivity() async {
    // 【修复】确保 HttpClient 在所有情况下都被关闭
    HttpClient? client;
    try {
      // 使用系统的 HTTP 客户端进行轻量级测试
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      // 测试多个可靠的服务
      final testUrls = [
        'https://www.baidu.com',
        'https://dns.alidns.com',
        'https://1.1.1.1',
      ];

      for (final url in testUrls) {
        try {
          final uri = Uri.parse(url);
          final request = await client.getUrl(uri);
          request.headers.set('User-Agent', 'IMBoy-NetworkTest/1.0');

          final response = await request.close().timeout(
            const Duration(seconds: 3),
          );

          if (response.statusCode >= 200 && response.statusCode < 400) {
            iPrint('> ws: 网络连通性测试成功 ($url)');
            return true;
          }
        } catch (e) {
          // 继续测试下一个 URL
          continue;
        }
      }

      return false;
    } catch (e) {
      iPrint('> ws: 网络测试异常: $e');
      return false; // 测试异常时返回 false
    } finally {
      // 【修复】确保 HttpClient 被关闭
      client?.close();
    }
  }

  /// 手动关闭连接
  Future<void> closeSocket({bool permanent = false}) async {
    iPrint('> ws: 手动关闭连接');
    _updateStatus(SocketStatus.disconnected);
    // 【修复】确保在关闭时清理所有资源
    _cancelStream();
    _cancelReconnectTimer();
    // 清理待确认消息
    _pendingMessages.clear();
    if (permanent) {
      _instance = null;
    }
  }

  /// 发送消息核心方法（优化版：简化确认机制）
  Future<bool> sendMessage(String message, String? messageId) async {
    if (!_preMessageCheck(message)) return false;

    if (_status == SocketStatus.connected) {
      try {
        _channel?.sink.add(message);
        _logMessageSent(message, messageId);

        // 如果有消息ID，启动确认机制
        if (messageId != null) {
          bool isRevokeMessage = false;
          try {
            final messageData = jsonDecode(message);
            final messageType = messageData['type']?.toString() ?? '';
            isRevokeMessage = messageType.contains('REVOKE');
          } catch (e) {
            // 忽略解析错误
          }

          _startMessageConfirmation(
            messageId,
            isRevokeMessage: isRevokeMessage,
          );
        }

        return true;
      } catch (e) {
        iPrint('> ws: 消息发送失败: $e');
        await _handleSendFailure(message, messageId);
        return false;
      }
    }

    // 连接断开时，消息入队等待重连
    iPrint('> ws: 连接断开，消息入队');
    _enqueueMessage(message);

    // 尝试重新连接
    await openSocket(from: 'sendMessage');
    return false;
  }

  /// 同步发送消息（用于 ACK 等需要立即发送的场景）
  /// 不经过消息队列，直接通过 WebSocket 发送
  bool sendDirect(String message) {
    if (_status == SocketStatus.connected && _channel != null) {
      try {
        _channel!.sink.add(message);
        return true;
      } catch (e) {
        iPrint('> ws: 直接发送消息失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 处理消息发送失败
  Future<void> _handleSendFailure(String message, String? messageId) async {
    iPrint('> ws: 处理消息发送失败 (${messageId ?? 'unknown'})');

    // 将消息加入重试队列
    _enqueueMessage(message);

    // 如果是网络问题，尝试重新连接
    if (_status != SocketStatus.connected) {
      await openSocket(from: 'retryAfterFailure');
    }
  }

  /// 启动消息确认机制
  void _startMessageConfirmation(
    String messageId, {
    bool isRevokeMessage = false,
  }) {
    // 设置超时确认（普通消息5秒，撤回消息10秒）
    int timeoutSeconds = isRevokeMessage ? 10 : 5;

    Timer(Duration(seconds: timeoutSeconds), () {
      if (_pendingMessages.remove(messageId)) {
        final isConnected = _status == SocketStatus.connected;
        iPrint('> ws: 消息确认超时: $messageId (连接正常: $isConnected)');
        // 连接断开时才通知失败，连接正常可能是服务端延迟
        if (!isConnected) {
          _notifyMessageSendResult(messageId, false);
        }
      }
    });

    _pendingMessages.add(messageId);
  }

  /// 处理消息确认（当收到服务器ACK时调用）
  void _handleMessageConfirmation(String messageId) {
    if (_pendingMessages.remove(messageId)) {
      iPrint('> ws: 消息已确认: $messageId');
      _notifyMessageSendResult(messageId, true);
    }
  }

  /// 安全记录消息发送日志（不泄露敏感信息）
  ///
  /// 在生产环境中只输出消息类型和大小，不输出完整内容
  /// 在开发环境中可通过 'debug_log_websocket_full' 开关启用详细日志
  void _logMessageSent(String message, String? messageId) {
    final id = messageId ?? 'unknown';

    // 检查是否启用完整日志（仅开发环境）
    final enableFullLog =
        kDebugMode &&
        StorageService.to.getBool('debug_log_websocket_full') == true;

    if (enableFullLog) {
      // 开发环境且启用详细日志时输出完整内容
      iPrint('> ws: 消息已发送 ($id): $message ;');
    } else {
      // 默认只输出消息类型和大小（不包含敏感内容）
      final msgType = _getMessageTypeInfo(message);
      final size = message.length;
      iPrint('> ws: 消息已发送 ($id) [$msgType] [$size bytes]');
      // iPrint('> ws: 消息已发送 ($id) [$msgType] [$size bytes] $message');
    }
  }

  /// 提取消息类型信息（不包含敏感内容）
  ///
  /// 返回格式：消息类型/消息子类型/加密状态
  /// 例如：C2C/text/E2EE 或 C2G/image/PLAIN
  String _getMessageTypeInfo(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type']?.toString() ?? 'UNKNOWN';
      final msgType = data['msg_type']?.toString() ?? 'unknown';
      final hasE2ee = data['e2ee'] != null;
      final encStatus = hasE2ee ? 'E2EE' : 'PLAIN';
      return '$type/$msgType/$encStatus';
    } catch (e, s) {
      // debugPrint("_getMessageTypeInfo $e, trace $s ");
      return 'UNKNOWN';
    }
  }

  /// 通知消息发送结果
  void _notifyMessageSendResult(String messageId, bool success) {
    // 通过事件总线通知消息发送结果
    AppEventBus.fireData({
      'type': 'MESSAGE_SEND_RESULT',
      'messageId': messageId,
      'success': success,
    });
  }

  /// 消息发送前检查
  bool _preMessageCheck(String message) {
    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('> ws: 消息丢弃（用户未登录）');
      return false;
    }
    if (message.isEmpty) {
      iPrint('> ws: 空消息被过滤');
      return false;
    }
    return true;
  }

  /// 消息入队处理
  void _enqueueMessage(String message) {
    if (!_messageQueue.messageStrings.contains(message)) {
      _messageQueue.enqueueLegacy(message);
      iPrint('> ws: 消息入队（当前队列长度：${_messageQueue.messageStrings.length}）');
    }
  }

  void _cancelStream() {
    _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 获取WebSocket URL
  /// Get WebSocket URL
  String? getWebSocketUrl() {
    return Env.effectiveWsUrl;
  }

  /// 获取消息队列大小
  /// Get message queue size
  int getMessageQueueSize() {
    return _messageQueue.messages.length;
  }

  /// 获取待确认消息数量
  /// Get pending message count
  int getPendingMessageCount() {
    return _pendingMessages.length;
  }

  /// 获取连接统计信息
  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'status': _status.name,
      'message_queue_size': _messageQueue.messages.length,
      'pending_messages': _pendingMessages.length,
      'connection_attempts': _backoff.attempts,
      'is_flushing': _isFlushing,
      'current_url': getWebSocketUrl(),
    };
  }

  /// 获取待确认消息列表（用于调试）
  /// Get pending messages list (for debugging)
  List<String> getPendingMessages() {
    return List<String>.from(_pendingMessages);
  }

  /// 清理过期的待确认消息
  /// Clean up expired pending messages
  void cleanupExpiredPendingMessages() {
    if (_pendingMessages.isNotEmpty) {
      iPrint('> ws: 清理过期的待确认消息，当前数量: ${_pendingMessages.length}');
      _pendingMessages.clear();
      iPrint('> ws: 已清理所有待确认消息');
    }
  }
}

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

  /// 当前已重试次数
  int attempts = 0;

  ExponentialBackoff({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 2),
    this.maxRetries = 20,
    this.jitterFactor = 0.3,
    this.jitterType = JitterType.full,
  });

  /// 获取下一次重试的延迟
  Duration nextDelay() {
    attempts = (attempts + 1).clamp(0, maxRetries);
    final int expMs = baseDelay.inMilliseconds * (1 << (attempts - 1));
    final int cappedMs = expMs.clamp(
      baseDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );
    Duration rawDelay = Duration(milliseconds: cappedMs);

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
    if (attempts > 0) {
      AppLogger.debug('重连计数器已重置（之前尝试了 $attempts 次）');
    }
    attempts = 0;
  }

  /// 完全随机 jitter：[0, delay * jitterFactor]
  Duration _fullJitter(Duration base) {
    int maxMs = (base.inMilliseconds * jitterFactor).toInt();
    if (maxMs <= 0) return base;
    return Duration(milliseconds: Random().nextInt(maxMs + 1));
  }

  /// 抖动范围为 [delay * (1-jitter), delay]
  Duration _equalJitter(Duration base) {
    int range = (base.inMilliseconds * jitterFactor).toInt();
    int minMs = base.inMilliseconds - range;
    int delayMs = minMs + Random().nextInt(range + 1);
    return Duration(milliseconds: delayMs);
  }

  /// ±jitterFactor * delay
  Duration _deviationJitter(Duration base) {
    int deviation = (base.inMilliseconds * jitterFactor).toInt();
    int jitterValue = deviation > 0
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
