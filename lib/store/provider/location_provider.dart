import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class LocationProvider extends HttpClient {
  Future<Map<String, dynamic>?> peopleNearby({
    required String longitude, // 经度
    required String latitude, // 维度
    int radius = 500000,
    String unit = 'm',
    int limit = 100,
    // Map<String, String>? options,
  }) async {
    IMBoyHttpResponse resp = await get(API.peopleNearby, queryParameters: {
      'radius': radius,
      'unit': unit,
      'limit': limit,
      'longitude': longitude,
      'latitude': latitude,
    });
    debugPrint("> on Provider/peopleNearby resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  /// 让自己可见
  Future<bool> makeMyselfVisible({
    // required Map<String, dynamic> latLng,
    required String longitude, // 经度
    required String latitude, // 维度
  }) async {
    IMBoyHttpResponse resp = await post(API.makeMyselfVisible, data: {
      // "latLng": latLng,
      "longitude": longitude,
      "latitude": latitude,
    });
    debugPrint("> on Provider/makeMyselfVisible resp: ${resp.toString()}");
    return resp.ok ? true : false;
  }

  /// 让自己不可见
  Future<bool> makeMyselfUnvisible() async {
    IMBoyHttpResponse resp = await post(API.makeMyselfUnvisible);
    debugPrint("> on Provider/makeMyselfUnvisible resp: ${resp.payload}");
    return resp.ok ? true : false;
  }
}
