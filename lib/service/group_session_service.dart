import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:synchronized/synchronized.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// Megolm 会话套件标识（e2ee 元数据 e2ee_suite 字段，区分既有 RSA+AES 套件）
const String kMegolmSuite = 'MEGOLM.V1';

/// E2EE 会话服务（vodozemac Megolm，C2G 群聊 + C2C 单聊统一走此套件）
///
/// 零信任架构：
/// - 每个发送者对每个会话域（群 gid / 单聊对端 uid）持有自己的 outbound
///   GroupSession（Megolm 标准语义，单聊即 2 人房间）；
/// - session key 在任何 encrypt 之前导出（棘轮推进后旧 index 不可再导出）；
/// - 导出 key 用接收方各设备 RSA-OAEP-256 公钥包裹，经具名 action
///   `e2ee_room_key` 消息分发（C2G/C2C 同名 action）——服务端视 payload 为
///   不透明字节（后端 EUnit c2g_e2ee_room_key_relayed_opaque_and_skips_gate
///   与 C2C 管道保真集成测试守护透传）；
/// - 接收方设备集合变化 → rotate（新建 session 全量重分发）；
/// - compliance_e2ee 模式：分发列表追加合规公钥包裹条目（审计可解密）。
class GroupSessionService {
  static final GroupSessionService _instance = GroupSessionService._internal();
  static GroupSessionService get to => _instance;
  GroupSessionService._internal();

  static const String _flagKeyPrefix = 'group_e2ee_mode_';
  static const String _inboundKeyPrefix = 'megolm_inbound_';
  static const String roomKeyAction = 'e2ee_room_key';

  /// room key 分发列表条目上限（成员×设备的合理倍数，防超大列表 CPU/内存 DoS）
  static const int _maxRoomKeyEntries = 4096;

  static bool _vodReady = false;
  static Future<void>? _initFuture;

  /// C2C 单聊的会话域前缀（outbound map 键 'c2c:$peerUid'，inbound 存储域 'c2c'）
  static const String c2cScope = 'c2c';

  /// 发送侧：会话域（gid / 'c2c:$peerUid'）→ outbound 会话状态
  final Map<String, _OutboundGroupSession> _outbound = {};

  /// 接收侧：'$storageScope:$sessionId' → inbound 会话（内存缓存，落地在安全存储）
  final Map<String, vod.InboundGroupSession> _inbound = {};

  /// 成员/设备集合可能已变化的会话域（S2C join/leave 标记，下次发送强刷公钥并 rotate）
  final Set<String> _staleGids = {};

  /// 每会话域一把发送锁：串行化 encrypt，避免 rotate 竞态（被踢成员前向保密缺口）
  final Map<String, Lock> _sendLocks = {};

  /// 懒加载 vodozemac 原生库（失败可重试）
  Future<void> ensureInitialized() async {
    if (_vodReady) return;
    _initFuture ??= fvod.init();
    try {
      await _initFuture;
      _vodReady = true;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  /// 测试专用：测试进程自行 vod.init(libraryPath:) 后标记就绪
  @visibleForTesting
  static void debugMarkVodReady() => _vodReady = true;

  // ===== 群级 E2EE 旗标（来源：S2C group_e2ee_mode 广播 / 群详情 / 收到 room key）=====

  /// 旗标存安全存储（与私钥同级保护，防本机篡改清零导致明文降级）
  Future<bool> isGroupE2EE(String gid) async {
    if (gid.isEmpty) return false;
    final v = await StorageSecureService.to.read(key: '$_flagKeyPrefix$gid');
    return v == '1';
  }

  Future<void> setGroupE2EEMode(String gid, int mode) async {
    // 后端契约 0→1 单向开启；本地只升不降（写 '1' 幂等，无需先读）。
    // 权威来源仅限服务端：group_e2ee_mode S2C 广播 + 群详情同步。
    if (gid.isEmpty || mode != 1) return;
    await StorageSecureService.to.write(key: '$_flagKeyPrefix$gid', value: '1');
    iPrint('[group_session] 群 $gid E2EE 已开启');
  }

  /// 群成员/设备变化标记：下次发送强刷公钥快照并 rotate
  void markGroupStale(String gid) {
    if (gid.isNotEmpty) _staleGids.add(gid);
  }

  // ===== 发送侧 =====

  /// 加密一条群消息；必要时自动建会话/rotate 并分发 room key。
  Future<({String sessionId, String ciphertext})> encryptGroupMessage({
    required String gid,
    required String plaintext,
  }) => _encryptScoped(
    scopeKey: gid,
    isGroup: true,
    target: gid,
    plaintext: plaintext,
  );

  /// 加密一条单聊消息（C2C 即 2 人 Megolm 房间，与群聊同一套件/分发机制）
  Future<({String sessionId, String ciphertext})> encryptC2CMessage({
    required String peerUid,
    required String plaintext,
  }) => _encryptScoped(
    scopeKey: '$c2cScope:$peerUid',
    isGroup: false,
    target: peerUid,
    plaintext: plaintext,
  );

  /// 同一会话域的并发发送串行化：stale 标记消费→公钥刷新→rotate→encrypt 必须原子，
  /// 否则被踢成员离群到 rotate 之间的窗口内会有新消息仍用旧 session（前向保密缺口）。
  Future<({String sessionId, String ciphertext})> _encryptScoped({
    required String scopeKey,
    required bool isGroup,
    required String target,
    required String plaintext,
  }) async {
    await ensureInitialized();
    final lock = _sendLocks.putIfAbsent(scopeKey, () => Lock());
    return lock.synchronized(() async {
      final force = _staleGids.remove(scopeKey);
      final deviceKeys = isGroup
          ? await E2EEService.getGroupDevicePublicKeys(
              target,
              forceRefresh: force,
            )
          : await E2EEService.getUserDevicePublicKeys(
              target,
              forceRefresh: force,
            );
      final didToPem = deviceKeys['didToPem'] ?? const <String, String>{};
      if (didToPem.isEmpty) {
        throw Exception('no_recipient_keys');
      }
      final didSet = didToPem.keys.toSet();

      var outbound = _outbound[scopeKey];
      if (outbound == null || !setEquals(outbound.dids, didSet)) {
        // ponytail: 任何成员/设备集合变化都整体 rotate + 全量重分发；
        // 若 key 消息量成为负担，可对"仅新增设备"改为 exportAt(当前 index) 定向补发
        outbound = await _rotateAndDistribute(
          isGroup: isGroup,
          target: target,
          didToPem: didToPem,
          didToKid: deviceKeys['didToKid'] ?? const <String, String>{},
          didSet: didSet,
        );
        _outbound[scopeKey] = outbound;
      }
      return (
        sessionId: outbound.sessionId,
        ciphertext: outbound.session.encrypt(plaintext),
      );
    });
  }

  Future<_OutboundGroupSession> _rotateAndDistribute({
    required bool isGroup,
    required String target,
    required Map<String, String> didToPem,
    required Map<String, String> didToKid,
    required Set<String> didSet,
  }) async {
    final session = vod.GroupSession();
    final sessionId = session.sessionId;
    // 棘轮语义：必须在任何 encrypt 之前导出（此后 exportAt(0) 返 null）
    final exported = session.toInbound().exportAt(0);
    if (exported == null || exported.isEmpty) {
      throw Exception('megolm_export_failed');
    }
    // 自持一份 inbound（本机换端恢复 / 历史重解密）
    await _storeInbound(isGroup ? target : c2cScope, sessionId, exported);

    final compliance = await _complianceKeyEntry(exported);
    final payload = buildRoomKeyPayload(
      gid: isGroup ? target : null,
      sessionId: sessionId,
      exportedKey: exported,
      didToPem: didToPem,
      didToKid: didToKid,
      extraKeys: compliance == null ? const [] : [compliance],
    );
    _sendRoomKeyMessage(isGroup ? 'C2G' : 'C2C', target, payload);
    iPrint(
      '[group_session] rotate scope=${isGroup ? target : '$c2cScope:$target'} '
      'session=$sessionId devices=${didSet.length}',
    );
    return _OutboundGroupSession(session, sessionId, didSet);
  }

  /// compliance_e2ee 模式：room key 额外用合规公钥包裹一份（审计侧可导入解密）；
  /// 获取失败降级为仅设备分发——与既有 RSA 套件 buildE2EEData 的行为一致。
  Future<Map<String, dynamic>?> _complianceKeyEntry(String exportedKey) async {
    if (EncryptionModeService.current != EncryptionMode.complianceE2ee) {
      return null;
    }
    try {
      final ck = await ComplianceKeyService.instance.getComplianceKey();
      if (ck == null) return null;
      return complianceEntryFor(exportedKey: exportedKey, key: ck);
    } on Object catch (e) {
      iPrint('[group_session] 合规密钥包装失败（降级为仅设备分发）: $e');
      return null;
    }
  }

  /// room key 经既有 C2G/C2C 通道分发（具名 action：服务端零查库放行、payload
  /// 不透明透传、save 语义离线接收方重连可拉取、websocket 队列离线兜底）
  void _sendRoomKeyMessage(
    String chatType,
    String to,
    Map<String, dynamic> payload,
  ) {
    final msgId =
        'rk_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(999999)}';
    final msg = {
      'id': msgId,
      'type': chatType,
      'to': to,
      'msg_type': roomKeyAction,
      'action': roomKeyAction,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    WebSocketService.to.sendMessage(jsonEncode(msg), msgId);
  }

  // ===== 接收侧 =====

  /// 处理入站 e2ee_room_key 消息（message_actions.dart 分发过来）
  Future<void> handleRoomKeyMessage(Map<String, dynamic> data) async {
    try {
      final payload = parseModelJsonMap(data['payload']);
      if (payload == null) return;
      if (payload['msg_type']?.toString() != roomKeyAction) return;

      // 域一致性校验（安全关键）：opaque payload 声明的域（gid/scope）必须与后端
      // 已鉴权的传输层字段（type + to）一致，否则任意用户可构造 type=C2G,to=群A
      // 但 payload.gid=群B 的消息，向"自己无权限"的群 B 命名空间注入伪造 session。
      // 后端对 e2ee_room_key 仅按 type+to 校验 is_member，故域必须锚定 type+to。
      final envelopeType = data['type']?.toString();
      final envelopeTo = data['to']?.toString() ?? '';
      final scope = payload['scope']?.toString() ?? '';
      String gid = payload['gid']?.toString() ?? '';
      if (gid.isEmpty && scope != c2cScope && envelopeType == 'C2G') {
        gid = envelopeTo; // 旧版群 payload 缺 gid，仅 C2G 通道回退到已鉴权目标
      }
      if (gid.isNotEmpty) {
        // 群 key 只能来自对应群的 C2G 通道（gid 必须等于后端校验过的 is_member 目标）
        if (envelopeType != 'C2G' || gid != envelopeTo) {
          AppLogger.error('[group_session] 群 room key 域不匹配，丢弃 gid=$gid');
          return;
        }
      } else if (scope == c2cScope) {
        // 单聊 key 只能来自 C2C 通道（session_id 高熵全局唯一，无需锚定 to）
        if (envelopeType != 'C2C') {
          AppLogger.error('[group_session] c2c room key 非 C2C 通道，丢弃');
          return;
        }
      } else {
        return; // 既非群 key 也非 c2c key，无法判定会话域
      }
      final storageScope = gid.isNotEmpty ? gid : c2cScope;
      final sessionId = payload['session_id']?.toString() ?? '';
      final keys = payload['keys'];
      if (sessionId.isEmpty || keys is! List) {
        return;
      }
      if (keys.length > _maxRoomKeyEntries) {
        AppLogger.error(
          '[group_session] room key keys 超限，丢弃 scope=$storageScope',
        );
        return;
      }

      final entry = pickMyKeyEntry(keys, deviceId);
      if (entry == null) return; // 本设备不在分发列表

      final kid = entry['kid']?.toString() ?? '';
      final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(
        kid,
      );
      if (privateKeyPem == null || privateKeyPem.isEmpty) {
        AppLogger.error('[group_session] room key 私钥不存在 kid=$kid');
        return;
      }
      final exported = unwrapSessionKey(
        ek: entry['ek']?.toString() ?? '',
        privateKeyPem: privateKeyPem,
      );

      await ensureInitialized();
      final inbound = vod.InboundGroupSession.import(exported);
      if (inbound.sessionId != sessionId) {
        AppLogger.error(
          '[group_session] session_id 不匹配，丢弃 scope=$storageScope',
        );
        return;
      }
      _inbound['$storageScope:$sessionId'] = inbound;
      await StorageSecureService.to.write(
        key: '$_inboundKeyPrefix$storageScope:$sessionId',
        value: exported,
      );
      // 安全：不从 room key 反推群策略旗标——e2ee_room_key 是任意成员可发的 C2G
      // 具名 action（后端仅校验 is_member，不校验群主/群 e2ee_mode），据此翻转
      // 本地强制加密旗标会让普通成员越权触发"仅群主可决策"的群级策略。旗标权威
      // 来源仅限服务端：group_e2ee_mode S2C 广播 + group_api 群详情同步。
      // 这里只存 inbound key 供解密收到的密文，不改旗标。
      iPrint(
        '[group_session] 收到 room key scope=$storageScope session=$sessionId',
      );
    } on Object catch (e, s) {
      AppLogger.error('[group_session] handleRoomKeyMessage error', e, s);
    }
  }

  /// 解密 Megolm 群消息（E2EEService.decryptE2EEMessage 按 e2ee_suite 委托过来）
  Future<String> decryptGroupMessage({
    required String gid,
    required String sessionId,
    required String ciphertext,
  }) => _decryptScoped(gid, sessionId, ciphertext);

  /// 解密 Megolm 单聊消息（session_id 全局唯一，C2C 统一存 'c2c' 域）
  Future<String> decryptC2CMessage({
    required String sessionId,
    required String ciphertext,
  }) => _decryptScoped(c2cScope, sessionId, ciphertext);

  Future<String> _decryptScoped(
    String storageScope,
    String sessionId,
    String ciphertext,
  ) async {
    await ensureInitialized();
    var inbound = _inbound['$storageScope:$sessionId'];
    if (inbound == null) {
      final exported = await StorageSecureService.to.read(
        key: '$_inboundKeyPrefix$storageScope:$sessionId',
      );
      if (exported == null || exported.isEmpty) {
        throw Exception(
          'no key found for device: megolm $storageScope/$sessionId',
        );
      }
      inbound = vod.InboundGroupSession.import(exported);
      _inbound['$storageScope:$sessionId'] = inbound;
    }
    return inbound.decrypt(ciphertext).plaintext;
  }

  Future<void> _storeInbound(
    String storageScope,
    String sessionId,
    String exported,
  ) async {
    _inbound['$storageScope:$sessionId'] = vod.InboundGroupSession.import(
      exported,
    );
    await StorageSecureService.to.write(
      key: '$_inboundKeyPrefix$storageScope:$sessionId',
      value: exported,
    );
  }

  // ===== 纯函数（可独立单测，不依赖原生库）=====

  /// 组装 room key 分发 payload：导出 key 逐设备 RSA-OAEP-256 包裹。
  /// [gid] 非空 → 群 payload；空/null → C2C payload（带 scope='c2c'）。
  /// [extraKeys] 追加条目（如合规审计包裹），不参与设备集合比较。
  static Map<String, dynamic> buildRoomKeyPayload({
    String? gid,
    required String sessionId,
    required String exportedKey,
    required Map<String, String> didToPem,
    required Map<String, String> didToKid,
    List<Map<String, dynamic>> extraKeys = const [],
  }) {
    final keys = <Map<String, dynamic>>[];
    for (final entry in didToPem.entries) {
      keys.add({
        'did': entry.key,
        'kid': didToKid[entry.key] ?? entry.key,
        'wrap_alg': 'RSA-OAEP-256',
        'ek': wrapSessionKey(
          exportedKey: exportedKey,
          publicKeyPem: entry.value,
        ),
      });
    }
    keys.addAll(extraKeys);
    return {
      'msg_type': roomKeyAction,
      if (gid != null && gid.isNotEmpty) 'gid': gid,
      if (gid == null || gid.isEmpty) 'scope': c2cScope,
      'session_id': sessionId,
      'alg': kMegolmSuite,
      'keys': keys,
    };
  }

  /// 组装合规审计密钥条目（纯函数，供 _complianceKeyEntry 与单测复用）
  static Map<String, dynamic> complianceEntryFor({
    required String exportedKey,
    required ComplianceKeyInfo key,
  }) => {
    'did': 'compliance-audit',
    'kid': key.keyId,
    'wrap_alg': 'RSA-OAEP-256',
    'ek': wrapSessionKey(exportedKey: exportedKey, publicKeyPem: key.publicKey),
  };

  /// 在 keys 列表中找到本设备条目
  static Map<String, dynamic>? pickMyKeyEntry(List<dynamic> keys, String did) {
    for (final k in keys) {
      if (k is Map && k['did']?.toString() == did) {
        return Map<String, dynamic>.from(k);
      }
    }
    return null;
  }

  /// RSA-OAEP-256 包裹导出的 session key（导出 key ≈165B < OAEP-2048 上限 190B，单次可装）
  static String wrapSessionKey({
    required String exportedKey,
    required String publicKeyPem,
  }) {
    final keyBytes = base64.decode(base64.normalize(exportedKey));
    final pub = RSAService.parsePublicKeyFromPem(publicKeyPem);
    final wrapped = RSAService.rsaEncrypt(pub, Uint8List.fromList(keyBytes));
    return base64.encode(wrapped);
  }

  /// 解包并重编码为 unpadded base64（vodozemac 期望无填充）
  static String unwrapSessionKey({
    required String ek,
    required String privateKeyPem,
  }) {
    final wrapped = base64.decode(base64.normalize(ek));
    final priv = RSAService.parsePrivateKeyFromPem(privateKeyPem);
    final keyBytes = RSAService.rsaDecrypt(priv, Uint8List.fromList(wrapped));
    return base64.encode(keyBytes).replaceAll('=', '');
  }
}

class _OutboundGroupSession {
  _OutboundGroupSession(this.session, this.sessionId, this.dids);
  final vod.GroupSession session;
  final String sessionId;
  final Set<String> dids;
}
