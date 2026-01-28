import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:imboy/config/init.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/e2ee_settings.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/store/api/e2ee_api.dart';

class E2EEService {
  static final Map<String, Map<String, String>> _userKeyCacheByDevice = {};
  static final Map<String, Map<String, String>> _groupKeyCacheByDevice = {};

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
  }

  /// 检查是否需要对消息进行端到端加密
  ///
  /// WebSocket API v2.0: msg_type/action 在顶层，不在 payload 内
  ///
  /// ## 加密条件（全部满足）
  /// 1. E2EE功能已启用（通过[E2EESettings.isEnabled]检查）
  /// 2. 消息类型为 C2C 或 C2G
  /// 3. 非action操作消息（action消息不加密）
  static bool shouldEncryptOutgoingPayload(
    String msgType,
    Map<String, dynamic> payload,
  ) {
    // 检查E2EE全局开关（用户设置）
    if (!E2EESettings.isEnabled()) {
      return false;
    }

    // 只对 C2C 和 C2G 消息加密
    if (msgType != 'C2C' && msgType != 'C2G') return false;

    // 注意：不再检查 payload 中的 msg_type/action（v2.0 中它们在顶层）
    // action检查由调用方完成（通过msgAction参数）
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
  ///   'e2ee': result['e2ee'],           // 元数据放入 e2ee（Map）
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
        .whereType<Map>()
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
    final privateKeyObj = await RSAService.privateKeyObject();
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

  static Future<Map<String, dynamic>> encryptC2C({
    required String msgId,
    required String fromUid,
    required String toUid,
    required int createdAt,
    required Map<String, dynamic> plaintextPayload,
  }) async {
    final deviceKeys = await _getUserDevicePublicKeys(toUid);
    final didToPem = deviceKeys['didToPem']!;
    final senderDid = deviceId;
    if (didToPem.isEmpty) {
      throw Exception('no_recipient_keys');
    }

    final aesKey = _secureRandomBytes(32);
    final aad = utf8.encode('$msgId|$fromUid|$toUid|$createdAt|$senderDid');
    final encrypted = EncrypterService.aesGcmEncryptBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(plaintextPayload))),
      aesKey,
      aad: Uint8List.fromList(aad),
    );

    final recipients = <Map<String, dynamic>>[];
    for (final entry in didToPem.entries) {
      final did = entry.key;
      final pem = entry.value;
      final pubKey = RSAService.parsePublicKeyFromPem(pem);
      final ek = RSAService.rsaEncrypt(pubKey, aesKey);
      recipients.add({'did': did, 'ek': base64.encode(ek)});
    }

    final sigInput = utf8.encode(
      '$msgId|$fromUid|$toUid|$createdAt|$senderDid|${encrypted['iv']}|${encrypted['ct']}',
    );
    final privateKeyObj = await RSAService.privateKeyObject();
    final sig = RSAService.rsaSign(privateKeyObj, Uint8List.fromList(sigInput));

    // WebSocket API v2.0: 只返回 e2ee 元数据，不包含 msg_type
    // msg_type 应该由调用者设置（保留原始类型：text, image 等）
    return {
      'e2ee': {
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        'sender_did': senderDid,
        'iv': encrypted['iv'],
        'ct': encrypted['ct'],
        'recipients': recipients,
        'sig': base64.encode(sig),
      },
    };
  }

  static Future<Map<String, dynamic>> encryptC2G({
    required String msgId,
    required String fromUid,
    required String gid,
    required int createdAt,
    required Map<String, dynamic> plaintextPayload,
  }) async {
    final deviceKeys = await _getGroupDevicePublicKeys(gid);
    final didToPem = deviceKeys['didToPem']!;
    final senderDid = deviceId;
    if (didToPem.isEmpty) {
      throw Exception('no_recipient_keys');
    }

    final aesKey = _secureRandomBytes(32);
    final aad = utf8.encode('$msgId|$fromUid|$gid|$createdAt|$senderDid');
    final encrypted = EncrypterService.aesGcmEncryptBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(plaintextPayload))),
      aesKey,
      aad: Uint8List.fromList(aad),
    );

    final recipients = <Map<String, dynamic>>[];
    for (final entry in didToPem.entries) {
      final did = entry.key;
      final pem = entry.value;
      final pubKey = RSAService.parsePublicKeyFromPem(pem);
      final ek = RSAService.rsaEncrypt(pubKey, aesKey);
      recipients.add({'did': did, 'ek': base64.encode(ek)});
    }

    final sigInput = utf8.encode(
      '$msgId|$fromUid|$gid|$createdAt|$senderDid|${encrypted['iv']}|${encrypted['ct']}',
    );
    final privateKeyObj = await RSAService.privateKeyObject();
    final sig = RSAService.rsaSign(privateKeyObj, Uint8List.fromList(sigInput));

    // WebSocket API v2.0: 只返回 e2ee 元数据，不包含 msg_type
    // msg_type 应该由调用者设置（保留原始类型：text, image 等）
    return {
      'e2ee': {
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        'sender_did': senderDid,
        'scope': 'group',
        'gid': gid,
        'iv': encrypted['iv'],
        'ct': encrypted['ct'],
        'recipients': recipients,
        'sig': base64.encode(sig),
      },
    };
  }

  /// 解密接收到的消息 payload
  ///
  /// ## v2.0 支持
  /// - v2.0 E2EE: payload 为字符串（密文），e2ee 元数据在顶层
  /// - v1.0 E2EE: payload 为 Map，包含 e2ee 字段
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
  /// ## v1.0 E2EE 格式
  /// ```json
  /// {
  ///   "msg_type": "e2ee",
  ///   "e2ee": {
  ///     "v": 1,
  ///     "alg": "rsa-oaep+aes-256-gcm",
  ///     "sender_did": "device1",
  ///     "iv": "base64_iv",
  ///     "ct": "base64_ciphertext",
  ///     "recipients": [
  ///       {"did": "deviceA", "ek": "base64_wrapped_key"}
  ///     ],
  ///     "sig": "base64_signature"
  ///   }
  /// }
  /// ```
  ///
  /// 返回解密后的 payload，如果解密失败则返回包含 `_e2ee_failed` 标记的 payload
  static Future<Map<String, dynamic>> decryptIncomingPayload({
    required String msgId,
    required String msgType,
    required String fromUid,
    required String toUid,
    required int createdAt,
    required Map<String, dynamic> payload,
  }) async {
    // 检查是否为 E2EE 消息
    // WebSocket API v2.0: 只检查 e2ee 字段是否存在（不再检查 msg_type == 'e2ee'）
    // v1.0 格式（msg_type == 'e2ee'）已废弃
    final e2ee = payload['e2ee'];
    final isV2Format = e2ee != null && e2ee != '';

    if (!isV2Format) return payload;

    final e2eeData = e2ee is Map ? e2ee.cast<String, dynamic>() : null;
    if (e2eeData is! Map) {
      // 解密失败时保留原始 msg_type，不修改为 'custom'
      return _decryptFailedPayload(
        payload,
        msgType: msgType,
        reason: 'invalid_e2ee',
      );
    }

    final e = e2ee.cast<String, dynamic>();

    // v2.0 格式支持（v1.0 已废弃）
    final isV2 = payload['_e2ee_v2'] == true;

    // v2.0: 从 keys 数组中查找当前设备的密钥
    final keysOrRecipients = e['keys'] ?? e['recipients'];
    if (keysOrRecipients is! List) {
      return _decryptFailedPayload(
        payload,
        msgType: msgType,
        reason: 'invalid_recipients',
      );
    }

    final myDid = deviceId;
    final me = keysOrRecipients
        .whereType<Map>()
        .map((x) => x.cast<String, dynamic>())
        .firstWhere(
          (r) => r['did'] == myDid || r['device_id'] == myDid,
          orElse: () => {},
        );
    if (me.isEmpty) {
      return _decryptFailedPayload(
        payload,
        msgType: msgType,
        reason: 'no_device_key',
      );
    }

    // 提取加密密钥、IV 和密文
    final ekB64 = me['ek']?.toString() ?? me['encrypted_key']?.toString() ?? '';
    String iv = '';
    String ct = '';

    if (isV2) {
      // v2.0: ciphertext 格式为 "base64(nonce).base64(ciphertext)"
      // e2ee 元数据中包含 nonce
      final ciphertext = e['ciphertext']?.toString() ?? '';
      if (ciphertext.isEmpty) {
        return _decryptFailedPayload(
          payload,
          msgType: msgType,
          reason: 'missing_ciphertext',
        );
      }

      // 分割 nonce 和密文
      final parts = ciphertext.split('.');
      if (parts.length != 2) {
        return _decryptFailedPayload(
          payload,
          msgType: msgType,
          reason: 'invalid_ciphertext_format',
        );
      }

      iv = parts[0]; // nonce (IV)
      ct = parts[1]; // 实际密文
    } else {
      // v1.0 格式已废弃，但保留兼容性
      iv = e['nonce']?.toString() ?? e['iv']?.toString() ?? '';
      ct = e['ciphertext']?.toString() ?? e['ct']?.toString() ?? '';
    }

    if (iv.isEmpty || ct.isEmpty || ekB64.isEmpty) {
      return _decryptFailedPayload(
        payload,
        msgType: msgType,
        reason: 'missing_fields',
      );
    }

    try {
      // 1. 使用私钥解密 AES 密钥
      final encKeyBytes = base64.decode(base64.normalize(ekB64));
      final privateKeyObj = await RSAService.privateKeyObject();
      final aesKey = RSAService.rsaDecrypt(
        privateKeyObj,
        Uint8List.fromList(encKeyBytes),
      );

      // 2. 使用 AES 密钥解密消息
      final senderDid =
          payload['sender_did']?.toString() ??
          e['sender_did']?.toString() ??
          '';
      final aad = utf8.encode('$msgId|$fromUid|$toUid|$createdAt|$senderDid');
      final plainBytes = EncrypterService.aesGcmDecryptBytes(
        iv,
        ct,
        aesKey,
        aad: Uint8List.fromList(aad),
      );

      // 3. 解析明文
      final decoded = jsonDecode(utf8.decode(plainBytes));
      if (decoded is! Map) {
        return _decryptFailedPayload(
          payload,
          msgType: msgType,
          reason: 'invalid_plaintext',
        );
      }

      final plain = decoded.cast<String, dynamic>();

      // 4. 保留原始元数据
      if (payload.containsKey('client_send_ts')) {
        plain['client_send_ts'] = payload['client_send_ts'];
      }
      if (plain['sender_did'] == null) {
        final injected = payload['sender_did'];
        final fromEnvelope = e['sender_did'];
        if (injected != null) {
          plain['sender_did'] = injected;
        } else if (fromEnvelope != null) {
          plain['sender_did'] = fromEnvelope;
        }
      }
      if (payload.containsKey('sender_dtype')) {
        plain['sender_dtype'] = payload['sender_dtype'];
      }
      if (plain['_e2ee'] == null) {
        plain['_e2ee'] = payload;
      }

      // 5. 验证签名（如果存在）
      final sigB64 = e['signature']?.toString() ?? e['sig']?.toString() ?? '';
      if (sigB64.isNotEmpty) {
        Map<String, String> didToPem = {};
        if (msgType == 'C2G') {
          didToPem = (await _getGroupDevicePublicKeys(toUid))['didToPem']!;
        } else if (msgType == 'C2C') {
          didToPem = (await _getUserDevicePublicKeys(fromUid))['didToPem']!;
        }
        final ok = didToPem.isEmpty
            ? false
            : _verifySignatureWithKeys(
                didToPem: didToPem,
                msgId: msgId,
                fromUid: fromUid,
                toUid: toUid,
                createdAt: createdAt,
                senderDid: senderDid,
                iv: iv,
                ct: ct,
                sigB64: sigB64,
              );
        plain['_e2ee_verified'] = ok;
      }

      return plain;
    } catch (e) {
      return _decryptFailedPayload(
        payload,
        msgType: msgType,
        reason: 'decrypt_error',
      );
    }
  }

  static bool _verifySignatureWithKeys({
    required Map<String, String> didToPem,
    required String msgId,
    required String fromUid,
    required String toUid,
    required int createdAt,
    required String senderDid,
    required String iv,
    required String ct,
    required String sigB64,
  }) {
    if (senderDid.isEmpty) return false;
    final pem = didToPem[senderDid];
    if (pem == null || pem.isEmpty) return false;
    final pubKey = RSAService.parsePublicKeyFromPem(pem);
    final sig = base64.decode(base64.normalize(sigB64));
    final sigInput = utf8.encode(
      '$msgId|$fromUid|$toUid|$createdAt|$senderDid|$iv|$ct',
    );
    return RSAService.rsaVerify(
      pubKey,
      Uint8List.fromList(sigInput),
      Uint8List.fromList(sig),
    );
  }

  static Map<String, dynamic> _decryptFailedPayload(
    Map<String, dynamic> payload, {
    required String msgType,
    required String reason,
  }) {
    return {
      'msg_type': msgType, // 保留原始消息类型
      'custom_type': 'e2ee',
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
  }) async {
    // 检查缓存
    final cached = _userKeyCacheByDevice[uid];
    if (cached != null && cached.isNotEmpty) {
      return {'didToPem': cached};
    }

    // 带重试的获取逻辑
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final list = await E2EEApi().userKeys(uid: uid);
        final didToPem = <String, String>{};
        for (final row in list) {
          final did = row['device_id']?.toString() ?? '';
          final pem = row['public_key']?.toString() ?? '';
          if (did.isEmpty || pem.isEmpty) continue;
          didToPem[did] = pem;
        }
        _userKeyCacheByDevice[uid] = didToPem;
        return {'didToPem': didToPem};
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          iPrint('获取用户设备密钥失败（已重试$maxRetries次）: $e');
          rethrow;
        }
        iPrint('获取用户设备密钥失败，第$attempt次重试...');
        await Future.delayed(retryDelay);
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
  }) async {
    // 检查缓存
    final cached = _groupKeyCacheByDevice[gid];
    if (cached != null && cached.isNotEmpty) {
      return {'didToPem': cached};
    }

    // 带重试的获取逻辑
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final members = await E2EEApi().groupMemberKeys(gid: gid);
        final didToPem = <String, String>{};
        for (final m in members) {
          final devices = m['devices'];
          if (devices is! List) continue;
          for (final d in devices.whereType<Map>()) {
            final row = d.cast<String, dynamic>();
            final did = row['device_id']?.toString() ?? '';
            final pem = row['public_key']?.toString() ?? '';
            if (did.isEmpty || pem.isEmpty) continue;
            didToPem[did] = pem;
          }
        }
        _groupKeyCacheByDevice[gid] = didToPem;
        return {'didToPem': didToPem};
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          iPrint('获取群组设备密钥失败（已重试$maxRetries次）: $e');
          rethrow;
        }
        iPrint('获取群组设备密钥失败，第$attempt次重试...');
        await Future.delayed(retryDelay);
      }
    }

    // 理论上不会到达这里
    throw Exception(
      'Failed to get group device keys after $maxRetries attempts',
    );
  }

  /// 内部方法：获取用户设备公钥（保留向后兼容）
  static Future<Map<String, Map<String, String>>> _getUserDevicePublicKeys(
    String uid,
  ) async {
    return getUserDevicePublicKeys(uid);
  }

  /// 内部方法：获取群组设备公钥（保留向后兼容）
  static Future<Map<String, Map<String, String>>> _getGroupDevicePublicKeys(
    String gid,
  ) async {
    return getGroupDevicePublicKeys(gid);
  }

  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return Uint8List.fromList(bytes);
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
