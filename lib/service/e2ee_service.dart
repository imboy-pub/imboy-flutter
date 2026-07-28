import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

/// Temporary compatibility service for the security_privacy module shell.
/// New upper-layer imports should prefer
/// `package:imboy/modules/security_privacy/public.dart`.
class E2EEService {
  static final Map<String, Map<String, String>> _userKeyCacheByDevice = {};
  static final Map<String, Map<String, String>> _groupKeyCacheByDevice = {};

  /// 设备 ID → 密钥版本 ID（kid）映射缓存，与公钥缓存同生命周期。
  ///
  /// 零信任契约：组装 e2ee recipients[].kid 时必须消费后端 user_keys /
  /// group_member_keys 返回的 key_id，不能用 device_id 充当 kid，否则
  /// 多密钥版本（密钥轮换/换设备）场景下接收方会选错密钥导致解密失败。
  static final Map<String, Map<String, String>> _userKidCacheByDevice = {};
  static final Map<String, Map<String, String>> _groupKidCacheByDevice = {};

  /// 群缓存：gid → (did → 该设备所属成员 uid)。
  /// room-key-over-Olm（ADR 13）发送侧据此解析对端 uid 建 Olm 会话；
  /// C2C 场景 did→uid 恒等于对端 uid，无需缓存（_userKeyResult 内联生成）。
  static final Map<String, Map<String, String>> _groupUidCacheByDevice = {};

  /// 缓存条目的存入时间戳（毫秒），用于 TTL 过期检查
  static final Map<String, int> _userKeyCacheTimestamp = {};
  static final Map<String, int> _groupKeyCacheTimestamp = {};

  /// 缓存 TTL（30 分钟），超过此时间的缓存条目将被视为过期
  static const int _cacheTtlMs = 30 * 60 * 1000;

  /// 检查缓存是否已过期
  static bool _isCacheExpired(Map<String, int> timestamps, String key) {
    final cachedAt = timestamps[key];
    if (cachedAt == null) return true;
    return DateTime.now().millisecondsSinceEpoch - cachedAt > _cacheTtlMs;
  }

  /// 组装用户设备密钥结果：device_id→public_key 与 device_id→kid 两份映射。
  /// didToKid 从 kid 缓存读取（与 didToPem 同生命周期写入）。
  static Map<String, Map<String, String>> _userKeyResult(
    String uid,
    Map<String, String> didToPem,
  ) {
    return {
      'didToPem': didToPem,
      'didToKid': _userKidCacheByDevice[uid] ?? const <String, String>{},
      // C2C：分发列表内所有设备均属对端 uid，did→uid 恒等映射
      'didToUid': {for (final did in didToPem.keys) did: uid},
    };
  }

  /// 组装群组设备密钥结果，语义同 [_userKeyResult]。
  static Map<String, Map<String, String>> _groupKeyResult(
    String gid,
    Map<String, String> didToPem,
  ) {
    return {
      'didToPem': didToPem,
      'didToKid': _groupKidCacheByDevice[gid] ?? const <String, String>{},
      // C2G：did→成员 uid（room-key-over-Olm 发送侧解析对端 uid 用）
      'didToUid': _groupUidCacheByDevice[gid] ?? const <String, String>{},
    };
  }

  static void setUserDeviceKeyCacheForTest(
    String uid,
    Map<String, String> didToPem,
  ) {
    _userKeyCacheByDevice[uid] = didToPem;
  }

  static void setGroupDeviceKeyCacheForTest(
    String gid,
    Map<String, String> didToPem,
  ) {
    _groupKeyCacheByDevice[gid] = didToPem;
    _groupKeyCacheTimestamp[gid] = DateTime.now().millisecondsSinceEpoch;
    _groupKidCacheByDevice[gid] = Map.fromIterable(
      didToPem.keys,
      value: (k) => 'kid_$k',
    );
    _groupUidCacheByDevice[gid] = Map.fromIterable(
      didToPem.keys,
      value: (k) => 'uid_$k',
    );
  }

  static void clearKeyCacheForTest() {
    _userKeyCacheByDevice.clear();
    _groupKeyCacheByDevice.clear();
    _userKidCacheByDevice.clear();
    _groupKidCacheByDevice.clear();
    _userKeyCacheTimestamp.clear();
    _groupKeyCacheTimestamp.clear();
  }

  /// 清理E2EE缓存（用于退出登录等场景）
  ///
  /// 清理设备密钥缓存，确保下次使用时重新获取最新密钥
  static void clearCache() {
    _userKeyCacheByDevice.clear();
    _groupKeyCacheByDevice.clear();
    _userKidCacheByDevice.clear();
    _groupKidCacheByDevice.clear();
    _userKeyCacheTimestamp.clear();
    _groupKeyCacheTimestamp.clear();
    iPrint('E2EE: 缓存已清理');
  }

  /// 清除特定用户的公钥缓存
  ///
  /// 当接收方更新密钥后，发送方需要调用此方法清除缓存
  static void clearUserKeyCache(String uid) {
    _userKeyCacheByDevice.remove(uid);
    _userKidCacheByDevice.remove(uid);
    _userKeyCacheTimestamp.remove(uid);
    iPrint('E2EE: 已清除用户 $uid 的公钥缓存');
  }

  /// 清除所有公钥缓存
  static void clearAllKeyCache() {
    _userKeyCacheByDevice.clear();
    _groupKeyCacheByDevice.clear();
    _userKeyCacheTimestamp.clear();
    _groupKeyCacheTimestamp.clear();
    iPrint('E2EE: 已清除所有公钥缓存');
  }

  /// 检查是否需要对消息进行端到端加密（经 [PolicyGate] 决策）。
  ///
  /// WebSocket API v2.0: msg_type/action 在顶层，不在 payload 内。
  /// action 操作消息由调用方拦截；此处只按后端 policy 判定 C2C/C2G。
  ///
  /// fail-closed（ADR 14 §S1.1 / CB-01/02）：策略未初始化时对 C2C/C2G 抛
  /// [E2eeSecurityException]，绝不静默以 plaintext 默认继续发送。
  static bool shouldEncryptOutgoingPayload(String chatType) {
    final decision = PolicyGate.requireReadyForSend(chatType);
    return decision is EncryptRequired;
  }

  /// 构建 E2EE 数据（v2.0 格式）
  ///
  /// 返回分离的 e2ee 元数据和密文字符串，符合 WebSocket API v2.0 规范
  ///
  /// ## v2.0 格式说明
  /// - **e2ee 元数据**：仅包含加密参数（nonce、keys 等），不包含密文
  /// - **ciphertext**：格式为 `base64(nonce).base64(ciphertext)` 的字符串
  /// - **分离设计**：e2ee 元数据放在消息顶层，ciphertext 作为 payload
  ///
  /// ## 返回值
  /// ```dart
  /// {
  ///   'e2ee': {
  ///     'e2ee': true,
  ///     'e2ee_ver': 1,
  ///     'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
  ///     'nonce': 'base64_encoded_nonce',
  ///     'keys': [
  ///       {
  ///         'did': 'deviceA',
  ///         'kid': 'key_v1',
  ///         'wrap_alg': 'RSA-OAEP-256',
  ///         'ek': 'base64_encoded_wrapped_key'
  ///       }
  ///     ]
  ///   },
  ///   'ciphertext': 'base64(nonce).base64(ciphertext)'
  /// }
  /// ```
  ///
  /// ## 使用示例
  /// ```dart
  /// final result = await E2EEService.buildE2EEData(
  ///   plaintext: jsonEncode(payload),
  ///   recipients: [
  ///     RecipientDevice(
  ///       deviceId: 'device123',
  ///       keyId: 'key_v1',
  ///       publicKey: publicKeyPem,
  ///     ),
  ///   ],
  /// );
  ///
  /// // 构建消息
  /// final message = {
  ///   'type': 'C2C',
  ///   'to': 'user123',
  ///   'msg_type': 'text',
  ///   'payload': result['ciphertext'],  // 密文作为 payload（字符串）
  ///   'e2ee': result['e2ee'],           // 元数据放入 e2ee（Map<String, dynamic>）
  /// };
  /// ```
  static Future<Map<String, dynamic>> buildE2EEData({
    required String plaintext,
    required List<RecipientDevice> recipients,
  }) async {
    // 1. 生成一次性 nonce (12 字节推荐用于 GCM)
    final nonce = _secureRandomBytes(12);

    // 2. 生成一次性对称密钥（AES-256）
    final aesKey = _secureRandomBytes(32);

    // 3. 使用 AES-GCM 加密明文（使用预生成的 nonce）
    final plaintextBytes = utf8.encode(plaintext);
    final encrypted = EncrypterService.aesGcmEncryptBytesWithIV(
      Uint8List.fromList(plaintextBytes),
      aesKey,
      nonce,
    );

    // 4. 提取密文
    final ct = encrypted['ct']!;

    // 5. 组合 nonce 和密文作为最终的 ciphertext
    // 格式: base64(nonce) + '.' + base64(ciphertext)
    final nonceBase64 = base64.encode(nonce);
    final ciphertextBase64 = '$nonceBase64.$ct';

    // 6. 为每个接收方设备包装密钥
    final keys = <Map<String, dynamic>>[];
    for (final recipient in recipients) {
      final wrappedKey = await _wrapAESKey(
        aesKey: aesKey,
        publicKeyPem: recipient.publicKey,
      );
      keys.add({
        'did': recipient.deviceId,
        'kid': recipient.keyId,
        'wrap_alg': 'RSA-OAEP-256',
        'ek': base64.encode(wrappedKey),
      });
    }

    // 6b. compliance_e2ee 模式：必须额外用合规公钥包装 AES 密钥。
    // fail-closed（CB-09/10）：合规密钥缺失/过期一律抛 E2eeSecurityException，
    // 绝不静默降级为仅设备加密或复用 stale cache——否则整条消息漏加审计接收方
    // 却被当作发送成功。异常向上传播由发送路径拒发。
    final policyMode = EncryptionModeService.current;
    if (policyMode == EncryptionMode.complianceE2ee) {
      final complianceKey = PolicyGate.requireComplianceKey(
        await ComplianceKeyService.instance.getComplianceKey(),
      );
      final wrappedCompliance = await _wrapAESKey(
        aesKey: aesKey,
        publicKeyPem: complianceKey.publicKey,
      );
      keys.add({
        'did': 'compliance-audit',
        'kid': complianceKey.keyId,
        'wrap_alg': 'RSA-OAEP-256',
        'ek': base64.encode(wrappedCompliance),
      });
      iPrint('E2EE: 已添加合规密钥包装 keyId=${complianceKey.keyId}');
    }

    // 7. 返回 e2ee 元数据和密文（分离）
    // 注意：e2ee 元数据中的 nonce 也是 base64 编码
    return {
      'e2ee': {
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        'nonce': nonceBase64,
        'keys': keys,
      },
      'ciphertext': ciphertextBase64,
    };
  }

  /// 解密 E2EE 消息（v2.0 格式）
  ///
  /// ## v2.0 格式说明
  /// - **ciphertext**：字符串格式，为 `base64(nonce).base64(ciphertext)`
  /// - **e2ee 元数据**：包含加密参数，其中 nonce 字段与 ciphertext 前缀相同
  ///
  /// ## 参数
  /// - [ciphertext]: 密文字符串（格式：`base64(nonce).base64(ciphertext)`）
  /// - [e2ee]: e2ee 元数据（包含 keys 数组）
  /// - [aad]: 附加认证数据（可选）
  ///
  /// ## 返回值
  /// 解密后的明文字符串
  ///
  /// ## 使用示例
  /// ```dart
  /// final plaintext = await E2EEService.decryptE2EEMessage(
  ///   ciphertext: 'base64nonce.base64ciphertext',
  ///   e2ee: message['e2ee'],
  /// );
  /// ```
  static Future<String> decryptE2EEMessage({
    required String ciphertext,
    required Map<String, dynamic> e2ee,
    String? aad,
  }) async {
    // ADR 02 §4：业务层不做 if/else 套件路由，统一走 Protocol Registry。
    // fromMetadata 兼容 v1 字符串（OLM.V1/MEGOLM.V1/RSA-OAEP-256+AES-256-GCM）
    // 与 v2 三元组（protocol/version）。未知套件抛 FormatException，由调用方
    // decryptIncomingPayload 捕获兜底 _e2ee_failed（不静默 fallback，§4.3）。
    //
    // aad 经 metadata 瞬态键透传：ADR 02 §2.1 冻结的 decrypt 接口无 aad 参数，
    // 仅 RsaLegacyProtocol 读取 metadata['aad']；Olm/Megolm 忽略。
    E2eeBootstrap.ensureRegistered();
    final metadata = (aad != null && aad.isNotEmpty)
        ? <String, dynamic>{...e2ee, 'aad': aad}
        : e2ee;
    return E2eeProtocolRegistry.resolve(
      metadata,
    ).decrypt(ciphertext: ciphertext, metadata: metadata);
  }

  /// 解密接收到的消息 payload
  ///
  /// ## v2.0 E2EE 格式
  /// ```json
  /// {
  ///   "msg_type": "text",  // 保留原始消息类型！
  ///   "e2ee": {
  ///     "e2ee": true,
  ///     "e2ee_ver": 1,
  ///     "e2ee_suite": "RSA-OAEP-256+AES-256-GCM",
  ///     "nonce": "base64_encoded_nonce",
  ///     "keys": [
  ///       {
  ///         "did": "deviceA",
  ///         "kid": "key_v1",
  ///         "wrap_alg": "RSA-OAEP-256",
  ///         "ek": "base64_encoded_wrapped_key"
  ///       }
  ///     ]
  ///   },
  ///   "payload": "base64(nonce).base64(ciphertext)"  // 密文字符串
  /// }
  /// ```
  ///
  /// 返回解密后的 payload，如果解密失败则返回包含 `_e2ee_failed` 标记的 payload
  static Future<Map<String, dynamic>> decryptIncomingPayload({
    required Map<String, dynamic> payload,
  }) async {
    final e2ee = payload['e2ee'];
    if (e2ee == null || e2ee == '') return payload;

    final e2eeData = e2ee is Map<String, dynamic>
        ? e2ee.cast<String, dynamic>()
        : null;
    if (e2eeData is! Map<String, dynamic>) {
      return _decryptFailedPayload(payload, reason: 'invalid_e2ee');
    }

    // S2.1 / ADR 15: Protected Frame v3 路径
    if (e2eeData['meta_version'] == 3) {
      // S2.2: per-device fan-out — 每个设备有独立信封
      if (e2eeData['fan_out'] == 'per_device') {
        final devices = e2eeData['devices'];
        if (devices is! Map<String, dynamic>) {
          return _decryptFailedPayload(
            payload,
            reason: 'fan_out_missing_devices',
          );
        }
        final myDid = deviceId;
        final myEnvelope = devices[myDid];
        if (myEnvelope is! Map<String, dynamic>) {
          return _decryptFailedPayload(payload, reason: 'no_device_envelope');
        }
        // 将 per-device 信封提升为标准 v3 信封格式
        final envelope = <String, dynamic>{'meta_version': 3, ...myEnvelope};
        return _decryptV3Payload(payload, envelope);
      }
      return _decryptV3Payload(payload, e2eeData);
    }

    final e = e2ee.cast<String, dynamic>();

    final keys = e['keys'];
    if (keys is! List || keys.isEmpty) {
      return _decryptFailedPayload(payload, reason: 'invalid_keys');
    }

    final myDid = deviceId;
    final me = keys
        .whereType<Map<String, dynamic>>()
        .map((x) => x.cast<String, dynamic>())
        .firstWhere((r) => r['did'] == myDid, orElse: () => {});
    if (me.isEmpty) {
      return _decryptFailedPayload(payload, reason: 'no_device_key');
    }

    final ekB64 = me['ek']?.toString() ?? '';
    if (ekB64.isEmpty) {
      return _decryptFailedPayload(payload, reason: 'missing_fields');
    }

    final ciphertext = payload['payload']?.toString() ?? '';
    if (ciphertext.isEmpty) {
      return _decryptFailedPayload(payload, reason: 'missing_ciphertext');
    }

    final parts = ciphertext.split('.');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return _decryptFailedPayload(
        payload,
        reason: 'invalid_ciphertext_format',
      );
    }
    final iv = parts[0];
    final nonce = e['nonce']?.toString() ?? '';
    if (nonce.isNotEmpty && nonce != iv) {
      return _decryptFailedPayload(payload, reason: 'nonce_mismatch');
    }

    try {
      final plaintext = await decryptE2EEMessage(
        ciphertext: ciphertext,
        e2ee: e as Map<String, dynamic>,
      );

      final decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic>) {
        return _decryptFailedPayload(payload, reason: 'invalid_plaintext');
      }

      final plain = decoded;

      // 保留原始元数据
      if (payload.containsKey('client_send_ts')) {
        plain['client_send_ts'] = payload['client_send_ts'];
      }
      if (plain['sender_did'] == null) {
        final injected = payload['sender_did'];
        if (injected != null) {
          plain['sender_did'] = injected;
        }
      }
      if (payload.containsKey('sender_dtype')) {
        plain['sender_dtype'] = payload['sender_dtype'];
      }
      if (plain['_e2ee'] == null) {
        plain['_e2ee'] = payload;
      }

      return plain;
    } catch (e) {
      return _decryptFailedPayload(payload, reason: 'decrypt_error');
    }
  }

  /// ADR 15 §4 接收侧 v3 解密路径。
  ///
  /// 流程：
  /// 1. 资源边界验证（PF3-08，密码学前拒绝）
  /// 2. 外层信封验证（header_hash + CBOR strict parse）
  /// 3. 协议解密（Olm/Megolm/MLS）
  /// 4. inner_frame CBOR 解码
  /// 5. inner/outer header 比对（PF3-03 跨上下文复制检测）
  /// 6. 返回 verified payload
  static Future<Map<String, dynamic>> _decryptV3Payload(
    Map<String, dynamic> payload,
    Map<String, dynamic> envelope,
  ) async {
    // 1. 资源边界（PF3-08）
    try {
      ProtectedFrameV3.validateEnvelopeBounds(envelope);
    } on FrameBoundsException catch (e) {
      return _decryptFailedPayload(payload, reason: 'bounds_${e.message}');
    }

    // 2. 外层信封验证
    final verification = ProtectedFrameV3.verifyOuterEnvelope(envelope);
    if (!verification.isValid) {
      return _decryptFailedPayload(
        payload,
        reason: 'envelope_${verification.reason}',
      );
    }
    final outerHeader = verification.decodedHeader!;

    // 2.5 纵向上下文绑定验证 (E2EE-012 / ADR 15 §3.3)
    final contextMismatch = _validateContextBinding(
      payload,
      outerHeader,
      envelope,
    );
    if (contextMismatch != null) {
      return _decryptFailedPayload(
        payload,
        reason: 'context_mismatch_$contextMismatch',
      );
    }

    // 2.6 序列号验证 (E2EE-025 / 提案 25 选项 C，已人工签字)
    //
    // `epoch_or_counter` **仅 MLS 使用**（承载 epoch）。Olm/Megolm 恒填 0，
    // 接收侧不对其做序列检查——理由（提案 25 §1.3 / §4）：
    //   1. `message_id` 位于**受认证**的 protected_header 内，改它会破坏
    //      header_hash / inner 比对，因此 `message_id` dedupe（ADR 15 §7.1，
    //      下方透传给 OlmProtocol → crypto_inbox_dedupe）已是密码学绑定的
    //      幂等保证；
    //   2. Olm Double Ratchet 的 message key 用后即毁，重放同一密文必然解密失败。
    // 在此之上再叠一套应用层计数器属重复机制，且其可用性风险（离线批量投递与
    // WS 重连乱序是 IMBoy 常态，严格单调必然误杀）高于其安全收益。
    //
    // ⚠️ 引入 MLS 时（E2EE-04x）**不得**直接复用 CryptoStore.checkAndUpdateSequence：
    // 它是严格单调，而 ADR 15 §7.2（修订后仅适用于 MLS）要求的是 IPsec 式
    // 滑动窗口（high-water mark + bitmap + resync），见提案 25 §3 选项 B。
    final protocol = outerHeader['protocol']?.toString() ?? '';
    if (protocol == 'mls') {
      return _decryptFailedPayload(payload, reason: 'mls_not_implemented');
    }

    // 3. 协议解密
    final ciphertextB64 = envelope['ciphertext'];
    if (ciphertextB64 is! String || ciphertextB64.isEmpty) {
      return _decryptFailedPayload(payload, reason: 'missing_ciphertext');
    }
    final protocolMetadata = envelope['protocol_metadata'];
    if (protocolMetadata is! Map<String, dynamic>) {
      return _decryptFailedPayload(
        payload,
        reason: 'missing_protocol_metadata',
      );
    }

    String innerFrameB64;
    try {
      // 协议路由：从 protocol_metadata 中解析 suite
      final metadata = <String, dynamic>{
        ...protocolMetadata,
        'protocol': outerHeader['protocol'],
        'version': outerHeader['protocol_version'],
        // S2.3c: 透传 message_id 供 OlmProtocol dedupe
        'message_id':
            outerHeader['message_id']?.toString() ??
            payload['id']?.toString() ??
            '',
      };
      final ciphertextStr = utf8.decode(base64Url.decode(ciphertextB64));
      innerFrameB64 = await E2eeProtocolRegistry.resolve(
        metadata,
      ).decrypt(ciphertext: ciphertextStr, metadata: metadata);
    } on DuplicateMessageException {
      // ADR 15 §7.1：重复密文幂等返回，ratchet 未重复推进。
      // 与"解密失败"语义不同——上层据此静默跳过，不应向用户报错。
      return _decryptFailedPayload(payload, reason: 'duplicate_message');
    } on OlmStateCommitException {
      // E2EE-030：本地事务存储不可用导致的 fail-closed，密文本身没问题，
      // 属**可重试**故障；压成 decrypt_error 会让上层当作永久失败。
      return _decryptFailedPayload(payload, reason: 'crypto_store_unavailable');
    } on CryptoStoreUnavailableException {
      // E2EE-025 §5.2：同上，来自 CryptoStore 自身的存储故障。
      return _decryptFailedPayload(payload, reason: 'crypto_store_unavailable');
    } catch (_) {
      // 其余一律归为稳定、无秘密的通用分类（ADR 15 §5：不上送 oracle 细节）
      return _decryptFailedPayload(payload, reason: 'decrypt_error');
    }

    // 4. inner_frame CBOR 解码
    Map<String, dynamic> innerFrame;
    try {
      final innerBytes = Uint8List.fromList(base64Url.decode(innerFrameB64));
      final decoded = CanonicalCbor.decode(innerBytes, strict: true);
      if (decoded is! Map<String, dynamic>) {
        return _decryptFailedPayload(payload, reason: 'inner_frame_not_map');
      }
      innerFrame = decoded;
    } catch (_) {
      return _decryptFailedPayload(payload, reason: 'inner_frame_cbor_invalid');
    }

    // 5. inner/outer header 比对（PF3-03）
    final innerHeaderRaw = innerFrame['protected_header'];
    if (innerHeaderRaw is! Map<String, dynamic>) {
      return _decryptFailedPayload(payload, reason: 'inner_header_missing');
    }
    final outerCtx = FrameContext.fromHeader(outerHeader);
    final innerCtx = FrameContext.fromHeader(innerHeaderRaw);
    final mismatch = ProtectedFrameV3.compareHeaders(
      outerContext: outerCtx,
      innerContext: innerCtx,
    );
    if (mismatch != null) {
      return _decryptFailedPayload(
        payload,
        reason: 'header_mismatch_$mismatch',
      );
    }

    // 6. 返回 verified payload
    final innerPayload = innerFrame['payload'];
    if (innerPayload is! Map<String, dynamic>) {
      return _decryptFailedPayload(payload, reason: 'inner_payload_invalid');
    }

    final plain = Map<String, dynamic>.from(innerPayload);

    // 保留服务端注入的可信字段
    if (payload.containsKey('sender_did')) {
      plain['sender_did'] = payload['sender_did'];
    }
    if (payload.containsKey('sender_dtype')) {
      plain['sender_dtype'] = payload['sender_dtype'];
    }
    if (payload.containsKey('client_send_ts')) {
      plain['client_send_ts'] = payload['client_send_ts'];
    }
    // 标记已通过 v3 验证
    plain['_e2ee_v3_verified'] = true;

    return plain;
  }

  /// 纵向上下文绑定校验 (E2EE-012 / ADR 15 §3.3)
  ///
  /// 比对外部传输层字段（payload）与经 SHA-256(canonical CBOR) 认证的受保护头部（outerHeader）。
  /// 任何不一致将返回不一致的字段名称作为错误原由；全部一致则返回 null。
  static String? _validateContextBinding(
    Map<String, dynamic> payload,
    Map<String, dynamic> outerHeader,
    Map<String, dynamic> envelope,
  ) {
    // 1. message_id
    final payloadId = payload['id']?.toString() ?? '';
    final headerId = outerHeader['message_id']?.toString() ?? '';
    if (payloadId != headerId) {
      return 'id';
    }

    // 2. sender_uid
    final payloadFrom = payload['from']?.toString() ?? '';
    final headerFrom = outerHeader['sender_uid']?.toString() ?? '';
    if (payloadFrom != headerFrom) {
      return 'from';
    }

    // 3. scope
    final payloadType = payload['type']?.toString() ?? '';
    final headerScope = outerHeader['scope']?.toString() ?? '';
    if (payloadType == 'C2C') {
      if (headerScope != 'c2c') {
        return 'type';
      }
    } else if (payloadType == 'C2G') {
      if (headerScope != 'group') {
        return 'type';
      }
    } else {
      return 'type';
    }

    // 4. destination & conversation_id
    final payloadTo = payload['to']?.toString() ?? '';
    final headerDest = outerHeader['destination']?.toString() ?? '';
    final headerConvId = outerHeader['conversation_id']?.toString() ?? '';
    if (payloadType == 'C2C') {
      if (payloadTo != headerDest) {
        return 'to';
      }
    } else if (payloadType == 'C2G') {
      if (payloadTo != headerConvId || payloadTo != headerDest) {
        return 'to';
      }
    } else {
      return 'to';
    }

    // 4.5 gid 校验 (C2G 辅助)
    if (payloadType == 'C2G') {
      final payloadGid = payload['gid']?.toString() ?? '';
      if (payloadGid != headerConvId) {
        return 'gid';
      }
    }

    // 5. message_type
    final payloadMsgType = payload['msg_type']?.toString() ?? '';
    final headerMsgType = outerHeader['message_type']?.toString() ?? '';
    if (payloadMsgType != headerMsgType) {
      return 'msg_type';
    }

    // 6. sender_did
    final payloadDid = payload['sender_did']?.toString() ?? '';
    final headerDid = outerHeader['sender_did']?.toString() ?? '';
    if (payloadDid != headerDid) {
      return 'sender_did';
    }

    // 7. session_id (session_ref)
    final protoMeta = envelope['protocol_metadata'];
    if (protoMeta is Map) {
      final payloadSessionId = protoMeta['session_id']?.toString() ?? '';
      final headerSessionRef = outerHeader['session_ref']?.toString() ?? '';
      if (payloadSessionId != headerSessionRef) {
        return 'session_id';
      }
    } else {
      return 'session_id';
    }

    return null; // 全部比对通过，上下文一致
  }

  static Map<String, dynamic> _decryptFailedPayload(
    Map<String, dynamic> payload, {
    required String reason,
  }) {
    final msgType = payload['msg_type']?.toString() ?? 'text';
    return {
      'msg_type': msgType, // 保留原始消息类型
      'text': '[加密消息]',
      '_e2ee_failed': true,
      '_e2ee_reason': reason,
      '_e2ee_raw': payload,
    };
  }

  /// 获取用户设备公钥（公共方法，用于 v2.0 发送）
  ///
  /// 带重试机制，网络抖动时自动重试
  static Future<Map<String, Map<String, String>>> getUserDevicePublicKeys(
    String uid, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool forceRefresh = false, // 强制刷新缓存
  }) async {
    // 检查缓存（除非强制刷新或已过期）
    if (!forceRefresh && !_isCacheExpired(_userKeyCacheTimestamp, uid)) {
      final cached = _userKeyCacheByDevice[uid];
      if (cached != null && cached.isNotEmpty) {
        return _userKeyResult(uid, cached);
      }
    }

    // 缓存过期时清除旧数据，确保不使用已撤销的公钥
    if (_isCacheExpired(_userKeyCacheTimestamp, uid)) {
      _userKeyCacheByDevice.remove(uid);
      _userKeyCacheTimestamp.remove(uid);
    }

    // 带重试的获取逻辑
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final list = await E2EEApi().userKeys(uid: uid);
        final didToPem = <String, String>{};
        final didToKid = <String, String>{};
        for (final row in list) {
          final did = row['device_id']?.toString() ?? '';
          final pem = row['public_key']?.toString() ?? '';
          if (did.isEmpty || pem.isEmpty) continue;
          didToPem[did] = pem;
          final kid = row['key_id']?.toString() ?? '';
          if (kid.isNotEmpty) didToKid[did] = kid;
        }

        // 【F-08 复核回退】forceRefresh 命中空列表时的处理：保留"带 TTL 门槛的
        // 抗抖动回退"，而非"空即吊销"。理由（对齐 docs/audit VERIFIED 版 BUG-07 裁决）：
        // 后端目前无法用显式 revoked 标志区分"空=临时 API 故障"与"空=真吊销"，
        // 在此前提下，若直接判定吊销会牺牲可用性（API 抖动时本端无法加密发出）。
        // 故仅在本地缓存未过期（30min TTL）时回退旧缓存抗抖；缓存已过期则自然失效。
        // 彻底解决需后端提供 revoked 显式标志（超出客户端范围），届时再切回"即时吊销"。
        if (didToPem.isEmpty && forceRefresh) {
          final cached = _userKeyCacheByDevice[uid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_userKeyCacheTimestamp, uid)) {
            iPrint(
              '⚠️ [E2EE] API 返回空，使用未过期缓存（抗抖动）: uid=$uid, 设备数=${cached.length}',
            );
            return _userKeyResult(uid, cached);
          }
        }

        _userKeyCacheByDevice[uid] = didToPem;
        _userKidCacheByDevice[uid] = didToKid;
        _userKeyCacheTimestamp[uid] = DateTime.now().millisecondsSinceEpoch;
        iPrint('✅ [E2EE] 获取用户公钥成功: uid=$uid, 设备数=${didToPem.length}');
        return _userKeyResult(uid, didToPem);
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          // 🔧 修复：API 调用失败时回退到未过期的缓存（用于测试环境）
          final cached = _userKeyCacheByDevice[uid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_userKeyCacheTimestamp, uid)) {
            iPrint('⚠️ [E2EE] API 失败，使用缓存: uid=$uid, 设备数=${cached.length}');
            return _userKeyResult(uid, cached);
          }
          iPrint('获取用户设备密钥失败（已重试$maxRetries次）: $e');
          rethrow;
        }
        iPrint('获取用户设备密钥失败，第$attempt次重试...');
        await Future<dynamic>.delayed(retryDelay);
      }
    }

    // 理论上不会到达这里
    throw Exception(
      'Failed to get user device keys after $maxRetries attempts',
    );
  }

  /// 获取群组设备公钥（公共方法，用于 v2.0 发送）
  ///
  /// 带重试机制，网络抖动时自动重试
  static Future<Map<String, Map<String, String>>> getGroupDevicePublicKeys(
    String gid, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    bool forceRefresh = false, // 强制刷新缓存
  }) async {
    // 检查缓存（除非强制刷新或已过期）
    if (!forceRefresh && !_isCacheExpired(_groupKeyCacheTimestamp, gid)) {
      final cached = _groupKeyCacheByDevice[gid];
      if (cached != null && cached.isNotEmpty) {
        return _groupKeyResult(gid, cached);
      }
    }

    // 缓存过期时清除旧数据，确保不使用已撤销的公钥
    if (_isCacheExpired(_groupKeyCacheTimestamp, gid)) {
      _groupKeyCacheByDevice.remove(gid);
      _groupKeyCacheTimestamp.remove(gid);
    }

    // 带重试的获取逻辑
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final members = await E2EEApi().groupMemberKeys(gid: gid);
        final didToPem = <String, String>{};
        final didToKid = <String, String>{};
        final didToUid = <String, String>{};
        for (final m in members) {
          final memberUid = m['uid']?.toString() ?? '';
          final devices = m['devices'];
          if (devices is! List) continue;
          for (final d in devices.whereType<Map<String, dynamic>>()) {
            final row = d.cast<String, dynamic>();
            final did = row['device_id']?.toString() ?? '';
            final pem = row['public_key']?.toString() ?? '';
            if (did.isEmpty || pem.isEmpty) continue;
            didToPem[did] = pem;
            final kid = row['key_id']?.toString() ?? '';
            if (kid.isNotEmpty) didToKid[did] = kid;
            if (memberUid.isNotEmpty) didToUid[did] = memberUid;
          }
        }

        // 【F-08 复核回退】群密钥同单聊语义：保留带 TTL 门槛的抗抖动回退
        // （对齐 VERIFIED 版 BUG-07：后端无 revoked 显式标志前，抗抖动优先于即时吊销）。
        if (didToPem.isEmpty && forceRefresh) {
          final cached = _groupKeyCacheByDevice[gid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_groupKeyCacheTimestamp, gid)) {
            iPrint(
              '⚠️ [E2EE] 群 API 返回空，使用未过期缓存（抗抖动）: gid=$gid, 设备数=${cached.length}',
            );
            return _groupKeyResult(gid, cached);
          }
        }

        _groupKeyCacheByDevice[gid] = didToPem;
        _groupKidCacheByDevice[gid] = didToKid;
        _groupUidCacheByDevice[gid] = didToUid;
        _groupKeyCacheTimestamp[gid] = DateTime.now().millisecondsSinceEpoch;
        return _groupKeyResult(gid, didToPem);
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          // 🔧 修复：API 调用失败时回退到未过期的缓存（用于测试环境）
          final cached = _groupKeyCacheByDevice[gid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_groupKeyCacheTimestamp, gid)) {
            iPrint('⚠️ [E2EE] API 失败，使用缓存: gid=$gid, 设备数=${cached.length}');
            return _groupKeyResult(gid, cached);
          }
          iPrint('获取群组设备密钥失败（已重试$maxRetries次）: $e');
          rethrow;
        }
        iPrint('获取群组设备密钥失败，第$attempt次重试...');
        await Future<dynamic>.delayed(retryDelay);
      }
    }

    // 理论上不会到达这里
    throw Exception(
      'Failed to get group device keys after $maxRetries attempts',
    );
  }

  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return Uint8List.fromList(bytes);
  }

  /// 重试解密之前失败的 E2EE 消息
  ///
  /// 当用户重新生成密钥后，可以调用此方法重新尝试解密之前失败的消息
  ///
  /// 参数:
  /// - failedPayload: 解密失败的消息 payload（包含 _e2ee_raw 等字段）
  ///
  /// 返回:
  /// - 解密成功后的 payload，如果仍然失败则返回原 payload
  ///
  /// 使用示例:
  /// ```dart
  /// final result = await E2EEService.retryDecryptFailedMessage(failedPayload);
  /// if (result.containsKey('_e2ee_failed')) {
  ///   // 仍然解密失败
  /// } else {
  ///   // 解密成功，更新消息
  /// }
  /// ```
  static Future<Map<String, dynamic>> retryDecryptFailedMessage(
    Map<String, dynamic> failedPayload,
  ) async {
    try {
      // 1. 尝试从 _e2ee_raw 中提取原始数据（兼容 _decryptFailedPayload 的存储结构）
      final rawPayload = failedPayload['_e2ee_raw'];
      String? rawCiphertext;
      Map<String, dynamic>? rawE2ee;

      if (rawPayload is Map<String, dynamic>) {
        rawCiphertext = rawPayload['payload']?.toString();
        final e2eeData = rawPayload['e2ee'];
        if (e2eeData is Map<String, dynamic>) {
          rawE2ee = e2eeData.cast<String, dynamic>();
        }
      }

      if (rawCiphertext == null || rawCiphertext.isEmpty) {
        iPrint('⚠️ [E2EE] 消息不包含原始密文，无法重试解密');
        return failedPayload;
      }

      if (rawE2ee == null) {
        iPrint('⚠️ [E2EE] 消息不包含 E2EE 元数据，无法重试解密');
        return failedPayload;
      }

      // 3. 尝试重新解密
      final plaintext = await decryptE2EEMessage(
        ciphertext: rawCiphertext,
        e2ee: rawE2ee,
      );

      // 解析解密后的内容
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('解密后的内容不是 JSON 对象');
      }

      final result = decoded.cast<String, dynamic>();

      // 保留原始消息类型
      final originalMsgType = failedPayload['_e2ee_original_msg_type']
          ?.toString();
      if (originalMsgType != null && originalMsgType.isNotEmpty) {
        result['msg_type'] = originalMsgType;
      }

      iPrint('✅ [E2EE] 重试解密成功');
      return result;
    } catch (e) {
      iPrint('❌ [E2EE] 重试解密失败: $e');
      return failedPayload;
    }
  }

  /// 使用 RSA 公钥包装 AES 密钥
  static Future<Uint8List> _wrapAESKey({
    required Uint8List aesKey,
    required String publicKeyPem,
  }) async {
    final pubKey = RSAService.parsePublicKeyFromPem(publicKeyPem);
    return RSAService.rsaEncrypt(pubKey, aesKey);
  }
}

/// E2EE 接收方设备信息
class RecipientDevice {
  final String deviceId;
  final String keyId;
  final String publicKey;

  RecipientDevice({
    required this.deviceId,
    required this.keyId,
    required this.publicKey,
  });
}
