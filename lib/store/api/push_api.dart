import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

/// 推送通知 API 客户端
///
/// 管理推送 token 的注册和注销
///
/// 后端合同（EPGZ-07 对齐，imboy user_device_handler push_register +
/// push_token 表 CHECK 约束）：
/// - POST /api/v1/push/register body {device_id, device_type, platform, token}
///   - device_type：设备 OS，值域 {android, ios, web}
///   - platform：推送通道 provider，值域 {fcm, apns, web_push, jpush}
/// - POST /api/v1/push/unregister body 仅 {device_id}
///
/// 历史错位（已修复）：曾把 device_type 的值（android/ios）塞进 platform
/// 字段、且 body 缺 device_type 键——两条 DB CHECK 均违反，注册必 500。
class PushApi extends HttpClient {
  /// 注册推送 token
  ///
  /// [token] 推送 token（FCM/APNs token，或 JPush RegistrationID）
  /// [deviceType] 设备 OS：android / ios / web
  /// [platform] 推送通道 provider：fcm / apns / web_push / jpush
  /// [deviceId] 设备 ID
  Future<bool> register({
    required String token,
    required String deviceType,
    required String platform,
    required String deviceId,
  }) async {
    if (kDebugMode) {}
    IMBoyHttpResponse resp = await post(
      API.pushRegister,
      data: {
        'token': token,
        'device_type': deviceType,
        'platform': platform,
        'device_id': deviceId,
      },
    );
    if (kDebugMode) {}
    return resp.ok;
  }

  /// 注销推送 token
  ///
  /// [deviceId] 设备 ID
  Future<bool> unregister({required String deviceId}) async {
    if (kDebugMode) {}
    IMBoyHttpResponse resp = await post(
      API.pushUnregister,
      data: {'device_id': deviceId},
    );
    if (kDebugMode) {}
    return resp.ok;
  }
}
