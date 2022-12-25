import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket状态
enum SocketStatus {
  SocketStatusConnected, // 已连接
  SocketStatusFailed, // 失败
  SocketStatusClosed, // 连接关闭
}

class WSService extends GetxService {
  static WSService get to => Get.find();

  Iterable<String> subprotocol = ['sip', 'text'];
  String pingMsg = 'ping';

  IOWebSocketChannel? _webSocketChannel; // WebSocket
  SocketStatus? _socketStatus; // socket状态
  Timer? _heartBeat; // 心跳定时器
  // _heartTimes 必须比 服务端 idle_timeout 小一些
  final int _heartTimes = 50000; // 心跳间隔(毫秒)
  final int _reconnectCount = 60; // 重连次数，默认60次
  int _reconnectTimes = 0; // 重连计数器
  Timer? _reconnectTimer; // 重连定时器

  late Function onOpen; // 连接开启回调
  late Function onMessage; // 接收消息回调重连定时器
  late Function onError; // 连接错误回调

  @override
  void onInit() {
    super.onInit();
    if (_socketStatus != SocketStatus.SocketStatusConnected) {
      // closeSocket();
      initWebSocket(onOpen: () {
        initHeartBeat();
      }, onMessage: (event) {
        // change(data);
        if (event == "pong" || event == "pong2") {
          return;
        }
        Map data = event is Map ? event : json.decode(event);
        eventBus.fire(data);
      }, onError: (e) {
        debugPrint("> ws onError ${e.runtimeType} | ${e.toString()};");
      });
    }
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }

  /// 初始化WebSocket
  /// 这个在main.dart中调用一次就行了
  void initWebSocket({
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
  void openSocket() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('> ws openSocket 网络连接异常ws');
      return;
    }
    if (!UserRepoLocal.to.isLogin) {
      debugPrint('> ws openSocket is not login');
      return;
    }
    if (_webSocketChannel == null) {
      _socketStatus = SocketStatus.SocketStatusFailed;
    }
    // 链接状态正常，不需要任何处理
    if (_socketStatus == SocketStatus.SocketStatusConnected) {
      // debugPrint('> ws openSocket _socketStatus: $_socketStatus;');
      return;
    } else {
      closeSocket();
    }
    String token = UserRepoLocal.to.accessToken;
    if (tokenExpired(token)) {
      debugPrint('> ws openSocket tokenExpired true');
      await UserRepoLocal.to.refreshAccessToken();
      token = UserRepoLocal.to.accessToken;
    }
    Map<String, dynamic> headers = await defaultHeaders();
    headers[Keys.tokenKey] = token;
    if (subprotocol.isEmpty) {
      _webSocketChannel = IOWebSocketChannel.connect(
        WS_URL,
        headers: headers,
      );
    } else {
      _webSocketChannel = IOWebSocketChannel.connect(
        WS_URL,
        headers: headers,
        protocols: subprotocol,
      );
    }
    // 连接成功，返回WebSocket实例
    _socketStatus = SocketStatus.SocketStatusConnected;
    // 连接成功，重置重连计数器
    _reconnectTimes = 0;
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }

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
  }

  /// WebSocket接收消息回调
  webSocketOnMessage(data) {
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
            '> ws _webSocketOnDone closeCode: ${_webSocketChannel!.closeCode}, closeReason: ${_webSocketChannel!.closeReason.toString()}');
      }
    }
    _socketStatus = SocketStatus.SocketStatusClosed;
      _reconnect();
  }

  /// WebSocket连接错误回调
  _webSocketOnError(e) {
    debugPrint('> ws _webSocketOnError ${_webSocketOnError.toString()}');
    WebSocketChannelException ex = e;
    _socketStatus = SocketStatus.SocketStatusFailed;
    onError(ex.message);
    closeSocket();
  }

  /// 初始化心跳
  void initHeartBeat() {
    debugPrint('> ws initHeartBeat');
    destroyHeartBeat();
    _heartBeat = Timer.periodic(
      Duration(milliseconds: _heartTimes),
      (timer) {
        sentHeart();
      },
    );
  }

  /// 心跳
  void sentHeart() {
    sendMessage(pingMsg);
  }

  /// 销毁心跳
  void destroyHeartBeat() {
    debugPrint('> ws destroyHeartBeat');
    if (_heartBeat != null) {
      _heartBeat!.cancel();
      _heartBeat = null;
    }
  }

  void destroyReconnectTimer() {
    if (_reconnectTimer != null) {
      debugPrint('> ws destroyReconnectTimer 重连次数超过最大次数 $_reconnectTimes');
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }
  }

  /// 关闭WebSocket
  void closeSocket() {
    debugPrint('> ws closeSocket');
    destroyHeartBeat();
    destroyReconnectTimer();
    if (_webSocketChannel != null) {
      debugPrint('> ws WebSocket连接关闭');
      _webSocketChannel!.sink.close();
      _socketStatus = SocketStatus.SocketStatusClosed;
      _webSocketChannel = null;
    }
  }

  /// 发送WebSocket消息
  bool sendMessage(String message) {
    bool result = false;
    openSocket();
    if(_socketStatus == SocketStatus.SocketStatusConnected) {
      // debugPrint('> ws sendMsg $message');
      _webSocketChannel!.sink.add(message);
      result = true;
    } else {
      debugPrint('> ws error _socketStatus ${_socketStatus.toString()} $message');
    }
    return result;
  }

  /// 重连机制
  void _reconnect() {
    if (_reconnectTimes == 0) {
      _reconnectTimes++;
      openSocket();
    } else if (_reconnectTimes < _reconnectCount) {
      _reconnectTimes++;
      _reconnectTimer = Timer.periodic(
        Duration(milliseconds: _heartTimes),
        (timer) {
          debugPrint('> ws _reconnect _reconnectTimes $_reconnectTimes');
          openSocket();
        },
      );
    } else {
      closeSocket();
      return;
    }
  }
}
