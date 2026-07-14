import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:synchronized/synchronized.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee_social_service.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// Megolm 群会话套件标识（e2ee 元数据 e2ee_suite 字段，区分既有 RSA+AES 套件）
const String kMegolmSuite = 'MEGOLM.V1';

/// 群级 E2EE 会话服务（P0-B B4，vodozemac Megolm）
///
/// 零信任架构：
/// - 每个发送者持有自己的 outbound GroupSession（Megolm 标准语义）；
/// - session key 在任何 encrypt 之前导出（棘轮推进后旧 index 不可再导出）；
/// - 导出 key 用群成员各设备 RSA-OAEP-256 公钥包裹，经 C2G 具名 action
///   `e2ee_room_key` 消息分发——服务端视 payload 为不透明字节（后端 EUnit
///   c2g_e2ee_room_key_relayed_opaque_and_skips_gate 守护逐字节透传）；
/// - 成员/设备集合变化 → rotate（新建 session 全量重分发）。
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

  /// 发送侧：gid → outbound 会话状态
  final Map<String, _OutboundGroupSession> _outbound = {};

  /// 接收侧：'$gid:$sessionId' → inbound 会话（内存缓存，落地在安全存储）
  final Map<String, vod.InboundGroupSession> _inbound = {};

  /// 成员/设备集合可能已变化的群（S2C join/leave 标记，下次发送强刷公钥并 rotate）
  final Set<String> _staleGids = {};

  /// 每群一把发送锁：串行化 encrypt，避免 rotate 竞态（被踢成员前向保密缺口）
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
  /// 同一 gid 的并发发送串行化：stale 标记消费→公钥刷新→rotate→encrypt 必须原子，
  /// 否则被踢成员离群到 rotate 之间的窗口内会有新消息仍用旧 session（前向保密缺口）。
  Future<({String sessionId, String ciphertext})> encryptGroupMessage({
    required String gid,
    required String plaintext,
  }) async {
    await ensureInitialized();
    final lock = _sendLocks.putIfAbsent(gid, () => Lock());
    return lock.synchronized(() async {
      final force = _staleGids.remove(gid);
      final deviceKeys = await E2EEService.getGroupDevicePublicKeys(
        gid,
        forceRefresh: force,
      );
      final didToPem = deviceKeys['didToPem'] ?? const <String, String>{};
      if (didToPem.isEmpty) {
        throw Exception('no_recipient_keys');
      }
      final didSet = didToPem.keys.toSet();

      var outbound = _outbound[gid];
      if (outbound == null || !setEquals(outbound.dids, didSet)) {
        // ponytail: 任何成员/设备集合变化都整体 rotate + 全量重分发；
        // 若 key 消息量成为负担，可对"仅新增设备"改为 exportAt(当前 index) 定向补发
        outbound = await _rotateAndDistribute(
          gid,
          didToPem,
          deviceKeys['didToKid'] ?? const <String, String>{},
          didSet,
        );
        _outbound[gid] = outbound;
      }
      return (
        sessionId: outbound.sessionId,
        ciphertext: outbound.session.encrypt(plaintext),
      );
    });
  }

  Future<_OutboundGroupSession> _rotateAndDistribute(
    String gid,
    Map<String, String> didToPem,
    Map<String, String> didToKid,
    Set<String> didSet,
  ) async {
    final session = vod.GroupSession();
    final sessionId = session.sessionId;
    // 棘轮语义：必须在任何 encrypt 之前导出（此后 exportAt(0) 返 null）
    final exported = session.toInbound().exportAt(0);
    if (exported == null || exported.isEmpty) {
      throw Exception('megolm_export_failed');
    }
    // 自持一份 inbound（本机换端恢复 / 历史重解密）
    await _storeInbound(gid, sessionId, exported);

    final payload = buildRoomKeyPayload(
      gid: gid,
      sessionId: sessionId,
      exportedKey: exported,
      didToPem: didToPem,
      didToKid: didToKid,
    );
    _sendRoomKeyMessage(gid, payload);
    iPrint(
      '[group_session] rotate gid=$gid session=$sessionId devices=${didSet.length}',
    );
    return _OutboundGroupSession(session, sessionId, didSet);
  }

  /// room key 经既有 C2G 通道分发（具名 action：服务端零查库放行、payload 不透明透传、
  /// save 语义离线成员重连可拉取、websocket 队列离线兜底）
  void _sendRoomKeyMessage(String gid, Map<String, dynamic> payload) {
    final msgId = E2EESocialService.generateMessageId();
    final msg = {
      'id': msgId,
      'type': 'C2G',
      'to': gid,
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
      final gid = payload['gid']?.toString() ?? data['to']?.toString() ?? '';
      final sessionId = payload['session_id']?.toString() ?? '';
      final keys = payload['keys'];
      if (gid.isEmpty || sessionId.isEmpty || keys is! List) return;
      if (keys.length > _maxRoomKeyEntries) {
        AppLogger.error('[group_session] room key keys 超限，丢弃 gid=$gid');
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
        AppLogger.error('[group_session] session_id 不匹配，丢弃 gid=$gid');
        return;
      }
      _inbound['$gid:$sessionId'] = inbound;
      await StorageSecureService.to.write(
        key: '$_inboundKeyPrefix$gid:$sessionId',
        value: exported,
      );
      // 安全：不从 room key 反推群策略旗标——e2ee_room_key 是任意成员可发的 C2G
      // 具名 action（后端仅校验 is_member，不校验群主/群 e2ee_mode），据此翻转
      // 本地强制加密旗标会让普通成员越权触发"仅群主可决策"的群级策略。旗标权威
      // 来源仅限服务端：group_e2ee_mode S2C 广播 + group_api 群详情同步。
      // 这里只存 inbound key 供解密收到的密文，不改旗标。
      iPrint('[group_session] 收到 room key gid=$gid session=$sessionId');
    } on Object catch (e, s) {
      AppLogger.error('[group_session] handleRoomKeyMessage error', e, s);
    }
  }

  /// 解密 Megolm 群消息（E2EEService.decryptE2EEMessage 按 e2ee_suite 委托过来）
  Future<String> decryptGroupMessage({
    required String gid,
    required String sessionId,
    required String ciphertext,
  }) async {
    await ensureInitialized();
    var inbound = _inbound['$gid:$sessionId'];
    if (inbound == null) {
      final exported = await StorageSecureService.to.read(
        key: '$_inboundKeyPrefix$gid:$sessionId',
      );
      if (exported == null || exported.isEmpty) {
        throw Exception('no key found for device: megolm $gid/$sessionId');
      }
      inbound = vod.InboundGroupSession.import(exported);
      _inbound['$gid:$sessionId'] = inbound;
    }
    return inbound.decrypt(ciphertext).plaintext;
  }

  Future<void> _storeInbound(
    String gid,
    String sessionId,
    String exported,
  ) async {
    _inbound['$gid:$sessionId'] = vod.InboundGroupSession.import(exported);
    await StorageSecureService.to.write(
      key: '$_inboundKeyPrefix$gid:$sessionId',
      value: exported,
    );
  }

  // ===== 纯函数（可独立单测，不依赖原生库）=====

  /// 组装 room key 分发 payload：导出 key 逐设备 RSA-OAEP-256 包裹
  static Map<String, dynamic> buildRoomKeyPayload({
    required String gid,
    required String sessionId,
    required String exportedKey,
    required Map<String, String> didToPem,
    required Map<String, String> didToKid,
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
    return {
      'msg_type': roomKeyAction,
      'gid': gid,
      'session_id': sessionId,
      'alg': kMegolmSuite,
      'keys': keys,
    };
  }

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
