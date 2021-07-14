import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:imboy/helper/websocket_heartbeat.dart';
import 'package:logger/logger.dart';

typedef Callback(data);

const api_prefix = 'http://dev.api.imboy.pub:9800';
const ws_url = 'ws://dev.api.imboy.pub:9800/websocket/';

// const api_prefix = 'http://local.api.imoby.pub:9800';
// const ws_url = 'ws://local.api.imoby.pub:9800/websocket/';

// const api_prefix = 'http://172.20.10.10:9800';
// const ws_url = 'ws://172.20.10.10:9800/websocket/';

class API {
  static const init = api_prefix + '/init';
  static const refreshtoken = api_prefix + '/refreshtoken';
  static const login = api_prefix + '/passport/login';
  static const regiser = api_prefix + '/passport/regiser';
  static const friendList = api_prefix + '/friend/list';
  static const conversationList = api_prefix + '/conversation/mine';

  static const avatarUrl = 'http://www.lorempixel.com/200/200/';
  static const cat = 'https://api.thecatapi.com/v1/images/search';
  static const upImg = "http://111.230.251.115/oldchen/fUser/oneDaySuggestion";
  static const update = 'http://www.flutterj.com/api/update.json';
  static const uploadImg = 'http://www.flutterj.com/upload/avatar';
}

DefaultCacheManager cacheManager = new DefaultCacheManager();

typedef VoidCallbackConfirm = void Function(bool isOk);

enum ClickType { select, open }

const Color mainBGColor = Color.fromRGBO(240, 240, 245, 1.0);

var logger = Logger();

WebsocketHeartbeat wshb = new WebsocketHeartbeat(ws_url, subprotocol: ['text']);

class cb {}
