import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/secure_token_storage_service.dart'
    show SecureTokenStorageService;
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/config/routes.dart';

/// 用户 API 提供者的 Riverpod Provider
/// 提供对 UserApi 单例的访问
final userApiProvider = Provider<UserApi>((ref) {
  return UserApi.to;
});

/// 用户 API 客户端
/// 负责处理用户相关的 HTTP 请求
/// 采用单例模式，通过 UserApi.to 访问实例
class UserApi extends HttpClient {
  // 私有构造函数，实现单例模式
  UserApi._();

  // 单例实例
  static final UserApi _instance = UserApi._();

  /// 获取单例实例
  static UserApi get to => _instance;
  Future<Map<String, dynamic>> turnCredential() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return {};
    }
    IMBoyHttpResponse resp = await get(API.turnCredential);
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
      UserRepoLocal.to.quitLogin();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
      return "";
    }
    Map<String, dynamic> headers = await defaultHeaders();
    headers[Keys.refreshTokenKey] = refreshToken;
    var response = await Dio(
      BaseOptions(baseUrl: Env().apiBaseUrl),
    ).post(API.refreshToken, options: Options(headers: headers));
    // iPrint("refreshAccessTokenApi ${response.toString()}");
    // iPrint("refreshAccessTokenApi refreshToken $refreshToken");
    IMBoyHttpResponse resp = handleResponse(response, uri: API.refreshToken);
    // 处理 token 相关错误（401 UNAUTHORIZED 包含了所有 token 失效情况）
    // 兼容旧版 705/706 错误码
    if (ErrorCode.shouldReLogin(resp.code)) {
      checkNewToken = true;
    }
    String newToken = resp.payload?['token'] ?? '';
    if (checkNewToken && strEmpty(newToken)) {
      UserRepoLocal.to.quitLogin();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.signIn,
        (route) => false,
      );
      return "";
    }
    await SecureTokenStorageService.saveToken(newToken);
    return newToken;
  }

  Future<Map<String, dynamic>?> ftsRecentlyUser({
    int page = 1,
    int size = 10,
    String keyword = '',
  }) async {
    IMBoyHttpResponse resp = await get(
      API.ftsRecentlyUser,
      queryParameters: {'page': page, 'size': size, 'keyword': keyword},
    );

    iPrint("> on UserApi/ftsRecentlyUser resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<Map<String, dynamic>?> userSearch({
    int page = 1,
    int size = 10,
    String keyword = '',
  }) async {
    IMBoyHttpResponse resp = await get(
      API.userSearch,
      queryParameters: {'page': page, 'size': size, 'keyword': keyword},
    );

    iPrint("> on UserApi/ftsUserSearch resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return null;
    }
    return resp.payload;
  }

  Future<bool> changeEmail({
    required String email,
    required String code,
  }) async {
    IMBoyHttpResponse resp = await put(
      API.userUpdate,
      data: {"field": "email", "value": email, "code": code},
    );
    return resp.ok;
  }

  /// 修改或绑定手机号（需短信验证码）
  /// 参数:
  /// - mobile: 要绑定的新手机号（带区号完整号码，如 +8613812345678）
  /// - code: 短信验证码
  /// 返回:
  /// - true 表示后端更新成功；false 失败（调用方应根据场景提示）
  Future<bool> changeMobile({
    required String mobile,
    required String code,
  }) async {
    IMBoyHttpResponse resp = await put(
      API.userUpdate,
      data: {"field": "mobile", "value": mobile, "code": code},
    );
    return resp.ok;
  }

  /// 用户允许被搜索 1 是  2 否
  Future<bool> allowSearch(int val) async {
    IMBoyHttpResponse resp = await put(
      API.userUpdate,
      data: {"field": "allow_search", "value": val},
    );
    return resp.ok;
  }

  Future<bool> changePassword({
    required String newPwd,
    required String existingPwd,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userChangePassword,
      data: {'new_pwd': newPwd, 'existing_pwd': existingPwd},
    );

    iPrint("> on UserApi/changePassword resp: ${resp.payload.toString()}");
    if (resp.ok) {
      return true;
    }
    EasyLoading.showError(resp.msg);
    return false;
  }

  Future<bool> setPassword({required String newPwd}) async {
    IMBoyHttpResponse resp = await post(
      API.userSetPassword,
      data: {'new_pwd': newPwd},
    );

    iPrint("> on UserApi/setPassword resp: ${resp.payload.toString()}");
    if (resp.ok) {
      StorageService.to.remove(Keys.needSetPwd);
      return true;
    }
    if (resp.msg == 'have_set') {
      StorageService.to.remove(Keys.needSetPwd);
    }
    EasyLoading.showError(resp.msg);
    return false;
  }

  Future<bool> applyLogout() async {
    try {
      IMBoyHttpResponse resp = await post(API.userApplyLogout);
      iPrint("> on UserApi/applyLogout resp: ${resp.payload.toString()}");
      if (!resp.ok) {
        iPrint(
          "> on UserApi/applyLogout failed: ${resp.msg}, code: ${resp.code}",
        );
        EasyLoading.showError(resp.msg);
        return false;
      }
      return true;
    } catch (e) {
      iPrint("> on UserApi/applyLogout error: $e");
      EasyLoading.showError(t.logoutRequestFailedPleaseCheckNetwork);
      return false;
    }
  }

  Future<bool> cancelLogout() async {
    IMBoyHttpResponse resp = await post(API.userCancelLogout);
    iPrint("> on UserApi/cancelLogout resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return false;
    }
    return true;
  }

  Future<bool> changeSetting(Map<String, dynamic> map) async {
    IMBoyHttpResponse resp = await post(API.userSetting, data: map);
    iPrint("> on UserApi/changeSetting resp: ${resp.payload.toString()}");
    if (!resp.ok) {
      return false;
    }
    return true;
  }
}
