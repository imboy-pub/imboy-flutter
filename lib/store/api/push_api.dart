import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

/// 推送通知 API 客户端
///
/// 管理推送 token 的注册和注销
class PushApi extends HttpClient {
  /// 注册推送 token
  ///
  /// [token] FCM/APNs 推送 token
  /// [platform] 平台标识: "android" / "ios"
  /// [deviceId] 设备 ID
  Future<bool> register({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    if (kDebugMode) {
      debugPrint('> on PushApi/register: platform=$platform');
    }
    IMBoyHttpResponse resp = await post(
      API.pushRegister,
      data: {'token': token, 'platform': platform, 'device_id': deviceId},
    );
    if (kDebugMode) {
      debugPrint('> on PushApi/register resp: ok=${resp.ok}');
    }
    return resp.ok;
  }

  /// 注销推送 token
  ///
  /// [deviceId] 设备 ID
  Future<bool> unregister({required String deviceId}) async {
    if (kDebugMode) {
      debugPrint('> on PushApi/unregister');
    }
    IMBoyHttpResponse resp = await post(
      API.pushUnregister,
      data: {'device_id': deviceId},
    );
    if (kDebugMode) {
      debugPrint('> on PushApi/unregister resp: ok=${resp.ok}');
    }
    return resp.ok;
  }
}
