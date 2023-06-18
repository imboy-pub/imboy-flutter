import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class UserCollectProvider extends HttpClient {
  Future<Map<String, dynamic>?> page(Map<String, dynamic> args) async {
    IMBoyHttpResponse resp =
        await get(API.userCollectPage, queryParameters: args);
    debugPrint("UserCollectProvider_page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 删除收藏
  Future<bool> remove({
    required String kindId,
  }) async {
    IMBoyHttpResponse resp = await post(API.userCollectRemove, data: {
      'kind_id': kindId,
    });
    debugPrint("> on Provider/deleteDevice resp: ${resp.payload}");
    return resp.ok ? true : false;
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
}
