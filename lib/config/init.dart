import 'package:flutter_cache_manager/flutter_cache_manager.dart';

typedef Callback(data);

//const api_prefix = 'http://demo2.imboy.leeyi.net:9800';
//const ws_url = 'ws://demo2.imboy.leeyi.net:9800/websocket/';

const api_prefix = 'http://local.api.imoby.pub:9800';
const ws_url = 'ws://local.api.imoby.pub:9800/websocket/';

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

enum ClickType { select, open }
