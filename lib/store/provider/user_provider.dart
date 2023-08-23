import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';

class UserProvider extends HttpClient {
  Future<Map<String, dynamic>> turnCredential() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return {};
    }
    IMBoyHttpResponse resp = await get(
      API.turnCredential,
    );
    if (!resp.ok) {
      return {};
    }
    return resp.payload;
  }

  Future<String> refreshAccessTokenApi(String refreshToken,
      {bool checkNewToken = true}) async {
    if (strEmpty(refreshToken)) {
      Get.offAll(() => PassportPage());
      return "";
    }

    var response = await Dio(BaseOptions(baseUrl: API_BASE_URL)).post(
      API.refreshToken,
      options: Options(
        contentType: "application/x-www-form-urlencoded",
        headers: {
          Keys.refreshTokenKey: refreshToken,
          'method': 'sha512',
          'sign': EncrypterService.sha512("$deviceId|$appVsnXY", SOLIDIFIED_KEY)
        },
      ),
    );
    IMBoyHttpResponse resp = handleResponse(response);
    if (resp.code == 705 || resp.code == 706) {
      checkNewToken = true;
    }
    String newToken = resp.payload?['token'] ?? '';
    if (checkNewToken && strEmpty(newToken)) {
      WebSocketService.to.closeSocket(true);
      Get.offAll(() => PassportPage());
      return "";
    }
    await StorageService.to.setString(Keys.tokenKey, newToken);
    return newToken;
  }

  Future<Map<String, dynamic>?> ftsRecentlyUser({
    int page = 1,
    int size = 10,
    String keyword = '',
  }) async {
    IMBoyHttpResponse resp = await get(API.ftsRecentlyUser, queryParameters: {
      'page': page,
      'size': size,
      'keyword': keyword,
    });

    iPrint("> on UserTagProvider/page resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }
}
