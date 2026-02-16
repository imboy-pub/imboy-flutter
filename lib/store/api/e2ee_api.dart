import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class E2EEApi extends HttpClient {
  /// 上报当前设备的 E2EE 公钥
  ///
  /// POST /v1/e2ee/report_device_key
  ///
  /// 将当前设备的 E2EE 公钥上传到服务器，使其他用户可以发送加密消息
  ///
  /// 请求参数:
  /// - device_id: 设备 ID
  /// - device_type: 设备类型 (android/ios/macos/web)
  /// - device_name: 设备名称（可选）
  /// - public_key: PEM 格式的公钥
  /// - key_id: 密钥 ID
  ///
  /// 返回:
  /// - success: 是否成功
  Future<bool> reportDeviceKey({
    required String deviceId,
    required String deviceType,
    String? deviceName,
    required String publicKey,
    required String keyId,
  }) async {
    IMBoyHttpResponse resp = await post(
      '/v1/e2ee/report_device_key',
      data: {
        'device_id': deviceId,
        'device_type': deviceType,
        if (deviceName != null && deviceName.isNotEmpty) 'device_name': deviceName,
        'public_key': publicKey,
        'key_id': keyId,
      },
    );
    return resp.ok;
  }

  Future<List<Map<String, dynamic>>> userKeys({required String uid}) async {
    IMBoyHttpResponse resp = await get(
      '/v1/e2ee/user_keys',
      queryParameters: {'uid': uid},
    );
    if (!resp.ok) return [];
    final payload = resp.payload;
    final devices = payload['devices'];
    if (devices is List) {
      return devices.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> groupMemberKeys({
    required String gid,
  }) async {
    IMBoyHttpResponse resp = await get(
      '/v1/e2ee/group_member_keys',
      queryParameters: {'gid': gid},
    );
    if (!resp.ok) return [];
    final payload = resp.payload;
    final members = payload['members'];
    if (members is List) {
      return members.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  void debugLogUserKeys(List<Map<String, dynamic>> list) {
    if (kDebugMode) {
      debugPrint('E2EEApi.userKeys count=${list.length}');
    }
  }
}
