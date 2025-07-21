import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' show defaultHeaders;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'websocket_message_queue.dart';

enum SocketStatus { connecting, connected, disconnected }

class WebSocketService extends GetxService {
  static WebSocketService get to => Get.find();

  // 状态管理
  final Rx<SocketStatus> status = SocketStatus.disconnected.obs;
  final PersistentMessageQueue _messageQueue = PersistentMessageQueue.to;

  // 网络与连接
  final Connectivity _connectivity = Connectivity();
  final ExponentialBackoff _backoff = ExponentialBackoff(maxRetries: 16);
  WebSocketChannel? _channel;
  bool _isFlushing = false;

  // 订阅管理
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  // 配置参数
  static const _pingInterval = Duration(seconds: 120);
  bool _connecting = false;

  @override
  void onInit() {
    super.onInit();

    // 初始化网络状态监听
    _netSub = _connectivity.onConnectivityChanged.listen((results) async {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      hasNetwork ? _handleNetworkRestored() : _handleNetworkLost();
    });

    // 初始化连接（应用启动时调用）
    if (_shouldReconnect()) {
      openSocket(from: 'init');
    }
  }

  @override
  void onClose() {
    _cleanupResources();
    super.onClose();
  }

  /// 处理网络恢复事件
  void _handleNetworkRestored() {
    if (_shouldHandleNetworkRestore()) {
      iPrint('> ws: 网络恢复，尝试重新连接');
      openSocket(from: 'network-restored');
    }
  }

  /// 判断是否需要处理网络恢复
  bool _shouldHandleNetworkRestore() {
    return status.value == SocketStatus.disconnected &&
        UserRepoLocal.to.isLoggedIn &&
        !_connecting;
  }

  /// 处理网络断开事件
  void _handleNetworkLost() {
    iPrint('> ws: 网络连接丢失');
    _updateStatus(SocketStatus.disconnected);
    _cancelStream();
  }

  /// 统一状态更新方法
  void _updateStatus(SocketStatus newStatus) {
    if (status.value != newStatus) {
      status.value = newStatus;
    }
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
    if (_connecting || status.value == SocketStatus.connected) return false;
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
      if (!await _checkNetworkConnectivity()) return;

      final token = await _getValidToken();
      if (token.isEmpty) return;

      _channel = IOWebSocketChannel.connect(
        Env.wsUrl ?? 'wss://pro.imboy.pub/ws/',
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
      iPrint('> ws: 连接成功');
    } catch (e, s) {
      iPrint('> ws: 连接失败 ${Env.wsUrl}; (${e.toString()}); $s');
      _handleConnectionFailure(e);
    } finally {
      _connecting = false;
    }
  }

  /// 处理连接失败后的操作
  void _handleConnectionFailure(dynamic error) {
    _updateStatus(SocketStatus.disconnected);
    _scheduleReconnection();
  }

  /// 处理接收到的消息
  void _onMessage(dynamic message) {
    iPrint("ws_onMessage ${DateTime.now()} : $message");
    try {
      final payload = message is String ? jsonDecode(message) : message;
      eventBus.fire(payload);
    } catch (e, s) {
      iPrint('> ws: 消息解析失败 ($message), $e ; $s');
    }
  }

  /// 清理所有资源
  void _cleanupResources() {
    _netSub?.cancel();
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

      while (!_messageQueue.isEmpty && status.value == SocketStatus.connected) {
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
          _messageQueue.enqueue(message);
          break;
        }
        if (status.value != SocketStatus.connected) break;
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
      Get.offAll(() => const LoginPage());
      return '';
    }
  }

  /// 刷新访问令牌
  Future<String> _refreshAccessToken() async {
    final newToken = await UserProvider().refreshAccessTokenApi(
      await UserRepoLocal.to.refreshToken,
      checkNewToken: false,
    );
    return newToken;
  }

  /// 处理连接丢失
  void _onError(Object e) {
    iPrint("_onError $e;");
    if (status.value == SocketStatus.disconnected) return;
    iPrint('> ws_onError: 连接丢失');
    _updateStatus(SocketStatus.disconnected);
    _cancelStream();
    _scheduleReconnection();
  }

  void _onClose() {
    if (status.value == SocketStatus.disconnected) return;
    int closeCode = _channel?.closeCode ?? 0;
    String closeReason = _channel?.closeReason ?? '';
    iPrint('> ws_onClose: 连接丢失 $closeCode: $closeReason;');

    _updateStatus(SocketStatus.disconnected);

    switch (closeCode) {
      case 4006:
        UserRepoLocal.to.quitLogin();
        Get.offAll(() => const LoginPage());
        break;
      default:
        _cancelStream();
        _scheduleReconnection();
    }
  }

  /// 调度重连任务
  void _scheduleReconnection() {
    if (!_shouldScheduleReconnect()) {
      iPrint('> ws: 停止重试（尝试次数: ${_backoff.attempts}）');
      return;
    }
    final delay = _backoff.nextDelay();
    iPrint('> ws: 将在 ${delay.inSeconds} 秒后尝试重连');
    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () => openSocket(from: 'reconnect'));
  }

  /// 判断是否需要调度重连
  bool _shouldScheduleReconnect() {
    return _shouldReconnect() &&
        _backoff.attempts < _backoff.maxRetries &&
        status.value != SocketStatus.connected;
  }

  /// 网络连通性检查
  Future<bool> _checkNetworkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    final hasNetwork = result.any((r) => r != ConnectivityResult.none);

    if (!hasNetwork) {
      iPrint('> ws: 无可用网络');
      _updateStatus(SocketStatus.disconnected);
      _connecting = false;
    }
    return hasNetwork;
  }

  /// 手动关闭连接
  Future<void> closeSocket({bool permanent = false}) async {
    iPrint('> ws: 手动关闭连接');
    _updateStatus(SocketStatus.disconnected);
    _cleanupResources();
    if (permanent) Get.delete<WebSocketService>();
  }

  /// 发送消息核心方法
  Future<bool> sendMessage(String message) async {
    if (!_preMessageCheck(message)) return false;

    if (status.value == SocketStatus.connected) {
      try {
        _channel?.sink.add(message);
        return true;
      } catch (e, s) {
        iPrint('> ws: 消息发送失败(${e.toString()}); $s');
      }
    }

    _enqueueMessage(message);
    await openSocket(from: 'sendMessage');
    return false;
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
    if (!_messageQueue.messages.contains(message)) {
      _messageQueue.enqueue(message);
      iPrint('> ws: 消息入队（当前队列长度：${_messageQueue.messages.length}）');
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

  /// 重置重试状态
  void reset() {
    attempts = 0;
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
