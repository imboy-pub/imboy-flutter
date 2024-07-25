import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/http/http_client.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// WebSocket状态
enum SocketStatus {
  SocketStatusConnected, // 已连接
  SocketStatusFailed, // 失败
  SocketStatusClosed, // 连接关闭
}

class WebSocketService {
  WebSocketService._();

  static WebSocketService get to {
    _instance ??= WebSocketService._();
    if (_instance != null) {
      _instance!._init();
    }
    return _instance!;
  }

  // wsConnectLock 防止token过期的时候产生多个WS链接
  bool wsConnectLock = false;
  static WebSocketService? _instance;

  Iterable<String> protocols = ['text', 'sip'];

  // String pingMsg = 'ping';

  IOWebSocketChannel? _webSocketChannel; // WebSocket
  SocketStatus? _socketStatus; // socket状态
  // Timer? _heartBeat; // 心跳定时器 使用 IOWebSocketChannel 的心跳机制
  // 服务端设置为128秒，客服端设置为120秒，不要超过128秒
  // _heartTimes 必须比 服务端 idle_timeout 小一些
  final int _heartTimes = 120000; // 心跳间隔(毫秒)
  final int _reconnectMax = 10; // 重连次数，默认10次
  int _reconnectTimes = 0; // 重连计数器
  Timer? _reconnectTimer; // 重连定时器

  // 这个waitMsg用于判断是否收到服务端回的心跳信息
  // bool waitMsg = false;
  // Timer? _timerWait; //

  late Function onOpen; // 连接开启回调
  late Function onMessage; // 接收消息回调重连定时器
  late Function onError; // 连接错误回调

  bool get isConnected =>
      _webSocketChannel != null && _webSocketChannel?.sink != null;

  int lastConnectedAt = 0;

  /// 在
  void _init() {
    if (_socketStatus != SocketStatus.SocketStatusConnected) {
      _initWebSocket(onOpen: () {
        // initHeartBeat();
      }, onMessage: (event) {
        // // 收到消息时标志置为true
        // waitMsg = true;
        // // _timerWait?
        // _timerWait?.cancel();
        // _timerWait = null;
        iPrint("initWebSocket_onMessage $event");
        // change(data);
        if (event == "pong" || event == "pong2") {
          return;
        }
        Map data = event is Map ? event : json.decode(event);
        eventBus.fire(data);
      }, onError: (e) {
        iPrint(
            "> ws onError ${e.runtimeType} | ${e.toString()};"); // 延时1s执行 _reconnect
        Future.delayed(const Duration(milliseconds: 1000), () {
          iPrint('> ws onError _reconnectTimes: $_reconnectTimes');
          _reconnect();
        });
      });
    }
  }

  /// 初始化WebSocket
  /// 这个在main.dart中调用一次就行了
  void _initWebSocket({
    required Function onOpen,
    required Function onMessage,
    required Function onError,
  }) {
    _reconnectTimes = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    this.onOpen = onOpen;
    this.onMessage = onMessage;
    this.onError = onError;
    openSocket();
  }

  /// 开启WebSocket连接
  Future<void> openSocket({bool fromReconnect = false}) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      iPrint('> ws openSocket 网络连接异常ws');
      return;
    }
    // 链接状态正常，不需要任何处理
    if (isConnected) {
      iPrint('> ws openSocket _socketStatus: $_socketStatus;');
      return;
    }

    String tk = await UserRepoLocal.to.accessToken;
    iPrint("Get.currentRoute ${Get.currentRoute}");
    if (tk.isEmpty) {
      iPrint('> ws openSocket tk isEmpty ${tk.isEmpty};');
      if (Get.currentRoute != '/PassportPage') {
        UserRepoLocal.to.logout();
        Get.offAll(() => PassportPage());
      }
      return;
    }
    if (tokenExpired(tk) == false) {
      String rtk = await UserRepoLocal.to.refreshToken;
      tk = await (UserProvider()).refreshAccessTokenApi(
        rtk,
        checkNewToken: false,
      );
    }
    Map<String, dynamic> headers = await defaultHeaders();

    headers[Keys.tokenKey] = tk;
    iPrint("openSocket_headers ${headers.toString()}");

    if (wsConnectLock) {
      return;
    }
    wsConnectLock = true;
    try {
      String? url = Env.wsUrl;
      if (strEmpty(url)) {
        await initConfig();
        url = Env.wsUrl;
      }
      _webSocketChannel = IOWebSocketChannel.connect(
        url!,
        headers: headers,
        pingInterval: Duration(milliseconds: _heartTimes),
        protocols: protocols,
      );
      // _webSocketChannel.innerWebSocket;
      // 连接成功，设置socket状态
      _socketStatus = SocketStatus.SocketStatusConnected;

      // 连接成功，重置重连计数器
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      if (fromReconnect == false) {
        _reconnectTimes = 0;
      }

      iPrint('> ws openSocket onOpen');
      // onOpen onMessage onError onClose
      onOpen();
      // 接收消息
      _webSocketChannel!.stream.listen(
        //监听服务器消息 onMessage
        (data) => webSocketOnMessage(data),
        //连接错误时调用 onError
        onError: _webSocketOnError,
        //关闭时调用 onClose
        onDone: _webSocketOnDone,
        //设置错误时取消订阅
        cancelOnError: true,
      );
      lastConnectedAt = DateTimeHelper.utc();
    } catch (e) {
      closeSocket();
      _socketStatus = SocketStatus.SocketStatusFailed;
      iPrint("> openSocket ${Env.wsUrl} error ${e.toString()}");
    } finally {
      wsConnectLock = false;
    }
  }

  /// WebSocket接收消息回调
  webSocketOnMessage(data) {
    // iPrint("> ws webSocketOnMessage $data ;");
    onMessage(data);
  }

  /// WebSocket关闭连接回调
  _webSocketOnDone() async {
    // https://developer.mozilla.org/zh-CN/docs/Web/API/CloseEvent
    // closeCode 1000 正常关闭; 无论为何目的而创建, 该链接都已成功完成任务.
    iPrint('> ws _webSocketOnDone');

    if (_webSocketChannel != null && _webSocketChannel!.closeCode != null) {
      iPrint(
          '> ws _webSocketOnDone closeCode: ${_webSocketChannel!.closeCode} ${DateTime.now()}');
      iPrint(
          '> ws _webSocketOnDone closeReason: ${_webSocketChannel!.closeReason.toString()}');
      // 1000 CLOSE_NORMAL 正常关闭；无论为何目的而创建，该链接都已成功完成任务
      // 1001 CLOSE_GOING_AWAY	终端离开，可能因为服务端错误，也可能因为浏览器正从打开连接的页面跳转离开
      // 1002	CLOSE_PROTOCOL_ERROR	由于协议错误而中断连接。
      // 1003	CLOSE_UNSUPPORTED	由于接收到不允许的数据类型而断开连接 (如仅接收文本数据的终端接收到了二进制数据).
      // 1005	CLOSE_NO_STATUS	保留。 表示没有收到预期的状态码。
      // 1007	Unsupported Data	由于收到了格式不符的数据而断开连接 (如文本消息中包含了非 UTF-8 数据).
      // 1009	CLOSE_TOO_LARGE	由于收到过大的数据帧而断开连接。
      // 4000–4999		可以由应用使用。
      // 4006 服务端通知客户端刷新token消息没有得到确认，系统主动关闭连接
      int closeCode = _webSocketChannel?.closeCode ?? 0;

      switch (closeCode) {
        case 4006:
          UserRepoLocal.to.logout();
          Get.offAll(() => PassportPage());
          break;
        default:
          closeSocket();
          Future.delayed(const Duration(milliseconds: 1000), () {
            iPrint('_webSocketOnDone _reconnectTimes: $_reconnectTimes');
            _reconnect();
          });
      }
    }
  }

  /// WebSocket连接错误回调
  _webSocketOnError(e) {
    iPrint('> ws _webSocketOnError ${_webSocketOnError.toString()}');
    iPrint('> ws _webSocketOnError ${e.toString()}');
    WebSocketChannelException ex = e;
    _socketStatus = SocketStatus.SocketStatusFailed;
    onError(ex.message);
    closeSocket();
  }

  void destroyReconnectTimer() {
    _reconnectTimes = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 关闭WebSocket
  void closeSocket({bool exit = false}) {
    iPrint('> ws closeSocket ${DateTime.now()}');
    // destroyHeartBeat();
    destroyReconnectTimer();
    iPrint('> ws WebSocket连接关闭 ${Env.wsUrl}');
    _webSocketChannel?.sink.close();
    _webSocketChannel = null;
    _socketStatus = SocketStatus.SocketStatusClosed;
    if (exit) {
      _instance = null;
    }
  }

  /// 发送WebSocket消息
  Future<bool> sendMessage(String msg) async {
    bool result = false;
    if (isConnected == false) {
      await WebSocketService.to.openSocket();
    }
    // iPrint('> ws sendMsg $msg');
    try {
      result = _send(msg);
    } catch (e) {
      await WebSocketService.to.openSocket();
      result = _send(msg);
    }
    return result;
  }

  bool _send(String msg) {
    _webSocketChannel?.sink.add(msg);
    return true;
  }

  /// 重连机制
  ///
  void _reconnect() {
    iPrint(
        '> ws _reconnect _reconnectTimes $_reconnectTimes < $_reconnectMax ${DateTime.now()}');
    if (_reconnectTimes < _reconnectMax) {
      WebSocketService.to.openSocket(fromReconnect: true);
      _reconnectTimes += 1;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer.periodic(
        Duration(milliseconds: _heartTimes),
        (timer) {
          WebSocketService.to.openSocket(fromReconnect: true);
        },
      );
    } else {
      // 达到最大重连次数，停止重连
      closeSocket();
      return;
    }
  }
}
