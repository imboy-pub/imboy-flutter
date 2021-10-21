import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/jwt.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket地址
const String _SOCKET_URL = ws_url;

/// WebSocket状态
enum SocketStatus {
  SocketStatusConnected, // 已连接
  SocketStatusFailed, // 失败
  SocketStatusClosed, // 连接关闭
}

class WebSocket {
  Iterable<String> subprotocol = ['text'];
  String pingMsg = 'ping';

  IOWebSocketChannel? _webSocketChannel; // WebSocket
  SocketStatus? _socketStatus; // socket状态
  Timer? _heartBeat; // 心跳定时器
  // _heartTimes 必须比 服务端 idle_timeout 小一些
  int _heartTimes = 50000; // 心跳间隔(毫秒)
  int _reconnectCount = 60; // 重连次数，默认60次
  int _reconnectTimes = 0; // 重连计数器
  Timer? _reconnectTimer; // 重连定时器

  late Function onOpen; // 连接开启回调
  late Function onMessage; // 接收消息回调重连定时器
  late Function onError; // 连接错误回调
  late Function onClose; // 手动关闭回调

  // 工厂模式 : 单例公开访问点
  factory WebSocket() => _getInstance();

  static WebSocket get instance => _getInstance();

  // 静态私有成员，没有初始化
  static WebSocket? _instance;

  // 静态、同步、私有访问点
  static WebSocket _getInstance() {
    debugPrint(
        ">>>>> on ws ${DateTime.now()} _getInstance ${_instance == null}");
    if (_instance == null) {
      _instance = new WebSocket._internal();
    } else if (_instance!._socketStatus != SocketStatus.SocketStatusConnected) {
      _instance = new WebSocket._internal();
    }
    return _instance!;
  }

  // 私有构造函数
  WebSocket._internal() {
    initWebSocket(onOpen: () {
      debugPrint(">>>>> on ws ${DateTime.now()} onOpen");
      initHeartBeat();
      // change(value, status: RxStatus.success());
    }, onMessage: (event) {
      // change(data);
      debugPrint(
          ">>>>> on ws ${DateTime.now()} onMessage ${event.runtimeType} | ${event.toString()}");
      if (event == "pong" || event == "pong2") {
        return;
      }
      Map data = event is Map ? event : json.decode(event);
      int code = data['code'] ?? 99999;
      String dtype = data['type'] ?? 'error';

      if (dtype == 'error') {
        switch (code) {
          // case 705: // token无效、刷新token 这里不处理，不发送消息
          case 706: // 需要重新登录
            {
              Get.off(new LoginPage());
            }
            break;
        }
      } else if (dtype == 'SYSTEM') {
      } else {
        eventBus.fire(data);
      }
    }, onError: (e) {
      debugPrint(
          ">>>>> on ws ${DateTime.now()} onError ${e.runtimeType} | ${e.toString()}");
      if (kDebugMode) {
        Get.snackbar("Tips", "ws2 onErr: " + e.message);
      }
      // change(value, status: RxStatus.error(e.message));
    }, onClose: (closeCode, closeReason) {
      debugPrint(
          ">>>>> on ws ${DateTime.now()} onClose ${closeCode} : ${closeReason}");
      if (kDebugMode) {
        Get.snackbar(
            "Tips",
            "ws2 h close code: " +
                closeCode.toString() +
                "; reason:" +
                closeReason);
      }
      //如果手动关闭连接，不再重连
      // change(value, status: RxStatus.error(closeReason));
    });
  }

  /// 初始化WebSocket
  /// 这个在main.dart中调用一次就行了
  void initWebSocket({
    required Function onOpen,
    required Function onMessage,
    required Function onError,
    required Function onClose,
  }) {
    this.onOpen = onOpen;
    this.onMessage = onMessage;
    this.onError = onError;
    this.onClose = onClose;
    debugPrint('>>>>> on ws ${DateTime.now()} initWebSocket');
    openSocket();
  }

  /// 开启WebSocket连接
  void openSocket() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      Get.snackbar("Tips", "网络连接异常ws");
      debugPrint('>>>>> on ws ${DateTime.now()} openSocket 网络连接异常ws');
      return;
    }
    closeSocket();
    if (_socketStatus == SocketStatus.SocketStatusConnected) {
      debugPrint(
          '>>>>> on ws ${DateTime.now()} openSocket SocketStatusConnected');
      return;
    } else {
      destroyHeartBeat();
    }
    debugPrint(
        '>>>>> on ws ${DateTime.now()} openSocket isLogin ${UserRepoSP.user.isLogin}');
    if (!UserRepoSP.user.isLogin) {
      debugPrint('>>>>> on ws ${DateTime.now()} openSocket is not login');
      return;
    }
    String token = UserRepoSP.user.accessToken;
    if (strEmpty(token)) {
      // Get.off(LoginPage());
      debugPrint('>>>>> on ws ${DateTime.now()} openSocket token empty');
      return;
    }
    if (token_expired(token)) {
      // await refreshtoken();
      // debugPrint('>>>>> on ws token old $token');
      token = UserRepoSP.user.accessToken;
      debugPrint('>>>>> on ws ${DateTime.now()} token new $token');
    }
    var headers = {
      'vsn': appVsn,
      'device-type': currentDeviceType(),
      'client-system': Platform.operatingSystem,
      'client-system-vsn': Platform.operatingSystemVersion,
      '${Keys.tokenKey}': token.replaceAll('+', '%2B'),
    };
    String url =
        _SOCKET_URL + '?' + Keys.tokenKey + '=' + token.replaceAll('+', '%2B');
    if (subprotocol.isEmpty) {
      _webSocketChannel = IOWebSocketChannel.connect(
        url,
        headers: headers,
      );
    } else {
      _webSocketChannel = IOWebSocketChannel.connect(
        url,
        headers: headers,
        protocols: subprotocol,
      );
    }
    // 连接成功，返回WebSocket实例
    _socketStatus = SocketStatus.SocketStatusConnected;
    Get.snackbar("Tips", "ws连接成功");
    debugPrint('>>>>> on ws ${DateTime.now()} 连接成功');
    // 连接成功，重置重连计数器
    _reconnectTimes = 0;
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }
    onOpen();
    // 接收消息
    _webSocketChannel!.stream.listen(
      (data) => webSocketOnMessage(data),
      onError: _webSocketOnError,
      onDone: _webSocketOnDone,
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
    debugPrint('>>>>> on ws ${DateTime.now()} _webSocketOnDone');
    if (_webSocketChannel != null) {
      if (_webSocketChannel!.closeCode != null) {
        debugPrint(
            '>>>>> on ws ${DateTime.now()} _webSocketOnDone closeCode: ${_webSocketChannel!.closeCode}, closeReason: ${_webSocketChannel!.closeReason.toString()}');
      }
    }
    _socketStatus = SocketStatus.SocketStatusClosed;
    _reconnect();
  }

  /// WebSocket连接错误回调
  _webSocketOnError(e) {
    debugPrint(
        '>>>>> on ws ${DateTime.now()} _webSocketOnError ${_webSocketOnError.toString()}');
    WebSocketChannelException ex = e;
    _socketStatus = SocketStatus.SocketStatusFailed;
    onError(ex.message);
    closeSocket();
  }

  /// 初始化心跳
  void initHeartBeat() {
    debugPrint('>>>>> on ws ${DateTime.now()} initHeartBeat');
    destroyHeartBeat();
    _heartBeat = Timer.periodic(
      Duration(milliseconds: _heartTimes),
      (timer) {
        _sentHeart();
      },
    );
  }

  /// 心跳
  void _sentHeart() {
    sendMessage(pingMsg);
  }

  /// 销毁心跳
  void destroyHeartBeat() {
    debugPrint('>>>>> on ws ${DateTime.now()} destroyHeartBeat');
    if (_heartBeat != null) {
      _heartBeat!.cancel();
      _heartBeat = null;
    }
  }

  void destroyReconnectTimer() {
    if (_reconnectTimer != null) {
      debugPrint(
          '>>>>> on ws ${DateTime.now()} destroyReconnectTimer 重连次数超过最大次数 $_reconnectTimes');
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }
  }

  /// 关闭WebSocket
  void closeSocket() {
    debugPrint('>>>>> on ws ${DateTime.now()} closeSocket');
    destroyHeartBeat();
    destroyReconnectTimer();
    if (_webSocketChannel != null) {
      debugPrint('>>>>> on ws ${DateTime.now()} WebSocket连接关闭');
      _webSocketChannel!.sink.close();
      _socketStatus = SocketStatus.SocketStatusClosed;
      _webSocketChannel = null;
    }
  }

  /// 发送WebSocket消息
  bool sendMessage(String message) {
    bool result = false;
    if (_webSocketChannel == null) {
      debugPrint(
          '>>>>> on ws ${DateTime.now()} sendMsg $message; _webSocketChannel is null');
      closeSocket();
    } else {
      switch (_socketStatus) {
        case SocketStatus.SocketStatusConnected:
          debugPrint('>>>>> on ws ${DateTime.now()} sendMsg $message');
          _webSocketChannel!.sink.add(message);
          result = true;
          break;
        case SocketStatus.SocketStatusClosed:
          Get.snackbar("Tips", "连接已关闭 ws ${DateTime.now()}");
          debugPrint('>>>>> on ws ${DateTime.now()} sendMsg 连接已关闭 $message');
          break;
        case SocketStatus.SocketStatusFailed:
          Get.snackbar("Tips", "发送失败 SocketStatusFailed");
          debugPrint('>>>>> on ws ${DateTime.now()} sendMsg  发送失败 $message');
          break;
        default:
          Get.snackbar("Tips", "发送失败 ws" + _socketStatus.toString());
          debugPrint(
              '>>>>> on ws ${DateTime.now()} sendMsg 发送失败 ${_socketStatus.toString()} $message');
          break;
      }
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
          debugPrint(
              '>>>>> on ws ${DateTime.now()} _reconnect _reconnectTimes $_reconnectTimes');
          openSocket();
        },
      );
    } else {
      destroyReconnectTimer();
      return;
    }
  }
}
