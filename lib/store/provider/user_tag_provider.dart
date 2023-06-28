import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class UserTagProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(API.userDevicePage, queryParameters: {
      'page': page,
      'size': size,
    });
    debugPrint("> on Provider/denylistPage resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 探究标签
  Future<bool> add({
    required List<String> tag,
  }) async {
    IMBoyHttpResponse resp = await post(API.userTagAdd, data: {
      "scene": "friend",
      "tag": tag,
    });
    debugPrint("> on Provider/changeName resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }
}
