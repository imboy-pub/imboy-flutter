import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
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

  static WebSocketService? _instance;

  Iterable<String> protocols = ['text', 'sip'];

  // String pingMsg = 'ping';

  IOWebSocketChannel? _webSocketChannel; // WebSocket
  SocketStatus? _socketStatus; // socket状态
  // Timer? _heartBeat; // 心跳定时器 使用 IOWebSocketChannel 的心跳机制
  // _heartTimes 必须比 服务端 idle_timeout 小一些
  final int _heartTimes = 10000; // 心跳间隔(毫秒)
  final int _reconnectCount = 10; // 重连次数，默认10次
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
        debugPrint("initWebSocket_onMessage $event");
        // change(data);
        if (event == "pong" || event == "pong2") {
          return;
        }
        Map data = event is Map ? event : json.decode(event);
        eventBus.fire(data);
      }, onError: (e) {
        debugPrint(
            "> ws onError ${e.runtimeType} | ${e.toString()};"); // 延时1s执行 _reconnect
        Future.delayed(const Duration(milliseconds: 1000), () {
          debugPrint('> ws onError _reconnectTimes: $_reconnectTimes');
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
    this.onOpen = onOpen;
    this.onMessage = onMessage;
    this.onError = onError;
    openSocket();
  }

  /// 开启WebSocket连接
  Future<void> openSocket() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('> ws openSocket 网络连接异常ws');
      return;
    }
    if (UserRepoLocal.to.isLogin == false) {
      debugPrint('> ws openSocket is not login');
      return;
    }

    // 链接状态正常，不需要任何处理
    if (isConnected) {
      // debugPrint('> ws openSocket _socketStatus: $_socketStatus;');
      return;
    }

    try {
      Map<String, dynamic> headers = await defaultHeaders();
      headers[Keys.tokenKey] = UserRepoLocal.to.accessToken;

      _webSocketChannel = IOWebSocketChannel.connect(
        WS_URL,
        headers: headers,
        pingInterval: Duration(milliseconds: _heartTimes),
        protocols: protocols,
      );

      // 连接成功，返回WebSocket实例
      _socketStatus = SocketStatus.SocketStatusConnected;

      // 连接成功，重置重连计数器
      _reconnectTimes = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      debugPrint('> ws openSocket onOpen');
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
    } catch (exception) {
      closeSocket(false);
      _socketStatus = SocketStatus.SocketStatusFailed;
      _reconnectTimes += 1;
      debugPrint("> openSocket $WS_URL error ${exception.toString()}");
    }
  }

  /// WebSocket接收消息回调
  webSocketOnMessage(data) {
    // debugPrint("> ws webSocketOnMessage $data ;");
    onMessage(data);
  }

  /// WebSocket关闭连接回调
  _webSocketOnDone() {
    // https://developer.mozilla.org/zh-CN/docs/Web/API/CloseEvent
    // closeCode 1000 正常关闭; 无论为何目的而创建, 该链接都已成功完成任务.
    debugPrint('> ws _webSocketOnDone');
    if (_webSocketChannel != null) {
      if (_webSocketChannel!.closeCode != null) {
        debugPrint(
            '> ws _webSocketOnDone closeCode: ${_webSocketChannel!.closeCode}');
        debugPrint(
            '> ws _webSocketOnDone closeReason: ${_webSocketChannel!.closeReason.toString()}');
        // 1000 CLOSE_NORMAL 正常关闭；无论为何目的而创建，该链接都已成功完成任务
        // 1001 CLOSE_GOING_AWAY	终端离开，可能因为服务端错误，也可能因为浏览器正从打开连接的页面跳转离开
        // 1002	CLOSE_PROTOCOL_ERROR	由于协议错误而中断连接。
        // 1003	CLOSE_UNSUPPORTED	由于接收到不允许的数据类型而断开连接 (如仅接收文本数据的终端接收到了二进制数据).
        // 1005	CLOSE_NO_STATUS	保留。 表示没有收到预期的状态码。
        // 1007	Unsupported Data	由于收到了格式不符的数据而断开连接 (如文本消息中包含了非 UTF-8 数据).
        // 1009	CLOSE_TOO_LARGE	由于收到过大的数据帧而断开连接。
        // 4000–4999		可以由应用使用。
        // 4006 通知客户端刷新token消息没有得到确认，系统主动关闭连接
        int closeCode = _webSocketChannel?.closeCode ?? 0;
        closeSocket(false);

        if (closeCode == 4006) {
          closeSocket(true);
          Get.offAll(() => PassportPage());
        } else {
          if (closeCode > 1000) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              debugPrint(
                  '> ws _webSocketOnDone _reconnectTimes: $_reconnectTimes');
              _reconnect();
            });
          }
        }
      }
    }
  }

  /// WebSocket连接错误回调
  _webSocketOnError(e) {
    debugPrint('> ws _webSocketOnError ${_webSocketOnError.toString()}');
    debugPrint('> ws _webSocketOnError ${e.toString()}');
    WebSocketChannelException ex = e;
    _socketStatus = SocketStatus.SocketStatusFailed;
    onError(ex.message);
    closeSocket(false);
  }

  void destroyReconnectTimer() {
    _reconnectTimer?.cancel();
  }

  /// 关闭WebSocket
  void closeSocket([bool nullInstance = true]) {
    debugPrint('> ws closeSocket');
    // destroyHeartBeat();
    destroyReconnectTimer();
    if (_webSocketChannel != null) {
      debugPrint('> ws WebSocket连接关闭 $WS_URL');
      _webSocketChannel?.sink.close();
      _webSocketChannel = null;
      _socketStatus = SocketStatus.SocketStatusClosed;
    }
    if (nullInstance) {
      _instance = null;
    }
  }

  /// 发送WebSocket消息
  Future<bool> sendMessage(String msg) async {
    bool result = false;
    if (isConnected == false) {
      await openSocket();
    }
    // debugPrint('> ws sendMsg $msg');
    try {
      result = _send(msg);
    } catch (e) {
      await openSocket();
      result = _send(msg);
    }
    return result;
  }

  bool _send(String msg) {
    _webSocketChannel!.sink.add(msg);
    return true;
  }

  /// 重连机制
  void _reconnect() {
    closeSocket(false);
    if (_reconnectTimes == 0) {
      _reconnectTimes += 1;

      openSocket();
    } else if (_reconnectTimes < _reconnectCount) {
      _reconnectTimes += 1;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer.periodic(
        Duration(milliseconds: _heartTimes),
        (timer) {
          debugPrint('> ws _reconnect _reconnectTimes $_reconnectTimes');
          openSocket();
        },
      );
    } else {
      return;
    }
  }
}
