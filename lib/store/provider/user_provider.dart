import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_keychain/flutter_keychain.dart';
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/env.dart';

import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserProvider extends HttpClient {
  Future<Map<String, dynamic>> turnCredential() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
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

  Future<String> refreshAccessTokenApi(
    String refreshToken, {
    bool checkNewToken = true,
  }) async {
    if (strEmpty(refreshToken)) {
      UserRepoLocal.to.logout();
      Get.offAll(() => PassportPage());
      return "";
    }
    Map<String, dynamic> headers = await defaultHeaders();
    headers[Keys.refreshTokenKey] = refreshToken;
    var response = await Dio(BaseOptions(baseUrl: Env.apiBaseUrl)).post(
      API.refreshToken,
      options: Options(
        headers: headers,
      ),
    );
    // iPrint("refreshAccessTokenApi ${response.toString()}");
    // iPrint("refreshAccessTokenApi refreshToken $refreshToken");
    IMBoyHttpResponse resp = handleResponse(response, uri: API.refreshToken);
    // 705 token 过期
    // 706 token 无效
    if (resp.code == 705 || resp.code == 706) {
      checkNewToken = true;
    }
    String newToken = resp.payload?['token'] ?? '';
    if (checkNewToken && strEmpty(newToken)) {
      UserRepoLocal.to.logout();
      Get.offAll(() => PassportPage());
      return "";
    }
    await FlutterKeychain.put(
      key: Keys.tokenKey,
      value: newToken,
    );
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
