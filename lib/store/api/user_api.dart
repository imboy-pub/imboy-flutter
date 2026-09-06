import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';
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
import 'package:imboy/config/init.dart' show navigateToSignIn;

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
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  Future<String> refreshAccessTokenApi(
    String refreshToken, {
    bool checkNewToken = true,
  }) async {
    if (strEmpty(refreshToken)) {
      await UserRepoLocal.to.quitLogin();
      navigateToSignIn(source: 'user_api_relogin');
      return "";
    }
    Map<String, dynamic> headers = await defaultHeaders();
    headers[Keys.refreshTokenKey] = refreshToken;
    var response = await Dio(
      BaseOptions(baseUrl: Env().apiBaseUrl),
    ).post<dynamic>(API.refreshToken, options: Options(headers: headers));
    // iPrint("refreshAccessTokenApi ${response.toString()}");
    // iPrint("refreshAccessTokenApi refreshToken $refreshToken");
    IMBoyHttpResponse resp = handleResponse(response, uri: API.refreshToken);
    // 处理 token 相关错误（401 UNAUTHORIZED 包含了所有 token 失效情况）
    if (ErrorCode.shouldReLogin(resp.code)) {
      checkNewToken = true;
    }
    String newToken = resp.payload?['token'] as String? ?? '';
    if (checkNewToken && strEmpty(newToken)) {
      await UserRepoLocal.to.quitLogin();
      navigateToSignIn(source: 'user_api_relogin');
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
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
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
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
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

  Future<bool> updateField(String field, String value) async {
    IMBoyHttpResponse resp = await put(
      API.userUpdate,
      data: {"field": field, "value": value},
    );
    if (!resp.ok) {
      // 透出后端中文原因，页面层不再叠兜底文案
      AppLoading.showBackendError(resp.msg);
      return false;
    }
    return true;
  }

  /// 用户允许被搜索 1 是  2 否
  Future<bool> allowSearch(int val) async {
    IMBoyHttpResponse resp = await put(
      API.userUpdate,
      data: {"field": "allow_search", "value": val},
    );
    if (!resp.ok) {
      AppLoading.showBackendError(resp.msg);
      return false;
    }
    return true;
  }

  /// 用户域错误码本地化：后端部分失败只回英文错误码（如 errorPassword），
  /// 裸显给用户不可读；有对应 i18n 键的翻译，其余原样透出
  /// （后端多为中文文案，如「已设置过密码，请使用修改密码」）。
  String _localizedUserErrMsg(String raw) {
    return switch (raw) {
      'errorPassword' => t.common.errorPassword,
      _ => raw,
    };
  }

  Future<bool> changePassword({
    required String newPwd,
    required String existingPwd,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userChangePassword,
      // 与 passport login 同契约：rsa_encrypt=0 明文传输（alpha.69 密码
      // 迁移后客户端统一行为）；服务端 safe_rsa_decrypt 据此跳过 RSA 解密。
      data: {
        'new_pwd': newPwd,
        'existing_pwd': existingPwd,
        'rsa_encrypt': '0',
      },
    );

    iPrint("> on UserApi/changePassword resp: ${resp.payload.toString()}");
    if (resp.ok) {
      return true;
    }
    AppLoading.showError(_localizedUserErrMsg(resp.msg));
    return false;
  }

  Future<bool> setPassword({required String newPwd}) async {
    IMBoyHttpResponse resp = await post(
      API.userSetPassword,
      // 契约：调用方传入的 newPwd 是 md5+RSA-OAEP 密文（provider 层
      // _encryptPassword 产出），必须声明 rsa_encrypt='1' 让服务端解密
      // 后存储。此前写死 '0'：服务端把 RSA 密文当明文直接 hash，导致
      // UI 设密后的密码任何登录形态都验证不过（批次120 AT-AS 实证）。
      data: {'new_pwd': newPwd, 'rsa_encrypt': '1'},
    );

    iPrint("> on UserApi/setPassword resp: ${resp.payload.toString()}");
    if (resp.ok) {
      StorageService.to.remove(Keys.needSetPwd);
      return true;
    }
    // 后端对已有密码账号返回中文文案（elib_response:error 透传
    // user_logic 的「已设置过密码，请使用修改密码」）；此态下设置页
    // 引导使命已完成，清除 needSetPwd 标记避免下次启动重复引导。
    if (resp.msg.contains('已设置过密码')) {
      StorageService.to.remove(Keys.needSetPwd);
    }
    AppLoading.showError(_localizedUserErrMsg(resp.msg));
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
        AppLoading.showError(resp.msg);
        return false;
      }
      return true;
    } on Object catch (e) {
      iPrint("> on UserApi/applyLogout error: $e");
      AppLoading.showError(t.common.logoutRequestFailedPleaseCheckNetwork);
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

  /// D-04：注销请求状态（pending/cancelled/completed + 预期完成时间 +
  /// 保留类别），页面据此渲染宽限期横幅与撤销入口。
  Future<Map<String, dynamic>?> deletionStatus() async {
    try {
      IMBoyHttpResponse resp = await get(API.userDeletionStatus);
      iPrint("> on UserApi/deletionStatus resp: ${resp.payload.toString()}");
      if (!resp.ok) {
        return null;
      }
      return resp.payload is Map<String, dynamic>
          ? resp.payload as Map<String, dynamic>
          : null;
    } on Object catch (e) {
      iPrint("> on UserApi/deletionStatus error: $e");
      return null;
    }
  }

  /// 导出用户数据（个人信息、联系人、聊天记录等）
  /// 返回 JSON 格式的用户数据，失败时返回 null
  Future<Map<String, dynamic>?> exportUserData() async {
    try {
      IMBoyHttpResponse resp = await get(API.userExportData);
      iPrint("> on UserApi/exportUserData resp: ${resp.payload.toString()}");
      if (!resp.ok) {
        AppLoading.showError(resp.msg);
        return null;
      }
      return resp.payload is Map<String, dynamic>
          ? resp.payload as Map<String, dynamic>
          : null;
    } on Object catch (e) {
      iPrint("> on UserApi/exportUserData error: $e");
      AppLoading.showError(t.common.operationFailedAgainLater);
      return null;
    }
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
