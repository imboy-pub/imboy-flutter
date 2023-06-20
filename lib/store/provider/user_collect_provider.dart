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

  ///
  Future<bool> change({
    required String action,
    required String kindId,
  }) async {
    IMBoyHttpResponse resp = await post(API.userCollectChange, data: {
      'action': action,
      'kind_id': kindId,
    });
    debugPrint("> on Provider/send_to_view callback resp: ${resp.payload.toString()}");
    return resp.ok ? true : false;
  }

  Future<bool> add(int kind, String kindId, String source, Map<String, dynamic> info) async {
    IMBoyHttpResponse resp = await post(API.userCollectAdd, data: {
      'kind': kind,
      'kind_id': kindId,
      'source': source,
      'info': info,
    });
    debugPrint("> on Provider/userDeviceAdd resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }
}
