import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/e2ee_settings.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/service/compliance_key_service.dart';

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

  /// 检查是否需要对消息进行端到端加密
  ///
  /// WebSocket API v2.0: msg_type/action 在顶层，不在 payload 内
  ///
  /// ## 加密条件（全部满足）
  /// 1. E2EE功能已启用（通过[E2EESettings.isEnabled]检查）
  /// 2. 消息类型为 C2C 或 C2G
  /// 3. 非action操作消息（action消息不加密）
  static bool shouldEncryptOutgoingPayload(String chatType) {
    // 1. 检查后端策略：如果策略要求加密，强制加密
    final policyMode = EncryptionModeService.current;
    if (policyMode.requiresEncryption) {
      // 策略要求加密，只对 C2C/C2G 消息生效
      if (chatType != 'C2C' && chatType != 'C2G') return false;
      return true;
    }

    // 2. 策略为 plaintext 时，检查用户本地 E2EE 开关
    if (!E2EESettings.isEnabled()) {
      return false;
    }

    // 只对 C2C 和 C2G 消息加密
    if (chatType != 'C2C' && chatType != 'C2G') return false;

    // action 检查由调用方完成
    return true;
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

    // 6b. compliance_e2ee 模式：额外用合规公钥包装 AES 密钥
    final policyMode = EncryptionModeService.current;
    if (policyMode == EncryptionMode.complianceE2ee) {
      try {
        final complianceKey = await ComplianceKeyService.instance
            .getComplianceKey();
        if (complianceKey != null) {
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
      } catch (e) {
        iPrint('E2EE: 合规密钥包装失败（降级为仅设备加密）: $e');
      }
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
    // 1. 解析 ciphertext（格式：base64(nonce).base64(ciphertext)）
    final parts = ciphertext.split('.');
    if (parts.length != 2) {
      // DEBUG: 打印实际收到的 ciphertext，以便定位投递路径上 payload 被破坏的位置。
      // ignore: avoid_print
      print(
        '[E2EE_DEBUG] ciphertext_len=${ciphertext.length} '
        'first40=${ciphertext.substring(0, ciphertext.length < 40 ? ciphertext.length : 40)} '
        'parts_count=${parts.length}',
      );
      throw Exception(
        'Invalid ciphertext format: expected "base64(nonce).base64(ciphertext)"',
      );
    }

    final nonceBase64 = parts[0];
    final ct = parts[1];

    // 2. 验证 nonce（可选：与 e2ee 元数据中的 nonce 比对）
    final e2eeNonce = e2ee['nonce']?.toString();
    if (e2eeNonce != null && e2eeNonce.isNotEmpty && e2eeNonce != nonceBase64) {
      // nonce 不匹配可能是数据篡改或格式错误
      throw Exception('Nonce mismatch between ciphertext and e2ee metadata');
    }

    // 3. 找到当前设备的密钥
    final myDid = deviceId;
    final keys = e2ee['keys'] as List?;
    if (keys == null || keys.isEmpty) {
      throw Exception('No encryption keys found in e2ee metadata');
    }

    final myKey = keys
        .whereType<Map<String, dynamic>>()
        .map((x) => x.cast<String, dynamic>())
        .firstWhere(
          (k) => k['did'] == myDid,
          orElse: () => throw Exception('No key found for device: $myDid'),
        );

    // 4. 解密 AES 密钥
    final ekB64 = myKey['ek']?.toString() ?? '';
    if (ekB64.isEmpty) {
      throw Exception('Missing encrypted key (ek) in e2ee metadata');
    }

    final encKeyBytes = base64.decode(base64.normalize(ekB64));
    final kid = myKey['kid']?.toString() ?? '';
    final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(kid);
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      throw Exception('私钥不存在 (kid: $kid)');
    }
    final privateKeyObj = RSAService.parsePrivateKeyFromPem(privateKeyPem);
    final aesKey = RSAService.rsaDecrypt(
      privateKeyObj,
      Uint8List.fromList(encKeyBytes),
    );

    // 5. 解密消息
    // 使用 nonceBase64 作为 IV（与加密时一致）
    final plainBytes = aad != null && aad.isNotEmpty
        ? EncrypterService.aesGcmDecryptBytes(
            nonceBase64,
            ct,
            aesKey,
            aad: Uint8List.fromList(utf8.encode(aad)),
          )
        : EncrypterService.aesGcmDecryptBytes(nonceBase64, ct, aesKey);

    return utf8.decode(plainBytes);
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

        // 🔧 修复：如果 API 返回空列表但有缓存（未过期），使用缓存
        if (didToPem.isEmpty && forceRefresh) {
          final cached = _userKeyCacheByDevice[uid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_userKeyCacheTimestamp, uid)) {
            iPrint('⚠️ [E2EE] API 返回空，使用缓存: uid=$uid, 设备数=${cached.length}');
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
        for (final m in members) {
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
          }
        }

        // 🔧 修复：如果 API 返回空列表但有缓存（未过期），使用缓存
        if (didToPem.isEmpty && forceRefresh) {
          final cached = _groupKeyCacheByDevice[gid];
          if (cached != null &&
              cached.isNotEmpty &&
              !_isCacheExpired(_groupKeyCacheTimestamp, gid)) {
            iPrint('⚠️ [E2EE] API 返回空，使用缓存: gid=$gid, 设备数=${cached.length}');
            return _groupKeyResult(gid, cached);
          }
        }

        _groupKeyCacheByDevice[gid] = didToPem;
        _groupKidCacheByDevice[gid] = didToKid;
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
