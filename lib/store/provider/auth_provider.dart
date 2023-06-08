import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class AuthProvider extends HttpClient {
  Future<String> getAssetsToken(String s) async {
    IMBoyHttpResponse resp = await post(API.assetsToken, data: {'s', s});
    debugPrint("AuthProvider_getAssetsToken resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return '';
    }
    return resp.payload['res'] ?? '';
  }
}
