import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

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
      API.e2eeReportDeviceKey,
      data: {
        'device_id': deviceId,
        'device_type': deviceType,
        if (deviceName != null && deviceName.isNotEmpty)
          'device_name': deviceName,
        'public_key': publicKey,
        'key_id': keyId,
      },
    );
    return resp.ok;
  }

  Future<List<Map<String, dynamic>>> userKeys({required String uid}) async {
    IMBoyHttpResponse resp = await get(
      API.e2eeUserKeys,
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
      API.e2eeGroupMemberKeys,
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

  /// 获取当前活跃的合规公钥
  ///
  /// 返回 {key_id, public_key} 或 null
  /// 用于 compliance_e2ee 模式的双密钥加密
  Future<Map<String, dynamic>?> getComplianceKey() async {
    IMBoyHttpResponse resp = await get(API.e2eeComplianceKey);
    if (!resp.ok) return null;
    return resp.payload as Map<String, dynamic>?;
  }

  /// GET /v1/e2ee/key/status — 查询当前设备密钥的服务端注册状态
  ///
  /// 返回 {has_valid_key, recovery_options, recommended_method} 或 null
  Future<Map<String, dynamic>?> keyStatus() async {
    final IMBoyHttpResponse resp = await get(API.e2eeKeyStatus);
    if (!resp.ok) return null;
    final p = resp.payload;
    return p is Map<String, dynamic> ? p : null;
  }

  /// GET /v1/e2ee/notifications/pull — 拉取待处理的 E2EE 通知
  ///
  /// 通知格式 [{type, payload, created_at}]；失败返回空列表
  Future<List<Map<String, dynamic>>> pullNotifications() async {
    final IMBoyHttpResponse resp = await get(API.e2eeNotificationsPull);
    if (!resp.ok) return [];
    final p = resp.payload;
    if (p is List) {
      return p.whereType<Map<String, dynamic>>().toList();
    }
    if (p is Map<String, dynamic>) {
      final list = p['list'] ?? p['notifications'];
      if (list is List) {
        return list.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
