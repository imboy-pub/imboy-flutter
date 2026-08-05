/// E2EE 协议抽象层（ADR 02 — Protocol Registry，接口签名冻结）。
///
/// 业务层（`E2EEService`、chat 发送/接收）只通过 [E2eeSessionProtocol] 接口与
/// [E2eeProtocolRegistry] 对话，不 import 任何具体协议实现类（`OlmProtocol` /
/// `MegolmProtocol` / `RsaLegacyProtocol` / 未来 `MlsProtocol`）。
///
/// 冻结项（ADR 02 §10，变更须走 01-overview §5 supersedes 流程）：
/// - [E2eeSessionProtocol] 接口签名；
/// - [ProtocolSuite] 三元组结构；
/// - [ProtocolSuite.fromMetadata] legacy 字符串兼容矩阵（§3.2）；
/// - [E2eeProtocolRegistry] register/resolve/all 签名。
library;

/// 协议套件标识。等价于 `(protocol, version, cipher)` 三元组（ADR 02 §3.1）。
class ProtocolSuite {
  const ProtocolSuite(this.protocol, this.version, this.cipher);

  /// 协议族：`olm` / `megolm` / `rsa-oaep` / `mls`（小写，注册表 key）。
  final String protocol;

  /// 协议实现版本号；Olm/Megolm 当前为 1。防 T9（rollback）需配合 ADR 03 device
  /// identity version + ADR 05 message counter 一起构成单调度，单独不足以抗回滚。
  final int version;

  /// 底层算法，如 `curve25519+ed25519+aes-256-gcm` / `rsa-oaep-256+aes-256-gcm`。
  final String cipher;

  /// 序列化为 wire string。格式：`PROTOCOL.VERSION`（如 `OLM.1`）。
  String get wire => '${protocol.toUpperCase()}.$version';

  /// 双写兼容旧客户端的 v1 `e2ee_suite` 字符串，与 [fromMetadata] 的 legacy
  /// case 互逆（olm→`OLM.V1` 等）。
  ///
  /// 注：ADR 02 §7.2 双写声称 `e2ee_suite: suite.wire` 兼容 v1，但 [wire] 产出
  /// `OLM.1`（无 `V`），旧客户端 `decryptE2EEMessage` 按 `OLM.V1` 字面比对将不匹配
  /// → 走 RSA 兜底解密失败。故双写必须用本 getter 而非 [wire]，满足 ADR 02 §7.1
  /// 向后兼容硬约束。wire 保留不变（冻结）。
  String get legacyWire {
    switch (protocol) {
      case 'olm':
        return 'OLM.V1';
      case 'megolm':
        return 'MEGOLM.V1';
      case 'rsa-oaep':
        return 'RSA-OAEP-256+AES-256-GCM';
      default:
        return wire;
    }
  }

  static const olm = ProtocolSuite('olm', 1, 'curve25519+ed25519+aes-256-gcm');
  static const megolm = ProtocolSuite(
    'megolm',
    1,
    'curve25519+ed25519+aes-256-gcm',
  );
  static const rsa = ProtocolSuite('rsa-oaep', 1, 'rsa-oaep-256+aes-256-gcm');

  /// MLS 占位（ADR 02 §8）。`version=0` 表示未发布，不 register，不参与协商。
  static const mls = ProtocolSuite('mls', 0, 'reserved');

  static String _cipherFor(String proto) {
    switch (proto) {
      case 'olm':
        return olm.cipher;
      case 'megolm':
        return megolm.cipher;
      case 'rsa-oaep':
        return rsa.cipher;
      case 'mls':
        return mls.cipher;
      default:
        return 'unknown';
    }
  }

  /// 从消息 e2ee metadata 解析套件（ADR 02 §3.2，兼容矩阵冻结）。
  ///
  /// 优先读 v2 三元组（`protocol` / `version`）；回退到 v1 `e2ee_suite` 字符串。
  /// 历史 3 种字符串（`OLM.V1` / `MEGOLM.V1` / `RSA-OAEP-256+AES-256-GCM`）
  /// 必须能解析（ADR 01 §6 验收标准 1 硬约束）。未知抛 [FormatException]。
  static ProtocolSuite fromMetadata(Map<String, dynamic> m) {
    final proto = m['protocol']?.toString().toLowerCase();
    if (proto != null && proto.isNotEmpty) {
      final version = int.tryParse(m['version']?.toString() ?? '') ?? 1;
      return ProtocolSuite(proto, version, _cipherFor(proto));
    }
    final legacy = m['e2ee_suite']?.toString() ?? '';
    switch (legacy) {
      case 'OLM.V1':
        return ProtocolSuite.olm;
      case 'MEGOLM.V1':
        return ProtocolSuite.megolm;
      case 'RSA-OAEP-256+AES-256-GCM':
        return ProtocolSuite.rsa;
      default:
        throw FormatException('unknown e2ee_suite: $legacy');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ProtocolSuite &&
      other.protocol == protocol &&
      other.version == version &&
      other.cipher == cipher;

  @override
  int get hashCode => Object.hash(protocol, version, cipher);

  @override
  String toString() => 'ProtocolSuite($protocol, v$version, $cipher)';
}

/// 加密结果：密文 + 写入消息顶层 `e2ee` 字段的元数据 map（ADR 02 §2.1）。
/// [metadata] 由服务端不透明透传（§6），接收方据此路由回同一套件解密。
class E2eeCiphertext {
  const E2eeCiphertext(this.ciphertext, this.metadata);

  final String ciphertext;
  final Map<String, dynamic> metadata;
}

/// 协议无关的会话上下文（ADR 02 §2.1）。
class E2eeContext {
  const E2eeContext({
    this.peerUid,
    this.peerDeviceId,
    this.gid,
    required this.scope,
  });

  final String? peerUid;
  final String? peerDeviceId;

  /// 非空＝群域；空＝单聊。
  final String? gid;

  /// `c2c` / `c2g`，对应 group_session_service 的 scope 语义。
  final String scope;
}

/// 解密失败异常（ADR 02 §2.1）。业务层捕获后产出 `_e2ee_failed` 兜底 payload。
class E2eeDecryptException implements Exception {
  const E2eeDecryptException(this.reason);

  /// `no_device_key` / `nonce_mismatch` / `decrypt_error` 等。
  final String reason;

  @override
  String toString() => 'E2eeDecryptException($reason)';
}

/// 协议无关的接收方设备（ADR 02 §2.1，字段冻结）。
class RecipientDevice {
  const RecipientDevice({
    required this.deviceId,
    required this.keyId,
    required this.publicKey,
    this.capabilities = const {},
  });

  final String deviceId;

  /// 与 e2ee_service 的 `_userKidCacheByDevice` 同语义。
  final String keyId;

  /// RSA-OAEP-256 PEM（legacy）或 curve25519 base64（Olm）。
  final String publicKey;

  /// 由 ADR 04 capability 注入，本接口不解释。
  final Set<ProtocolSuite> capabilities;
}

/// 所有 E2EE 协议插件必须实现的抽象接口（ADR 02 §2.1，签名冻结）。
///
/// 用 `abstract interface class`（Dart 3）而非 `abstract class`：接口冻结要求
/// 实现类不能继承默认行为，每个协议插件必须自给自足，Registry 不提供 fallback。
abstract interface class E2eeSessionProtocol {
  /// 套件标识。Registry 按此 key（`suite.protocol`）注册/查找。
  ProtocolSuite get suite;

  /// 设备本地初始化（首次登录 / 换设备 / 清理后重建）。幂等。
  /// Olm: 创建 Account、发布 identity_key + OTK。Megolm: no-op。
  /// RSA-legacy: 加载本地 kid→私钥，发布公钥。
  Future<void> initialize({required String userId, required String deviceId});

  /// 加密明文，产出可被 [decrypt] 还原的密文 + 该协议透传的 e2ee 元数据。
  /// [recipients] 是多设备 fan-out 接收方；群聊可只含 1 个虚拟 recipient。
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  });

  /// 解密。[metadata] 即加密时产出的 map（服务端透传，未解析）。失败抛
  /// [E2eeDecryptException]。
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  });

  /// 清理本端所有会话状态（退出登录 / 重置）。清 Olm pickle / Megolm session /
  /// ratchet 缓存；不清 device identity key（ADR 03 单独管理）。
  Future<void> clearAll();
}

/// 协议注册表（ADR 02 §2.2）。全局单例。
/// 启动时由 `main()` 调用 [register]，业务层只调用 [resolve] / [all]。
class E2eeProtocolRegistry {
  const E2eeProtocolRegistry._();

  static final Map<String, E2eeSessionProtocol> _byProtocol = {};

  /// 注册协议实现。key = `suite.protocol`。同名重复注册抛 [StateError]。
  static void register(E2eeSessionProtocol impl) {
    final key = impl.suite.protocol;
    if (_byProtocol.containsKey(key)) {
      throw StateError('E2EE protocol already registered: $key');
    }
    _byProtocol[key] = impl;
  }

  /// 按元数据路由：解析 [metadata] 为 [ProtocolSuite] 后查表。
  /// 未注册协议抛 [StateError]，**不静默 fallback**（ADR 02 §4.3）。
  static E2eeSessionProtocol resolve(Map<String, dynamic> metadata) {
    final suite = ProtocolSuite.fromMetadata(metadata);
    final impl = _byProtocol[suite.protocol];
    if (impl == null) {
      throw StateError('No E2EE protocol registered for: ${suite.protocol}');
    }
    return impl;
  }

  /// 本端已注册的全部套件。供 ADR 04 Capability Negotiation 上报能力。
  static List<ProtocolSuite> all() =>
      _byProtocol.values.map((p) => p.suite).toList(growable: false);

  /// 已注册的协议实现（只读）。供 [E2eeBootstrap.ensureReady] 逐个初始化。
  static List<E2eeSessionProtocol> registered() =>
      _byProtocol.values.toList(growable: false);

  /// 清空注册表（仅测试用：隔离用例间的全局状态）。
  static void resetForTest() => _byProtocol.clear();
}

/// 设备信任状态（ADR 03 §3.1 / ADR 06 状态机）。
enum DeviceTrustState {
  unverified,
  verified,
  revoked;

  static DeviceTrustState fromString(String? s) {
    switch (s) {
      case 'verified':
        return DeviceTrustState.verified;
      case 'revoked':
        return DeviceTrustState.revoked;
      case 'unverified':
      default:
        return DeviceTrustState.unverified;
    }
  }

  String toApiString() => name;
}

/// 设备验证方式（记录 trust_state 如何达到的，ADR 06）。
enum VerificationMethod {
  scanned,
  safetyNumber,
  manual,
  crossSigned;

  String toApiString() => name;
}
