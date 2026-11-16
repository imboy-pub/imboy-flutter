part of 'e2ee_service.dart';

/// 设备集合异常类别（AC-15）。
enum DeviceSetAnomalyKind {
  /// 幽灵设备：服务端 Olm 设备列表下发了本地 fan-out / 已批准集合中
  /// 不存在的未知设备。
  ghostDevice,

  /// 遗漏设备：本地已知（上次记录）的设备未出现在服务端下发的活跃集合中
  /// （可能被撤销/下线，也可能是服务端数据不一致）。
  missingDevice,

  /// 新设备：对端设备集合相对上次记录出现新增设备（聚合安全码将变化，
  /// 既有「已验证」状态失效，需要重新带外核验）。
  newDevice,
}

/// E2EE 设备集合异常事件（AC-15）。
///
/// 触发策略：**刷新 + 告警，不崩溃不静默**——
/// - 幽灵/遗漏/新增意味着服务端设备视图与本地信任视图不一致（可能被塞入、
///   移除设备，或对端合法增删设备），消费方应清密钥缓存强制刷新并提示
///   用户重验安全码；
/// - 事件只承载事实（设备 ID 集合），不携带任何密钥材料。
final class E2eeDeviceSetAnomalyEvent extends AppEvent {
  const E2eeDeviceSetAnomalyEvent({
    required this.peerUid,
    required this.kind,
    this.ghostDeviceIds = const {},
    this.missingDeviceIds = const {},
    this.newDeviceIds = const {},
  });

  /// 发生异常的对端用户 ID。
  final String peerUid;

  /// 异常类别。
  final DeviceSetAnomalyKind kind;

  /// 幽灵设备 ID 集合（kind == ghostDevice 时非空）。
  final Set<String> ghostDeviceIds;

  /// 遗漏设备 ID 集合（kind == missingDevice 时非空）。
  final Set<String> missingDeviceIds;

  /// 新增设备 ID 集合（kind == newDevice 时非空）。
  final Set<String> newDeviceIds;

  @override
  List<Object?> get props => [
    peerUid,
    kind,
    ghostDeviceIds,
    missingDeviceIds,
    newDeviceIds,
  ];

  @override
  String toString() =>
      'E2eeDeviceSetAnomalyEvent(peerUid: $peerUid, kind: $kind, '
      'ghost={${ghostDeviceIds.join(',')}}, '
      'missing={${missingDeviceIds.join(',')}}, '
      'new={${newDeviceIds.join(',')}})';
}

/// 本地安全码信任标记失效事件（AC-15）。
///
/// 对端身份换钥（S2C `e2ee_key_changed`，C01 identity_version 推进）或
/// 信任撤销（`e2ee_trust_changed` → revoked/unverified）时，本地
/// 「已验证」标记必须同步失效——静默沿用旧验证等于放行换钥后的 MITM。
final class SafetyNumberTrustInvalidatedEvent extends AppEvent {
  const SafetyNumberTrustInvalidatedEvent({
    required this.peerUid,
    required this.reason,
  });

  /// 信任被失效的对端用户 ID。
  final String peerUid;

  /// 失效原因（peer_key_changed / trust_revoked / …），仅用于日志与 UI 提示。
  final String reason;

  @override
  List<Object?> get props => [peerUid, reason];

  @override
  String toString() =>
      'SafetyNumberTrustInvalidatedEvent(peerUid: $peerUid, reason: $reason)';
}

/// 解密失败发生率度量 —— 「[加密消息] 占位发生率压到一辈子遇不到」的验证仪表。
///
/// 两个互补口径（存量口径见 `E2EEHealthCheckService.failureInventory()`）：
/// - **累计发生**（本类，只增不减）：占位产生即按 reason 分桶计数并持久化，
///   反映「这台设备的用户到底遇到过几次」；
/// - **存量盘点**（健康检查服务）：DB 内现存占位行扫描，被自愈恢复
///   （路径4 retryFailedMessages）消化后会下降。
///
/// 计数点只有两类：
/// - message.dart 落库漏斗：占位行即将持久化（唯一持久化事件点）；
/// - mapper toTypeMessage 读时解密失败：密文行每次渲染都会重试，传 dedupKey
///   做本次启动内去重，避免逐帧渲染造成的计数膨胀。
///
/// 幂等重投（duplicate_message / already_processed）不落占位故不计数；
/// 服务端 ACK 前重投的极端序列可能对同一行重复计数，对趋势判断无影响。
class E2EEDecryptFailureMetrics {
  E2EEDecryptFailureMetrics._();

  static const _storeKey = 'e2ee_decrypt_fail_metrics';

  /// 本次启动内去重（读时解密失败按「reason×行」计一次）
  static final Set<String> _seenDedupKeys = {};

  /// 归一化失败原因：只允许有限分类，避免持久化不可信内容
  static String normalizeReason(Object? reason) {
    return normalizeDecryptFailureReason(reason);
  }

  /// 记一次占位产生（fire-and-forget：度量绝不阻塞消息主链路）。
  ///
  /// [dedupKey] 提供时同一 key 本次启动只计一次（读时解密场景传 `'r:<msgId>'`）。
  static void count(Object? reason, {String? dedupKey}) {
    unawaited(_bump(reason, dedupKey: dedupKey));
  }

  /// [count] 的可等待版：测试确定性用，生产调用方请用 [count]。
  static Future<void> countAwait(Object? reason, {String? dedupKey}) =>
      _bump(reason, dedupKey: dedupKey);

  static Future<void> _bump(Object? reason, {String? dedupKey}) async {
    try {
      final key = normalizeReason(reason);
      if (dedupKey != null && !_seenDedupKeys.add('$key|$dedupKey')) {
        return;
      }
      final m = _normalizedSnapshot();
      m[key] = (m[key] ?? 0) + 1;
      await StorageService.setMap(_storeKey, m);
      iPrint('📊 [E2EE_METRICS] decrypt failure: $key total=${m[key]}');
    } catch (_) {
      // 度量失败静默：不影响消息主链路
    }
  }

  /// 累计计数快照（reason → 次数）
  static Future<Map<String, int>> snapshot() async => _normalizedSnapshot();

  static Map<String, int> _normalizedSnapshot() {
    try {
      final m = StorageService.getMap(_storeKey);
      final result = <String, int>{};
      for (final entry in m.entries) {
        final key = normalizeReason(entry.key);
        final value = entry.value;
        final count = value is int ? value : int.tryParse('$value') ?? 0;
        result[key] = (result[key] ?? 0) + count;
      }
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  /// 清零（仅测试用）
  static Future<void> resetForTest() async {
    _seenDedupKeys.clear();
    await StorageService.setMap(_storeKey, <String, dynamic>{});
  }
}
