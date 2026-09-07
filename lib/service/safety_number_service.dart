/// Safety Number（安全码）计算服务（审计 P1-2 接线 + 多设备聚合）。
///
/// 把 [SafetyNumber]（Signal FingerprintProtocol v2 兼容，纯函数）接进产品：
/// - 双方设备集合取 [OlmApi.listDevices] 返回的全部活跃 Olm 设备；
/// - 本端当前设备 identity 取 [OlmSessionService.localCurve25519Identity]；
/// - 其余 identity 均走 [OlmSessionService.peerCurve25519Identity] 的签名校验与 TOFU；
/// - 双方全部设备 identity key 参与聚合计算（Signal 跨设备指纹语义）：
///   任一新设备加入/移除，聚合码都会变化。
library;

import 'package:flutter/foundation.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/e2ee/safety_number.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

typedef SafetyDeviceListLoader =
    Future<List<Map<String, dynamic>>> Function(String uid);
typedef SafetyIdentityLoader =
    Future<String> Function(String uid, String deviceId);

/// 安全码计算结果。
class SafetyNumberResult {
  /// 60 位安全码（12 组 × 5 位）。
  final String number;

  /// 本端参与聚合的设备数量。
  final int localDeviceCount;

  /// 对端参与聚合的设备数量。
  final int remoteDeviceCount;

  /// 首个远程设备 ID（用于 trust/record 上报，阶段 B 扩展点）。
  final String remoteDeviceId;

  const SafetyNumberResult({
    required this.number,
    required this.localDeviceCount,
    required this.remoteDeviceCount,
    required this.remoteDeviceId,
  });
}

/// Safety Number 计算服务。
class SafetyNumberService {
  SafetyNumberService._();

  /// 本地“已验证”状态必须绑定当前安全码。
  ///
  /// 旧版本只存时间戳，设备增删或 identity 变化后仍显示已验证。严格比较让旧值
  /// 自动失效，并确保聚合码任何变化都会要求用户重新带外核验。
  static bool isCurrentNumberVerified(String? stored, String current) =>
      stored != null && stored == current;

  /// 计算本端与 [peerUid] 之间的多设备聚合安全码。
  ///
  /// 双方全部已注册设备均参与计算。返回值包含设备数量，供 UI 展示。
  ///
  /// 抛错语义：
  /// - 对端无任何设备 / 设备无 Olm identity → [ArgumentError]（页面提示"对方
  ///   尚未启用端到端加密"）；
  /// - 对端 identity 签名校验失败 / TOFU 失配 → [OlmAuthenticationException]
  ///   （与建会话同款 fail-closed，页面提示"对方身份密钥已变更"）。
  static Future<SafetyNumberResult> generateForPeer({
    required String peerUid,
    @visibleForTesting String? localUidOverride,
    @visibleForTesting String? localDeviceIdOverride,
    @visibleForTesting SafetyDeviceListLoader? deviceListLoader,
    @visibleForTesting Future<String> Function()? localIdentityLoader,
    @visibleForTesting SafetyIdentityLoader? verifiedIdentityLoader,
  }) async {
    final localUid = localUidOverride ?? UserRepoLocal.to.currentUid.toString();
    final localDid = localDeviceIdOverride ?? deviceId;
    if (localUid.isEmpty || localDid.isEmpty || peerUid.isEmpty) {
      throw ArgumentError('uid_and_device_id_required');
    }

    final listDevices =
        deviceListLoader ?? (uid) => OlmApi().listDevices(uid: uid);
    final identityFor =
        verifiedIdentityLoader ??
        (uid, did) => OlmSessionService.to.peerCurve25519Identity(uid, did);
    final localIdentity =
        localIdentityLoader ?? OlmSessionService.to.localCurve25519Identity;

    final lists = await Future.wait([
      listDevices(localUid),
      listDevices(peerUid),
    ]);
    final localDeviceIds = _activeDeviceIds(lists[0]);
    final remoteDeviceIds = _activeDeviceIds(lists[1]);
    if (!localDeviceIds.contains(localDid)) {
      throw ArgumentError('local_device_not_registered');
    }
    if (remoteDeviceIds.isEmpty) {
      throw ArgumentError('no_recipient_devices');
    }

    final localDevices = await Future.wait([
      for (final did in localDeviceIds)
        _deviceIdentity(
          uid: localUid,
          did: did,
          identityLoader: did == localDid
              ? (_, _) => localIdentity()
              : identityFor,
        ),
    ]);
    final remoteDevices = await Future.wait([
      for (final did in remoteDeviceIds)
        _deviceIdentity(uid: peerUid, did: did, identityLoader: identityFor),
    ]);

    final number = SafetyNumber.generateAggregate(
      localUid: localUid,
      localDevices: localDevices,
      remoteUid: peerUid,
      remoteDevices: remoteDevices,
    );
    return SafetyNumberResult(
      number: number,
      localDeviceCount: localDevices.length,
      remoteDeviceCount: remoteDevices.length,
      remoteDeviceId: remoteDevices.first.deviceId,
    );
  }

  static List<String> _activeDeviceIds(List<Map<String, dynamic>> devices) {
    final ids = devices
        .map((row) => row['device_id']?.toString() ?? '')
        .where((did) => did.isNotEmpty)
        .toSet()
        .toList();
    ids.sort();
    return ids;
  }

  static Future<DeviceIdentity> _deviceIdentity({
    required String uid,
    required String did,
    required SafetyIdentityLoader identityLoader,
  }) async {
    return DeviceIdentity(
      deviceId: did,
      identityPub: await identityLoader(uid, did),
    );
  }
}
