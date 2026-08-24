import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/app_loading.dart';

class LocationApi extends HttpClient {
  Future<Map<String, dynamic>?> peopleNearby({
    required String longitude, // 经度
    required String latitude, // 维度
    int radius = 500000,
    String unit = 'm',
    int limit = 100,
    // Map<String, String>? options,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.peopleNearby,
      queryParameters: {
        'radius': radius,
        'unit': unit,
        'limit': limit,
        'longitude': longitude,
        'latitude': latitude,
      },
    );
    if (!resp.ok) {
      // fail-open 改造：页面层（people_nearby_provider）只有 try/finally
      // 没有 catch，不能抛异常；透出后端错误消息，null 返回即失败。
      if (resp.msg.isNotEmpty) {
        AppLoading.showBackendError(resp.msg);
      }
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  /// 让自己可见
  Future<bool> makeMyselfVisible({
    // required Map<String, dynamic> latLng,
    required String longitude, // 经度
    required String latitude, // 维度
  }) async {
    IMBoyHttpResponse resp = await post(
      API.makeMyselfVisible,
      data: {
        // "latLng": latLng,
        "longitude": longitude,
        "latitude": latitude,
      },
    );
    return resp.ok ? true : false;
  }

  /// 让自己不可见
  Future<bool> makeMyselfUnVisible() async {
    IMBoyHttpResponse resp = await post(API.makeMyselfUnVisible);
    return resp.ok ? true : false;
  }
}
