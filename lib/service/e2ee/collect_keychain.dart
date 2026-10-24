/// E2EE 收藏密钥链（PLAN 2026-10-24-e2ee-collect §6，v7.1）
///
/// 每用户 CK 版本链 CKv1/v2…（256-bit，服务端永不持有）+ §6.5 轮换状态机。
///
/// ## 状态机（持久化于密钥链元数据，中断可恢复）
/// ```
/// NORMAL(vN) → ROTATING（生成 CKv(N+1)，即刻停止用 vN seal——旧版本写入门槛）
///   → REWRAP_RUNNING（分页遍历重封；每条 CAS，冲突重读重封）
///   → REWRAP_VERIFY（全量复扫断言 0 条 vN；发现掉队行回 RUNNING）
///   → PEERS_CONFIRMED（其余确认设备均 ACK）
///   → CLEAR_vN（四前置缺一不可）
/// ```
///
/// ## fail-closed
/// ROTATING..PEERS_CONFIRMED 期间一律拒绝新 seal（[sealAllowed] false），
/// 防止轮换中继续产出旧版本密文；清除 vN 需 §6.5(a)-(d) 全部成立。
///
/// 存储复用 StorageSecureService（iOS Keychain / Android EncryptedSharedPreferences），
/// 本模块不做 IO 之外的任何事；密钥字节仅以 base64 形式出入存储。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:imboy/service/storage_secure.dart' show StorageSecureService;

/// 轮换状态机状态（PLAN §6.5）。
enum CollectRotationPhase {
  normal,
  rotating,
  rewrapRunning,
  rewrapVerify,
  peersConfirmed,
}

/// 单个 CK 版本。
class CollectKeyVersion {
  const CollectKeyVersion({required this.version, required this.ckB64});

  final int version;

  /// 32 字节 CK 的 base64。
  final String ckB64;

  Map<String, dynamic> toJson() => {'v': version, 'ck': ckB64};

  static CollectKeyVersion fromJson(Map<String, dynamic> j) =>
      CollectKeyVersion(version: j['v'] as int, ckB64: j['ck'] as String);
}

/// 密钥链持久化状态。
class CollectKeychainState {
  const CollectKeychainState({
    required this.keys,
    this.phase = CollectRotationPhase.normal,
    this.peerAckedVersions = const {},
  });

  /// 版本链（升序）；CLEAR 后旧版本被移除（保留无害，清除是优化）。
  final List<CollectKeyVersion> keys;

  final CollectRotationPhase phase;

  /// 其余确认设备已 ACK 切换完成的版本（§6.5(c) 的记账）。
  final Map<int, bool> peerAckedVersions;

  int get activeVersion => keys.isEmpty ? 0 : keys.last.version;

  CollectKeyVersion? get activeKey => keys.isEmpty ? null : keys.last;

  CollectKeychainState copyWith({
    List<CollectKeyVersion>? keys,
    CollectRotationPhase? phase,
    Map<int, bool>? peerAckedVersions,
  }) => CollectKeychainState(
    keys: keys ?? this.keys,
    phase: phase ?? this.phase,
    peerAckedVersions: peerAckedVersions ?? this.peerAckedVersions,
  );

  Map<String, dynamic> toJson() => {
    'keys': keys.map((k) => k.toJson()).toList(),
    'phase': phase.name,
    'acks': peerAckedVersions.map((k, v) => MapEntry(k.toString(), v)),
  };

  static CollectKeychainState fromJson(Map<String, dynamic> j) {
    final keys =
        (j['keys'] as List? ?? [])
            .map(
              (e) => CollectKeyVersion.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.version.compareTo(b.version));
    return CollectKeychainState(
      keys: keys,
      phase: CollectRotationPhase.values.firstWhere(
        (p) => p.name == (j['phase'] as String?),
        orElse: () => CollectRotationPhase.normal,
      ),
      peerAckedVersions: (j['acks'] as Map? ?? {}).map(
        (k, v) => MapEntry(int.parse(k.toString()), v == true),
      ),
    );
  }
}

/// §6.5 清除旧版本的四前置（缺一不可）。
class ClearEligibility {
  const ClearEligibility({
    required this.verifyPassed,
    required this.replicatedElsewhere,
    required this.allPeersAcked,
    required this.serverGateProven,
  });

  /// (a) REWRAP_VERIFY 通过：全量复扫 0 条 vN 记录。
  final bool verifyPassed;

  /// (b) CKv(N+1) 已持久化于本设备且至少一台其他确认设备回报已持久化。
  final bool replicatedElsewhere;

  /// (c) 全部确认设备 ACK 切换完成。
  final bool allPeersAcked;

  /// (d) 服务端 key_version 高水位门已验证生效（F4）。
  final bool serverGateProven;

  bool get eligible =>
      verifyPassed && replicatedElsewhere && allPeersAcked && serverGateProven;
}

/// 纯逻辑状态机（可测；存储由 [CollectKeychain] 包装）。
class CollectKeychainLogic {
  /// 写入门槛：仅 NORMAL 允许新 seal（旧版本密文停产）。
  static bool sealAllowed(CollectKeychainState s) =>
      s.phase == CollectRotationPhase.normal && s.keys.isNotEmpty;

  /// 首次生成 CKv1（CSPRNG 32 字节）。
  static CollectKeychainState bootstrap() => CollectKeychainState(
    keys: [CollectKeyVersion(version: 1, ckB64: _randomCk())],
  );

  /// 开始轮换：生成 CKv(N+1) 并进入 ROTATING（立即停产 vN seal）。
  static CollectKeychainState beginRotation(CollectKeychainState s) {
    if (s.keys.isEmpty) {
      throw StateError('keychain empty');
    }
    if (s.phase != CollectRotationPhase.normal) {
      throw StateError('rotation already in progress: ${s.phase.name}');
    }
    return s
        .copyWith(
          keys: [
            ...s.keys,
            CollectKeyVersion(version: s.activeVersion + 1, ckB64: _randomCk()),
          ],
        )
        .copyWith(phase: CollectRotationPhase.rewrapRunning);
  }

  /// REWRAP_RUNNING → REWRAP_VERIFY（分页重封完成；0 条掉队由调用方断言）。
  static CollectKeychainState beginVerify(CollectKeychainState s) {
    _require(s, CollectRotationPhase.rewrapRunning);
    return s.copyWith(phase: CollectRotationPhase.rewrapVerify);
  }

  /// VERIFY 发现掉队 vN 行 → 回 RUNNING 继续重封。
  static CollectKeychainState backToRunning(CollectKeychainState s) {
    _require(s, CollectRotationPhase.rewrapVerify);
    return s.copyWith(phase: CollectRotationPhase.rewrapRunning);
  }

  /// VERIFY 通过 + 全部确认设备 ACK → PEERS_CONFIRMED。
  static CollectKeychainState peersConfirmed(CollectKeychainState s) {
    _require(s, CollectRotationPhase.rewrapVerify);
    return s.copyWith(phase: CollectRotationPhase.peersConfirmed);
  }

  /// 记账某设备对版本的 ACK（§6.5(c)；ACK 仅代表收讫，不构成授权）。
  static CollectKeychainState markPeerAck(
    CollectKeychainState s,
    int version,
    bool acked,
  ) => s.copyWith(peerAckedVersions: {...s.peerAckedVersions, version: acked});

  /// 清除旧版本（PEERS_CONFIRMED + 四前置全成立；未满足则原样保留）。
  static CollectKeychainState clearOldVersion(
    CollectKeychainState s,
    int version,
    ClearEligibility e,
  ) {
    if (s.phase != CollectRotationPhase.peersConfirmed || !e.eligible) {
      return s;
    }
    if (version >= s.activeVersion) {
      throw StateError('refuse to clear active version');
    }
    return s.copyWith(keys: s.keys.where((k) => k.version != version).toList());
  }

  static void _require(CollectKeychainState s, CollectRotationPhase p) {
    if (s.phase != p) {
      throw StateError('expected $p, got ${s.phase.name}');
    }
  }

  static String _randomCk() {
    final rng = Random.secure();
    return base64.encode(
      Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
    );
  }
}

/// 存储包装：单例读写 StorageSecureService（key: collect_ck_keychain_v1）。
///
/// 键落在 C05 秘密清单 `collect_ck_` 前缀下：logout/换号由
/// E2eeSecretInventory.purgeAll 清理持久键并经 [clearCache] 清内存副本
///（CK 为账号级秘密，缺任一步都会让下一账号读到前一账号的密钥链）。
/// 重新登录后本设备无 CK，须经 §6.2 跨设备同步取回。
class CollectKeychain {
  CollectKeychain._();
  static final CollectKeychain to = CollectKeychain._();

  static const String _kCollectKeychainStorageKey =
      'collect_ck_keychain_v1'; // gitleaks:allow

  CollectKeychainState? _cached;

  /// 读取（缓存）；空链时返回空状态（不自动 bootstrap——bootstrap 显式调用）。
  Future<CollectKeychainState> load() async {
    if (_cached != null) return _cached!;
    final raw = await StorageSecureService.to.read(
      key: _kCollectKeychainStorageKey,
    );
    if (raw == null || raw.isEmpty) {
      return const CollectKeychainState(keys: []);
    }
    _cached = CollectKeychainState.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    return _cached!;
  }

  Future<void> save(CollectKeychainState s) async {
    _cached = s;
    await StorageSecureService.to.write(
      key: _kCollectKeychainStorageKey,
      value: jsonEncode(s.toJson()),
    );
  }

  /// 丢弃内存副本（logout/换号 purge 接线；持久键由清单前缀清理）。
  void clearCache() => _cached = null;

  /// 确保存在首版本（首次使用收藏加密时调用）。
  Future<CollectKeychainState> ensureBootstrap() async {
    final s = await load();
    if (s.keys.isNotEmpty) return s;
    final bootstrapped = CollectKeychainLogic.bootstrap();
    await save(bootstrapped);
    return bootstrapped;
  }

  /// 当前可 seal 的 CK；轮换中返回 null（写入门槛）。
  Future<CollectKeyVersion?> sealableKey() async {
    final s = await load();
    return CollectKeychainLogic.sealAllowed(s) ? s.activeKey : null;
  }
}
