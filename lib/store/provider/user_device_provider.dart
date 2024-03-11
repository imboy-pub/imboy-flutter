import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserDeviceProvider extends HttpClient {
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

  /// 修改设备名称
  Future<bool> changeName({
    required String deviceId,
    required String name,
  }) async {
    IMBoyHttpResponse resp = await post(API.userDeviceChangeName, data: {
      "did": deviceId,
      "name": name,
    });
    debugPrint("> on Provider/changeName resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  /// 删除设备
  Future<bool> deleteDevice({
    required String deviceId,
  }) async {
    IMBoyHttpResponse resp = await post(API.userDeviceDelete, data: {
      "did": deviceId,
    });
    debugPrint("> on Provider/deleteDevice resp: ${resp.payload}");
    return resp.ok ? true : false;
  }
}
