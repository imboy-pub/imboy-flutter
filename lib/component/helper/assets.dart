import 'package:flutter/widgets.dart';
import 'package:imboy/config/const.dart';

import 'datetime.dart';
import 'func.dart';

class Assets {
  static String getImgPath(String name, {String format = 'png'}) {
    return 'assets/images/$name.$format';
  }

  /// Assets.authData()
  static Map<String, dynamic> authData() {
    int v = DateTimeHelper.currentTimeSecond();
    // md5(a + v)
    String authToken = generateMD5("$UP_AUTH_KEY$v").substring(8, 24);
    return {
      'v': v,
      'a': authToken,
      's': UPLOAD_SENCE,
    };
  }

  /// 获取URL地址的 v 参数，和当前时间做比较，再决定是否重新生成授权令牌
  /// Assets.viewUrl
  static Uri viewUrl(String url) {
    int now = DateTimeHelper.currentTimeSecond();
    int diff = 3600; // 1hour

    Map<String, dynamic> cache = {};
    // 从服务器去授权码，缓存，服务器设定的缓存时间，
    // 判断有授权码，直接设置响应；
    // 否则，通过aes加密方式想服务器请求授权令牌，并且缓存之

    Uri u = Uri.parse(url);
    int v = int.parse("${u.queryParameters['v'] ?? 0}");
    debugPrint("> viewUrl $v if ${v > 0 && now < (v + diff)} | $url ");
    if (v > 0 && now < (v + diff)) {
      return u;
    }
    Map<String, dynamic> data = authData();
    Map<String, String> q = Map<String, String>.from(u.queryParameters)
      ..addAll({
        's': data['s'],
        'a': data['a'],
        'v': data['v'].toString(),
      });
    debugPrint("viewUrl 2 ${Uri(
      scheme: u.scheme,
      host: u.host,
      path: u.path,
      port: u.port,
      queryParameters: q,
    ).toString()}");
    return Uri(
      scheme: u.scheme,
      host: u.host,
      path: u.path,
      port: u.port,
      queryParameters: q,
    );
  }
}
