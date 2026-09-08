import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// 上报设备公钥的结构化结果。
///
/// 后端在上报成功时返回当前用户除本设备外、已上报有效公钥的活跃设备
/// 数量（[otherDeviceCount]）。客户端据此区分两种"无本地密钥→新生成"
/// 场景：
/// - 全新注册首次登录：[otherDeviceCount] == 0，无历史消息可恢复；
/// - 换设备/重装：[otherDeviceCount] > 0，需提示 E2EE 恢复。
@immutable
class E2EEReportResult {
  const E2EEReportResult({required this.ok, this.otherDeviceCount = 0});

  /// 上报是否成功（HTTP 业务成功）。
  final bool ok;

  /// 该用户除本设备外、已上报有效公钥的活跃设备数量。
  final int otherDeviceCount;

  /// 是否存在其他活跃设备（即"换设备/重装"场景）。
  bool get hasOtherDevice => otherDeviceCount > 0;
}

/// 校验 ok 响应的列表形 payload（如 devices/members）。
///
/// fail-closed：业务失败走 [IMBoyHttpResponse.throwIfFailed]；
/// 成功但形状不对（payload 非 Map、键缺失/非 List、元素非 Map）抛
/// [FormatException]，错误信息只含方法名与期望形状，不含 payload 内容。
List<Map<String, dynamic>> _listPayloadOrThrow(
  dynamic payload,
  String method,
  String key,
) {
  if (payload is! Map) {
    throw FormatException('E2EEApi.$method: 期望 payload 为含 $key 列表的 Map');
  }
  final rows = payload[key];
  if (rows is! List) {
    throw FormatException('E2EEApi.$method: 期望 payload.$key 为 List');
  }
  for (final row in rows) {
    if (row is! Map) {
      throw FormatException('E2EEApi.$method: 期望 payload.$key 元素均为 Map');
    }
  }
  return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

class E2EEApi extends HttpClient {
  /// 上报当前设备的 E2EE 公钥
  ///
  /// POST /api/v1/e2ee/report_device_key
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
  /// - [E2EEReportResult]：包含是否成功与 other_device_count，
  ///   供调用方区分"换设备"与"首次注册"。
  Future<E2EEReportResult> reportDeviceKey({
    required String deviceId,
    required String deviceType,
    String? deviceName,
    required String publicKey,
    required String keyId,
  }) async {
    final IMBoyHttpResponse resp = await post(
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
    if (!resp.ok) {
      return const E2EEReportResult(ok: false);
    }
    final payload = resp.payload;
    int otherDeviceCount = 0;
    if (payload is Map) {
      final raw = payload['other_device_count'];
      if (raw is int) {
        otherDeviceCount = raw;
      } else if (raw is num) {
        otherDeviceCount = raw.toInt();
      }
    }
    return E2EEReportResult(ok: true, otherDeviceCount: otherDeviceCount);
  }

  Future<List<Map<String, dynamic>>> userKeys({required String uid}) async {
    final IMBoyHttpResponse resp = await get(
      API.e2eeUserKeys,
      queryParameters: {'uid': uid},
    );
    resp.throwIfFailed();
    return _listPayloadOrThrow(resp.payload, 'userKeys', 'devices');
  }

  Future<List<Map<String, dynamic>>> groupMemberKeys({
    required String gid,
  }) async {
    final IMBoyHttpResponse resp = await get(
      API.e2eeGroupMemberKeys,
      queryParameters: {'gid': gid},
    );
    resp.throwIfFailed();
    return _listPayloadOrThrow(resp.payload, 'groupMemberKeys', 'members');
  }

  void debugLogUserKeys(List<Map<String, dynamic>> list) {
    if (kDebugMode) {}
  }

  /// 获取当前活跃的合规公钥
  ///
  /// 返回 {key_id, public_key} 或 null
  /// 用于 compliance_e2ee 模式的双密钥加密
  ///
  /// fail-closed：传输/业务失败抛错（后端"无活跃合规密钥"即业务失败）。
  /// ok 且 payload 为 null 视为契约中的"无密钥"空语义返回 null；
  /// ok 但 payload 非 Map 视为畸形成功响应抛 [FormatException]。
  Future<Map<String, dynamic>?> getComplianceKey() async {
    final IMBoyHttpResponse resp = await get(API.e2eeComplianceKey);
    resp.throwIfFailed();
    final p = resp.payload;
    if (p == null) return null;
    if (p is Map<String, dynamic>) return p;
    throw const FormatException(
      'E2EEApi.getComplianceKey: 期望 payload 为 Map 或 null',
    );
  }

  /// GET /api/v1/e2ee/key/status — 查询当前设备密钥的服务端注册状态
  ///
  /// 返回 {has_valid_key, recovery_options, recommended_method} 或 null
  ///
  /// fail-closed：传输/业务失败抛错；ok 且 payload 为 null 返回 null
  /// （调用方按"无法确认注册状态"处理）；ok 但 payload 非 Map 抛
  /// [FormatException]。
  Future<Map<String, dynamic>?> keyStatus() async {
    final IMBoyHttpResponse resp = await get(API.e2eeKeyStatus);
    resp.throwIfFailed();
    final p = resp.payload;
    if (p == null) return null;
    if (p is Map<String, dynamic>) return p;
    throw const FormatException('E2EEApi.keyStatus: 期望 payload 为 Map 或 null');
  }

  /// GET /api/v1/e2ee/notifications/pull — 拉取待处理的 E2EE 通知
  ///
  /// 支持增量拉取，返回好友的密钥变更记录
  ///
  /// fail-closed：传输/业务失败抛错；ok 但 payload 不是 List、也不是含
  /// notifications/list 列表的 Map 时抛 [FormatException]。
  /// 列表内非 Map 元素沿用既有防御行为过滤（见
  /// [IMBoyHttpResponse.payloadList] 的注释）。
  Future<List<Map<String, dynamic>>> pullNotifications({
    int since = 0,
    int limit = 50,
  }) async {
    final IMBoyHttpResponse resp = await get(
      API.e2eeNotificationsPull,
      queryParameters: {'since': since, 'limit': limit},
    );
    resp.throwIfFailed();
    final p = resp.payload;
    if (p is List) {
      return p.whereType<Map<String, dynamic>>().toList();
    }
    if (p is Map<String, dynamic>) {
      final list = p['notifications'] ?? p['list'];
      if (list is List) {
        return list.whereType<Map<String, dynamic>>().toList();
      }
    }
    throw const FormatException(
      'E2EEApi.pullNotifications: 期望 payload 为 List 或含 notifications 列表的 Map',
    );
  }
}
