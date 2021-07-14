import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/api/passport_api.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/jwt.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/store/repository/user_repository.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

///
/// 心跳功能参考
/// https://github.com/zimv/websocket-heartbeat-js/blob/master/lib/index.js
///
class WebsocketHeartbeat {
  String url;
  Iterable<String> subprotocol = ['text'];
  String pingMsg = 'ping';

  // 时间单位都是毫秒  milliseconds
  int pingTimeout = 15000;
  int reconnectTimeout = 10;

  // 重新链接次数限制
  int repeatLimit = 30;

  bool lockReconnect = false;
  bool forbidReconnect = false;

  // 重新链接计数器
  int repeat = 0;

  var channel;

  ///
  /// 长连接是否建立
  ///
  bool _isOn = false;

  WebsocketHeartbeat(url,
      {Iterable<String> subprotocol,
      String pingMsg,
      int pingTimeout,
      int reconnectTimeout,
      int repeatLimit}) {
    this.url = url;
    if (subprotocol.isNotEmpty) {
      this.subprotocol = subprotocol;
    }
    if (strNoEmpty(pingMsg)) {
      this.pingMsg = pingMsg;
    }
    if (isPositiveInt(pingTimeout)) {
      this.pingTimeout = pingTimeout;
    }
    if (isPositiveInt(reconnectTimeout)) {
      this.reconnectTimeout = reconnectTimeout;
    }
    if (isPositiveInt(repeatLimit)) {
      this.repeatLimit = repeatLimit;
    }
    this.repeat = 0;
    this.createWebSocket();
  }

  Future<void> createWebSocket([var callback, var args]) async {
    if (this._isOn == true && this.channel != null) {
      return;
    }
    try {
      String token = UserRepository.accessToken();
      if (!strNoEmpty(token)) {
        return;
      }
      if (token_expired(token)) {
        await refreshtoken();
        debugPrint('>>>>>>>>>>>>>>>>>>> on token old $token');
        token = UserRepository.accessToken();
        debugPrint('>>>>>>>>>>>>>>>>>>> on token new $token');
      }
      String url =
          this.url + '?' + Keys.tokenKey + '=' + token.replaceAll('+', '%2B');
      //创建websocket连接
      Duration pingInterval = Duration(milliseconds: this.pingTimeout);
      var headers = {
        'vsn': appVsn,
        'device-type': currentDeviceType(),
        'client-system': Platform.operatingSystem,
        'client-system-vsn': Platform.operatingSystemVersion,
        // js websocket 不能设置header；为兼容，token不放到header里面
        // '${Keys.tokenKey}': token.replaceAll('+', '%2B'),
      };
      if (this.subprotocol.isEmpty) {
        this.channel = new IOWebSocketChannel.connect(
          url,
          pingInterval: pingInterval,
          headers: headers,
        );
      } else {
        this.channel = new IOWebSocketChannel.connect(
          url,
          pingInterval: pingInterval,
          headers: headers,
          protocols: this.subprotocol,
        );
      }
      this.initEventHandle();
      if (callback != null) {
        callback();
      }
      this._isOn = true;
      // 链接成功之后，repeat 归零
      this.repeat = 0;
    } on Exception catch (e, unexpectedStackTrace) {
      // 任意一个异常
      debugPrint(
          '>>>>>>>>>>>>>>>>>>> on Unknown 1: ${e}, unexpectedStackTrace ${unexpectedStackTrace}');
    } catch (e, unexpectedStackTrace) {
      // 非具体类型
      debugPrint(
          '>>>>>>>>>>>>>>>>>>> on Unknown 2: ${e}, unexpectedStackTrace ${unexpectedStackTrace}');
    }
  }

  void initEventHandle() {
    this.channel.stream.listen(
          this.onData,
          onError: this.onError,
          onDone: this.onClose,
        );
  }

  bool connected() {
    return _isOn;
  }

  void reconnect() {
    debugPrint(
        ">>>>>>>>>>>>>>>>>>> on reconnect repeatLimit: ${this.repeatLimit} repeat: ${this.repeat}");
    if (this.repeatLimit > 0 && this.repeatLimit <= this.repeat) {
      //limit repeat the number
      return;
    }
    if (this.lockReconnect || this.forbidReconnect) {
      return;
    }
    this.lockReconnect = true;
    this.repeat++; //必须在lockReconnect之后，避免进行无效计数
    int reconnectTimeout = this.reconnectTimeout + 2000 * this.repeat;
    if (this.repeat > (this.repeatLimit / 2)) {
      reconnectTimeout = reconnectTimeout - 1000 * this.repeat;
    }
    if (reconnectTimeout < this.reconnectTimeout) {
      reconnectTimeout = this.reconnectTimeout;
    }

    new Timer(new Duration(milliseconds: reconnectTimeout), () {
      int ts = DateTimeHelper.currentTimeMillis();
      debugPrint(">>>>>>>>>>>>>>>>>>> on reconnect dt ${ts}");
      this.createWebSocket();
      this.lockReconnect = false;
    });
  }

  Future<bool> send(msg) async {
    if (this._isOn == false ||
        this.channel == null ||
        this.channel.sink == null) {
      return false;
      // this.createWebSocket((msg) {
      //   logger.d(">>>>>>>>>>>>>>>>>> on send msg callback ${msg}");
      //   this.send(msg);
      // });
    }
    debugPrint(
        "websocket_heartbeat send channel ${this.channel} sink ${this.channel.sink}");
    if (msg.isNotEmpty) {
      var resp = this.channel.sink.add(msg);
      debugPrint(">>>>>>>>>>>>>>>>>>> on send msg resp ${resp}");
      return resp;
    }
    return true;
  }

  void onClose() {
    debugPrint(">>>>>>>>>>>>>>>>>>> onclose Socket is closed");
    _isOn = false;
    this.reconnect();
  }

  void onError(err) {
    debugPrint(
        ">>>>>>>>>>>>>>>>>>> onerror ${err.runtimeType.toString()} msg>>>>>> ${err.toString()} >>>>>> ${err.hashCode} || >>");
    WebSocketChannelException ex = err;
    debugPrint(ex.message);
    _isOn = false;
    this.reconnect();
  }

  void onData(event) async {
//    debugPrint(
//        ">>>>>>>>>>>>>>>>>>> onData ${event.runtimeType} | ${event.toString()}");
    Map data = event is Map ? event : json.decode(event);
    int code = data['code'] ?? 99999;
    String dtype = data['type'] ?? 'error';

    if (dtype == 'error') {
      debugPrint(" websocket_heartbeat code >>> ${code}");
      switch (code) {
        // case 705: // token无效、刷新token 这里不处理，不发送消息
        case 706: // 需要重新登录
          {
            Get.to(() => LoginPage());
          }
          break;
      }
    }
    // eventBus.fire(data);
  }

  // 手动关闭websocket
  void close(int closeCode, String closeReason) {
    debugPrint(">>>>>>>>>>>>>>>>>>> on close ${closeCode} : ${closeReason}");
    //如果手动关闭连接，不再重连
    this.forbidReconnect = true;
    if (this.channel != null) {
      this.channel.sink.close();
      this.channel = null;
    }
    _isOn = false;
  }

  void setPingTimeout(int pingTimeout) {
    this.pingTimeout = pingTimeout;
  }
}
