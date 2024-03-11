import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class DenylistProvider extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(API.denylistPage, queryParameters: {
      'page': page,
      'size': size,
    });
    debugPrint("> on Provider/denylistPage resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 加入黑名单
  Future<Map?> add({
    required String deniedUserUid,
  }) async {
    IMBoyHttpResponse resp = await post(API.denylistAdd, data: {
      "denied_user_id": deniedUserUid,
    });
    debugPrint("> on Provider/denylistAdd resp: ${resp.toString()}");
    return resp.ok ? resp.payload : null;
  }

  /// 移除黑名单
  Future<bool> remove({
    required String deniedUserUid,
  }) async {
    IMBoyHttpResponse resp = await post(API.denylistRemove, data: {
      "denied_user_id": deniedUserUid,
    });
    debugPrint("> on Provider/denylistRemove resp: ${resp.payload}");
    return resp.ok ? true : false;
  }
}
