/// Safety Number（安全码）计算服务（审计 P1-2 接线 + 多设备聚合）。
///
/// 把 [SafetyNumber]（Signal FingerprintProtocol v2 兼容，纯函数）接进产品：
/// - 双方设备集合取 [OlmApi.listDevices] 返回的全部活跃 Olm 设备；
/// - 本端当前设备 identity 取 [OlmSessionService.localCurve25519Identity]；
/// - 其余 identity 均走 [OlmSessionService.peerCurve25519Identity] 的签名校验与 TOFU；
/// - 双方全部设备 identity key 参与聚合计算（Signal 跨设备指纹语义）：
///   任一新设备加入/移除，聚合码都会变化。
library;

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/e2ee/safety_number.dart';
import 'package:imboy/service/e2ee_service.dart'
    show
        E2EEService,
        E2eeDeviceSetAnomalyEvent,
        DeviceSetAnomalyKind,
        SafetyNumberTrustInvalidatedEvent;
import 'package:imboy/service/events/events.dart' show AppEventBus;
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

typedef SafetyDeviceListLoader = Future<List<Map<String, dynamic>>> Function(
  String uid,
);
typedef SafetyIdentityLoader = Future<String> Function(
  String uid,
  String deviceId,
);

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

  /// 对端参与聚合的**全部**设备 ID（排序后）。
  ///
  /// AC-15：markVerified 时把它记为批准集合——此后集合外的新设备
  /// 不沿用旧批准。
  final List<String> remoteDeviceIds;

  const SafetyNumberResult({
    required this.number,
    required this.localDeviceCount,
    required this.remoteDeviceCount,
    required this.remoteDeviceId,
    required this.remoteDeviceIds,
  });
}

/// Safety Number 计算服务。
class SafetyIdentitySnapshot {
  const SafetyIdentitySnapshot(
    this.account,
    this.generation,
    this.peerUid,
    this.revision,
  );
  final String account;
  final int generation;
  final String peerUid;
  final int revision;
}

class SafetyNumberService {
  SafetyNumberService._();

  static final Map<String, int> _revisions = {};
  static final Map<String, Future<void>> _writes = {};

  static String _scope(String account, String peerUid) => '$account:$peerUid';
  static String _key(String prefix, String account, String peerUid) =>
      '$prefix${_scope(account, peerUid)}';

  static SafetyIdentitySnapshot snapshot(String peerUid) {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    if (account.isEmpty || user.isAuthTransitioning) {
      throw StateError('safety number requires a stable session');
    }
    return SafetyIdentitySnapshot(
      account,
      user.sessionGeneration,
      peerUid,
      _revisions[_scope(account, peerUid)] ?? 0,
    );
  }

  static bool isCurrent(SafetyIdentitySnapshot state) {
    return isSameSession(state) &&
        (_revisions[_scope(state.account, state.peerUid)] ?? 0) ==
            state.revision;
  }

  static bool isSameSession(SafetyIdentitySnapshot state) {
    final user = UserRepoLocal.to;
    return !user.isAuthTransitioning &&
        user.currentUid == state.account &&
        user.sessionGeneration == state.generation;
  }

  static Future<T> _serialize<T>(String scope, Future<T> Function() action) {
    final previous = _writes[scope] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final barrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    _writes[scope] = barrier;
    unawaited(
      barrier.whenComplete(() {
        if (identical(_writes[scope], barrier)) _writes.remove(scope);
      }),
    );
    return result;
  }

  /// 「已验证」标记存储键前缀（值 = 绑定的 60 位聚合码）。
  static const String _verifiedKeyPrefix = 'safety_number_verified_';

  /// 用户批准的对端设备集合存储键前缀（值 = 排序 JSON 数组）。
  ///
  /// 语义：用户比对聚合码一致（或显式确认）时，把**当时参与聚合的对端全部
  /// 设备**记为已批准集合。此后集合外的对端新设备不沿用旧批准——
  /// 它们的加入会改变聚合码，使 [_verifiedKeyPrefix] 的严格相等失效，
  /// 必须重新带外核验（AC-15「新设备经确认才建立信任」）。
  static const String _approvedDevsetKeyPrefix = 'safety_number_devset_';

  /// 设备集合漂移检测基线存储键前缀（每次成功计算后更新）。
  ///
  /// 与 [_approvedDevsetKeyPrefix] 分离：基线是**观察事实**（服务端上次下发了
  /// 什么），批准集合是**信任决定**（用户验证过什么）。信任决定不得被
  /// 观察动作静默改写。
  static const String _devsetBaselineKeyPrefix =
      'safety_number_devset_baseline_';

  /// 本地“已验证”状态必须绑定当前安全码。
  ///
  /// 旧版本只存时间戳，设备增删或 identity 变化后仍显示已验证。严格比较让旧值
  /// 自动失效，并确保聚合码任何变化都会要求用户重新带外核验。
  static bool isCurrentNumberVerified(String? stored, String current) =>
      stored != null && stored == current;

  /// 读取本地已验证的聚合码（无标记返回 null）。
  static Future<String?> localVerifiedNumber(String peerUid) async {
    final state = snapshot(peerUid);
    final raw = await StorageSecureService.to.read(
      key: _key(_verifiedKeyPrefix, state.account, peerUid),
    );
    if (!isCurrent(state)) throw StateError('safety number session changed');
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// 标记「已验证」：绑定当前聚合码，并记录批准的对端设备集合。
  ///
  /// 调用时机：用户带外比对聚合码一致（trust/record 上报成功）或显式
  /// TOFU 确认。此后任何对端设备增删/换钥都会改变聚合码，使该标记
  /// 自动失效（[isCurrentNumberVerified]）。
  static Future<void> markVerified({
    required String peerUid,
    required String number,
    required Set<String> approvedRemoteDeviceIds,
    SafetyIdentitySnapshot? identity,
  }) async {
    final state = identity ?? snapshot(peerUid);
    if (state.peerUid != peerUid) {
      throw StateError('safety number peer changed');
    }
    await _serialize(_scope(state.account, peerUid), () async {
      if (!isCurrent(state)) throw StateError('safety number identity changed');
      await _writeApprovedDevset(
        state.account,
        peerUid,
        approvedRemoteDeviceIds,
      );
      if (!isCurrent(state)) {
        await StorageSecureService.to.delete(
          key: _key(_approvedDevsetKeyPrefix, state.account, peerUid),
        );
        throw StateError('safety number identity changed');
      }
      await StorageSecureService.to.write(
        key: _key(_verifiedKeyPrefix, state.account, peerUid),
        value: number,
      );
      if (!isCurrent(state)) {
        await StorageSecureService.to.delete(
          key: _key(_verifiedKeyPrefix, state.account, peerUid),
        );
        await StorageSecureService.to.delete(
          key: _key(_approvedDevsetKeyPrefix, state.account, peerUid),
        );
        throw StateError('safety number identity changed');
      }
    });
  }

  /// 读取已批准的对端设备集合（未验证过返回空集）。
  static Future<Set<String>> approvedRemoteDeviceIds(String peerUid) async {
    final state = snapshot(peerUid);
    final raw = await StorageSecureService.to.read(
      key: _key(_approvedDevsetKeyPrefix, state.account, peerUid),
    );
    if (!isCurrent(state)) throw StateError('safety number session changed');
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>{};
      return decoded.map((e) => e.toString()).toSet();
    } on FormatException {
      return const <String>{};
    }
  }

  /// 使本地信任标记失效（AC-15：换钥/撤销 → 需重验，非静默沿用）。
  ///
  /// 清除聚合码绑定与批准设备集合，并广播 [SafetyNumberTrustInvalidatedEvent]
  /// （UI 提示「对方身份已变化，请重新验证安全码」）。
  ///
  /// 返回是否确实清除了已存在的信任（从未验证过 → false，幂等无事件）。
  static Future<bool> invalidateTrust(
    String peerUid,
    String reason, {
    SafetyIdentitySnapshot? identity,
  }) async {
    final state = identity ?? snapshot(peerUid);
    if (state.peerUid != peerUid || !isCurrent(state)) {
      throw StateError('safety number identity changed');
    }
    final scope = _scope(state.account, peerUid);
    _revisions[scope] = state.revision + 1;
    return _serialize(scope, () async {
      final stored = await StorageSecureService.to.read(
        key: _key(_verifiedKeyPrefix, state.account, peerUid),
      );
      final approved = await StorageSecureService.to.read(
        key: _key(_approvedDevsetKeyPrefix, state.account, peerUid),
      );
      if (stored == null && (approved == null || approved.isEmpty)) {
        return false;
      }
      await StorageSecureService.to.delete(
        key: _key(_verifiedKeyPrefix, state.account, peerUid),
      );
      await StorageSecureService.to.delete(
        key: _key(_approvedDevsetKeyPrefix, state.account, peerUid),
      );
      if (!isSameSession(state)) {
        throw StateError('session changed during trust invalidation');
      }
      iPrint(
        '[SafetyNumber][AC-15] trust invalidated: peer=$peerUid reason=$reason',
      );
      AppEventBus.fire(
        SafetyNumberTrustInvalidatedEvent(peerUid: peerUid, reason: reason),
      );
      return true;
    });
  }

  static Future<void> _writeApprovedDevset(
    String account,
    String peerUid,
    Set<String> deviceIds,
  ) async {
    final sorted = deviceIds.toList()..sort();
    await StorageSecureService.to.write(
      key: _key(_approvedDevsetKeyPrefix, account, peerUid),
      value: jsonEncode(sorted),
    );
  }

  /// 设备集合漂移检测（AC-15）：对比服务端本次下发的对端设备集合与
  /// 上次观察基线，变化即广播告警事件并刷新密钥缓存。
  ///
  /// 策略：**刷新 + 告警，不崩溃不静默**——
  /// - 新设备（服务端下发本地基线没有）→ newDevice 事件；
  /// - 遗漏设备（基线有、下发没有）→ missingDevice 事件；
  /// - 首次观察（无基线）只记基线，不告警。
  ///
  /// 检测失败（存储读不了等）不阻断安全码计算——安全码本身仍由
  /// 聚合算法保证绑定当前全设备集合，检测只是额外的显式信号。
  static Future<void> _checkDeviceSetDrift(
    String peerUid,
    List<String> currentRemoteDeviceIds,
    SafetyIdentitySnapshot identity,
  ) async {
    try {
      if (!isCurrent(identity)) return;
      final baselineKey = _key(
        _devsetBaselineKeyPrefix,
        identity.account,
        peerUid,
      );
      final raw = await StorageSecureService.to.read(key: baselineKey);
      final current = currentRemoteDeviceIds.toSet();
      if (raw == null || raw.isEmpty) {
        await StorageSecureService.to.write(
          key: baselineKey,
          value: jsonEncode(current.toList()..sort()),
        );
        return;
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>? ?? [];
      final baseline = decoded.map((e) => e.toString()).toSet();

      final added = current.difference(baseline);
      final removed = baseline.difference(current);
      if (added.isEmpty && removed.isEmpty) return;

      // 更新基线（下次以本次为基准）
      await StorageSecureService.to.write(
        key: baselineKey,
        value: jsonEncode(current.toList()..sort()),
      );
      // 刷新：设备集合变了，缓存的设备公钥不可再信
      E2EEService.clearUserKeyCache(peerUid);

      if (added.isNotEmpty) {
        iPrint(
          '[SafetyNumber][AC-15] new remote devices: peer=$peerUid '
          'added={${added.join(',')}}',
        );
        AppEventBus.fire(
          E2eeDeviceSetAnomalyEvent(
            peerUid: peerUid,
            kind: DeviceSetAnomalyKind.newDevice,
            newDeviceIds: added,
          ),
        );
      }
      if (removed.isNotEmpty) {
        iPrint(
          '[SafetyNumber][AC-15] missing remote devices: peer=$peerUid '
          'removed={${removed.join(',')}}',
        );
        AppEventBus.fire(
          E2eeDeviceSetAnomalyEvent(
            peerUid: peerUid,
            kind: DeviceSetAnomalyKind.missingDevice,
            missingDeviceIds: removed,
          ),
        );
      }
    } on Object catch (e) {
      // 检测是增强信号，不阻断主流程；错误只记类型（Finding 014）
      iPrint(
        '[SafetyNumber][AC-15] device set drift check failed '
        '(errType=${e.runtimeType})',
      );
    }
  }

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
    final identity = snapshot(peerUid);
    final localUid = localUidOverride ?? UserRepoLocal.to.currentUid.toString();
    if (localUid != identity.account) {
      throw StateError('safety number session changed');
    }
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

    // AC-15：安全码绑定完整设备集合的配套信号——对端设备集合相对上次
    // 观察出现增删时广播告警 + 刷新密钥缓存（不崩溃不静默）。
    // 聚合码本身已由严格相等保证旧验证失效；这里补的是显式用户可见信号。
    if (!isCurrent(identity)) {
      throw StateError('safety number identity changed');
    }
    await _checkDeviceSetDrift(peerUid, remoteDeviceIds, identity);
    if (!isCurrent(identity)) {
      throw StateError('safety number identity changed');
    }

    return SafetyNumberResult(
      number: number,
      localDeviceCount: localDevices.length,
      remoteDeviceCount: remoteDevices.length,
      remoteDeviceId: remoteDevices.first.deviceId,
      remoteDeviceIds: List.unmodifiable(remoteDeviceIds),
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
