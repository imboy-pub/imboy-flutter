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
  final _ExponentialBackoff _backoff = _ExponentialBackoff();
  WebSocketChannel? _channel;

  // 订阅管理
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;

  // 配置参数
  static const _pingInterval = Duration(seconds: 120);
  static const _maxRetries = 16;
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
        // Uri.parse('wss://pro.imboy.pub/ws/'),
        headers: {
          ...await defaultHeaders(),
          Keys.tokenKey: token,
        },
        protocols: ['text', 'sip'],
        pingInterval: _pingInterval,
      );
      // https://github.com/dart-lang/web_socket_channel/issues/182
      // ready property to make sure that connection is either completed or failed, then a try-catch will work.
      await _channel!.ready;

      _updateStatus(SocketStatus.connected);
      _backoff.reset();
      _cancelReconnectTimer();
      _flushMessageQueue();

      _wsSub?.cancel();
      final start = DateTime.now();

      _wsSub = _channel?.stream.listen(
        //监听服务器消息 onMessage
            (data) => _onMessage(data),
        // onError: (e) => _onConnectionLost(e),
        // onDone: () => _onConnectionLost(),
        //连接错误时调用 onError
        onError: _onError,
        //关闭时调用 onClose
        onDone: () {
          final end = DateTime.now();
          iPrint('Connection closed after ${end.difference(start).inSeconds} seconds');
          _onClose();
        },        //设置错误时取消订阅
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
    // ping/pong 是 WebSocket 的控制帧，在大多数 WebSocket 实现中，这些控制帧不会作为 message 事件传递到客户端的数据流中（stream.listen 的回调）
    iPrint("ws_onMessage ${DateTime.now()} : $message");
    // if (message == "pong" || message == "pong2") {
    //   return;
    // }
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

  /// 发送积压消息
  void _flushMessageQueue() {
    while (!_messageQueue.isEmpty && status.value == SocketStatus.connected) {
      final message = _messageQueue.dequeue();
      if (message != null) {
        _channel?.sink.add(message);
      }
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
  void _onError(e) {
    iPrint("_onError $e;");
    if (status.value == SocketStatus.disconnected) return;
    iPrint('> ws_onError: 连接丢失');
    _updateStatus(SocketStatus.disconnected);
    _cancelStream();
    _scheduleReconnection();
  }

  void _onClose() {
    if (status.value == SocketStatus.disconnected) return;

    // 1000 CLOSE_NORMAL 正常关闭；无论为何目的而创建，该链接都已成功完成任务
    // 1001 CLOSE_GOING_AWAY	终端离开，可能因为服务端错误，也可能因为浏览器正从打开连接的页面跳转离开
    // 1002	CLOSE_PROTOCOL_ERROR	由于协议错误而中断连接。
    // 1003	CLOSE_UNSUPPORTED	由于接收到不允许的数据类型而断开连接 (如仅接收文本数据的终端接收到了二进制数据).
    // 1005	CLOSE_NO_STATUS	保留。 表示没有收到预期的状态码。
    // 1007	Unsupported Data	由于收到了格式不符的数据而断开连接 (如文本消息中包含了非 UTF-8 数据).
    // 1009	CLOSE_TOO_LARGE	由于收到过大的数据帧而断开连接。
    // 4000–4999		可以由应用使用。
    // 4006 服务端通知客户端刷新token消息没有得到确认，系统主动关闭连接
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

    final delay = _backoff.nextDelay(jitter: true, maxRetries:_maxRetries,) ;
    iPrint('> ws: 将在 ${delay.inSeconds} 秒后尝试重连');

    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () => openSocket(from: 'reconnect'));
  }

  /// 判断是否需要调度重连
  bool _shouldScheduleReconnect() {
    return _shouldReconnect() &&
        _backoff.attempts < _maxRetries &&
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

/// 指数退避重试策略
class _ExponentialBackoff {
  static const _baseDelay = Duration(seconds: 1);
  static const _maxDelay = Duration(minutes: 2);
  static const _jitterFactor = 0.3;

  int attempts = 0;
  Duration _current = _baseDelay;

  Duration nextDelay({bool jitter = true, int maxRetries = 20}) {
    attempts = min(attempts + 1, maxRetries);
    final nextMs = (_current.inMilliseconds * 2)
        .clamp(_baseDelay.inMilliseconds, _maxDelay.inMilliseconds);
    _current = Duration(milliseconds: nextMs);
    return jitter ? _applyJitter(nextMs) : _current;
  }

  Duration _applyJitter(int baseMs) {
    final variation = (baseMs * _jitterFactor).toInt();
    final jitterValue = Random().nextInt(variation * 2 + 1) - variation;
    return _current + Duration(milliseconds: jitterValue);
  }

  void reset() {
    attempts = 0;
    _current = _baseDelay;
  }
}