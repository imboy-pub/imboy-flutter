import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:web_socket_channel/io.dart';

import 'package:imboy/config/const.dart';
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
    _self ??= WebSocketService._();
    iPrint("WebSocketService_init ${_self.hashCode} ${_self.toString()}");
    if (_self != null) {
      _self!._init();
    }
    return _self!;
  }

  // wsConnectLock 防止token过期的时候产生多个WS链接
  bool wsConnectLock = false;
  static WebSocketService? _self;

  Iterable<String> protocols = ['text', 'sip'];

  // String pingMsg = 'ping';

  IOWebSocketChannel? _wsChannel; //
  SocketStatus? _socketStatus; // socket状态
  // Timer? _heartBeat; // 心跳定时器 使用 IOWebSocketChannel 的心跳机制
  // 服务端设置为128秒，客服端设置为120秒，不要超过128秒
  // _heartTimes 必须比 服务端 idle_timeout 小一些
  final int _heartTimes = 120000; // 心跳间隔(毫秒)

  final int _reconnectMax = 16; // 重连次数，默认16次
  int _reconnectTimes = 0; // 重连计数器
  // 当websocket 服务出现故障的时候，按 _ts(t)返回的毫秒时间间隔最多重试 _reconnectMax 次

  bool get isConnected => _socketStatus == SocketStatus.SocketStatusConnected;

  ///
  Future<void> _init() async {
    await openSocket(from: 'init');
  }

  /// 开启WebSocket连接
  Future<void> openSocket({String from = ''}) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      iPrint('> ws openSocket 网络连接异常ws');
      return;
    }
    iPrint(
        '> ws openSocket _socketStatus: $_socketStatus, isConnected $isConnected;');
    iPrint(
        '> ws openSocket _reconnectTimes ${_reconnectTimes > 0} $_reconnectTimes');

    iPrint('> ws openSocket wsConnectLock: $wsConnectLock; from $from;');
    // 链接状态正常，不需要任何处理
    if (isConnected && from.startsWith('_reconnect_') == false) {
      return;
    }
    if (wsConnectLock) {
      return;
    }
    wsConnectLock = true;

    String? url = Env.wsUrl;
    if (strEmpty(url)) {
      await initConfig();
      url = Env.wsUrl;
    }
    iPrint("currentEnv $currentEnv wsUrl $url");

    try {
      String tk = await UserRepoLocal.to.accessToken;
      iPrint("Get.currentRoute ${Get.currentRoute}");
      if (tk.isEmpty) {
        iPrint('> ws openSocket tk isEmpty ${tk.isEmpty};');
        wsConnectLock = false;
        if (Get.currentRoute != '/PassportPage' && Get.currentRoute != '/Hnb') {
          UserRepoLocal.to.quitLogin();
          Get.offAll(() => PassportPage());
        }
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

      _wsChannel = IOWebSocketChannel.connect(
        url!,
        headers: headers,
        pingInterval: Duration(milliseconds: _heartTimes),
        protocols: protocols,
      );

      // https://github.com/dart-lang/web_socket_channel/issues/182
      // ready property to make sure that connection is either completed or failed, then a try-catch will work.
      await _wsChannel?.ready;
      // 连接成功，设置socket状态
      _socketStatus = SocketStatus.SocketStatusConnected;

      iPrint('> ws openSocket onOpen');
      // onOpen onMessage onError onClose
      // 接收消息
      _wsChannel?.stream.listen(
        //监听服务器消息 onMessage
        (data) => _onMessage(data),
        //连接错误时调用 onError
        onError: _onError,
        //关闭时调用 onClose
        onDone: _onClose,
        //设置错误时取消订阅
        cancelOnError: true,
      );
    } catch (e) {
      await closeSocket();
      _socketStatus = SocketStatus.SocketStatusFailed;
      iPrint("> openSocket ${Env.wsUrl} error ${e.toString()}");
    } finally {
      iPrint("> openSocket finally ${Env.wsUrl} ");
      wsConnectLock = false;
    }
  }

  _onMessage(event) {
    iPrint("> ws_onMessage $event");
    if (event == "pong" || event == "pong2") {
      return;
    }
    Map data = event is Map ? event : json.decode(event);
    eventBus.fire(data);
  }

  /// WebSocket关闭连接回调
  _onClose() async {
    _socketStatus = SocketStatus.SocketStatusClosed;
    // https://developer.mozilla.org/zh-CN/docs/Web/API/CloseEvent
    // closeCode 1000 正常关闭; 无论为何目的而创建, 该链接都已成功完成任务.
    if (_wsChannel != null && _wsChannel!.closeCode != null) {
      iPrint(
          '> ws _onClose closeCode: ${_wsChannel!.closeCode} ${DateTime.now()}');
      iPrint(
          '> ws _onClose closeReason: ${_wsChannel!.closeReason.toString()}');
      // 1000 CLOSE_NORMAL 正常关闭；无论为何目的而创建，该链接都已成功完成任务
      // 1001 CLOSE_GOING_AWAY	终端离开，可能因为服务端错误，也可能因为浏览器正从打开连接的页面跳转离开
      // 1002	CLOSE_PROTOCOL_ERROR	由于协议错误而中断连接。
      // 1003	CLOSE_UNSUPPORTED	由于接收到不允许的数据类型而断开连接 (如仅接收文本数据的终端接收到了二进制数据).
      // 1005	CLOSE_NO_STATUS	保留。 表示没有收到预期的状态码。
      // 1007	Unsupported Data	由于收到了格式不符的数据而断开连接 (如文本消息中包含了非 UTF-8 数据).
      // 1009	CLOSE_TOO_LARGE	由于收到过大的数据帧而断开连接。
      // 4000–4999		可以由应用使用。
      // 4006 服务端通知客户端刷新token消息没有得到确认，系统主动关闭连接
      int closeCode = _wsChannel?.closeCode ?? 0;

      switch (closeCode) {
        case 4006:
          UserRepoLocal.to.quitLogin();
          Get.offAll(() => PassportPage());
          break;
        default:
          await closeSocket();
          Future.delayed(const Duration(milliseconds: 1000), () async {
            iPrint('> ws _onClose _reconnectTimes: $_reconnectTimes');
            await _reconnect();
          });
      }
    }
  }

  /// WebSocket连接错误回调
  _onError(e) async {
    iPrint('> ws _onError ${e.toString()}');
    _socketStatus = SocketStatus.SocketStatusFailed;
    // await closeSocket();
    await _reconnect();
  }

  /// 关闭WebSocket
  Future<void> closeSocket({bool exit = false}) async {
    iPrint('> ws closeSocket ${DateTime.now()}');
    _socketStatus = SocketStatus.SocketStatusClosed;
    // destroyHeartBeat();
    iPrint('> ws WebSocket连接关闭 ${Env.wsUrl}');
    await _wsChannel?.sink.close();
    _wsChannel = null;
    if (exit) {
      _self = null;
    }
  }

  /// 发送WebSocket消息
  Future<bool> sendMessage(String msg) async {
    bool result = false;
    if (isConnected == false) {
      await WebSocketService.to.openSocket(from: 'sendMessage1');
    }
    iPrint('> ws sendMsg $msg');
    try {
      result = _send(msg);
    } catch (e) {
      await WebSocketService.to.openSocket(from: 'sendMessage2');
      result = _send(msg);
    }

    _reconnectTimes = 0;
    return result;
  }

  bool _send(String msg) {
    _wsChannel?.sink.add(msg);
    return true;
  }

  /// 重连机制
  Future<void> _reconnect() async {
    iPrint('> ws _reconnect _reconnectTimes $_reconnectTimes');
    if (_reconnectTimes > _reconnectMax) {
      // 如果达到最大重连次数，停止重连并关闭 WebSocket
      iPrint('> ws 达到最大重连次数，停止重连');
      await closeSocket();
    } else {
      int ms = _ts(_reconnectTimes);
      iPrint('> ws _reconnect _reconnectTimes $_reconnectTimes; ms $ms');
      Future.delayed(Duration(milliseconds: ms), () async {
        _reconnectTimes += 1;
        iPrint('> ws _onClose _reconnectTimes: $_reconnectTimes');
        await openSocket(from: '_reconnect_$_reconnectTimes');
      });
    }
  }

  int _ts(t) {
    return [
      5000,
      2500,
      6000,
      1500,
      5000,
      2500,
      6000,
      2000,
      7500,
      3000,
      2000,
      1500,
      2000,
      3000,
      8000,
      3000,
    ][t % 16];
  }
}
